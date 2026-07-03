import Foundation
import Observation
import SwiftUI

/// Per-call context for the interaction coordinator.
///
/// `cellID` and `manager` are read fresh from the modifier on every `body` pass rather than frozen in
/// the coordinator, so a row that reuses a SwiftUI identity with a new id or a different scope manager
/// always coordinates against the current values.
struct SwipeCellInteractionInputs {
    let cellID: AnyHashable
    let manager: SwipeCellManager?
    let configuration: SwipeCellConfiguration
    let settlingAnimation: Animation
    let isInteractionEnabled: Bool
    let destructiveTrigger: (SwipeCellSide) -> SwipeCellDestructiveTrigger?

    init(
        cellID: AnyHashable,
        manager: SwipeCellManager?,
        configuration: SwipeCellConfiguration = .platformDefault,
        settlingAnimation: Animation,
        isInteractionEnabled: Bool = true,
        destructiveTrigger: @escaping (SwipeCellSide) -> SwipeCellDestructiveTrigger? = { _ in nil }
    ) {
        self.cellID = cellID
        self.manager = manager
        self.configuration = configuration
        self.settlingAnimation = settlingAnimation
        self.isInteractionEnabled = isInteractionEnabled
        self.destructiveTrigger = destructiveTrigger
    }
}

struct SwipeCellDestructiveTrigger {
    let action: SwipeAction
    let completion: SwipeActionCompletion
}

nonisolated enum SwipeCellHapticEventKind: Equatable, Sendable {
    case arm
    case disarm
}

nonisolated struct SwipeCellHapticEvent: Equatable, Sendable {
    let id: Int
    let kind: SwipeCellHapticEventKind
}

/// Owns one row's swipe interaction state and the gesture → decision → offset/settle flow, shared by
/// the `swipeCellIdentity` escape hatch and the declarative `swipeCellActions` path.
///
/// Centralizing it keeps the no-animation active-drag transaction, the deferred settling, the
/// reset-token collapse, the directional lock, and the settling-side lifecycle defined once instead of
/// duplicated per entry point — so later destructive trigger / haptic / fire-timing work has a single
/// place to attach rather than two parallel modifiers to keep in sync.
@Observable
final class SwipeCellInteractionCoordinator: SwipeCellDestructiveTriggerHost {
    private(set) var contentOffset: CGFloat = 0
    private(set) var normalOpenProgress: CGFloat = 0
    private(set) var deformationProgress: CGFloat = 0
    private(set) var isArmed = false
    private(set) var armChangeID = 0
    private(set) var armChangeKind: SwipeActionArmChangeKind?
    private(set) var hapticEvent: SwipeCellHapticEvent?
    /// SwiftUI state jumps to the target value before animating; keep the last revealed side alive so
    /// actions can visually settle closed with the content instead of vanishing on the reset frame.
    private(set) var settlingSide: SwipeCellSide?
    /// During destructive close-to-zero, keep the takeover face mounted for the same visual settle
    /// window as `settlingSide`; otherwise SwiftUI applies the target unarmed values before animating.
    private(set) var takeoverSettlingSide: SwipeCellSide?
    /// Local gate for automatic open/close/reset animations. The manager covers shared owner
    /// transitions; this row-local flag also covers animated programmatic opens before manager state can
    /// describe an in-flight render.
    @ObservationIgnored private(set) var isAutomaticInputSuppressed = false
    /// Epoch key for value-keyed forced-reset close animation. It changes only when the visible row
    /// owns an animated close-to-zero, keeping release settles and active drags transparent.
    private(set) var closeToken = 0
    @ObservationIgnored private let forcedResetCloseController = SwipeCellForcedResetCloseController()
    @ObservationIgnored private var gestureStartSide: SwipeCellSide?
    /// Gesture-relative clock for direct-touch fast intent arbitration and diagnostics.
    @ObservationIgnored private var gestureStartTimestamp: TimeInterval?
    /// Per-gesture closed-origin fast-open preflight. It keeps raw intent classification separate from
    /// the visible movement rendered during active drag.
    @ObservationIgnored private var directTouchFastIntent = SwipeCellDirectTouchFastIntent()
    /// Locks layout-derived interaction geometry for the active gesture. Width changes should affect the
    /// next gesture, not retarget thresholds or settling while a drag/scroll-swipe is already underway.
    @ObservationIgnored private var gestureModel: SwipeCellInteractionModel?
    @ObservationIgnored private let resetGenerationTracker = SwipeCellResetGenerationTracker()
    @ObservationIgnored private let tapCloseSuppression = SwipeCellTapCloseSuppression()
    @ObservationIgnored private let hapticThrottle = SwipeCellHapticThrottle()
    @ObservationIgnored private var inputSuppressionEpoch = 0

    /// Test projections intentionally stay on the coordinator while the controller owns the mechanism
    /// state, preserving #67's original-name facade contract for a structural move.
    var pendingCloseToken: Int? { forcedResetCloseController.pendingCloseToken }
    var pendingCloseDriver: SwipeCellForcedResetCloseDriver? { forcedResetCloseController.pendingCloseDriver }
    var pendingMacOSResetTokenCloseEpoch: Int? { forcedResetCloseController.pendingMacOSResetTokenCloseEpoch }
    var lastForcedResetCloseDriver: SwipeCellForcedResetCloseDriver? {
        forcedResetCloseController.lastForcedResetCloseDriver
    }
    #if DEBUG
        var lastMacOSResetTokenCloseTerminalState: String? {
            forcedResetCloseController.lastMacOSResetTokenCloseTerminalState
        }
        var macOSResetTokenCloseTerminalCount: Int {
            forcedResetCloseController.macOSResetTokenCloseTerminalCount
        }
    #endif
    /// Unit tests can hold the macOS epoch open; SwiftUI completes zero-view animations immediately.
    var pausesMacOSResetTokenCloseCompletionForTesting: Bool {
        get { forcedResetCloseController.pausesMacOSResetTokenCloseCompletionForTesting }
        set { forcedResetCloseController.pausesMacOSResetTokenCloseCompletionForTesting = newValue }
    }

    /// Tap-to-close is briefly suppressed right after a gesture so the lift that ends a drag does not
    /// immediately read as a content tap.
    var canTapClose: Bool { tapCloseSuppression.canTapClose }

    func canReceivePanInput(_ inputs: SwipeCellInteractionInputs) -> Bool {
        inputs.isInteractionEnabled
            && !isAutomaticInputSuppressed
    }

    /// Align the local reset-token baseline with the manager on appear, so only later token changes
    /// (another cell, scroll, external close) collapse this row.
    func syncResetGenerationBaseline(_ generation: Int) {
        resetGenerationTracker.syncBaseline(generation)
    }

    func hostAppeared(_ inputs: SwipeCellInteractionInputs) {
        #if DEBUG
            logHostLifecycle(event: "host.appear", inputs: inputs)
        #endif
        syncResetGenerationBaseline(inputs.manager?.resetGeneration ?? 0)
    }

    func hostDisappeared(_ inputs: SwipeCellInteractionInputs) {
        #if DEBUG
            logHostLifecycle(event: "host.disappear", inputs: inputs)
        #endif
        guard let pending = forcedResetCloseController.pendingDetachedCleanup(for: inputs.cellID) else { return }

        completeForcedResetClose(
            epoch: pending.epoch,
            driver: pending.closeDriver,
            terminalState: .detachedCleanup
        )
    }

    /// The side currently revealed: the owner's live phase, else the offset sign, else the side held
    /// through a close settle. Drives which action side the shell mounts.
    func currentVisibleSide(_ inputs: SwipeCellInteractionInputs) -> SwipeCellSide? {
        if let manager = inputs.manager,
            let visibleSide = SwipeCellActionPresentation.visibleSide(for: inputs.cellID, manager: manager)
        {
            return visibleSide
        }
        if abs(contentOffset) > 0.5 {
            return contentOffset > 0 ? .leading : .trailing
        }
        return settlingSide
    }

    private func isTakeoverVisibleBeforeSettling() -> Bool {
        isArmed || deformationProgress >= 1
    }

    // MARK: - Pan

    func panBegan(
        _ inputs: SwipeCellInteractionInputs,
        model: SwipeCellInteractionModel? = nil,
        timestamp: TimeInterval? = nil
    ) {
        guard canReceivePanInput(inputs) else {
            clearGestureSession()
            return
        }

        gestureModel = model
        gestureStartTimestamp = timestamp ?? ProcessInfo.processInfo.systemUptime
        if inputs.manager?.ownsActiveCell(inputs.cellID) == true {
            gestureStartSide = inputs.manager?.activeSide
        } else {
            gestureStartSide = nil
        }
        #if DEBUG
            logValidationEvent(
                "pan.began",
                inputs: inputs,
                fields: [
                    .init("phaseAfter", inputs.manager?.phase),
                    .init("activeAfter", inputs.manager?.activeCellID),
                    .init("openOriginSide", gestureStartSide),
                ]
            )
        #endif
    }

