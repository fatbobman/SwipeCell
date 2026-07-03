import CoreGraphics
import Foundation

/// Per-gesture direct-touch fast-intent arbitration.
///
/// Fast intent is detected from raw input, while the returned visible movement is a coherent
/// provisional / committed path. Closed-origin fast open avoids early high-energy samples becoming
/// 1:1 row displacement; open-origin fast close can reserve a small visible release distance instead
/// of letting active tracking collapse fully to closed before release. Slow and manual paths stay
/// direct-touch tracking.
nonisolated struct SwipeCellDirectTouchFastIntent {
    private static let preflightTimeLimit: TimeInterval = 0.12
    private static let preflightSampleLimit = 3
    private static let preflightCommitSampleMinimum = 3
    private static let preflightVisibleScale: CGFloat = 0.35
    private static let preflightVisibleExtentCapRatio: CGFloat = 0.25
    private static let largeStepVisibleRampEntryExtentRatio: CGFloat = 0.6
    private static let openManualDebtRecoveryDistanceRatio: CGFloat = 0.125
    private static let openManualDebtRecoveryThresholdRatio: CGFloat = 0.25
    private static let openManualDebtRecoveryDebtRatio: CGFloat = 0.4
    private static let openManualDebtRecoveryExtentFloorRatio: CGFloat = 0.25
    private static let openManualDebtRecoveryMinimum: CGFloat = 8
    private static let openOnlyManualDebtFrameStepExtentRatio: CGFloat = 0.12
    private static let openOnlyManualDebtFirstFrameScale: CGFloat = 0.65
    private static let openOnlyManualDebtSecondFrameScale: CGFloat = 0.85
    private static let openOnlyProtectedHandoffEpsilon: CGFloat = 0.0001
    private static let manualVisibleDebtFrameStepExtentRatio: CGFloat = 0.16
    private static let manualVisibleDebtFrameStepFingerRatio: CGFloat = 2.5
    private static let manualVisibleDebtFrameStepMinimum: CGFloat = 8
    private static let committedManualContinuationDelay: TimeInterval = preflightTimeLimit
    private static let committedManualContinuationThresholdRatio: CGFloat = 0.5
    private static let reversalDistance: CGFloat = 12

    private var phase: Phase = .inactive

    var committedAutoOpenSide: SwipeCellSide? {
        guard case .committedAutoOpen(let state) = phase else { return nil }
        return state.side
    }

    #if DEBUG
        var debugState: SwipeCellDirectTouchFastIntentDebugState {
            phase.debugState
        }
    #endif

    mutating func reset() {
        phase = .inactive
    }

    mutating func visibleMotion(
        snapshot: SwipeCellInteractionSnapshot,
        value: SwipeCellPanValue,
        model: SwipeCellInteractionModel,
        startSide: SwipeCellSide?,
        gestureStartTimestamp: TimeInterval?
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion? {
        guard model.motion.trackingStyle == .directTouch else {
            phase = .normalTracking
            return nil
        }

        let sampleTimestamp = resolvedTimestamp(
            gestureStartTimestamp: gestureStartTimestamp,
            sampleTimestamp: value.timestamp
        )
        let sideConfiguration = model.configuration.sideConfiguration(for: snapshot.interactionSide)
        if let startSide {
            return openOriginCloseVisibleMotion(
                snapshot: snapshot,
                value: value,
                startSide: startSide,
                sideConfiguration: sideConfiguration,
                motion: model.motion,
                gestureStartTimestamp: gestureStartTimestamp,
                sampleTimestamp: sampleTimestamp
            )
        }

        if case .committedAutoOpen(var state) = phase {
            guard state.side == snapshot.interactionSide,
                sideConfiguration.isEnabled
            else {
                phase = .reversedOrCancelled
                return nil
            }

            if isClearReversal(
                value: value,
                side: state.side,
                lastRawMovement: state.lastRawMovement,
                sideConfiguration: sideConfiguration,
                motion: model.motion
            ) {
                phase = .reversedOrCancelled
                return nil
            }

            let currentRawMovement = SwipeCellInteractionGeometry.movement(
                value.translation.width,
                toward: state.side
            )
            let visibleMovement = committedAutoOpenMovement(
                state: state,
                sideConfiguration: sideConfiguration
            )
            // Once playback has had a short window to establish open, sustained outward movement is a
            // manual continuation. Handoff from the current sample so stretch resumes without a raw jump.
            if shouldHandOffCommittedAutoOpenToManual(
                movement: snapshot.effectiveMovement,
                sideConfiguration: sideConfiguration,
                elapsedSinceCommit: sampleTimestamp - state.commitTimestamp
            ) {
                return beginManualTracking(
                    side: state.side,
                    baselineMovement: snapshot.effectiveMovement,
                    visibleMovement: visibleMovement,
                    lastRawMovement: currentRawMovement,
                    recoversVisibleDebt: true
                )
            }

            let shouldAnimateAutoOpen = state.shouldAnimateAutoOpen
            state.lastRawMovement = currentRawMovement
            state.lastVisibleMovement = visibleMovement
            state.shouldAnimateAutoOpen = false
            phase = .committedAutoOpen(state)
            return SwipeCellDirectTouchFastIntentVisibleMotion(
                movement: visibleMovement,
                shouldAnimateAutoOpen: shouldAnimateAutoOpen
            )
        }

        guard sideConfiguration.isEnabled,
            snapshot.effectiveMovement > 0
        else {
            phase = .normalTracking
            return nil
        }

        switch phase {
        case .inactive:
            guard snapshot.isArmed == false else {
                phase = .normalTracking
                return nil
            }
            // A large first sample can bypass preflight entirely; keep only the visible output ramped so
            // raw movement still owns release and destructive decisions.
            if isLargeStepVisibleRampCandidate(
                snapshot: snapshot,
                value: value,
                sideConfiguration: sideConfiguration,
                motion: model.motion,
                gestureStartTimestamp: gestureStartTimestamp,
                sampleTimestamp: sampleTimestamp
            ) {
                return beginLargeStepVisibleRamp(
                    side: snapshot.interactionSide,
                    baselineMovement: snapshot.effectiveMovement,
                    visibleMovement: preflightVisibleMovement(
                        actualMovement: snapshot.effectiveMovement,
                        sideConfiguration: sideConfiguration
                    ),
                    lastRawMovement: SwipeCellInteractionGeometry.movement(
                        value.translation.width,
                        toward: snapshot.interactionSide
                    )
                )
            }
            guard
                isPreflightCandidate(
                    value: value,
                    side: snapshot.interactionSide,
                    sideConfiguration: sideConfiguration
                )
            else {
                phase = .normalTracking
                return nil
            }

            var state = SamplingState(
                side: snapshot.interactionSide,
                firstTimestamp: gestureStartTimestamp ?? sampleTimestamp
            )
            return advanceSampling(
                state: &state,
                snapshot: snapshot,
                value: value,
                sideConfiguration: sideConfiguration,
                motion: model.motion,
                sampleTimestamp: sampleTimestamp
            )
        case .provisionalFast(var state):
            guard state.side == snapshot.interactionSide else {
                phase = .reversedOrCancelled
                return nil
            }

            if SwipeCellInteractionGeometry.movement(value.translation.width, toward: state.side) <= 0 {
                phase = .reversedOrCancelled
                return nil
            }

            return advanceSampling(
                state: &state,
                snapshot: snapshot,
                value: value,
                sideConfiguration: sideConfiguration,
                motion: model.motion,
                sampleTimestamp: sampleTimestamp
            )
        case .pendingManualHandoff(let state):
            guard state.side == snapshot.interactionSide,
                snapshot.effectiveMovement > 0
            else {
                phase = .reversedOrCancelled
                return nil
            }

            let currentRawMovement = SwipeCellInteractionGeometry.movement(
                value.translation.width,
                toward: state.side
            )
            return beginManualTracking(
                side: state.side,
                baselineMovement: snapshot.effectiveMovement,
                visibleMovement: state.visibleMovement,
                lastRawMovement: currentRawMovement,
                recoversVisibleDebt: true
            )
        case .manualTracking(var state):
            guard state.side == snapshot.interactionSide else {
                phase = .reversedOrCancelled
                return nil
            }

            return manualTrackingMotion(
                state: &state,
                snapshot: snapshot,
                value: value,
                sideConfiguration: sideConfiguration,
                storesAsLargeStepRamp: false
            )
        case .largeStepVisibleRamp(var state):
            guard state.side == snapshot.interactionSide else {
                phase = .reversedOrCancelled
                return nil
            }

            return manualTrackingMotion(
                state: &state,
                snapshot: snapshot,
                value: value,
                sideConfiguration: sideConfiguration,
                storesAsLargeStepRamp: true
            )
        case .normalTracking, .reversedOrCancelled:
            return nil
        case .committedAutoOpen, .committedAutoClose:
            return nil
        }
    }

    private mutating func openOriginCloseVisibleMotion(
        snapshot: SwipeCellInteractionSnapshot,
        value: SwipeCellPanValue,
        startSide: SwipeCellSide,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion,
        gestureStartTimestamp: TimeInterval?,
        sampleTimestamp: TimeInterval
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion? {
        guard sideConfiguration.isEnabled,
            snapshot.interactionSide == startSide
        else {
            phase = .normalTracking
            return nil
        }

        let closeDistance = SwipeCellInteractionGeometry.resetDistance(
            value.translation.width,
            from: startSide
        )
        guard closeDistance > 0 else {
            phase = .reversedOrCancelled
            return nil
        }

        if case .committedAutoClose(var state) = phase {
            guard state.side == startSide else {
                phase = .reversedOrCancelled
                return nil
            }

            if shouldCancelCommittedAutoClose(
                state: state,
                effectiveMovement: snapshot.effectiveMovement
            ) {
                phase = .reversedOrCancelled
                return nil
            }

            let visibleMovement = fastCloseReservedMovement(
                effectiveMovement: snapshot.effectiveMovement,
                sideConfiguration: sideConfiguration
            )
            state.lastVisibleMovement = visibleMovement
            state.lastRawCloseDistance = closeDistance
            phase = .committedAutoClose(state)
            return SwipeCellDirectTouchFastIntentVisibleMotion(
                movement: visibleMovement,
                shouldAnimateAutoOpen: false
            )
        }

        guard
            isOpenOriginFastCloseReserveCandidate(
                value: value,
                side: startSide,
                sideConfiguration: sideConfiguration,
                motion: motion,
                gestureStartTimestamp: gestureStartTimestamp,
                sampleTimestamp: sampleTimestamp
            )
        else {
            phase = .normalTracking
            return nil
        }

        let visibleMovement = fastCloseReservedMovement(
            effectiveMovement: snapshot.effectiveMovement,
            sideConfiguration: sideConfiguration
        )
        phase = .committedAutoClose(
            CommittedAutoCloseState(
                side: startSide,
                lastVisibleMovement: visibleMovement,
                lastRawCloseDistance: closeDistance
            )
        )
        return SwipeCellDirectTouchFastIntentVisibleMotion(
            movement: visibleMovement,
            shouldAnimateAutoOpen: false
        )
    }

    static func initialCompressionElapsed(
        gestureStartTimestamp: TimeInterval?,
        sampleTimestamp: TimeInterval?
    ) -> TimeInterval? {
        guard let start = gestureStartTimestamp, start.isFinite else { return nil }
        let current = sampleTimestamp ?? ProcessInfo.processInfo.systemUptime
        guard current.isFinite, current >= start else { return nil }
        return current - start
    }

    private mutating func advanceSampling(
        state: inout SamplingState,
        snapshot: SwipeCellInteractionSnapshot,
        value: SwipeCellPanValue,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion,
        sampleTimestamp: TimeInterval
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion? {
        state.sampleCount += 1
        state.lastRawMovement = SwipeCellInteractionGeometry.movement(
            value.translation.width,
            toward: state.side
        )

        let heldMovement = preflightVisibleMovement(
            actualMovement: snapshot.effectiveMovement,
            sideConfiguration: sideConfiguration
        )
        state.lastVisibleMovement = heldMovement
        let elapsed = sampleTimestamp - state.firstTimestamp

        guard elapsed < Self.preflightTimeLimit else {
            if state.sampleCount > 1 {
                return beginManualFallback(
                    state: state,
                    baselineMovement: snapshot.effectiveMovement,
                    sideConfiguration: sideConfiguration,
                    visibleMovement: heldMovement
                )
            }
            phase = .normalTracking
            return nil
        }

        // A long early movement is manual-drag evidence. If preflight already held earlier samples,
        // rebase manual tracking here instead of replaying the suppressed displacement in one frame.
        guard
            isShortFastIntentMovement(
                movement: state.lastRawMovement,
                sideConfiguration: sideConfiguration
            )
        else {
            return beginManualFallback(
                state: state,
                baselineMovement: snapshot.effectiveMovement,
                sideConfiguration: sideConfiguration,
                visibleMovement: heldMovement
            )
        }

        let qualifiesForActiveFastOpen = qualifiesForFastOpenIntent(
            value: value,
            side: state.side,
            sideConfiguration: sideConfiguration,
            motion: motion
        )
        guard qualifiesForActiveFastOpen else {
            if state.sampleCount > 1 {
                return beginManualFallback(
                    state: state,
                    baselineMovement: snapshot.effectiveMovement,
                    sideConfiguration: sideConfiguration,
                    visibleMovement: heldMovement
                )
            }

            phase = .provisionalFast(state)
            return SwipeCellDirectTouchFastIntentVisibleMotion(
                movement: heldMovement,
                shouldAnimateAutoOpen: false
            )
        }

        // Two high-energy samples are enough to suppress raw displacement, but not enough to prove
        // "flick" over "manual drag". Playback only takes over after another short confirming sample.
        if state.sampleCount >= Self.preflightCommitSampleMinimum {
            var committedState = CommittedAutoOpenState(
                side: state.side,
                commitTimestamp: sampleTimestamp,
                startVisibleMovement: heldMovement,
                lastVisibleMovement: heldMovement,
                shouldAnimateAutoOpen: true,
                lastRawMovement: state.lastRawMovement
            )
            let visibleMovement = committedAutoOpenMovement(
                state: committedState,
                sideConfiguration: sideConfiguration
            )
            committedState.lastVisibleMovement = visibleMovement
            let shouldAnimateAutoOpen = committedState.shouldAnimateAutoOpen
            committedState.shouldAnimateAutoOpen = false
            phase = .committedAutoOpen(committedState)
            return SwipeCellDirectTouchFastIntentVisibleMotion(
                movement: visibleMovement,
                shouldAnimateAutoOpen: shouldAnimateAutoOpen
            )
        }

        if state.sampleCount >= Self.preflightSampleLimit {
            return beginManualFallback(
                state: state,
                baselineMovement: snapshot.effectiveMovement,
                sideConfiguration: sideConfiguration,
                visibleMovement: heldMovement
            )
        }

        phase = .provisionalFast(state)
        return SwipeCellDirectTouchFastIntentVisibleMotion(
            movement: heldMovement,
            shouldAnimateAutoOpen: false
        )
    }

    private mutating func beginManualFallback(
        state: SamplingState,
        baselineMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        visibleMovement: CGFloat
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion {
        // Open-only fallback delays the manual baseline by one sample to avoid a held-to-open jump.
        // Destructive sides keep the immediate path so the fire boundary is not pushed past the finger.
        guard sideConfiguration.allowsDestructive == false else {
            return beginManualTracking(
                state: state,
                baselineMovement: baselineMovement,
                visibleMovement: visibleMovement,
                recoversVisibleDebt: true
            )
        }

        return beginPendingManualHandoff(
            state: state,
            visibleMovement: visibleMovement
        )
    }

    private mutating func beginPendingManualHandoff(
        state: SamplingState,
        visibleMovement: CGFloat
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion {
        let boundedVisibleMovement = min(max(visibleMovement, 0), max(state.lastRawMovement, 0))
        let handoffState = PendingManualHandoffState(
            side: state.side,
            visibleMovement: boundedVisibleMovement,
            lastRawMovement: state.lastRawMovement
        )
        phase = .pendingManualHandoff(handoffState)
        return SwipeCellDirectTouchFastIntentVisibleMotion(
            movement: boundedVisibleMovement,
            shouldAnimateAutoOpen: false
        )
    }

    private mutating func beginManualTracking(
        state: SamplingState,
        baselineMovement: CGFloat,
        visibleMovement: CGFloat,
        recoversVisibleDebt: Bool
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion {
        beginManualTracking(
            side: state.side,
            baselineMovement: baselineMovement,
            visibleMovement: visibleMovement,
            lastRawMovement: state.lastRawMovement,
            recoversVisibleDebt: recoversVisibleDebt
        )
    }

    private mutating func beginManualTracking(
        side: SwipeCellSide,
        baselineMovement: CGFloat,
        visibleMovement: CGFloat,
        lastRawMovement: CGFloat,
        recoversVisibleDebt: Bool = false
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion {
        let boundedVisibleMovement = min(max(visibleMovement, 0), max(baselineMovement, 0))
        let visibleDebt = recoversVisibleDebt ? max(0, max(baselineMovement, 0) - boundedVisibleMovement) : 0
        let manualState = ManualTrackingState(
            side: side,
            baselineMovement: max(baselineMovement, 0),
            visibleBaseline: boundedVisibleMovement,
            visibleDebt: visibleDebt,
            lastVisibleMovement: boundedVisibleMovement,
            lastEffectiveMovement: max(baselineMovement, 0),
            visibleDebtRecoveryFrameCount: 0,
            lastRawMovement: lastRawMovement
        )
        phase = .manualTracking(manualState)
        return SwipeCellDirectTouchFastIntentVisibleMotion(
            movement: boundedVisibleMovement,
            shouldAnimateAutoOpen: false
        )
    }

    private mutating func beginLargeStepVisibleRamp(
        side: SwipeCellSide,
        baselineMovement: CGFloat,
        visibleMovement: CGFloat,
        lastRawMovement: CGFloat
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion {
        let boundedVisibleMovement = min(max(visibleMovement, 0), max(baselineMovement, 0))
        let manualState = ManualTrackingState(
            side: side,
            baselineMovement: max(baselineMovement, 0),
            visibleBaseline: boundedVisibleMovement,
            visibleDebt: max(0, max(baselineMovement, 0) - boundedVisibleMovement),
            lastVisibleMovement: boundedVisibleMovement,
            lastEffectiveMovement: max(baselineMovement, 0),
            visibleDebtRecoveryFrameCount: 0,
            lastRawMovement: lastRawMovement
        )
        phase = .largeStepVisibleRamp(manualState)
        return SwipeCellDirectTouchFastIntentVisibleMotion(
            movement: boundedVisibleMovement,
            shouldAnimateAutoOpen: false
        )
    }

    private mutating func manualTrackingMotion(
        state: inout ManualTrackingState,
        snapshot: SwipeCellInteractionSnapshot,
        value: SwipeCellPanValue,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        storesAsLargeStepRamp: Bool
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion? {
        guard snapshot.effectiveMovement > 0 else {
            phase = .reversedOrCancelled
            return nil
        }

        let currentRawMovement = SwipeCellInteractionGeometry.movement(
            value.translation.width,
            toward: state.side
        )
        if shouldContinueOpenOnlyProtectedTrackingFromOpenBoundary(
            state: state,
            sideConfiguration: sideConfiguration
        ) {
            return ordinaryTrackingMotionFromProtectedState(
                state: state,
                effectiveMovement: snapshot.effectiveMovement,
                lastRawMovement: currentRawMovement
            )
        }

        let trackedMovement = min(
            snapshot.effectiveMovement,
            max(0, state.visibleBaseline + snapshot.effectiveMovement - state.baselineMovement)
        )
        let recoveredMovement = recoveredManualMovement(
            state: state,
            trackedMovement: trackedMovement,
            effectiveMovement: snapshot.effectiveMovement,
            sideConfiguration: sideConfiguration
        )
        let visibleMovement = visibleDebtRateLimitedMovement(
            state: state,
            targetMovement: recoveredMovement,
            effectiveMovement: snapshot.effectiveMovement,
            sideConfiguration: sideConfiguration,
            storesAsLargeStepRamp: storesAsLargeStepRamp
        )
        if state.visibleDebt > 0,
            visibleMovement > state.lastVisibleMovement
        {
            state.visibleDebtRecoveryFrameCount += 1
        }
        if shouldHandOffOpenOnlyProtectedTracking(
            state: state,
            visibleMovement: visibleMovement,
            sideConfiguration: sideConfiguration
        ) {
            // Reaching open is a semantic boundary for open-only debt recovery: after this sample, pause
            // and slight reverse must follow from the rendered baseline instead of replaying stale debt.
            return beginManualTracking(
                side: state.side,
                baselineMovement: snapshot.effectiveMovement,
                visibleMovement: visibleMovement,
                lastRawMovement: currentRawMovement
            )
        }
        state.lastVisibleMovement = visibleMovement
        state.lastEffectiveMovement = snapshot.effectiveMovement
        state.lastRawMovement = currentRawMovement
        phase = storesAsLargeStepRamp ? .largeStepVisibleRamp(state) : .manualTracking(state)
        return SwipeCellDirectTouchFastIntentVisibleMotion(
            movement: visibleMovement,
            shouldAnimateAutoOpen: false
        )
    }

    private mutating func ordinaryTrackingMotionFromProtectedState(
        state: ManualTrackingState,
        effectiveMovement: CGFloat,
        lastRawMovement: CGFloat
    ) -> SwipeCellDirectTouchFastIntentVisibleMotion {
        let visibleMovement = min(
            effectiveMovement,
            max(0, state.lastVisibleMovement + effectiveMovement - state.lastEffectiveMovement)
        )
        return beginManualTracking(
            side: state.side,
            baselineMovement: effectiveMovement,
            visibleMovement: visibleMovement,
            lastRawMovement: lastRawMovement
        )
    }

    private func shouldContinueOpenOnlyProtectedTrackingFromOpenBoundary(
        state: ManualTrackingState,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        state.visibleDebt > 0
            && sideConfiguration.allowsDestructive == false
            && hasReachedOpenBoundary(
                movement: state.lastVisibleMovement,
                sideConfiguration: sideConfiguration
            )
    }

    private func shouldHandOffOpenOnlyProtectedTracking(
        state: ManualTrackingState,
        visibleMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        guard state.visibleDebt > 0,
            sideConfiguration.allowsDestructive == false
        else {
            return false
        }

        return hasReachedOpenBoundary(
            movement: visibleMovement,
            sideConfiguration: sideConfiguration
        )
    }

    private func hasReachedOpenBoundary(
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        guard sideConfiguration.normalOpenExtent > 0 else { return true }
        return movement + Self.openOnlyProtectedHandoffEpsilon >= sideConfiguration.normalOpenExtent
    }

    private func recoveredManualMovement(
        state: ManualTrackingState,
        trackedMovement: CGFloat,
        effectiveMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        guard state.visibleDebt > 0,
            sideConfiguration.isEnabled,
            effectiveMovement.isFinite
        else {
            return trackedMovement
        }

        let recoveryProgress = visibleDebtRecoveryProgress(
            state: state,
            movement: effectiveMovement,
            sideConfiguration: sideConfiguration
        )
        let recoveredMovement = effectiveMovement - state.visibleDebt * (1 - recoveryProgress)
        return min(effectiveMovement, max(trackedMovement, recoveredMovement))
    }

    private func visibleDebtRateLimitedMovement(
        state: ManualTrackingState,
        targetMovement: CGFloat,
        effectiveMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        storesAsLargeStepRamp: Bool
    ) -> CGFloat {
        guard state.visibleDebt > 0,
            targetMovement > state.lastVisibleMovement,
            effectiveMovement.isFinite,
            state.lastEffectiveMovement.isFinite
        else {
            return targetMovement
        }

        if sideConfiguration.allowsDestructive,
            effectiveMovement >= sideConfiguration.destructiveActivationExtent
        {
            return targetMovement
        }

        let effectiveDelta = max(0, effectiveMovement - state.lastEffectiveMovement)
        let maximumStep = manualVisibleDebtFrameStep(
            effectiveDelta: effectiveDelta,
            sideConfiguration: sideConfiguration,
            storesAsLargeStepRamp: storesAsLargeStepRamp,
            recoveryFrameCount: state.visibleDebtRecoveryFrameCount
        )
        return min(targetMovement, state.lastVisibleMovement + maximumStep)
    }

    private func manualVisibleDebtFrameStep(
        effectiveDelta: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        storesAsLargeStepRamp: Bool,
        recoveryFrameCount: Int
    ) -> CGFloat {
        if sideConfiguration.allowsDestructive == false,
            storesAsLargeStepRamp == false
        {
            let extentStep = sideConfiguration.normalOpenExtent * Self.openOnlyManualDebtFrameStepExtentRatio
            let candidate = max(Self.manualVisibleDebtFrameStepMinimum, extentStep)
            guard candidate.isFinite, candidate > 0 else { return Self.manualVisibleDebtFrameStepMinimum }
            return candidate * openOnlyManualDebtEaseInScale(recoveryFrameCount: recoveryFrameCount)
        }

        let extentStep = sideConfiguration.normalOpenExtent * Self.manualVisibleDebtFrameStepExtentRatio
        let floorStep = max(Self.manualVisibleDebtFrameStepMinimum, extentStep)
        let fingerStep = effectiveDelta * Self.manualVisibleDebtFrameStepFingerRatio
        let candidate = max(floorStep, fingerStep)
        guard candidate.isFinite, candidate > 0 else { return Self.manualVisibleDebtFrameStepMinimum }
        return candidate
    }

    private func openOnlyManualDebtEaseInScale(recoveryFrameCount: Int) -> CGFloat {
        // The first recovered frames connect from the held baseline before full repayment speed takes over.
        switch recoveryFrameCount {
        case 0:
            return Self.openOnlyManualDebtFirstFrameScale
        case 1:
            return Self.openOnlyManualDebtSecondFrameScale
        default:
            return 1
        }
    }

    private func visibleDebtRecoveryProgress(
        state: ManualTrackingState,
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        if sideConfiguration.allowsDestructive {
            return destructiveVisibleDebtRecoveryProgress(
                state: state,
                movement: movement,
                sideConfiguration: sideConfiguration
            )
        }

        return openVisibleDebtRecoveryProgress(
            state: state,
            movement: movement,
            sideConfiguration: sideConfiguration
        )
    }

    private func openVisibleDebtRecoveryProgress(
        state: ManualTrackingState,
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        let openExtent = sideConfiguration.normalOpenExtent
        guard openExtent > 0 else { return 1 }

        let start = max(state.baselineMovement, 0)
        let recoveryDistance = openManualDebtRecoveryDistance(
            visibleDebt: state.visibleDebt,
            sideConfiguration: sideConfiguration
        )
        let end = max(openExtent, start + recoveryDistance)

        return clampedProgress(movement, from: start, to: end)
    }

    private func openManualDebtRecoveryDistance(
        visibleDebt: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        let extentDistance = sideConfiguration.normalOpenExtent * Self.openManualDebtRecoveryDistanceRatio
        let thresholdDistance = sideConfiguration.normalOpenThreshold * Self.openManualDebtRecoveryThresholdRatio
        let baseDistance = min(extentDistance, thresholdDistance)
        let debtDistance = visibleDebt * Self.openManualDebtRecoveryDebtRatio
        let extentFloor = sideConfiguration.normalOpenExtent * Self.openManualDebtRecoveryExtentFloorRatio
        let candidate = max(baseDistance, debtDistance, extentFloor)
        guard candidate.isFinite, candidate > 0 else { return Self.openManualDebtRecoveryMinimum }
        return max(Self.openManualDebtRecoveryMinimum, candidate)
    }

    private func destructiveVisibleDebtRecoveryProgress(
        state: ManualTrackingState,
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        let activation = sideConfiguration.destructiveActivationExtent
        guard activation > sideConfiguration.normalOpenExtent else { return 1 }

        let start = min(
            max(sideConfiguration.normalOpenExtent, state.baselineMovement),
            activation
        )
        if start >= activation {
            return movement > state.baselineMovement ? 1 : 0
        }

        let end = activation
        guard end > start else { return 0 }

        return clampedProgress(movement, from: start, to: end)
    }

    private func clampedProgress(_ movement: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        guard end > start else { return movement >= end ? 1 : 0 }
        return min(max((movement - start) / (end - start), 0), 1)
    }

    private func committedAutoOpenMovement(
        state: CommittedAutoOpenState,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        let targetMovement = sideConfiguration.normalOpenExtent
        guard targetMovement.isFinite, targetMovement > 0 else { return state.lastVisibleMovement }

        return targetMovement
    }

    private func preflightVisibleMovement(
        actualMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        guard actualMovement.isFinite, actualMovement > 0 else { return 0 }

        let extentCap = max(1, sideConfiguration.normalOpenExtent * Self.preflightVisibleExtentCapRatio)
        let scaled = actualMovement * Self.preflightVisibleScale
        return min(actualMovement, scaled, extentCap)
    }

    private func isPreflightCandidate(
        value: SwipeCellPanValue,
        side: SwipeCellSide,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        let actualTowardSide = SwipeCellInteractionGeometry.movement(value.translation.width, toward: side)
        let predictedTowardSide = SwipeCellInteractionGeometry.movement(
            value.predictedEndTranslation.width,
            toward: side
        )
        let predictionGain = predictedTowardSide - actualTowardSide

        return actualTowardSide > 0
            && isShortFastIntentMovement(
                movement: actualTowardSide,
                sideConfiguration: sideConfiguration
            )
            && predictedTowardSide >= sideConfiguration.normalOpenThreshold
            && predictionGain >= predictionGainFloor(sideConfiguration: sideConfiguration)
            && predictedTowardSide > actualTowardSide
    }

    private func isLargeStepVisibleRampCandidate(
        snapshot: SwipeCellInteractionSnapshot,
        value: SwipeCellPanValue,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion,
        gestureStartTimestamp: TimeInterval?,
        sampleTimestamp: TimeInterval
    ) -> Bool {
        guard let gestureStartTimestamp,
            sampleTimestamp >= gestureStartTimestamp,
            sampleTimestamp - gestureStartTimestamp < Self.preflightTimeLimit,
            snapshot.effectiveMovement
                >= largeStepVisibleRampEntryMovement(
                    sideConfiguration: sideConfiguration
                )
        else {
            return false
        }

        if sideConfiguration.allowsDestructive,
            snapshot.effectiveMovement >= sideConfiguration.destructiveActivationExtent
        {
            return false
        }

        let actualTowardSide = SwipeCellInteractionGeometry.movement(
            value.translation.width,
            toward: snapshot.interactionSide
        )
        let predictedTowardSide = SwipeCellInteractionGeometry.movement(
            value.predictedEndTranslation.width,
            toward: snapshot.interactionSide
        )
        let predictionGain = predictedTowardSide - actualTowardSide
        let releaseSpeed = max(
            0,
            value.velocity.x * SwipeCellInteractionGeometry.directionMultiplier(for: snapshot.interactionSide)
        )

        return predictionGain >= predictionGainFloor(sideConfiguration: sideConfiguration)
            || releaseSpeed
                >= releaseVelocityFloor(
                    sideConfiguration: sideConfiguration,
                    motion: motion
                )
    }

    private func largeStepVisibleRampEntryMovement(
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        max(
            sideConfiguration.normalOpenThreshold,
            sideConfiguration.normalOpenExtent * Self.largeStepVisibleRampEntryExtentRatio
        )
    }

    private func qualifiesForFastOpenIntent(
        value: SwipeCellPanValue,
        side: SwipeCellSide,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion
    ) -> Bool {
        let actualTowardSide = SwipeCellInteractionGeometry.movement(value.translation.width, toward: side)
        let predictedTowardSide = SwipeCellInteractionGeometry.movement(
            value.predictedEndTranslation.width,
            toward: side
        )
        let predictionGain = predictedTowardSide - actualTowardSide
        let releaseSpeed = max(0, value.velocity.x * SwipeCellInteractionGeometry.directionMultiplier(for: side))

        return actualTowardSide > 0
            && isShortFastIntentMovement(
                movement: actualTowardSide,
                sideConfiguration: sideConfiguration
            )
            && predictedTowardSide >= sideConfiguration.normalOpenThreshold
            && predictionGain
                >= predictionGainFloor(
                    sideConfiguration: sideConfiguration
                )
            && releaseSpeed
                >= activeFastOpenVelocityFloor(
                    sideConfiguration: sideConfiguration,
                    motion: motion
                )
    }

    private func shouldHandOffCommittedAutoOpenToManual(
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        elapsedSinceCommit: TimeInterval
    ) -> Bool {
        guard movement.isFinite,
            elapsedSinceCommit.isFinite,
            elapsedSinceCommit >= Self.committedManualContinuationDelay
        else {
            return false
        }

        let continuationThreshold =
            sideConfiguration.normalOpenExtent
            + sideConfiguration.normalOpenThreshold * Self.committedManualContinuationThresholdRatio
        return movement >= continuationThreshold
    }

    private func shouldCancelCommittedAutoClose(
        state: CommittedAutoCloseState,
        effectiveMovement: CGFloat
    ) -> Bool {
        effectiveMovement > state.lastVisibleMovement + Self.reversalDistance
    }

    private func fastCloseReservedMovement(
        effectiveMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        guard effectiveMovement.isFinite else { return 0 }

        let reserve = SwipeCellReleaseSettleMotion.directTouchFastIntentVisibleReleaseReserveDistance(
            targetOffset: sideConfiguration.normalOpenExtent
        )
        guard reserve > 0 else { return max(0, effectiveMovement) }
        return min(
            sideConfiguration.normalOpenExtent,
            max(max(0, effectiveMovement), reserve)
        )
    }

    private func isOpenOriginFastCloseReserveCandidate(
        value: SwipeCellPanValue,
        side: SwipeCellSide,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion,
        gestureStartTimestamp: TimeInterval?,
        sampleTimestamp: TimeInterval
    ) -> Bool {
        guard
            let elapsed = Self.initialCompressionElapsed(
                gestureStartTimestamp: gestureStartTimestamp,
                sampleTimestamp: sampleTimestamp
            ),
            elapsed < Self.preflightTimeLimit
        else {
            return false
        }

        let actualCloseDistance = SwipeCellInteractionGeometry.resetDistance(
            value.translation.width,
            from: side
        )
        let predictedCloseDistance = SwipeCellInteractionGeometry.resetDistance(
            value.predictedEndTranslation.width,
            from: side
        )
        let predictionGain = predictedCloseDistance - actualCloseDistance
        let closeThreshold = sideConfiguration.normalOpenThreshold
        let closeSpeed = max(
            0,
            -value.velocity.x * SwipeCellInteractionGeometry.directionMultiplier(for: side)
        )

        return actualCloseDistance
            >= Self.directTouchAutomaticReleaseActualFloor(
                sideConfiguration: sideConfiguration
            )
            && predictedCloseDistance >= closeThreshold
            && predictionGain >= predictionGainFloor(sideConfiguration: sideConfiguration)
            && closeSpeed
                >= releaseVelocityFloor(
                    sideConfiguration: sideConfiguration,
                    motion: motion
                )
    }

    private func isShortFastIntentMovement(
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        guard movement.isFinite, movement > 0 else { return false }
        return movement < sideConfiguration.normalOpenThreshold
    }

    private func isClearReversal(
        value: SwipeCellPanValue,
        side: SwipeCellSide,
        lastRawMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion
    ) -> Bool {
        let currentRawMovement = SwipeCellInteractionGeometry.movement(value.translation.width, toward: side)
        if currentRawMovement <= 0 { return true }

        let reverseSpeed = max(0, -value.velocity.x * SwipeCellInteractionGeometry.directionMultiplier(for: side))
        return currentRawMovement + Self.reversalDistance < lastRawMovement
            && reverseSpeed
                >= releaseVelocityFloor(
                    sideConfiguration: sideConfiguration,
                    motion: motion
                ) * 0.5
    }

    private func predictionGainFloor(
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        min(
            sideConfiguration.normalOpenThreshold,
            max(12, sideConfiguration.normalOpenThreshold * 0.3)
        )
    }

    private static func directTouchAutomaticReleaseActualFloor(
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        min(sideConfiguration.normalOpenThreshold, 1)
    }

    private func activeFastOpenVelocityFloor(
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion
    ) -> CGFloat {
        guard sideConfiguration.normalOpenExtent.isFinite,
            sideConfiguration.normalOpenExtent > 0,
            Self.preflightTimeLimit > 0
        else {
            return .greatestFiniteMagnitude
        }

        let preflightImpulseFloor = sideConfiguration.normalOpenExtent / Self.preflightTimeLimit
        let releaseFloor = releaseVelocityFloor(
            sideConfiguration: sideConfiguration,
            motion: motion
        )
        // Active auto-open takes over while the finger is still down, so it needs a short-window
        // impulse. Release prediction remains lower because it only resolves a target after lift.
        let releaseImpulseFloor = releaseFloor.isFinite ? releaseFloor * 2 : releaseFloor
        return max(preflightImpulseFloor, releaseImpulseFloor)
    }

    private func releaseVelocityFloor(
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion
    ) -> CGFloat {
        guard motion.releasePredictionDuration > 0 else { return .greatestFiniteMagnitude }
        return max(240, sideConfiguration.normalOpenExtent / motion.releasePredictionDuration)
    }

    private func resolvedTimestamp(
        gestureStartTimestamp: TimeInterval?,
        sampleTimestamp: TimeInterval?
    ) -> TimeInterval {
        sampleTimestamp
            ?? gestureStartTimestamp
            ?? ProcessInfo.processInfo.systemUptime
    }

    private enum Phase {
        case inactive
        case provisionalFast(SamplingState)
        case pendingManualHandoff(PendingManualHandoffState)
        case manualTracking(ManualTrackingState)
        case largeStepVisibleRamp(ManualTrackingState)
        case normalTracking
        case committedAutoOpen(CommittedAutoOpenState)
        case committedAutoClose(CommittedAutoCloseState)
        case reversedOrCancelled

        #if DEBUG
            var debugState: SwipeCellDirectTouchFastIntentDebugState {
                switch self {
                case .inactive:
                    SwipeCellDirectTouchFastIntentDebugState(phase: "inactive")
                case .provisionalFast(let state):
                    SwipeCellDirectTouchFastIntentDebugState(
                        phase: "provisionalFast",
                        isFastCandidate: true,
                        side: state.side,
                        sampleCount: state.sampleCount,
                        firstTimestamp: state.firstTimestamp,
                        lastVisibleMovement: state.lastVisibleMovement,
                        lastRawMovement: state.lastRawMovement
                    )
                case .pendingManualHandoff(let state):
                    SwipeCellDirectTouchFastIntentDebugState(
                        phase: "pendingManualHandoff",
                        side: state.side,
                        lastVisibleMovement: state.visibleMovement,
                        lastRawMovement: state.lastRawMovement
                    )
                case .manualTracking(let state):
                    SwipeCellDirectTouchFastIntentDebugState(
                        phase: "manualTracking",
                        side: state.side,
                        visibleDebt: state.visibleDebt,
                        lastVisibleMovement: state.lastVisibleMovement,
                        lastRawMovement: state.lastRawMovement
                    )
                case .largeStepVisibleRamp(let state):
                    SwipeCellDirectTouchFastIntentDebugState(
                        phase: "largeStepVisibleRamp",
                        side: state.side,
                        visibleDebt: state.visibleDebt,
                        lastVisibleMovement: state.lastVisibleMovement,
                        lastRawMovement: state.lastRawMovement
                    )
                case .normalTracking:
                    SwipeCellDirectTouchFastIntentDebugState(phase: "normalTracking")
                case .committedAutoOpen(let state):
                    SwipeCellDirectTouchFastIntentDebugState(
                        phase: "committedAutoOpen",
                        isFastIntent: true,
                        isFastCandidate: true,
                        side: state.side,
                        commitTimestamp: state.commitTimestamp,
                        startVisibleMovement: state.startVisibleMovement,
                        lastVisibleMovement: state.lastVisibleMovement,
                        lastRawMovement: state.lastRawMovement
                    )
                case .committedAutoClose(let state):
                    SwipeCellDirectTouchFastIntentDebugState(
                        phase: "committedAutoClose",
                        isFastIntent: true,
                        isFastCandidate: true,
                        side: state.side,
                        lastVisibleMovement: state.lastVisibleMovement,
                        lastRawMovement: state.lastRawCloseDistance
                    )
                case .reversedOrCancelled:
                    SwipeCellDirectTouchFastIntentDebugState(phase: "reversedOrCancelled")
                }
            }
        #endif
    }

    private struct SamplingState {
        let side: SwipeCellSide
        let firstTimestamp: TimeInterval
        var sampleCount = 0
        var lastVisibleMovement: CGFloat = 0
        var lastRawMovement: CGFloat = 0
    }

    private struct PendingManualHandoffState {
        let side: SwipeCellSide
        let visibleMovement: CGFloat
        let lastRawMovement: CGFloat
    }

    private struct ManualTrackingState {
        let side: SwipeCellSide
        let baselineMovement: CGFloat
        let visibleBaseline: CGFloat
        let visibleDebt: CGFloat
        var lastVisibleMovement: CGFloat
        var lastEffectiveMovement: CGFloat
        var visibleDebtRecoveryFrameCount: Int
        var lastRawMovement: CGFloat
    }

    private struct CommittedAutoOpenState {
        let side: SwipeCellSide
        let commitTimestamp: TimeInterval
        let startVisibleMovement: CGFloat
        var lastVisibleMovement: CGFloat
        var shouldAnimateAutoOpen: Bool
        var lastRawMovement: CGFloat
    }

    private struct CommittedAutoCloseState {
        let side: SwipeCellSide
        var lastVisibleMovement: CGFloat
        var lastRawCloseDistance: CGFloat
    }
}

nonisolated struct SwipeCellDirectTouchFastIntentVisibleMotion: Equatable, Sendable {
    let movement: CGFloat
    let shouldAnimateAutoOpen: Bool
}

#if DEBUG
    nonisolated struct SwipeCellDirectTouchFastIntentDebugState: Equatable, Sendable {
        let phase: String
        let isFastIntent: Bool
        let isFastCandidate: Bool
        let side: SwipeCellSide?
        let sampleCount: Int?
        let firstTimestamp: TimeInterval?
        let commitTimestamp: TimeInterval?
        let startVisibleMovement: CGFloat?
        let visibleDebt: CGFloat?
        let lastVisibleMovement: CGFloat?
        let lastRawMovement: CGFloat?

        init(
            phase: String,
            isFastIntent: Bool = false,
            isFastCandidate: Bool = false,
            side: SwipeCellSide? = nil,
            sampleCount: Int? = nil,
            firstTimestamp: TimeInterval? = nil,
            commitTimestamp: TimeInterval? = nil,
            startVisibleMovement: CGFloat? = nil,
            visibleDebt: CGFloat? = nil,
            lastVisibleMovement: CGFloat? = nil,
            lastRawMovement: CGFloat? = nil
        ) {
            self.phase = phase
            self.isFastIntent = isFastIntent
            self.isFastCandidate = isFastCandidate
            self.side = side
            self.sampleCount = sampleCount
            self.firstTimestamp = firstTimestamp
            self.commitTimestamp = commitTimestamp
            self.startVisibleMovement = startVisibleMovement
            self.visibleDebt = visibleDebt
            self.lastVisibleMovement = lastVisibleMovement
            self.lastRawMovement = lastRawMovement
        }
    }
#endif