    func panChanged(
        _ value: SwipeCellPanValue,
        model: SwipeCellInteractionModel,
        inputs: SwipeCellInteractionInputs
    ) {
        guard canReceivePanInput(inputs) else { return }

        let activeModel = gestureModel ?? model
        // Scroll-wheel close can carry its own visible-side seed; direct touch relies on gestureStartSide.
        let openOriginSide = value.openOriginSide ?? gestureStartSide
        let snapshot = activeModel.snapshot(
            startSide: openOriginSide,
            lockedSide: committedDragSide(inputs),
            translationWidth: value.translation.width,
            predictedEndTranslationWidth: value.predictedEndTranslation.width,
            openOriginMovement: value.openOriginMovement,
            bypassesNormalReleaseThreshold: value.bypassesNormalReleaseThreshold,
            pointerActive: true
        )
        // Ownership may only be claimed by an enabled-side pan that produces real movement. A
        // closed-origin pan toward a disabled or empty side still resolves a nominal `interactionSide`,
        // but the model clamps its `effectiveMovement` to 0; engaging there would let an invisible reveal
        // attempt replace and reset another row that is held/open (issue #56). Open-origin reverse-close
        // keeps engaging because its side is the visible owner side with positive movement until it
        // reaches closed, and a same-owner begin is a no-op. The gate lives in this shared path: the
        // macOS scroll-wheel accumulator already filters disabled-side starts, so a real scroll reveal
        // arrives with positive movement and the check holds vacuously there.
        if snapshot.effectiveMovement > 0 {
            let replacedActiveCell =
                inputs.manager?.beginInteraction(for: inputs.cellID, side: snapshot.interactionSide)
                ?? false
            #if DEBUG
                logValidationEvent(
                    "pan.claimOwner",
                    inputs: inputs,
                    fields: [
                        .init("side", snapshot.interactionSide),
                        .init("effectiveMovement", snapshot.effectiveMovement),
                        .init("replacedActiveCell", replacedActiveCell),
                    ]
                )
            #endif
        }
        let update = activeDragUpdate(
            from: snapshot,
            value: value,
            model: activeModel,
            startSide: openOriginSide
        )
        applyOffsetUpdate(
            update,
            inputs: inputs,
            animatedRequest: update.animationRole != .none,
            publishesArmFeed: true
        )
    }

    func panEnded(
        _ value: SwipeCellPanValue,
        model: SwipeCellInteractionModel,
        inputs: SwipeCellInteractionInputs
    ) {
        guard canReceivePanInput(inputs) else {
            clearGestureSession()
            return
        }

        let activeModel = gestureModel ?? model
        // Keep the release snapshot on the same open-origin seed used for active movement.
        let openOriginSide = value.openOriginSide ?? gestureStartSide
        let releaseValue = committedFastOpenReleaseValue(
            value,
            model: activeModel,
            openOriginSide: openOriginSide
        )
        let rawSnapshot = activeModel.snapshot(
            startSide: openOriginSide,
            lockedSide: committedDragSide(inputs),
            translationWidth: releaseValue.translation.width,
            predictedEndTranslationWidth: releaseValue.predictedEndTranslation.width,
            openOriginMovement: releaseValue.openOriginMovement,
            bypassesNormalReleaseThreshold: releaseValue.bypassesNormalReleaseThreshold,
            pointerActive: false
        )
        let snapshot = SwipeCellGestureReleaseResolver.resolvedSnapshot(
            rawSnapshot,
            value: releaseValue,
            model: activeModel,
            startSide: openOriginSide
        )
        #if DEBUG
            logDirectTouchRelease(
                snapshot: snapshot,
                value: releaseValue,
                model: activeModel,
                startSide: openOriginSide
            )
            logValidationEvent(
                "pan.ended",
                inputs: inputs,
                fields: [
                    .init("fromOffset", contentOffset),
                    .init("targetOffset", snapshot.settlingTarget?.contentOffset),
                    .init("releaseTarget", SwipeCellValidationDiagnostics.string(snapshot.releaseTarget)),
                    .init("classification", String(describing: snapshot.releaseClassification)),
                ]
            )
        #endif
        clearGestureSession()
        suppressTapCloseBriefly(inputs)

        switch SwipeCellGestureReleaseResolver.staleReleaseDecision(inputs) {
        case .ignoreIndirectScroll:
            #if DEBUG
                logInertStaleRelease(inputs)
            #endif
            return
        case .collapseDirectTouch:
            collapseStaleRelease(inputs)
            return
        case .none:
            break
        }

        if case .destructive(let side) = snapshot.releaseTarget {
            inputs.manager?.beginGestureReleaseSettle(for: inputs.cellID)
            applyDestructiveRelease(
                side,
                snapshot: snapshot,
                releaseVelocity: releaseValue.velocity,
                inputs: inputs
            )
            return
        }

        let releaseTarget = snapshot.releaseTarget ?? .closed
        inputs.manager?.beginGestureReleaseSettle(for: inputs.cellID)
        let visibleResetCompletion: (() -> Void)? =
            releaseTarget == .closed
            ? {
                self.applyClosedReleaseTarget(inputs)
                inputs.manager?.completeVisibleReset(for: inputs.cellID)
            }
            : {
                inputs.manager?.applyReleaseTarget(releaseTarget, for: inputs.cellID)
            }
        let targetOffset = snapshot.settlingTarget?.contentOffset ?? 0
        let sideConfiguration = activeModel.configuration
            .sideConfiguration(for: snapshot.interactionSide)
        let referenceDistance = SwipeCellGestureReleaseResolver.referenceDistance(
            releaseTarget: releaseTarget,
            sideConfiguration: sideConfiguration,
            contentOffset: contentOffset,
            targetOffset: targetOffset
        )
        let settlePlan = SwipeCellGestureReleaseResolver.releaseSettlePlan(
            releaseVelocity: releaseValue.velocity,
            releaseTarget: releaseTarget,
            releaseClassification: snapshot.releaseClassification,
            contentOffset: contentOffset,
            targetOffset: targetOffset,
            referenceDistance: referenceDistance,
            motion: inputs.configuration.motion
        )
        applyDeferredAnimatedOffsetUpdate(
            .releaseSettling(from: snapshot),
            inputs: inputs,
            source: "release",
            settleAnimation: settlePlan.animation,
            settleMetrics: settlePlan.metrics,
            completion: visibleResetCompletion
        )
    }

    func panCancelled(_ inputs: SwipeCellInteractionInputs) {
        guard canReceivePanInput(inputs) else {
            clearGestureSession()
            return
        }

        clearGestureSession()
        suppressTapCloseBriefly(inputs)
        #if DEBUG
            logValidationEvent(
                "pan.cancelled",
                inputs: inputs,
                fields: [.init("fromOffset", contentOffset)]
            )
        #endif
        applyDeferredAnimatedOffsetUpdate(
            .forcedReset,
            inputs: inputs,
            source: "gesture-cancelled",
            completion: { inputs.manager?.completeVisibleReset(for: inputs.cellID) }
        )
        expectLocalResetGeneration(inputs)
        inputs.manager?.close(inputs.cellID, reason: .gestureCancelled)
    }

    // MARK: - Tap

    /// Shared preparation for a content tap-to-close: drop any gesture lock and schedule the deferred
    /// settle. The actual `manager.close` stays at the call site — inline for the identity path, inside
    /// `SwipeCellContentTapGate` for the action path — to preserve each path's ownership ordering.
    func beginContentTapClose(_ inputs: SwipeCellInteractionInputs) {
        guard inputs.isInteractionEnabled else { return }

        clearGestureSession()
        #if DEBUG
            logValidationEvent(
                "tap.ownerClose",
                inputs: inputs,
                fields: [.init("fromOffset", contentOffset)]
            )
        #endif
        applyDeferredAnimatedOffsetUpdate(
            .forcedReset,
            inputs: inputs,
            source: "tap-content",
            claimsForcedResetBeforeDeferring: shouldClaimContentTapCloseBeforeDeferring(inputs),
            completion: { inputs.manager?.completeVisibleReset(for: inputs.cellID) }
        )
        expectLocalResetGeneration(inputs)
    }

    /// macOS content-tap close mutates the manager immediately after this preparation hook returns.
    /// Claiming first preserves the coordinator-owned close epoch across that render churn.
    private func shouldClaimContentTapCloseBeforeDeferring(_ inputs: SwipeCellInteractionInputs) -> Bool {
        inputs.configuration.motion.trackingStyle == .indirectScroll
    }

    /// Collapse for an action tap. The optional completion is the public `.afterCollapse` boundary:
    /// it runs only after the visible row reset settles, so deletion/removal work cannot race the close.
    /// Immediate macOS action-collapse paths can claim the close before deferring the render; that keeps
    /// the coordinator-owned terminal alive even if the user closure mutates or removes the row first.
    func beginActionTapClose(
        _ inputs: SwipeCellInteractionInputs,
        claimsCloseBeforeDeferring: Bool = false,
        completion: @escaping () -> Void = {}
    ) {
        guard inputs.isInteractionEnabled else { return }

        clearGestureSession()
        #if DEBUG
            logValidationEvent(
                "tap.actionClose",
                inputs: inputs,
                fields: [.init("fromOffset", contentOffset)]
            )
        #endif
        applyDeferredAnimatedOffsetUpdate(
            .forcedReset,
            inputs: inputs,
            source: "tap-action",
            claimsForcedResetBeforeDeferring: claimsCloseBeforeDeferring,
            completion: {
                inputs.manager?.completeVisibleReset(for: inputs.cellID)
                completion()
            }
        )
        expectLocalResetGeneration(inputs)
        inputs.manager?.close(inputs.cellID, reason: .actionTrigger)
    }

    func performActionTap(
        resolution: SwipeCellActionTapGate.Resolution,
        inputs: SwipeCellInteractionInputs,
        action: @escaping () -> Void
    ) {
        switch resolution {
        case .ignored:
            return
        case .immediate:
            if shouldClaimImmediateAutoCollapseBeforeClosure(inputs) {
                beginActionTapClose(inputs, claimsCloseBeforeDeferring: true)
                #if DEBUG
                    SwipeCellUserClosureDiagnostics.emit(
                        .invoked,
                        inputs: inputs,
                        triggerSource: "tap-action",
                        resolvedTiming: "immediate"
                    )
                #endif
                action()
            } else {
                #if DEBUG
                    SwipeCellUserClosureDiagnostics.emit(
                        .invoked,
                        inputs: inputs,
                        triggerSource: "tap-action",
                        resolvedTiming: "immediate"
                    )
                #endif
                action()
                beginActionTapClose(inputs)
            }
        case .afterCollapse:
            #if DEBUG
                SwipeCellUserClosureDiagnostics.emit(
                    .queued,
                    inputs: inputs,
                    triggerSource: "tap-action",
                    resolvedTiming: "afterCollapse"
                )
            #endif
            beginActionTapClose(inputs) {
                #if DEBUG
                    SwipeCellUserClosureDiagnostics.emitCollapseTerminal(
                        inputs: inputs,
                        triggerSource: "tap-action",
                        resolvedTiming: "afterCollapse"
                    )
                    SwipeCellUserClosureDiagnostics.emit(
                        .invoked,
                        inputs: inputs,
                        triggerSource: "tap-action",
                        resolvedTiming: "afterCollapse"
                    )
                #endif
                action()
            }
        case .triggerAndHoldOpen:
            #if DEBUG
                SwipeCellUserClosureDiagnostics.emit(
                    .invoked,
                    inputs: inputs,
                    triggerSource: "tap-action",
                    resolvedTiming: "triggerAndHoldOpen"
                )
            #endif
            action()
        }
    }

    /// Only the indirect-scroll action-collapse driver needs claim-before-closure ordering. Direct-touch
    /// keeps its existing action-before-close sequence so the iOS timing contract stays frozen.
    private func shouldClaimImmediateAutoCollapseBeforeClosure(_ inputs: SwipeCellInteractionInputs) -> Bool {
        inputs.configuration.motion.trackingStyle == .indirectScroll
    }

    // MARK: - Reset token

    func handleResetGenerationChange(_ generation: Int, inputs: SwipeCellInteractionInputs) {
        guard resetGenerationTracker.receive(generation) else { return }

        // A replacing row observes the same reset token; only stale non-owners should collapse.
        guard inputs.manager?.ownsActiveCell(inputs.cellID) != true else { return }

        let resetRequest = inputs.manager?.resetRequest(for: generation)
        #if DEBUG
            logValidationEvent(
                "resetToken.received",
                inputs: inputs,
                fields: [
                    .init("resetGen", generation),
                    .init("resetReason", resetRequest?.reason),
                    .init("animatedRequest", resetRequest?.animated ?? true),
                ]
            )
        #endif
        let completion: () -> Void = {
            inputs.manager?.completeVisibleReset(for: inputs.cellID)
        }
        if resetRequest?.animated == false {
            applyImmediateForcedReset(inputs: inputs, source: "reset-token", completion: completion)
        } else {
            applyDeferredAnimatedOffsetUpdate(
                .forcedReset,
                inputs: inputs,
                source: "reset-token",
                completion: completion
            )
        }
    }

    // MARK: - Programmatic open

    func applyProgrammaticOpen(
        _ request: SwipeCellProgrammaticOpenRequest,
        model: SwipeCellInteractionModel,
        inputs: SwipeCellInteractionInputs
    ) {
        guard canApplyProgrammaticOpen(request, model: model, inputs: inputs) else { return }

        clearGestureSession()
        cancelPendingForcedResetClose(inputs: inputs, terminalState: .cancelledByNewLocalOwner)
        settlingSide = nil
        takeoverSettlingSide = nil
        let openOffset = Self.programmaticOpenOffset(
            for: request.side,
            sideConfiguration: model.configuration.sideConfiguration(for: request.side)
        )

        if request.animated {
            applyDeferredAnimatedProgrammaticOpen(
                request,
                contentOffset: openOffset,
                model: model,
                inputs: inputs
            )
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                writeProgrammaticOpenState(contentOffset: openOffset, inputs: inputs)
            }
        }
    }

    // MARK: - Internals

    private func canApplyProgrammaticOpen(
        _ request: SwipeCellProgrammaticOpenRequest,
        model: SwipeCellInteractionModel,
        inputs: SwipeCellInteractionInputs
    ) -> Bool {
        guard inputs.isInteractionEnabled,
            request.cellID == inputs.cellID,
            inputs.manager?.ownsActiveCell(inputs.cellID) == true,
            inputs.manager?.activeSide == request.side,
            inputs.manager?.phase == .open(request.side)
        else {
            return false
        }

        return model.configuration.sideConfiguration(for: request.side).isEnabled
    }

    private func applyDeferredAnimatedProgrammaticOpen(
        _ request: SwipeCellProgrammaticOpenRequest,
        contentOffset: CGFloat,
        model: SwipeCellInteractionModel,
        inputs: SwipeCellInteractionInputs
    ) {
        // Animated programmatic open needs the same clean transaction separation as release settles;
        // same-turn writes can coalesce into a visual jump even though the final offset is correct.
        let inputSuppressionEpoch = beginAutomaticInputSuppression()
        DispatchQueue.main.async {
            guard self.canApplyProgrammaticOpen(request, model: model, inputs: inputs) else {
                self.endAutomaticInputSuppression(inputSuppressionEpoch)
                return
            }

            withAnimation(inputs.settlingAnimation) {
                self.writeProgrammaticOpenState(contentOffset: contentOffset, inputs: inputs)
            } completion: {
                self.endAutomaticInputSuppression(inputSuppressionEpoch)
            }
        }
    }

    private static func programmaticOpenOffset(
        for side: SwipeCellSide,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        switch side {
        case .leading:
            sideConfiguration.normalOpenExtent
        case .trailing:
            -sideConfiguration.normalOpenExtent
        }
    }

    private func writeProgrammaticOpenState(
        contentOffset: CGFloat,
        inputs: SwipeCellInteractionInputs
    ) {
        // Programmatic open is a normal-open command, not a synthetic destructive release.
        self.contentOffset = contentOffset
        normalOpenProgress = 1
        deformationProgress = 0
        setArmed(false, inputs: inputs, publishesFeedMarker: false)
    }

    private func applyImmediateForcedReset(
        inputs: SwipeCellInteractionInputs,
        source: String,
        publishesArmFeed: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        #if DEBUG
            let fromOffset = contentOffset
            let sideBeforeClose = currentVisibleSide(inputs)
            let settlingSideBeforeClose = settlingSide
        #endif
        cancelPendingForcedResetClose(inputs: inputs, terminalState: .cancelledByNewLocalOwner)
        settlingSide = nil
        takeoverSettlingSide = nil
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            writeActiveDragState(.forcedReset, inputs: inputs, publishesArmFeed: publishesArmFeed)
        }
        completion?()
        #if DEBUG
            emitSettleEvent(
                "settle.immediate",
                update: .forcedReset,
                inputs: inputs,
                source: source,
                animatedRequest: false,
                deferred: false,
                completion: completion != nil,
                fromOffset: fromOffset,
                sideBeforeClose: sideBeforeClose,
                visibleSideAfter: currentVisibleSide(inputs),
                settlingSideBeforeClose: settlingSideBeforeClose,
                settlingSideAfter: settlingSide,
                ownsClosingSettle: false,
                verdict: SwipeCellValidationDiagnostics.settleCompletionVerdict(
                    animatedRequest: false,
                    fromOffset: fromOffset,
                    targetOffset: 0,
                    role: .forcedReset,
                    ownsClosingSettle: false
                )
            )
        #endif
    }

    private func committedDragSide(_ inputs: SwipeCellInteractionInputs) -> SwipeCellSide? {
        // A fresh drag locks to the side committed on its first frame (recorded as the manager's active
        // side); reversing past the origin then collapses toward closed instead of revealing the
        // opposite side. An open-side start carries its own lock via `gestureStartSide`.
        guard gestureStartSide == nil,
            let manager = inputs.manager,
            manager.ownsActiveCell(inputs.cellID)
        else { return nil }
        return manager.activeSide
    }

    private func activeDragUpdate(
        from snapshot: SwipeCellInteractionSnapshot,
        value: SwipeCellPanValue,
        model: SwipeCellInteractionModel,
        startSide: SwipeCellSide?
    ) -> SwipeCellOffsetUpdate {
        let update = SwipeCellOffsetUpdate.activeDrag(from: snapshot)
        let fastMotion = directTouchFastIntent.visibleMotion(
            snapshot: snapshot,
            value: value,
            model: model,
            startSide: startSide,
            gestureStartTimestamp: gestureStartTimestamp
        )
        #if DEBUG
            logDirectTouchFastIntent(
                snapshot: snapshot,
                value: value,
                model: model,
                startSide: startSide,
                visibleMovement: fastMotion?.movement
            )
        #endif

        guard let fastMotion else {
            return update
        }

        let visibleMovement = fastMotion.movement
        // Direct-touch fast intent renders from coherent visible movement; chrome state must use the
        // same movement so destructive stretch cannot lead or lag the rendered offset. The commit frame
        // uses release-settle animation so auto-open plays independently from later pan sample cadence.
        return SwipeCellOffsetUpdate(
            contentOffset: SwipeCellInteractionGeometry.signedOffset(
                visibleMovement,
                for: snapshot.interactionSide
            ),
            normalOpenProgress: normalOpenProgress(
                movement: visibleMovement,
                model: model,
                side: snapshot.interactionSide
            ),
            deformationProgress: deformationProgress(
                movement: visibleMovement,
                model: model,
                side: snapshot.interactionSide
            ),
            isArmed: isArmed(
                movement: visibleMovement,
                model: model,
                side: snapshot.interactionSide
            ),
            animationRole: fastMotion.shouldAnimateAutoOpen ? .releaseSettling : .none
        )
    }

    #if DEBUG
        private func logDirectTouchFastIntent(
            snapshot: SwipeCellInteractionSnapshot,
            value: SwipeCellPanValue,
            model: SwipeCellInteractionModel,
            startSide: SwipeCellSide?,
            visibleMovement: CGFloat?
        ) {
            SwipeCellInteractionDiagnosticsEmitter.emitDirectTouchFastIntent(
                snapshot: snapshot,
                value: value,
                model: model,
                startSide: startSide,
                gestureStartTimestamp: gestureStartTimestamp,
                visibleMovement: visibleMovement,
                fastState: directTouchFastIntent.debugState
            )
        }
    #endif

    private func normalOpenProgress(
        movement: CGFloat,
        model: SwipeCellInteractionModel,
        side: SwipeCellSide
    ) -> CGFloat {
        let sideConfiguration = model.configuration.sideConfiguration(for: side)
        guard sideConfiguration.isEnabled, sideConfiguration.normalOpenExtent > 0 else { return 0 }
        return min(max(movement / sideConfiguration.normalOpenExtent, 0), 1)
    }

    private func deformationProgress(
        movement: CGFloat,
        model: SwipeCellInteractionModel,
        side: SwipeCellSide
    ) -> CGFloat {
        let sideConfiguration = model.configuration.sideConfiguration(for: side)
        guard sideConfiguration.isEnabled, sideConfiguration.allowsDestructive else { return 0 }

        let start = sideConfiguration.normalOpenExtent
        let span = sideConfiguration.destructiveActivationExtent - start
        guard span > 0 else { return movement >= sideConfiguration.destructiveActivationExtent ? 1 : 0 }

        return min(max((movement - start) / span, 0), 1)
    }

    private func isArmed(
        movement: CGFloat,
        model: SwipeCellInteractionModel,
        side: SwipeCellSide
    ) -> Bool {
        let sideConfiguration = model.configuration.sideConfiguration(for: side)
        return sideConfiguration.isEnabled && sideConfiguration.allowsDestructive
            && movement >= sideConfiguration.destructiveActivationExtent
    }

    private func committedFastOpenReleaseValue(
        _ value: SwipeCellPanValue,
        model: SwipeCellInteractionModel,
        openOriginSide: SwipeCellSide?
    ) -> SwipeCellPanValue {
        guard openOriginSide == nil,
            let committedSide = directTouchFastIntent.committedAutoOpenSide,
            SwipeCellInteractionGeometry.movement(value.translation.width, toward: committedSide) > 0
        else {
            return value
        }

        // Committed fast-open release is an automatic open command; do not carry raw prediction,
        // velocity, or destructive overdrag from the still-moving finger into target resolution.
        let sideConfiguration = model.configuration.sideConfiguration(for: committedSide)
        guard sideConfiguration.isEnabled,
            sideConfiguration.normalOpenExtent.isFinite,
            sideConfiguration.normalOpenExtent > 0
        else {
            return value
        }

        let openTranslationWidth = SwipeCellInteractionGeometry.signedOffset(
            sideConfiguration.normalOpenExtent,
            for: committedSide
        )
        let openTranslation = CGSize(width: openTranslationWidth, height: value.translation.height)

        return SwipeCellPanValue(
            translation: openTranslation,
            predictedEndTranslation: openTranslation,
            allowsDestructiveRelease: false,
            bypassesNormalReleaseThreshold: true,
            velocity: .zero,
            openOriginSide: value.openOriginSide,
            openOriginMovement: value.openOriginMovement,
            timestamp: value.timestamp
        )
    }

    #if DEBUG
        private func logInertStaleRelease(_ inputs: SwipeCellInteractionInputs) {
            SwipeCellInteractionDiagnosticsEmitter.emitInertStaleRelease(
                snapshot: diagnosticsSnapshot(inputs)
            )
        }
    #endif

    private func collapseStaleRelease(_ inputs: SwipeCellInteractionInputs) {
        // A delayed release from an old owner must not re-open local UI after the scope moved on.
        #if DEBUG
            logValidationEvent(
                "pan.ended",
                inputs: inputs,
                verdict: .suspect("stale-release-after-owner-replacement"),
                fields: [.init("fromOffset", contentOffset)]
            )
        #endif
        if let resetGeneration = inputs.manager?.resetGeneration {
            resetGenerationTracker.syncBaseline(resetGeneration)
        }
        applyDeferredAnimatedOffsetUpdate(
            .forcedReset,
            inputs: inputs,
            source: "stale-release",
            completion: { inputs.manager?.completeVisibleReset(for: inputs.cellID) }
        )
    }

    private func applyClosedReleaseTarget(_ inputs: SwipeCellInteractionInputs) {
        // Closed release should not publish the manager reset until the visible settle completes; that
        // pre-animation invalidation is noticeable as a small hitch compared with open.
        expectLocalResetGeneration(inputs)
        inputs.manager?.applyReleaseTarget(.closed, for: inputs.cellID)
    }

    #if DEBUG
        private func logDirectTouchRelease(
            snapshot: SwipeCellInteractionSnapshot,
            value: SwipeCellPanValue,
            model: SwipeCellInteractionModel,
            startSide: SwipeCellSide?
        ) {
            SwipeCellInteractionDiagnosticsEmitter.emitDirectTouchRelease(
                snapshot: snapshot,
                value: value,
                model: model,
                startSide: startSide,
                gestureStartTimestamp: gestureStartTimestamp,
                contentOffset: contentOffset
            )
        }
    #endif

    private func suppressTapCloseBriefly(_ inputs: SwipeCellInteractionInputs) {
        tapCloseSuppression.suppress(for: inputs.configuration.timing.tapCloseSuppression)
    }

    private func expectLocalResetGeneration(_ inputs: SwipeCellInteractionInputs) {
        guard let manager = inputs.manager,
            manager.ownsActiveCell(inputs.cellID)
        else { return }

        resetGenerationTracker.expectNext(after: manager.resetGeneration)
    }

    private func applyDeferredAnimatedOffsetUpdate(
        _ update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String,
        publishesArmFeed: Bool = false,
        settleAnimation: Animation? = nil,
        settleMetrics: SwipeCellReleaseSettleMetrics? = nil,
        claimsForcedResetBeforeDeferring: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        // Invariant: the gesture-release settle MUST run on a later main-queue turn than the active
        // drag. The active-drag transaction is still settling when `panEnded` arrives; applying the
        // settle animation in the same turn coalesces it into a state jump — the settle animation is
        // lost. Deferring gives the settle its own clean transaction. The action side stays visible
        // across the gap via the offset-sign fallback in `currentVisibleSide`, then `applyOffsetUpdate`'s
        // settling owner takes over once content reaches rest.
        //
        // Do not make the render write synchronous for any tracking style. It was tried for
        // `.indirectScroll` (issue #28 #1), on the theory that spring tracking has no transaction to
        // escape; the macOS settle lost its animation. Unit tests do not catch it — they assert the final
        // offset (which still reaches 0), not whether an animation played — so only on-device feel reveals
        // the regression.
        #if DEBUG
            emitSettleEvent(
                "settle.schedule",
                update: update,
                inputs: inputs,
                source: source,
                animatedRequest: true,
                deferred: true,
                completion: completion != nil,
                fromOffset: contentOffset,
                sideBeforeClose: currentVisibleSide(inputs),
                visibleSideAfter: currentVisibleSide(inputs),
                settlingSideBeforeClose: settlingSide,
                settlingSideAfter: settlingSide,
                ownsClosingSettle: update.ownsVisibleCloseSettle(fromContentOffset: contentOffset)
            )
            emitMeasureSettleEvent(
                "settle.schedule",
                update: update,
                inputs: inputs,
                source: source,
                animatedRequest: true,
                deferred: true,
                completion: completion != nil,
                fromOffset: contentOffset,
                ownsClosingSettle: update.ownsVisibleCloseSettle(fromContentOffset: contentOffset),
                metrics: settleMetrics
            )
        #endif
        let inputSuppressionEpoch = beginAutomaticInputSuppression()
        beginDeferredTakeoverSettlingIfNeeded(update, inputs: inputs, source: source)
        let claimedClose: SwipeCellClaimedForcedResetClose? =
            if claimsForcedResetBeforeDeferring {
                claimDeferredForcedResetCloseIfNeeded(
                    update,
                    inputs: inputs,
                    source: source,
                    publishesArmFeed: publishesArmFeed,
                    settleAnimation: settleAnimation,
                    inputSuppressionEpoch: inputSuppressionEpoch,
                    completion: completion
                )
            } else {
                nil
            }
        DispatchQueue.main.async {
            if let claimedClose {
                self.renderClaimedForcedResetClose(
                    claimedClose,
                    publishesArmFeed: publishesArmFeed,
                    settleAnimation: settleAnimation
                )
            } else {
                self.applyOffsetUpdate(
                    update,
                    inputs: inputs,
                    source: source,
                    animatedRequest: true,
                    deferred: true,
                    publishesArmFeed: publishesArmFeed,
                    settleAnimation: settleAnimation,
                    settleMetrics: settleMetrics,
                    inputSuppressionEpoch: inputSuppressionEpoch,
                    completion: completion
                )
            }
        }
    }

    private func beginDeferredTakeoverSettlingIfNeeded(
        _ update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String
    ) {
        guard source == "destructive-trigger",
            update.animationRole == .forcedReset,
            update.ownsVisibleCloseSettle(fromContentOffset: contentOffset)
        else {
            return
        }

        takeoverSettlingSide = currentVisibleSide(inputs)
    }

    private func claimDeferredForcedResetCloseIfNeeded(
        _ update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String,
        publishesArmFeed: Bool,
        settleAnimation: Animation?,
        inputSuppressionEpoch: Int,
        completion: (() -> Void)?
    ) -> SwipeCellClaimedForcedResetClose? {
        guard update.animationRole == .forcedReset else { return nil }

        let fromOffset = contentOffset
        let ownsSettlingSide = update.ownsVisibleCloseSettle(fromContentOffset: fromOffset)
        guard ownsSettlingSide,
            let closeDriving = forcedResetCloseController.driver(
                for: update,
                inputs: inputs,
                source: source,
                animatedRequest: true,
                ownsSettlingSide: ownsSettlingSide
            ),
            closeDriving.rendering == .indirectScroll
        else {
            return nil
        }

        let sideBeforeClose = currentVisibleSide(inputs)
        let settlingSideBeforeClose = settlingSide
        settlingSide = sideBeforeClose
        let settleAppliedAt = ProcessInfo.processInfo.systemUptime
        let epoch = beginIndirectScrollForcedResetClose(
            closeDriver: closeDriving.identity,
            update: update,
            inputs: inputs,
            source: source,
            animatedRequest: true,
            deferred: true,
            publishesArmFeed: publishesArmFeed,
            settleAnimation: settleAnimation,
            completion: completion,
            inputSuppressionEpoch: inputSuppressionEpoch,
            fromOffset: fromOffset,
            sideBeforeClose: sideBeforeClose,
            settlingSideBeforeClose: settlingSideBeforeClose,
            ownsSettlingSide: ownsSettlingSide,
            settleAppliedAt: settleAppliedAt,
            phaseAtSettleApply: inputs.manager?.phase,
            activeAtSettleApply: inputs.manager?.activeCellID,
            resetGenerationAtSettleApply: inputs.manager?.resetGeneration ?? 0,
            rendersImmediately: false
        )

        return SwipeCellClaimedForcedResetClose(epoch: epoch, driver: closeDriving.identity)
    }

    /// The active-drag state writes shared by both tracking styles; only the enclosing transaction
    /// (disabled-animations vs. spring) differs.
    private func writeActiveDragState(
        _ update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        publishesArmFeed: Bool
    ) {
        contentOffset = update.contentOffset
        normalOpenProgress = update.normalOpenProgress
        deformationProgress = update.deformationProgress
        setArmed(update.isArmed, inputs: inputs, publishesFeedMarker: publishesArmFeed)
    }

    private func applyOffsetUpdate(
        _ update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String = "active-drag",
        animatedRequest: Bool = false,
        deferred: Bool = false,
        publishesArmFeed: Bool = false,
        settleAnimation: Animation? = nil,
        settleMetrics: SwipeCellReleaseSettleMetrics? = nil,
        inputSuppressionEpoch: Int? = nil,
        completion: (() -> Void)? = nil
    ) {
        switch update.animationRole {
        case .none:
            cancelPendingForcedResetClose(inputs: inputs, terminalState: .cancelledByNewLocalOwner)
            settlingSide = nil
            takeoverSettlingSide = nil
            // Tracking model by input modality (issue #28): direct touch keeps a 1:1 `disablesAnimations`
            // write (content glued to the finger); indirect scroll tracks with a stiff spring so the
            // settle inherits velocity and an interrupting scroll retargets the in-flight settle instead
            // of jumping it.
            switch inputs.configuration.motion.trackingStyle {
            case .indirectScroll:
                withAnimation(SwipeCellReleaseSettleMotion.trackingAnimation()) {
                    writeActiveDragState(update, inputs: inputs, publishesArmFeed: publishesArmFeed)
                }
            case .directTouch:
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    writeActiveDragState(update, inputs: inputs, publishesArmFeed: publishesArmFeed)
                }
            }
            completion?()
        case .releaseSettling, .forcedReset:
            // A close drives two competing settles (deferred release/tap vs. reset token). Only the one
            // that still has a revealed offset to animate owns the settling side; the redundant one
            // arrives with content already at rest and must leave it alone, or its immediate completion
            // clears the side and the action buttons vanish before the content finishes sliding back.
            let fromOffset = contentOffset
            let sideBeforeClose = currentVisibleSide(inputs)
            let settlingSideBeforeClose = settlingSide
            let ownsSettlingSide = update.ownsVisibleCloseSettle(fromContentOffset: fromOffset)
            let ownsTakeoverSettling = ownsSettlingSide && isTakeoverVisibleBeforeSettling()
            if ownsSettlingSide {
                settlingSide = sideBeforeClose
            }
            if ownsTakeoverSettling {
                takeoverSettlingSide = sideBeforeClose
            }
            #if DEBUG
                emitMeasureSettleEvent(
                    "settle.apply",
                    update: update,
                    inputs: inputs,
                    source: source,
                    animatedRequest: animatedRequest,
                    deferred: deferred,
                    completion: completion != nil,
                    fromOffset: fromOffset,
                    ownsClosingSettle: ownsSettlingSide,
                    metrics: settleMetrics
                )
                let settleAppliedAt = ProcessInfo.processInfo.systemUptime
                // Apply-time manager identity. Compared at completion to expose whether another cell mutated
                // the shared manager (e.g. a new owner reaching `open`) while this close animated — the
                // suspected collapse source behind sub-frame `unexpected-immediate-reset` completions.
                let phaseAtSettleApply = inputs.manager?.phase
                let activeAtSettleApply = inputs.manager?.activeCellID
                let resetGenerationAtSettleApply = inputs.manager?.resetGeneration ?? 0
            #else
                let settleAppliedAt: TimeInterval = 0
                let phaseAtSettleApply: SwipeCellPhase? = nil
                let activeAtSettleApply: AnyHashable? = nil
                let resetGenerationAtSettleApply = 0
            #endif

            if let closeDriving = forcedResetCloseController.driver(
                for: update,
                inputs: inputs,
                source: source,
                animatedRequest: animatedRequest,
                ownsSettlingSide: ownsSettlingSide
            ) {
                beginForcedResetClose(
                    closeDriving,
                    update: update,
                    inputs: inputs,
                    source: source,
                    animatedRequest: animatedRequest,
                    deferred: deferred,
                    publishesArmFeed: publishesArmFeed,
                    settleAnimation: settleAnimation,
                    completion: completion,
                    inputSuppressionEpoch: inputSuppressionEpoch,
                    fromOffset: fromOffset,
                    sideBeforeClose: sideBeforeClose,
                    settlingSideBeforeClose: settlingSideBeforeClose,
                    ownsSettlingSide: ownsSettlingSide,
                    settleAppliedAt: settleAppliedAt,
                    phaseAtSettleApply: phaseAtSettleApply,
                    activeAtSettleApply: activeAtSettleApply,
                    resetGenerationAtSettleApply: resetGenerationAtSettleApply
                )

                #if DEBUG
                    let visibleSideAfter = currentVisibleSide(inputs)
                    let closeDriver = closeDriving.identity
                    let visibleSideVerdict = SwipeCellValidationDiagnostics.visibleSideVerdict(
                        fromOffset: fromOffset,
                        targetOffset: update.contentOffset,
                        visibleSideBefore: sideBeforeClose,
                        visibleSideAfter: visibleSideAfter,
                        settlingSideAfter: settlingSide
                    )
                    emitSettleEvent(
                        "settle.apply",
                        update: update,
                        inputs: inputs,
                        source: source,
                        animatedRequest: animatedRequest,
                        deferred: deferred,
                        completion: completion != nil,
                        fromOffset: fromOffset,
                        sideBeforeClose: sideBeforeClose,
                        visibleSideAfter: visibleSideAfter,
                        settlingSideBeforeClose: settlingSideBeforeClose,
                        settlingSideAfter: settlingSide,
                        ownsClosingSettle: ownsSettlingSide,
                        closeDriver: closeDriver,
                        closeEpoch: forcedResetCloseController.closeEpoch(for: closeDriver),
                        verdict: visibleSideVerdict
                            ?? SwipeCellValidationDiagnostics.settleApplyVerdict(
                                animatedRequest: animatedRequest,
                                fromOffset: fromOffset,
                                targetOffset: update.contentOffset,
                                role: update.animationRole,
                                ownsClosingSettle: ownsSettlingSide
                            )
                            ?? SwipeCellValidationDiagnostics.resetTokenSettleVerdict(
                                source: source,
                                role: update.animationRole,
                                fromOffset: fromOffset,
                                targetOffset: update.contentOffset,
                                cellID: inputs.cellID,
                                activeCellID: inputs.manager?.activeCellID,
                                resettingCellID: inputs.manager?.resettingCellID
                            )
                            ?? SwipeCellValidationDiagnostics.staleReleaseVerdict(
                                source: source,
                                role: update.animationRole,
                                targetOffset: update.contentOffset,
                                cellID: inputs.cellID,
                                activeCellID: inputs.manager?.activeCellID
                            )
                    )
                #endif
                return
            }

            withAnimation(settleCurve(for: update, override: settleAnimation, inputs: inputs)) {
                contentOffset = update.contentOffset
                normalOpenProgress = update.normalOpenProgress
                deformationProgress = update.deformationProgress
                setArmed(update.isArmed, inputs: inputs, publishesFeedMarker: publishesArmFeed)
            } completion: {
                #if DEBUG
                    // Read the shared manager before this close's own completion side effects, so the window
                    // measured is "what other cells did while it animated", not the local visible-reset.
                    let managerMutatedDuringSettle = SwipeCellValidationDiagnostics.managerMutatedDuringSettle(
                        phaseAtApply: phaseAtSettleApply,
                        activeAtApply: activeAtSettleApply,
                        resetGenerationAtApply: resetGenerationAtSettleApply,
                        phaseAtCompletion: inputs.manager?.phase,
                        activeAtCompletion: inputs.manager?.activeCellID,
                        resetGenerationAtCompletion: inputs.manager?.resetGeneration ?? 0
                    )
                    let resettingBeforeCompletion = inputs.manager?.resettingCellID
                #endif
                if ownsSettlingSide {
                    self.settlingSide = nil
                }
                if ownsTakeoverSettling {
                    self.takeoverSettlingSide = nil
                }
                completion?()
                if let inputSuppressionEpoch {
                    self.endAutomaticInputSuppression(inputSuppressionEpoch)
                }
                #if DEBUG
                    let settleElapsed = ProcessInfo.processInfo.systemUptime - settleAppliedAt
                    self.emitMeasureSettleEvent(
                        "settle.complete",
                        update: update,
                        inputs: inputs,
                        source: source,
                        animatedRequest: animatedRequest,
                        deferred: deferred,
                        completion: completion != nil,
                        fromOffset: fromOffset,
                        ownsClosingSettle: ownsSettlingSide,
                        metrics: settleMetrics,
                        settleElapsed: settleElapsed
                    )
                    self.emitSettleEvent(
                        "settle.complete",
                        update: update,
                        inputs: inputs,
                        source: source,
                        animatedRequest: animatedRequest,
                        deferred: deferred,
                        completion: completion != nil,
                        fromOffset: fromOffset,
                        sideBeforeClose: sideBeforeClose,
                        visibleSideAfter: self.currentVisibleSide(inputs),
                        settlingSideBeforeClose: settlingSideBeforeClose,
                        settlingSideAfter: self.settlingSide,
                        ownsClosingSettle: ownsSettlingSide,
                        settleElapsed: settleElapsed,
                        resettingBeforeCompletion: resettingBeforeCompletion,
                        phaseAtApply: phaseAtSettleApply,
                        activeAtApply: activeAtSettleApply,
                        resetGenerationAtApply: resetGenerationAtSettleApply,
                        managerMutatedDuringSettle: managerMutatedDuringSettle,
                        verdict: SwipeCellValidationDiagnostics.immediateAnimatedSettleVerdict(
                            animatedRequest: animatedRequest,
                            fromOffset: fromOffset,
                            targetOffset: update.contentOffset,
                            role: update.animationRole,
                            ownsClosingSettle: ownsSettlingSide,
                            settleElapsed: settleElapsed
                        )
                            ?? SwipeCellValidationDiagnostics.resetTokenSettleVerdict(
                                source: source,
                                role: update.animationRole,
                                fromOffset: fromOffset,
                                targetOffset: update.contentOffset,
                                cellID: inputs.cellID,
                                activeCellID: inputs.manager?.activeCellID,
                                resettingCellID: resettingBeforeCompletion
                            )
                            ?? SwipeCellValidationDiagnostics.settleCompletionVerdict(
                                animatedRequest: animatedRequest,
                                fromOffset: fromOffset,
                                targetOffset: update.contentOffset,
                                role: update.animationRole,
                                ownsClosingSettle: ownsSettlingSide
                            )
                            ?? SwipeCellValidationDiagnostics.staleReleaseVerdict(
                                source: source,
                                role: update.animationRole,
                                targetOffset: update.contentOffset,
                                cellID: inputs.cellID,
                                activeCellID: inputs.manager?.activeCellID
                            )
                    )
                #endif
            }
            #if DEBUG
                let visibleSideAfter = currentVisibleSide(inputs)
                let visibleSideVerdict = SwipeCellValidationDiagnostics.visibleSideVerdict(
                    fromOffset: fromOffset,
                    targetOffset: update.contentOffset,
                    visibleSideBefore: sideBeforeClose,
                    visibleSideAfter: visibleSideAfter,
                    settlingSideAfter: settlingSide
                )
                emitSettleEvent(
                    "settle.apply",
                    update: update,
                    inputs: inputs,
                    source: source,
                    animatedRequest: animatedRequest,
                    deferred: deferred,
                    completion: completion != nil,
                    fromOffset: fromOffset,
                    sideBeforeClose: sideBeforeClose,
                    visibleSideAfter: visibleSideAfter,
                    settlingSideBeforeClose: settlingSideBeforeClose,
                    settlingSideAfter: settlingSide,
                    ownsClosingSettle: ownsSettlingSide,
                    verdict: visibleSideVerdict
                        ?? SwipeCellValidationDiagnostics.settleApplyVerdict(
                            animatedRequest: animatedRequest,
                            fromOffset: fromOffset,
                            targetOffset: update.contentOffset,
                            role: update.animationRole,
                            ownsClosingSettle: ownsSettlingSide
                        )
                        ?? SwipeCellValidationDiagnostics.resetTokenSettleVerdict(
                            source: source,
                            role: update.animationRole,
                            fromOffset: fromOffset,
                            targetOffset: update.contentOffset,
                            cellID: inputs.cellID,
                            activeCellID: inputs.manager?.activeCellID,
                            resettingCellID: inputs.manager?.resettingCellID
                        )
                        ?? SwipeCellValidationDiagnostics.staleReleaseVerdict(
                            source: source,
                            role: update.animationRole,
                            targetOffset: update.contentOffset,
                            cellID: inputs.cellID,
                            activeCellID: inputs.manager?.activeCellID
                        )
                )
            #endif
        }
    }

    private func beginForcedResetClose(
        _ closeDriving: any ForcedResetCloseDriving,
        update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String,
        animatedRequest: Bool,
        deferred: Bool,
        publishesArmFeed: Bool,
        settleAnimation: Animation?,
        completion: (() -> Void)?,
        inputSuppressionEpoch: Int?,
        fromOffset: CGFloat,
        sideBeforeClose: SwipeCellSide?,
        settlingSideBeforeClose: SwipeCellSide?,
        ownsSettlingSide: Bool,
        settleAppliedAt: TimeInterval,
        phaseAtSettleApply: SwipeCellPhase?,
        activeAtSettleApply: AnyHashable?,
        resetGenerationAtSettleApply: Int
    ) {
        switch closeDriving.rendering {
        case .pinnedValueToken:
            beginPinnedForcedResetClose(
                update: update,
                inputs: inputs,
                source: source,
                animatedRequest: animatedRequest,
                deferred: deferred,
                publishesArmFeed: publishesArmFeed,
                completion: completion,
                inputSuppressionEpoch: inputSuppressionEpoch,
                fromOffset: fromOffset,
                sideBeforeClose: sideBeforeClose,
                settlingSideBeforeClose: settlingSideBeforeClose,
                ownsSettlingSide: ownsSettlingSide,
                settleAppliedAt: settleAppliedAt,
                phaseAtSettleApply: phaseAtSettleApply,
                activeAtSettleApply: activeAtSettleApply,
                resetGenerationAtSettleApply: resetGenerationAtSettleApply
            )
        case .indirectScroll:
            beginIndirectScrollForcedResetClose(
                closeDriver: closeDriving.identity,
                update: update,
                inputs: inputs,
                source: source,
                animatedRequest: animatedRequest,
                deferred: deferred,
                publishesArmFeed: publishesArmFeed,
                settleAnimation: settleAnimation,
                completion: completion,
                inputSuppressionEpoch: inputSuppressionEpoch,
                fromOffset: fromOffset,
                sideBeforeClose: sideBeforeClose,
                settlingSideBeforeClose: settlingSideBeforeClose,
                ownsSettlingSide: ownsSettlingSide,
                settleAppliedAt: settleAppliedAt,
                phaseAtSettleApply: phaseAtSettleApply,
                activeAtSettleApply: activeAtSettleApply,
                resetGenerationAtSettleApply: resetGenerationAtSettleApply
            )
        }
    }

    private func beginPinnedForcedResetClose(
        update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String,
        animatedRequest: Bool,
        deferred: Bool,
        publishesArmFeed: Bool,
        completion: (() -> Void)?,
        inputSuppressionEpoch: Int?,
        fromOffset: CGFloat,
        sideBeforeClose: SwipeCellSide?,
        settlingSideBeforeClose: SwipeCellSide?,
        ownsSettlingSide: Bool,
        settleAppliedAt: TimeInterval,
        phaseAtSettleApply: SwipeCellPhase?,
        activeAtSettleApply: AnyHashable?,
        resetGenerationAtSettleApply: Int
    ) {
        cancelPendingForcedResetClose(inputs: inputs, terminalState: .cancelledByNewLocalOwner)
        closeToken += 1
        #if DEBUG
            forcedResetCloseController.beginPinnedClose(
                closeToken: closeToken,
                update: update,
                inputs: inputs,
                source: source,
                animatedRequest: animatedRequest,
                deferred: deferred,
                completion: completion,
                fromOffset: fromOffset,
                sideBeforeClose: sideBeforeClose,
                settlingSideBeforeClose: settlingSideBeforeClose,
                ownsSettlingSide: ownsSettlingSide,
                inputSuppressionEpoch: inputSuppressionEpoch,
                settleAppliedAt: settleAppliedAt,
                phaseAtSettleApply: phaseAtSettleApply,
                activeAtSettleApply: activeAtSettleApply,
                resetGenerationAtSettleApply: resetGenerationAtSettleApply
            )
        #else
            forcedResetCloseController.beginPinnedClose(
                closeToken: closeToken,
                update: update,
                inputs: inputs,
                completion: completion,
                ownsSettlingSide: ownsSettlingSide,
                inputSuppressionEpoch: inputSuppressionEpoch
            )
        #endif
        writeActiveDragState(update, inputs: inputs, publishesArmFeed: publishesArmFeed)
    }

    /// Indirect-scroll closes can outlive or bypass the value-keyed view modifier, so this path owns
    /// completion from the coordinator epoch instead of waiting for `closeToken` observation.
    @discardableResult
    private func beginIndirectScrollForcedResetClose(
        closeDriver: SwipeCellForcedResetCloseDriver,
        update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String,
        animatedRequest: Bool,
        deferred: Bool,
        publishesArmFeed: Bool,
        settleAnimation: Animation?,
        completion: (() -> Void)?,
        inputSuppressionEpoch: Int?,
        fromOffset: CGFloat,
        sideBeforeClose: SwipeCellSide?,
        settlingSideBeforeClose: SwipeCellSide?,
        ownsSettlingSide: Bool,
        settleAppliedAt: TimeInterval,
        phaseAtSettleApply: SwipeCellPhase?,
        activeAtSettleApply: AnyHashable?,
        resetGenerationAtSettleApply: Int,
        rendersImmediately: Bool = true
    ) -> Int {
        cancelPendingForcedResetClose(inputs: inputs, terminalState: .cancelledByNewLocalOwner)
        let epoch: Int
        #if DEBUG
            epoch = forcedResetCloseController.beginIndirectScrollClose(
                closeDriver: closeDriver,
                update: update,
                inputs: inputs,
                source: source,
                animatedRequest: animatedRequest,
                deferred: deferred,
                completion: completion,
                fromOffset: fromOffset,
                sideBeforeClose: sideBeforeClose,
                settlingSideBeforeClose: settlingSideBeforeClose,
                ownsSettlingSide: ownsSettlingSide,
                inputSuppressionEpoch: inputSuppressionEpoch,
                settleAppliedAt: settleAppliedAt,
                phaseAtSettleApply: phaseAtSettleApply,
                activeAtSettleApply: activeAtSettleApply,
                resetGenerationAtSettleApply: resetGenerationAtSettleApply
            )
        #else
            epoch = forcedResetCloseController.beginIndirectScrollClose(
                closeDriver: closeDriver,
                update: update,
                inputs: inputs,
                completion: completion,
                ownsSettlingSide: ownsSettlingSide,
                inputSuppressionEpoch: inputSuppressionEpoch
            )
        #endif

        #if DEBUG
            emitSettleEvent(
                "macOSClose.start",
                update: update,
                inputs: inputs,
                source: source,
                animatedRequest: animatedRequest,
                deferred: deferred,
                completion: completion != nil,
                fromOffset: fromOffset,
                sideBeforeClose: sideBeforeClose,
                visibleSideAfter: currentVisibleSide(inputs),
                settlingSideBeforeClose: settlingSideBeforeClose,
                settlingSideAfter: settlingSide,
                ownsClosingSettle: ownsSettlingSide,
                closeDriver: closeDriver,
                closeEpoch: epoch
            )
        #endif

        guard rendersImmediately else { return epoch }

        withAnimation(settleCurve(for: update, override: settleAnimation, inputs: inputs)) {
            writeActiveDragState(update, inputs: inputs, publishesArmFeed: publishesArmFeed)
        } completion: {
            guard self.pausesMacOSResetTokenCloseCompletionForTesting == false else { return }
            self.completeForcedResetClose(epoch: epoch, driver: closeDriver, terminalState: .visibleComplete)
        }

        return epoch
    }

    private func renderClaimedForcedResetClose(
        _ claimedClose: SwipeCellClaimedForcedResetClose,
        publishesArmFeed: Bool,
        settleAnimation: Animation?
    ) {
        guard let pending = forcedResetCloseController.pendingClaimedClose(claimedClose) else { return }

        withAnimation(settleCurve(for: pending.update, override: settleAnimation, inputs: pending.inputs)) {
            writeActiveDragState(pending.update, inputs: pending.inputs, publishesArmFeed: publishesArmFeed)
        } completion: {
            guard self.pausesMacOSResetTokenCloseCompletionForTesting == false else { return }
            self.completeForcedResetClose(
                epoch: claimedClose.epoch,
                driver: claimedClose.driver,
                terminalState: .visibleComplete
            )
        }

        #if DEBUG
            let visibleSideAfter = currentVisibleSide(pending.inputs)
            let visibleSideVerdict = SwipeCellValidationDiagnostics.visibleSideVerdict(
                fromOffset: pending.fromOffset,
                targetOffset: pending.update.contentOffset,
                visibleSideBefore: pending.sideBeforeClose,
                visibleSideAfter: visibleSideAfter,
                settlingSideAfter: settlingSide
            )
            emitSettleEvent(
                "settle.apply",
                update: pending.update,
                inputs: pending.inputs,
                source: pending.source,
                animatedRequest: pending.animatedRequest,
                deferred: pending.deferred,
                completion: pending.completion != nil,
                fromOffset: pending.fromOffset,
                sideBeforeClose: pending.sideBeforeClose,
                visibleSideAfter: visibleSideAfter,
                settlingSideBeforeClose: pending.settlingSideBeforeClose,
                settlingSideAfter: settlingSide,
                ownsClosingSettle: pending.ownsSettlingSide,
                closeDriver: pending.closeDriver,
                closeEpoch: pending.epoch,
                verdict: visibleSideVerdict
                    ?? SwipeCellValidationDiagnostics.settleApplyVerdict(
                        animatedRequest: pending.animatedRequest,
                        fromOffset: pending.fromOffset,
                        targetOffset: pending.update.contentOffset,
                        role: pending.update.animationRole,
                        ownsClosingSettle: pending.ownsSettlingSide
                    )
                    ?? SwipeCellValidationDiagnostics.resetTokenSettleVerdict(
                        source: pending.source,
                        role: pending.update.animationRole,
                        fromOffset: pending.fromOffset,
                        targetOffset: pending.update.contentOffset,
                        cellID: pending.inputs.cellID,
                        activeCellID: pending.inputs.manager?.activeCellID,
                        resettingCellID: pending.inputs.manager?.resettingCellID
                    )
                    ?? SwipeCellValidationDiagnostics.staleReleaseVerdict(
                        source: pending.source,
                        role: pending.update.animationRole,
                        targetOffset: pending.update.contentOffset,
                        cellID: pending.inputs.cellID,
                        activeCellID: pending.inputs.manager?.activeCellID
                    )
            )
        #endif
    }

    func completePinnedClose(token: Int) {
        completeForcedResetClose(
            epoch: token,
            driver: .pinnedValueToken,
            terminalState: .visibleComplete
        )
    }

    private func completeForcedResetClose(
        epoch: Int,
        driver: SwipeCellForcedResetCloseDriver,
        terminalState: SwipeCellForcedResetCloseTerminalState
    ) {
        guard
            let pending = forcedResetCloseController.complete(
                epoch: epoch,
                driver: driver,
                terminalState: terminalState
            )
        else { return }

        #if DEBUG
            // Read before local completion side effects; the validation line should describe what happened
            // during the visual close window, not what this completion is about to clean up.
            let managerMutatedDuringSettle = SwipeCellValidationDiagnostics.managerMutatedDuringSettle(
                phaseAtApply: pending.phaseAtSettleApply,
                activeAtApply: pending.activeAtSettleApply,
                resetGenerationAtApply: pending.resetGenerationAtSettleApply,
                phaseAtCompletion: pending.inputs.manager?.phase,
                activeAtCompletion: pending.inputs.manager?.activeCellID,
                resetGenerationAtCompletion: pending.inputs.manager?.resetGeneration ?? 0
            )
            let resettingBeforeCompletion = pending.inputs.manager?.resettingCellID
        #endif
        if terminalState.completesVisibleReset {
            if pending.ownsSettlingSide {
                settlingSide = nil
                takeoverSettlingSide = nil
            }
            pending.completion?()
        }
        if let inputSuppressionEpoch = pending.inputSuppressionEpoch {
            endAutomaticInputSuppression(inputSuppressionEpoch)
        }

        #if DEBUG
            let settleElapsed = ProcessInfo.processInfo.systemUptime - pending.applyTimestamp
            if pending.closeDriver != .pinnedValueToken {
                emitSettleEvent(
                    "macOSClose.terminal",
                    update: pending.update,
                    inputs: pending.inputs,
                    source: pending.source,
                    animatedRequest: pending.animatedRequest,
                    deferred: pending.deferred,
                    completion: terminalState.completesVisibleReset && pending.completion != nil,
                    fromOffset: pending.fromOffset,
                    sideBeforeClose: pending.sideBeforeClose,
                    visibleSideAfter: currentVisibleSide(pending.inputs),
                    settlingSideBeforeClose: pending.settlingSideBeforeClose,
                    settlingSideAfter: settlingSide,
                    ownsClosingSettle: pending.ownsSettlingSide,
                    settleElapsed: settleElapsed,
                    resettingBeforeCompletion: resettingBeforeCompletion,
                    phaseAtApply: pending.phaseAtSettleApply,
                    activeAtApply: pending.activeAtSettleApply,
                    resetGenerationAtApply: pending.resetGenerationAtSettleApply,
                    managerMutatedDuringSettle: managerMutatedDuringSettle,
                    closeDriver: pending.closeDriver,
                    closeEpoch: pending.epoch,
                    terminalState: terminalState
                )
            }
        #endif

        guard terminalState.completesVisibleReset else { return }

        #if DEBUG
            emitSettleEvent(
                "settle.complete",
                update: pending.update,
                inputs: pending.inputs,
                source: pending.source,
                animatedRequest: pending.animatedRequest,
                deferred: pending.deferred,
                completion: pending.completion != nil,
                fromOffset: pending.fromOffset,
                sideBeforeClose: pending.sideBeforeClose,
                visibleSideAfter: currentVisibleSide(pending.inputs),
                settlingSideBeforeClose: pending.settlingSideBeforeClose,
                settlingSideAfter: settlingSide,
                ownsClosingSettle: pending.ownsSettlingSide,
                settleElapsed: settleElapsed,
                resettingBeforeCompletion: resettingBeforeCompletion,
                phaseAtApply: pending.phaseAtSettleApply,
                activeAtApply: pending.activeAtSettleApply,
                resetGenerationAtApply: pending.resetGenerationAtSettleApply,
                managerMutatedDuringSettle: managerMutatedDuringSettle,
                closeDriver: pending.closeDriver,
                closeEpoch: pending.epoch,
                terminalState: terminalState,
                verdict: SwipeCellValidationDiagnostics.immediateAnimatedSettleVerdict(
                    animatedRequest: pending.animatedRequest,
                    fromOffset: pending.fromOffset,
                    targetOffset: pending.update.contentOffset,
                    role: pending.update.animationRole,
                    ownsClosingSettle: pending.ownsSettlingSide,
                    settleElapsed: settleElapsed
                )
                    ?? SwipeCellValidationDiagnostics.resetTokenSettleVerdict(
                        source: pending.source,
                        role: pending.update.animationRole,
                        fromOffset: pending.fromOffset,
                        targetOffset: pending.update.contentOffset,
                        cellID: pending.inputs.cellID,
                        activeCellID: pending.inputs.manager?.activeCellID,
                        resettingCellID: resettingBeforeCompletion
                    )
                    ?? SwipeCellValidationDiagnostics.settleCompletionVerdict(
                        animatedRequest: pending.animatedRequest,
                        fromOffset: pending.fromOffset,
                        targetOffset: pending.update.contentOffset,
                        role: pending.update.animationRole,
                        ownsClosingSettle: pending.ownsSettlingSide
                    )
                    ?? SwipeCellValidationDiagnostics.staleReleaseVerdict(
                        source: pending.source,
                        role: pending.update.animationRole,
                        targetOffset: pending.update.contentOffset,
                        cellID: pending.inputs.cellID,
                        activeCellID: pending.inputs.manager?.activeCellID
                    )
            )
        #endif
    }

    private func cancelPendingForcedResetClose(
        inputs: SwipeCellInteractionInputs,
        terminalState: SwipeCellForcedResetCloseTerminalState
    ) {
        guard let pending = forcedResetCloseController.pendingCancellable(for: inputs.cellID) else { return }

        completeForcedResetClose(
            epoch: pending.epoch,
            driver: pending.closeDriver,
            terminalState: terminalState
        )
    }

    @discardableResult
    private func beginAutomaticInputSuppression() -> Int {
        inputSuppressionEpoch += 1
        isAutomaticInputSuppressed = true
        clearGestureSession()
        return inputSuppressionEpoch
    }

    private func endAutomaticInputSuppression(_ epoch: Int) {
        guard inputSuppressionEpoch == epoch else { return }
        isAutomaticInputSuppressed = false
    }

    private func clearGestureSession() {
        gestureStartSide = nil
        gestureStartTimestamp = nil
        directTouchFastIntent.reset()
        gestureModel = nil
    }

    /// Resolve the curve for an animated settle by role. Gesture-release settles use the motion curve:
    /// the target-aware override from `panEnded`, or a targetless duration-owned fallback for settles
    /// with no live target metadata (e.g. a controller `holdExpanded`). Programmatic resets keep the
    /// public `settlingAnimation` so the close/reset feel stays exactly as before (issue #13).
    private func settleCurve(
        for update: SwipeCellOffsetUpdate,
        override: Animation?,
        inputs: SwipeCellInteractionInputs
    ) -> Animation {
        switch update.animationRole {
        case .releaseSettling:
            return override
                ?? SwipeCellReleaseSettleMotion.fallbackReleaseSettleAnimation(
                    remainingDistance: abs(update.contentOffset - contentOffset),
                    motion: inputs.configuration.motion
                )
        case .forcedReset, .none:
            return inputs.settlingAnimation
        }
    }

    private func applyDestructiveRelease(
        _ side: SwipeCellSide,
        snapshot: SwipeCellInteractionSnapshot,
        releaseVelocity: CGPoint,
        inputs: SwipeCellInteractionInputs
    ) {
        SwipeCellDestructiveTriggerHandler.applyRelease(
            side,
            snapshot: snapshot,
            releaseVelocity: releaseVelocity,
            inputs: inputs,
            host: self
        )
    }

    func shouldClaimImmediateDestructiveAutoCollapseBeforeClosure(
        _ inputs: SwipeCellInteractionInputs
    ) -> Bool {
        shouldClaimImmediateAutoCollapseBeforeClosure(inputs)
    }

    func destructiveTriggerExpandAnimation(
        releaseVelocity: CGPoint,
        releaseTarget: SwipeCellReleaseTarget,
        releaseClassification: SwipeCellReleaseClassification,
        targetOffset: CGFloat,
        inputs: SwipeCellInteractionInputs
    ) -> Animation {
        SwipeCellGestureReleaseResolver.animation(
            releaseVelocity: releaseVelocity,
            releaseTarget: releaseTarget,
            releaseClassification: releaseClassification,
            contentOffset: contentOffset,
            targetOffset: targetOffset,
            referenceDistance: max(abs(targetOffset), abs(contentOffset)),
            motion: inputs.configuration.motion
        )
    }

    func applyDestructiveTriggerOffsetUpdate(
        _ update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String,
        settleAnimation: Animation?,
        claimsForcedResetBeforeDeferring: Bool,
        completion: (() -> Void)?
    ) {
        applyDeferredAnimatedOffsetUpdate(
            update,
            inputs: inputs,
            source: source,
            settleAnimation: settleAnimation,
            claimsForcedResetBeforeDeferring: claimsForcedResetBeforeDeferring,
            completion: completion
        )
    }

    func expectDestructiveTriggerLocalResetGeneration(_ inputs: SwipeCellInteractionInputs) {
        expectLocalResetGeneration(inputs)
    }

    #if DEBUG
        private func logValidationEvent(
            _ event: String,
            inputs: SwipeCellInteractionInputs,
            verdict: @autoclosure () -> SwipeCellValidationDiagnostics.Verdict? = nil,
            fields: @autoclosure () -> [SwipeCellValidationDiagnostics.Field] = []
        ) {
            SwipeCellInteractionDiagnosticsEmitter.emitValidationEvent(
                event,
                snapshot: diagnosticsSnapshot(inputs),
                verdict: verdict(),
                fields: fields()
            )
        }

        private func logHostLifecycle(event: String, inputs: SwipeCellInteractionInputs) {
            SwipeCellInteractionDiagnosticsEmitter.emitHostLifecycle(
                event: event,
                snapshot: diagnosticsSnapshot(inputs)
            )
        }

        private func emitMeasureSettleEvent(
            _ event: String,
            update: SwipeCellOffsetUpdate,
            inputs: SwipeCellInteractionInputs,
            source: String,
            animatedRequest: Bool,
            deferred: Bool,
            completion: Bool,
            fromOffset: @autoclosure () -> CGFloat,
            ownsClosingSettle: Bool,
            metrics: SwipeCellReleaseSettleMetrics?,
            settleElapsed: @autoclosure () -> TimeInterval? = nil
        ) {
            guard let metrics else { return }

            let targetOffset = update.contentOffset
            let resolvedFromOffset = fromOffset()
            let activeCellID = inputs.manager?.activeCellID
            let activeCell = activeCellID.map { SwipeCellValidationDiagnostics.cellString($0) } ?? "nil"
            let hasActiveSwipeDrag = inputs.manager?.hasActiveSwipeDrag == true
            SwipeCellDiagnostics.trace(
                .measure,
                event: "MEASURE_SETTLE",
                fields: [
                    .init("settleEvent", event),
                    .init("source", source),
                    .init("role", SwipeCellValidationDiagnostics.string(update.animationRole)),
                    .init("tracking", SwipeCellValidationDiagnostics.string(inputs.configuration.motion.trackingStyle)),
                    .init("phase", SwipeCellValidationDiagnostics.string(inputs.manager?.phase)),
                    .init("active", activeCell),
                    .init("drag", hasActiveSwipeDrag),
                    .init("fromOffset", resolvedFromOffset),
                    .init("targetOffset", targetOffset),
                    .init("applyRemaining", abs(targetOffset - resolvedFromOffset)),
                    .init("releaseRemaining", metrics.actualRemainingDistance),
                    .init("pacedRemaining", metrics.pacedRemainingDistance),
                    .init("reference", metrics.referenceDistance),
                    .init("releaseSpeed", metrics.releaseSpeed),
                    .init("settleDuration", metrics.settleDuration),
                    .init("releaseTarget", metrics.releaseTarget),
                    .init("classification", String(describing: metrics.releaseClassification)),
                    .init("animated", animatedRequest),
                    .init("deferred", deferred),
                    .init("completion", completion),
                    .init("ownsClosing", ownsClosingSettle),
                    .init("settleElapsed", settleElapsed()),
                    .init("ts", ProcessInfo.processInfo.systemUptime),
                ]
            )
        }

        private func emitSettleEvent(
            _ event: String,
            update: SwipeCellOffsetUpdate,
            inputs: SwipeCellInteractionInputs,
            source: String,
            animatedRequest: Bool,
            deferred: Bool,
            completion: Bool,
            fromOffset: @autoclosure () -> CGFloat,
            sideBeforeClose: SwipeCellSide?,
            visibleSideAfter: @autoclosure () -> SwipeCellSide?,
            settlingSideBeforeClose: SwipeCellSide?,
            settlingSideAfter: @autoclosure () -> SwipeCellSide?,
            ownsClosingSettle: Bool,
            settleElapsed: @autoclosure () -> TimeInterval? = nil,
            resettingBeforeCompletion: @autoclosure () -> AnyHashable? = nil,
            phaseAtApply: @autoclosure () -> SwipeCellPhase? = nil,
            activeAtApply: @autoclosure () -> AnyHashable? = nil,
            resetGenerationAtApply: @autoclosure () -> Int? = nil,
            managerMutatedDuringSettle: @autoclosure () -> Bool? = nil,
            closeDriver: @autoclosure () -> SwipeCellForcedResetCloseDriver? = nil,
            closeEpoch: @autoclosure () -> Int? = nil,
            terminalState: @autoclosure () -> SwipeCellForcedResetCloseTerminalState? = nil,
            verdict: @autoclosure () -> SwipeCellValidationDiagnostics.Verdict? = nil
        ) {
            SwipeCellInteractionDiagnosticsEmitter.emitSettleEvent(
                event,
                update: update,
                snapshot: diagnosticsSnapshot(inputs),
                source: source,
                animatedRequest: animatedRequest,
                deferred: deferred,
                completion: completion,
                fromOffset: fromOffset(),
                visibleSideBefore: sideBeforeClose,
                visibleSideAfter: visibleSideAfter(),
                settlingSideBefore: settlingSideBeforeClose,
                settlingSideAfter: settlingSideAfter(),
                ownsClosingSettle: ownsClosingSettle,
                settleElapsed: settleElapsed(),
                resettingBeforeCompletion: resettingBeforeCompletion(),
                phaseAtApply: phaseAtApply(),
                activeAtApply: activeAtApply(),
                resetGenerationAtApply: resetGenerationAtApply(),
                managerMutatedDuringSettle: managerMutatedDuringSettle(),
                closeDriver: closeDriver(),
                closeEpoch: closeEpoch(),
                terminalState: terminalState(),
                verdict: verdict()
            )
        }

        private func diagnosticsSnapshot(
            _ inputs: SwipeCellInteractionInputs
        ) -> SwipeCellInteractionDiagnosticsSnapshot {
            SwipeCellInteractionDiagnosticsSnapshot(
                inputs: inputs,
                visibleSide: currentVisibleSide(inputs),
                settlingSide: settlingSide,
                contentOffset: contentOffset
            )
        }
    #endif

    private func setArmed(
        _ newValue: Bool,
        inputs: SwipeCellInteractionInputs,
        publishesFeedMarker: Bool
    ) {
        guard isArmed != newValue else { return }

        isArmed = newValue

        // `isArmed` is continuous visual state; marker/haptic output is only an active-drag boundary.
        guard publishesFeedMarker else { return }
        armChangeID += 1
        armChangeKind = newValue ? .enterFire : .exitFire
        publishHaptic(newValue ? .arm : .disarm, inputs: inputs, respectsSuppression: true)
    }

    private func publishHaptic(
        _ kind: SwipeCellHapticEventKind,
        inputs: SwipeCellInteractionInputs,
        respectsSuppression: Bool
    ) {
        // Disabled policy exits before the throttle so an off-state boundary crossing is not suppressed.
        guard inputs.configuration.feedback.hapticPolicy.emitsBoundaryFeedback else { return }
        guard
            let event = hapticThrottle.nextEvent(
                kind: kind,
                respectsSuppression: respectsSuppression,
                suppression: inputs.configuration.timing.hapticSuppression
            )
        else { return }

        hapticEvent = event
    }
}
