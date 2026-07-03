import Foundation

nonisolated enum SwipeCellScrollWheelPhase: Equatable {
    case none
    case mayBegin
    case began
    case changed
    case ended
    case cancelled
}

nonisolated struct SwipeCellScrollWheelSample: Equatable {
    let delta: CGSize
    let phase: SwipeCellScrollWheelPhase
    let momentumPhase: SwipeCellScrollWheelPhase
    let timestamp: TimeInterval?

    init(
        delta: CGSize,
        phase: SwipeCellScrollWheelPhase = .none,
        momentumPhase: SwipeCellScrollWheelPhase = .none,
        timestamp: TimeInterval? = nil
    ) {
        self.delta = delta
        self.phase = phase
        self.momentumPhase = momentumPhase
        self.timestamp = timestamp
    }
}

nonisolated enum SwipeCellIndirectTouchPresencePhase: Equatable {
    case active
    case stationary
    case ended
    case cancelled
}

nonisolated struct SwipeCellIndirectTouchPresenceSample: Equatable {
    let phase: SwipeCellIndirectTouchPresencePhase
    let timestamp: TimeInterval?

    init(
        phase: SwipeCellIndirectTouchPresencePhase,
        timestamp: TimeInterval? = nil
    ) {
        self.phase = phase
        self.timestamp = timestamp
    }
}

nonisolated enum SwipeCellScrollWheelPanEvent: Equatable {
    case ignored
    case began(SwipeCellPanValue)
    case changed(SwipeCellPanValue)
    case latched
    case ended(SwipeCellPanValue)
    case cancelled
}

/// Maps macOS scroll-wheel input to a synthetic pan for the shared interaction model (issue #27).
///
/// Indirect, velocity-less, phase-segmented scroll-wheel input is not treated as a 1:1 direct-touch
/// pan. Instead device-normalized horizontal distance is accumulated along a side locked at `began`,
/// converted to a `progress` axis through the active indirect-scroll gain profile. Progress up to 1 maps
/// to the normal-open extent; only post-open extra progress maps onto the row width locked at gesture start.
/// The shared model still receives point translation and decides open/destructive/settle targets.
nonisolated struct SwipeCellScrollWheelPanAccumulator: Equatable {
    private enum GestureMode: Equatable {
        case reveal
        case close(OpenOriginClose)
    }

    private struct OpenOriginClose: Equatable {
        let startMovement: CGFloat
        let startProgress: CGFloat
    }

    private struct BeginningContext: Equatable {
        let side: SwipeCellSide
        let containerWidth: CGFloat
        let mode: GestureMode
    }

    private static let visualEpsilon: CGFloat = 0.5
    private static let fastNormalReleaseIntentWindow: TimeInterval = 0.16
    private static let fastNormalReleaseIntentProgress: CGFloat = 0.15

    private var input: SwipeCellConfiguration.PlatformInput
    // Source of side enablement and model geometry; closed-to-open uses `normalOpenExtent`, while only
    // post-open extra movement uses the locked row width below.
    private var interactionConfiguration: SwipeCellInteractionConfiguration
    private var container: SwipeCellContainer
    private var containerWidth: CGFloat
    private var contentOffset: CGFloat

    private(set) var isActive = false
    // Locked on the first qualifying physical event. Gain maps accumulated distance onto this side, so a
    // mid-gesture reversal collapses toward closed instead of flipping to reveal the opposite side.
    private var side: SwipeCellSide?
    // Locked on `began` so live window resizing cannot jump the synthetic offset mid-gesture.
    private var lockedContainerWidth: CGFloat?
    // Locked with the row width so active mapping and destructive gating use the same geometry snapshot
    // that the coordinator locked for release. View updates may refresh the next gesture's configuration.
    private var lockedInput: SwipeCellConfiguration.PlatformInput?
    private var lockedInteractionConfiguration: SwipeCellInteractionConfiguration?
    private var lockedContainer: SwipeCellContainer?
    // Synthetic row progress after applying per-event gain. Reveal mode accumulates toward `side`; close
    // mode accumulates toward closed from its open-origin seed. Momentum contributes nothing, so inertia
    // can neither open, arm, nor deepen close speed (the #22/#28 invariant).
    private var accumulatedProgress: CGFloat = 0
    private var uncappedAccumulatedProgress: CGFloat = 0
    // Fast-intent and threshold-bypass signals stay in the raw `D_fast` domain. Adaptive visual gain may
    // cap slow-drag movement for comfort, but that cap must not turn a slow sample into a fast commit hint.
    private var fastReferenceProgress: CGFloat = 0
    private var uncappedFastReferenceProgress: CGFloat = 0
    private var gestureMode: GestureMode = .reveal
    private var peakCloseReleaseVelocityX: CGFloat = 0
    private var peakCloseReleaseVelocityTimestamp: TimeInterval?
    private var latestCloseReleaseVelocityX: CGFloat = 0
    private var latestCloseReleaseVelocityTimestamp: TimeInterval?
    private var fastNormalReleaseIntent = false
    private var fastIntentStartTimestamp: TimeInterval?
    private var fastIntentTriggerTimestamp: TimeInterval?
    private var fastIntentLatestTimestamp: TimeInterval?
    private var fastIntentSampleCount = 0
    private var fastIntentWindowDistance: CGFloat = 0
    #if DEBUG
        private(set) var measureDiagnosticsSnapshot = SwipeCellScrollWheelMeasureDiagnosticsSnapshot.inactive
    #endif
    // Active samples may detect a fast candidate for diagnostics, but only release-time validation can
    // bypass the half-threshold target gate.
    private var releaseBypassesNormalReleaseThreshold: Bool?
    // Active close samples may still report a peak speed for diagnostics / pan-value parity, but #77's
    // indirect-scroll settle no longer consumes that synthetic velocity for ordinary close pacing.
    private var releaseVelocityOverrideX: CGFloat?
    // Crossing the destructive distance is not enough for scroll-wheel release. A destructive release
    // needs one more physical toward-side event while already across the boundary, so a fast flick
    // settles open instead of firing a destructive action.
    private var hasDestructiveContinuation = false
    // ScrollView-backed macOS rows do not receive List's keep-alive micro-events. Once physical movement
    // reaches destructive distance, momentum / synthetic end can hold the armed snapshot until real ended.
    private var hasLatchedDestructiveArm = false
    // Per-gesture capability detection for issue #71. An ended touch is trusted only after this gesture
    // has observed non-resting indirect touch presence; unmatched or delayed streams keep the #70 fallback.
    private var hasObservedIndirectTouchPresence = false
    // While Trackpad contact is active, momentum / synthetic-end are hold signals for the current
    // position, not release signals. Destructive release still requires stationary/finish confirmation.
    private var isIndirectTouchPresenceActive = false
    // A reveal continuing from an already-open row accumulates gesture translation from zero, but the
    // destructive gate is an absolute-position test. Seed the open-origin movement captured at `began` so
    // `isAtDestructiveDistance` reflects the row's real offset (origin + translation), not translation alone.
    private var revealOriginMovement: CGFloat = 0

    init(
        input: SwipeCellConfiguration.PlatformInput = SwipeCellConfiguration.platformDefault.input,
        interactionConfiguration: SwipeCellInteractionConfiguration = SwipeCellInteractionConfiguration(
            leading: .disabled,
            trailing: .disabled
        ),
        container: SwipeCellContainer = .list,
        containerWidth: CGFloat = 0,
        contentOffset: CGFloat = 0
    ) {
        self.input = input
        self.interactionConfiguration = interactionConfiguration
        self.container = container
        self.containerWidth = containerWidth
        self.contentOffset = contentOffset
    }

    mutating func update(
        input: SwipeCellConfiguration.PlatformInput,
        interactionConfiguration: SwipeCellInteractionConfiguration,
        container: SwipeCellContainer,
        containerWidth: CGFloat,
        contentOffset: CGFloat = 0
    ) {
        self.input = input
        self.interactionConfiguration = interactionConfiguration
        self.container = container
        self.containerWidth = containerWidth
        self.contentOffset = contentOffset
    }

    mutating func handle(_ sample: SwipeCellScrollWheelSample) -> SwipeCellScrollWheelPanEvent {
        if sample.phase == .cancelled {
            return measured(cancelActiveGesture(), timestamp: sample.timestamp)
        }

        // Momentum (inertia) never starts or deepens a row swipe. ScrollView destructive arms are the one
        // hold exception: the event confirms "still held", but contributes no movement and never fires.
        guard sample.momentumPhase == .none else {
            if holdTouchPresenceActiveGestureIfNeeded(confirmsDestructiveHold: true) {
                return measured(.latched, timestamp: sample.timestamp)
            }
            if latchDestructiveArmIfNeeded() {
                return measured(.latched, timestamp: sample.timestamp)
            }
            return finishActiveGesture(additionalDelta: .zero, releaseTimestamp: sample.timestamp)
        }

        if sample.phase == .ended {
            #if DEBUG
                SwipeCellDiagnostics.trace(
                    .scrollFast,
                    event: "finish",
                    fields: [
                        .init("cause", "phase-ended"),
                        .init("active", isActive),
                        .init("atDestructive", isAtDestructiveDistance),
                        .init("delta", sample.delta.width, precision: 2),
                    ]
                )
            #endif
            return finishActiveGesture(additionalDelta: sample.delta, releaseTimestamp: sample.timestamp)
        }

        guard sample.delta != .zero else {
            return measured(.ignored, timestamp: sample.timestamp)
        }

        if isActive {
            accumulate(
                sample.delta,
                confirmsDestructiveContinuation: true,
                updatesCloseReleaseVelocity: true,
                updatesFastIntent: true,
                timestamp: sample.timestamp
            )
            return measured(.changed(currentValue), timestamp: sample.timestamp)
        }

        guard sample.phase != .mayBegin,
            let beginning = beginningContext(for: sample.delta)
        else {
            return measured(.ignored, timestamp: sample.timestamp)
        }

        isActive = true
        side = beginning.side
        lockedContainerWidth = beginning.containerWidth
        lockedInput = input
        lockedInteractionConfiguration = interactionConfiguration
        lockedContainer = container
        gestureMode = beginning.mode
        revealOriginMovement = revealOrigin(for: beginning)
        accumulatedProgress = 0
        uncappedAccumulatedProgress = 0
        fastReferenceProgress = 0
        uncappedFastReferenceProgress = 0
        peakCloseReleaseVelocityX = 0
        peakCloseReleaseVelocityTimestamp = nil
        latestCloseReleaseVelocityX = 0
        latestCloseReleaseVelocityTimestamp = nil
        fastNormalReleaseIntent = false
        fastIntentStartTimestamp = nil
        fastIntentTriggerTimestamp = nil
        fastIntentLatestTimestamp = nil
        fastIntentSampleCount = 0
        fastIntentWindowDistance = 0
        releaseBypassesNormalReleaseThreshold = nil
        releaseVelocityOverrideX = nil
        hasDestructiveContinuation = false
        hasLatchedDestructiveArm = false
        hasObservedIndirectTouchPresence = false
        isIndirectTouchPresenceActive = false
        accumulate(
            sample.delta,
            confirmsDestructiveContinuation: false,
            updatesCloseReleaseVelocity: true,
            updatesFastIntent: true,
            timestamp: sample.timestamp
        )
        return measured(.began(currentValue), timestamp: sample.timestamp)
    }

    mutating func finishActiveGesture() -> SwipeCellScrollWheelPanEvent {
        if holdTouchPresenceActiveGestureIfNeeded(confirmsDestructiveHold: true) {
            return measured(.latched, timestamp: nil)
        }
        if latchDestructiveArmIfNeeded() {
            return measured(.latched, timestamp: nil)
        }
        return finishActiveGesture(additionalDelta: .zero, releaseTimestamp: nil)
    }

    mutating func handleTouchPresence(
        _ sample: SwipeCellIndirectTouchPresenceSample
    ) -> SwipeCellScrollWheelPanEvent {
        guard isActive,
            lockedContainer == .scrollView
        else { return .ignored }

        switch sample.phase {
        case .active:
            hasObservedIndirectTouchPresence = true
            isIndirectTouchPresenceActive = true
            return measured(.ignored, timestamp: sample.timestamp)
        case .stationary:
            hasObservedIndirectTouchPresence = true
            isIndirectTouchPresenceActive = true
            let event: SwipeCellScrollWheelPanEvent =
                holdTouchPresenceActiveGestureIfNeeded(confirmsDestructiveHold: true)
                ? .latched : .ignored
            return measured(event, timestamp: sample.timestamp)
        case .ended:
            guard hasObservedIndirectTouchPresence else {
                return measured(.ignored, timestamp: sample.timestamp)
            }
            isIndirectTouchPresenceActive = false
            return finishActiveGesture(additionalDelta: .zero, releaseTimestamp: sample.timestamp)
        case .cancelled:
            guard hasObservedIndirectTouchPresence else {
                return measured(.ignored, timestamp: sample.timestamp)
            }
            isIndirectTouchPresenceActive = false
            return measured(cancelActiveGesture(), timestamp: sample.timestamp)
        }
    }

    mutating func cancelActiveGesture() -> SwipeCellScrollWheelPanEvent {
        guard isActive else {
            return measured(.ignored, timestamp: nil)
        }

        reset()
        return measured(.cancelled, timestamp: nil)
    }

    private mutating func finishActiveGesture(
        additionalDelta: CGSize,
        releaseTimestamp: TimeInterval?
    ) -> SwipeCellScrollWheelPanEvent {
        guard isActive else {
            return measured(.ignored, timestamp: releaseTimestamp)
        }

        if additionalDelta != .zero {
            accumulate(
                additionalDelta,
                confirmsDestructiveContinuation: false,
                updatesCloseReleaseVelocity: false,
                updatesFastIntent: false,
                timestamp: nil
            )
        }
        releaseBypassesNormalReleaseThreshold =
            recordReleaseFastNormalReleaseIntent(timestamp: releaseTimestamp)
        releaseVelocityOverrideX = releaseCloseVelocityX(timestamp: releaseTimestamp)
        let value = currentValue
        #if DEBUG
            refreshMeasureDiagnostics(timestamp: releaseTimestamp)
        #endif
        reset()
        return .ended(value)
    }

    /// The side/row-width a fresh scroll would lock, or `nil` when the input should fall through.
    private func beginningContext(for delta: CGSize) -> BeginningContext? {
        guard abs(delta.width) >= input.scrollWheelMinStartDelta,
            SwipeCellPanIntent.isHorizontal(delta: delta)
        else {
            return nil
        }

        if let closeContext = openOriginCloseBeginningContext(for: delta) {
            return closeContext
        }

        guard let measuredContainerWidth else { return nil }
        let candidate: SwipeCellSide = delta.width >= 0 ? .leading : .trailing
        guard interactionConfiguration.sideConfiguration(for: candidate).isEnabled else {
            return nil
        }
        return BeginningContext(
            side: candidate,
            containerWidth: measuredContainerWidth,
            mode: .reveal
        )
    }

    private func openOriginCloseBeginningContext(for delta: CGSize) -> BeginningContext? {
        guard let visibleSide,
            closeContribution(delta.width, for: visibleSide) > 0
        else {
            return nil
        }

        let widthForMapping = measuredContainerWidth ?? referenceRevealDistance
        let startMovement = abs(contentOffset)
        let startProgress = progress(
            forMovement: startMovement,
            side: visibleSide,
            containerWidth: widthForMapping
        )
        return BeginningContext(
            side: visibleSide,
            containerWidth: widthForMapping,
            mode: .close(
                OpenOriginClose(
                    startMovement: startMovement,
                    startProgress: startProgress
                )
            )
        )
    }

    private mutating func accumulate(
        _ delta: CGSize,
        confirmsDestructiveContinuation: Bool,
        updatesCloseReleaseVelocity: Bool,
        updatesFastIntent: Bool,
        timestamp: TimeInterval?
    ) {
        guard let side else { return }

        if case .close(let context) = gestureMode {
            let rawCloseContribution = closeContribution(delta.width, for: side)
            // Active movement stays capped for visual continuity. The raw physical close impulse remains
            // observable on the synthetic pan value, but release-close motion now uses distance pacing.
            let releaseMovementDelta =
                lockedContainerWidth.map {
                    closeMovementDelta(
                        context: context,
                        side: side,
                        containerWidth: $0,
                        closeContribution: rawCloseContribution,
                        accumulatedProgress: accumulatedProgress
                    )
                } ?? 0
            let contribution = max(0, boundedProgressContribution(rawCloseContribution))
            accumulatedProgress += contribution
            uncappedAccumulatedProgress += max(0, progressContribution(for: rawCloseContribution))
            fastReferenceProgress += max(0, boundedFastReferenceProgressContribution(rawCloseContribution))
            uncappedFastReferenceProgress += max(0, fastReferenceProgressContribution(for: rawCloseContribution))
            if updatesFastIntent {
                recordFastNormalReleaseIntent(
                    contribution: rawCloseContribution,
                    timestamp: timestamp
                )
            }
            if updatesCloseReleaseVelocity, releaseMovementDelta > 0 {
                recordCloseReleaseVelocity(
                    movementDelta: releaseMovementDelta,
                    side: side,
                    timestamp: timestamp
                )
            } else if updatesCloseReleaseVelocity, rawCloseContribution <= 0 {
                clearCloseReleaseVelocity()
            }
            return
        }

        // Toward-side contribution, with the per-event progress increment capped so one fast event
        // (especially a coarse line wheel) eases in instead of teleporting the row.
        let toward = side == .leading ? delta.width : -delta.width
        let contribution = boundedProgressContribution(toward)
        let wasAtDestructiveDistance = isAtDestructiveDistance
        accumulatedProgress = max(0, accumulatedProgress + contribution)
        uncappedAccumulatedProgress = max(0, uncappedAccumulatedProgress + progressContribution(for: toward))
        fastReferenceProgress = max(
            0,
            fastReferenceProgress + boundedFastReferenceProgressContribution(toward)
        )
        uncappedFastReferenceProgress = max(
            0,
            uncappedFastReferenceProgress + fastReferenceProgressContribution(for: toward)
        )
        if updatesFastIntent {
            recordFastNormalReleaseIntent(
                contribution: toward,
                timestamp: timestamp
            )
        }

        if !isAtDestructiveDistance {
            hasDestructiveContinuation = false
            hasLatchedDestructiveArm = false
        } else if confirmsDestructiveContinuation, contribution > 0, wasAtDestructiveDistance {
            hasDestructiveContinuation = true
        }
    }

    private mutating func latchDestructiveArmIfNeeded() -> Bool {
        let isReveal: Bool = if case .reveal = gestureMode { true } else { false }
        let eligible = isActive && lockedContainer == .scrollView && isReveal && isAtDestructiveDistance
        #if DEBUG
            SwipeCellDiagnostics.trace(
                .scrollFast,
                event: "latch-check",
                fields: [
                    .init("eligible", eligible),
                    .init("active", isActive),
                    .init("container", String(describing: lockedContainer)),
                    .init("reveal", isReveal),
                    .init("atDestructive", isAtDestructiveDistance),
                    .init("rawMovement", rawMovement, precision: 2),
                    .init("revealOrigin", revealOriginMovement, precision: 2),
                ]
            )
        #endif
        guard eligible else { return false }

        hasLatchedDestructiveArm = true
        return true
    }

    private mutating func holdTouchPresenceActiveGestureIfNeeded(
        confirmsDestructiveHold: Bool
    ) -> Bool {
        guard isActive,
            lockedContainer == .scrollView,
            isIndirectTouchPresenceActive
        else { return false }

        if confirmsDestructiveHold {
            _ = latchDestructiveArmIfNeeded()
        }
        return true
    }

    /// Clamp a per-event contribution after adaptive gain so `|Δprogress| ≤ scrollWheelMaxProgressStep`.
    /// A non-positive/invalid step disables the cap rather than freezing input.
    private func boundedProgressContribution(_ contribution: CGFloat) -> CGFloat {
        let progress = progressContribution(for: contribution)
        let step = activeInput.scrollWheelMaxProgressStep
        guard step.isFinite, step > 0 else { return progress }
        return min(max(progress, -step), step)
    }

    private func boundedFastReferenceProgressContribution(_ contribution: CGFloat) -> CGFloat {
        let progress = fastReferenceProgressContribution(for: contribution)
        let step = activeInput.scrollWheelMaxProgressStep
        guard step.isFinite, step > 0 else { return progress }
        return min(max(progress, -step), step)
    }

    private func progressContribution(for contribution: CGFloat) -> CGFloat {
        guard contribution != 0 else { return 0 }
        return contribution / adaptiveReferenceRevealDistance(forDelta: abs(contribution))
    }

    private func fastReferenceProgressContribution(for contribution: CGFloat) -> CGFloat {
        contribution / referenceRevealDistance
    }

    private func adaptiveReferenceRevealDistance(forDelta delta: CGFloat) -> CGFloat {
        let slowReference = slowReferenceRevealDistance
        let fastReference = referenceRevealDistance
        guard fastReference > slowReference else { return fastReference }

        let lowerDelta = adaptiveLowerDelta
        let upperDelta = adaptiveUpperDelta
        guard upperDelta > lowerDelta else {
            return delta < lowerDelta ? slowReference : fastReference
        }

        let t = min(max((delta - lowerDelta) / (upperDelta - lowerDelta), 0), 1)
        let smoothstep = t * t * (3 - 2 * t)
        return slowReference + (fastReference - slowReference) * smoothstep
    }

    /// `D_fast`: fast-flick reference distance used by adaptive mapping and invalid fast-intent fallback.
    private var referenceRevealDistance: CGFloat {
        positiveFiniteDistance(activeInput.scrollWheelReferenceRevealDistance, fallback: 48)
    }

    private var slowReferenceRevealDistance: CGFloat {
        min(
            positiveFiniteDistance(
                activeInput.scrollWheelSlowReferenceRevealDistance,
                fallback: referenceRevealDistance
            ),
            referenceRevealDistance
        )
    }

    private var adaptiveLowerDelta: CGFloat {
        positiveFiniteDistance(activeInput.scrollWheelAdaptiveLowerDelta, fallback: 20)
    }

    private var adaptiveUpperDelta: CGFloat {
        max(
            adaptiveLowerDelta,
            positiveFiniteDistance(activeInput.scrollWheelAdaptiveUpperDelta, fallback: 40)
        )
    }

    private func positiveFiniteDistance(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return fallback }
        return value
    }

    private var progress: CGFloat {
        // `accumulatedProgress` is floored at zero, so progress is already non-negative; it may exceed 1
        // after normal open, where extra movement enters the row-width gain range.
        accumulatedProgress
    }

    private mutating func reset() {
        isActive = false
        side = nil
        lockedContainerWidth = nil
        lockedInput = nil
        lockedInteractionConfiguration = nil
        lockedContainer = nil
        accumulatedProgress = 0
        uncappedAccumulatedProgress = 0
        fastReferenceProgress = 0
        uncappedFastReferenceProgress = 0
        gestureMode = .reveal
        peakCloseReleaseVelocityX = 0
        peakCloseReleaseVelocityTimestamp = nil
        latestCloseReleaseVelocityX = 0
        latestCloseReleaseVelocityTimestamp = nil
        fastNormalReleaseIntent = false
        fastIntentStartTimestamp = nil
        fastIntentTriggerTimestamp = nil
        fastIntentLatestTimestamp = nil
        fastIntentSampleCount = 0
        fastIntentWindowDistance = 0
        releaseBypassesNormalReleaseThreshold = nil
        releaseVelocityOverrideX = nil
        hasDestructiveContinuation = false
        hasLatchedDestructiveArm = false
        hasObservedIndirectTouchPresence = false
        isIndirectTouchPresenceActive = false
        revealOriginMovement = 0
    }

    private var currentValue: SwipeCellPanValue {
        let translation = CGSize(width: syntheticTranslationWidth, height: 0)
        // predicted == translation preserves #22's no-prediction invariant: synthetic velocity remains
        // diagnostic-only for indirect-scroll open-origin close and never participates in target choice.
        return SwipeCellPanValue(
            translation: translation,
            predictedEndTranslation: translation,
            allowsDestructiveRelease: allowsDestructiveRelease,
            bypassesNormalReleaseThreshold:
                releaseBypassesNormalReleaseThreshold ?? bypassesNormalReleaseThreshold,
            velocity: CGPoint(x: releaseVelocityOverrideX ?? releaseVelocityX, y: 0),
            openOriginSide: openOriginSeed?.side,
            openOriginMovement: openOriginSeed?.movement
        )
    }

    private var syntheticTranslationWidth: CGFloat {
        guard let side, let lockedContainerWidth else { return 0 }

        switch gestureMode {
        case .reveal:
            let movement = mappedMovement(progress: progress, for: side, containerWidth: lockedContainerWidth)
            return side == .leading ? movement : -movement
        case .close(let context):
            let movement = closeMovement(context: context, side: side, containerWidth: lockedContainerWidth)
            let translationTowardSide = movement - context.startMovement
            return side == .leading ? translationTowardSide : -translationTowardSide
        }
    }

    private func mappedMovement(progress: CGFloat, for side: SwipeCellSide, containerWidth: CGFloat) -> CGFloat {
        let normalOpenExtent = activeInteractionConfiguration.sideConfiguration(for: side).normalOpenExtent
        guard progress > 1 else {
            return progress * normalOpenExtent
        }

        return normalOpenExtent + (progress - 1) * containerWidth
    }

    private func closeMovement(
        context: OpenOriginClose,
        side: SwipeCellSide,
        containerWidth: CGFloat
    ) -> CGFloat {
        closeMovement(
            context: context,
            side: side,
            containerWidth: containerWidth,
            accumulatedProgress: accumulatedProgress
        )
    }

    private func closeMovement(
        context: OpenOriginClose,
        side: SwipeCellSide,
        containerWidth: CGFloat,
        accumulatedProgress: CGFloat
    ) -> CGFloat {
        let closeProgress = max(0, context.startProgress - accumulatedProgress)
        return min(
            context.startMovement,
            mappedMovement(progress: closeProgress, for: side, containerWidth: containerWidth)
        )
    }

    private func closeMovementDelta(
        context: OpenOriginClose,
        side: SwipeCellSide,
        containerWidth: CGFloat,
        closeContribution: CGFloat,
        accumulatedProgress: CGFloat
    ) -> CGFloat {
        let contribution = max(0, progressContribution(for: closeContribution))
        guard contribution > 0 else { return 0 }

        let movementBefore = closeMovement(
            context: context,
            side: side,
            containerWidth: containerWidth,
            accumulatedProgress: accumulatedProgress
        )
        let movementAfter = closeMovement(
            context: context,
            side: side,
            containerWidth: containerWidth,
            accumulatedProgress: accumulatedProgress + contribution
        )
        return max(0, movementBefore - movementAfter)
    }

    private func progress(
        forMovement movement: CGFloat,
        side: SwipeCellSide,
        containerWidth: CGFloat
    ) -> CGFloat {
        let normalOpenExtent = interactionConfiguration.sideConfiguration(for: side).normalOpenExtent
        guard normalOpenExtent > 0 else { return 0 }
        guard movement > normalOpenExtent else { return movement / normalOpenExtent }

        let extraSpan = containerWidth.isFinite && containerWidth > 0 ? containerWidth : referenceRevealDistance
        return 1 + (movement - normalOpenExtent) / extraSpan
    }

    private var measuredContainerWidth: CGFloat? {
        guard containerWidth.isFinite, containerWidth > 0 else { return nil }
        return containerWidth
    }

    private var rawMovement: CGFloat {
        guard lockedContainerWidth != nil else { return 0 }
        return abs(syntheticTranslationWidth)
    }

    private var isAtDestructiveDistance: Bool {
        guard case .reveal = gestureMode else { return false }
        guard let side else { return false }
        let sideConfiguration = activeInteractionConfiguration.sideConfiguration(for: side)
        // Absolute row offset = open-origin captured at `began` + this gesture's reveal translation. A
        // reveal continuing from an already-open row would otherwise under-report and never arm.
        return sideConfiguration.allowsDestructive
            && revealOriginMovement + rawMovement >= sideConfiguration.destructiveActivationExtent
    }

    /// Open-origin reveal distance to seed at `began`: the row's existing same-side open offset when a
    /// reveal continues from an already-open row, otherwise zero. Close gestures never arm destructive.
    private func revealOrigin(for beginning: BeginningContext) -> CGFloat {
        guard case .reveal = beginning.mode,
            let visible = visibleSide,
            visible == beginning.side
        else { return 0 }
        return abs(contentOffset)
    }

    private var allowsDestructiveRelease: Bool {
        !isAtDestructiveDistance || hasDestructiveContinuation || hasLatchedDestructiveArm
    }

    private var bypassesNormalReleaseThreshold: Bool {
        guard let side, let lockedContainerWidth else { return false }
        let sideConfiguration = activeInteractionConfiguration.sideConfiguration(for: side)
        guard sideConfiguration.isEnabled else { return false }

        switch gestureMode {
        case .reveal:
            let cappedMovement = mappedMovement(
                progress: progress,
                for: side,
                containerWidth: lockedContainerWidth
            )
            guard cappedMovement > 0,
                cappedMovement < sideConfiguration.normalOpenThreshold
            else { return false }

            if fastNormalReleaseIntent {
                return true
            }

            let rawCappedMovement = mappedMovement(
                progress: fastReferenceProgress,
                for: side,
                containerWidth: lockedContainerWidth
            )
            let rawUncappedMovement = mappedMovement(
                progress: uncappedFastReferenceProgress,
                for: side,
                containerWidth: lockedContainerWidth
            )
            return rawUncappedMovement > rawCappedMovement
        case .close(let context):
            let closeThreshold = min(sideConfiguration.normalOpenThreshold, context.startMovement)
            guard closeThreshold > 0 else { return false }

            let cappedMovement = closeMovement(
                context: context,
                side: side,
                containerWidth: lockedContainerWidth
            )
            let cappedCloseDistance = context.startMovement - cappedMovement
            guard cappedCloseDistance > 0,
                cappedCloseDistance < closeThreshold
            else { return false }

            if fastNormalReleaseIntent {
                return true
            }

            let rawCappedMovement = closeMovement(
                context: context,
                side: side,
                containerWidth: lockedContainerWidth,
                accumulatedProgress: fastReferenceProgress
            )
            let rawCappedCloseDistance = context.startMovement - rawCappedMovement
            let rawUncappedMovement = closeMovement(
                context: context,
                side: side,
                containerWidth: lockedContainerWidth,
                accumulatedProgress: uncappedFastReferenceProgress
            )
            return context.startMovement - rawUncappedMovement > rawCappedCloseDistance
        }
    }

    private var activeInput: SwipeCellConfiguration.PlatformInput {
        lockedInput ?? input
    }

    private var activeInteractionConfiguration: SwipeCellInteractionConfiguration {
        lockedInteractionConfiguration ?? interactionConfiguration
    }

    private mutating func measured(
        _ event: SwipeCellScrollWheelPanEvent,
        timestamp: TimeInterval?
    ) -> SwipeCellScrollWheelPanEvent {
        #if DEBUG
            refreshMeasureDiagnostics(timestamp: timestamp)
        #endif
        return event
    }

    #if DEBUG
        private mutating func refreshMeasureDiagnostics(timestamp: TimeInterval?) {
            let commit = fastIntentCommitDiagnostic
            measureDiagnosticsSnapshot = SwipeCellScrollWheelMeasureDiagnosticsSnapshot(
                isActive: isActive,
                mode: fastIntentModeLabel,
                side: debugSideLabel,
                referenceRevealDistance: referenceRevealDistance,
                slowReferenceRevealDistance: slowReferenceRevealDistance,
                adaptiveLowerDelta: adaptiveLowerDelta,
                adaptiveUpperDelta: adaptiveUpperDelta,
                maxProgressStep: activeInput.scrollWheelMaxProgressStep,
                minStartDelta: activeInput.scrollWheelMinStartDelta,
                fastIntentRequiredDistance: fastNormalReleaseIntentDistance,
                fastReleaseOpenCommitRatio: fastReleaseOpenCommitRatio,
                fastIntentWindowDistance: fastIntentWindowDistance,
                fastIntentSampleCount: fastIntentSampleCount,
                isSingleFastIntentSample: fastIntentSampleCount == 1,
                hasFastIntent: fastNormalReleaseIntent,
                fastIntentStartAge: fastIntentElapsed(at: timestamp),
                fastIntentTriggerAge: fastIntentElapsed(from: fastIntentTriggerTimestamp, to: timestamp),
                fastIntentCommitDistance: commit?.distance,
                fastIntentCommitThreshold: commit?.threshold,
                visualProgress: progress,
                uncappedVisualProgress: uncappedAccumulatedProgress,
                fastReferenceProgress: fastReferenceProgress,
                uncappedFastReferenceProgress: uncappedFastReferenceProgress,
                releaseBypassesNormalReleaseThreshold: releaseBypassesNormalReleaseThreshold,
                hasObservedIndirectTouchPresence: hasObservedIndirectTouchPresence,
                isIndirectTouchPresenceActive: isIndirectTouchPresenceActive,
                hasLatchedDestructiveArm: hasLatchedDestructiveArm
            )
        }

        private var debugSideLabel: String {
            guard let side else { return "nil" }
            switch side {
            case .leading:
                return "leading"
            case .trailing:
                return "trailing"
            }
        }
    #endif

    private var fastNormalReleaseIntentDistance: CGFloat {
        let value = activeInput.scrollWheelFastReleaseIntentDistance
        let fallback = referenceRevealDistance * Self.fastNormalReleaseIntentProgress
        return max(positiveFiniteDistance(value, fallback: fallback), 1)
    }

    private var fastReleaseOpenCommitRatio: CGFloat {
        let value = activeInput.scrollWheelFastReleaseOpenCommitRatio
        guard value.isFinite, value > 0, value < 1 else { return 1 }
        return value
    }

    private mutating func recordFastNormalReleaseIntent(
        contribution: CGFloat,
        timestamp: TimeInterval?
    ) {
        guard contribution > 0 else {
            clearFastNormalReleaseIntent()
            logFastNormalReleaseIntent(
                event: "reset-nonpositive",
                contribution: contribution,
                timestamp: timestamp,
                elapsed: nil,
                windowDistance: fastIntentWindowDistance,
                triggered: false
            )
            return
        }
        guard let timestamp, timestamp.isFinite else {
            logFastNormalReleaseIntent(
                event: "skip-no-timestamp",
                contribution: contribution,
                timestamp: timestamp,
                elapsed: nil,
                windowDistance: fastIntentWindowDistance,
                triggered: false
            )
            return
        }
        fastIntentLatestTimestamp = timestamp

        let didCapContribution = didCapFastReferenceProgressContribution(contribution)
        if didCapContribution {
            fastNormalReleaseIntent = true
            fastIntentTriggerTimestamp = timestamp
        }

        guard let start = fastIntentStartTimestamp, timestamp >= start else {
            let event = fastIntentStartTimestamp == nil ? "start-window" : "restart-regressed"
            fastNormalReleaseIntent = didCapContribution
            fastIntentTriggerTimestamp = didCapContribution ? timestamp : nil
            fastIntentStartTimestamp = timestamp
            fastIntentSampleCount = 1
            fastIntentWindowDistance = contribution
            logFastNormalReleaseIntent(
                event: event,
                contribution: contribution,
                timestamp: timestamp,
                elapsed: nil,
                windowDistance: fastIntentWindowDistance,
                triggered: false
            )
            return
        }

        let elapsed = timestamp - start
        guard elapsed <= Self.fastNormalReleaseIntentWindow else {
            fastNormalReleaseIntent = didCapContribution
            fastIntentTriggerTimestamp = fastNormalReleaseIntent ? timestamp : nil
            fastIntentStartTimestamp = timestamp
            fastIntentSampleCount = 1
            fastIntentWindowDistance = contribution
            logFastNormalReleaseIntent(
                event: "restart-expired",
                contribution: contribution,
                timestamp: timestamp,
                elapsed: elapsed,
                windowDistance: fastIntentWindowDistance,
                triggered: false
            )
            return
        }

        fastIntentSampleCount += 1
        fastIntentWindowDistance += contribution
        let didTrigger =
            fastIntentSampleCount >= 2
            && fastIntentWindowDistance >= fastNormalReleaseIntentDistance
        if didTrigger {
            fastNormalReleaseIntent = true
            fastIntentTriggerTimestamp = timestamp
        }
        logFastNormalReleaseIntent(
            event: didTrigger ? "triggered" : "waiting",
            contribution: contribution,
            timestamp: timestamp,
            elapsed: elapsed,
            windowDistance: fastIntentWindowDistance,
            triggered: didTrigger
        )
    }

    private mutating func clearFastNormalReleaseIntent() {
        fastNormalReleaseIntent = false
        fastIntentStartTimestamp = nil
        fastIntentTriggerTimestamp = nil
        fastIntentLatestTimestamp = nil
        fastIntentSampleCount = 0
        fastIntentWindowDistance = 0
    }

    private func logFastNormalReleaseIntent(
        event: String,
        contribution: CGFloat,
        timestamp: TimeInterval?,
        elapsed: TimeInterval?,
        windowDistance: CGFloat,
        triggered: Bool
    ) {
        #if DEBUG
            SwipeCellDiagnostics.trace(
                .scrollFast,
                event: event,
                fields: [
                    .init("mode", fastIntentModeLabel),
                    .init("contribution", contribution),
                    .init("windowDistance", windowDistance),
                    .init("required", fastNormalReleaseIntentDistance),
                    .init("commitDistance", fastIntentCommitDiagnostic?.distance),
                    .init("commitThreshold", fastIntentCommitDiagnostic?.threshold),
                    .init("cappedProgress", accumulatedProgress),
                    .init("uncappedProgress", uncappedAccumulatedProgress),
                    .init("fastProgress", fastReferenceProgress),
                    .init("uncappedFastProgress", uncappedFastReferenceProgress),
                    .init("samples", fastIntentSampleCount),
                    .init("elapsed", elapsed),
                    .init("window", Self.fastNormalReleaseIntentWindow),
                    .init("timestamp", timestamp),
                    .init("triggerTimestamp", fastIntentTriggerTimestamp),
                    .init("dRef", referenceRevealDistance),
                    .init("progressLimit", Self.fastNormalReleaseIntentProgress),
                    .init("triggered", triggered),
                    .init("fastIntent", fastNormalReleaseIntent),
                ]
            )
        #endif
    }

    private func didCapFastReferenceProgressContribution(_ contribution: CGFloat) -> Bool {
        abs(boundedFastReferenceProgressContribution(contribution))
            < abs(fastReferenceProgressContribution(for: contribution))
    }

    // Some native-feeling fast opens have only one or two active samples before ended/momentum/synthetic
    // finish. Release validation keeps that short window alive without letting stale low-signal drags pass.
    private mutating func recordReleaseFastNormalReleaseIntent(timestamp: TimeInterval?) -> Bool {
        let releaseTimestamp = normalizedFastIntentReleaseTimestamp(timestamp)
        if fastNormalReleaseIntent {
            guard let elapsed = fastIntentElapsed(from: fastIntentTriggerTimestamp, to: releaseTimestamp) else {
                fastNormalReleaseIntent = false
                logFastNormalReleaseIntent(
                    event: "release-fast-no-timestamp",
                    contribution: 0,
                    timestamp: releaseTimestamp,
                    elapsed: nil,
                    windowDistance: fastIntentWindowDistance,
                    triggered: false
                )
                return false
            }
            guard elapsed <= Self.fastNormalReleaseIntentWindow else {
                fastNormalReleaseIntent = false
                logFastNormalReleaseIntent(
                    event: "release-fast-expired",
                    contribution: 0,
                    timestamp: releaseTimestamp,
                    elapsed: elapsed,
                    windowDistance: fastIntentWindowDistance,
                    triggered: false
                )
                return false
            }

            logFastNormalReleaseIntent(
                event: "release-fast-confirmed",
                contribution: 0,
                timestamp: releaseTimestamp,
                elapsed: elapsed,
                windowDistance: fastIntentWindowDistance,
                triggered: true
            )
            return true
        }

        guard fastIntentSampleCount == 1 else {
            if releaseOpenCommitRatioReachesFastIntentThreshold(timestamp: releaseTimestamp) {
                fastNormalReleaseIntent = true
                fastIntentTriggerTimestamp = releaseTimestamp
                logFastNormalReleaseIntent(
                    event: "release-open-ratio-confirmed",
                    contribution: 0,
                    timestamp: releaseTimestamp,
                    elapsed: fastIntentElapsed(at: releaseTimestamp),
                    windowDistance: fastIntentWindowDistance,
                    triggered: true
                )
                return true
            }
            logFastNormalReleaseIntent(
                event: "release-skip-samples",
                contribution: 0,
                timestamp: releaseTimestamp,
                elapsed: fastIntentElapsed(at: releaseTimestamp),
                windowDistance: fastIntentWindowDistance,
                triggered: false
            )
            return false
        }
        guard let elapsed = fastIntentElapsed(at: releaseTimestamp) else {
            logFastNormalReleaseIntent(
                event: "release-no-timestamp",
                contribution: 0,
                timestamp: releaseTimestamp,
                elapsed: nil,
                windowDistance: fastIntentWindowDistance,
                triggered: false
            )
            return false
        }
        guard elapsed <= Self.fastNormalReleaseIntentWindow else {
            logFastNormalReleaseIntent(
                event: "release-expired",
                contribution: 0,
                timestamp: releaseTimestamp,
                elapsed: elapsed,
                windowDistance: fastIntentWindowDistance,
                triggered: false
            )
            return false
        }
        guard fastIntentWindowDistance >= fastNormalReleaseIntentDistance else {
            logFastNormalReleaseIntent(
                event: "release-short-distance",
                contribution: 0,
                timestamp: releaseTimestamp,
                elapsed: elapsed,
                windowDistance: fastIntentWindowDistance,
                triggered: false
            )
            return false
        }

        fastNormalReleaseIntent = true
        fastIntentTriggerTimestamp = releaseTimestamp
        logFastNormalReleaseIntent(
            event: "triggered-single-release",
            contribution: 0,
            timestamp: releaseTimestamp,
            elapsed: elapsed,
            windowDistance: fastIntentWindowDistance,
            triggered: true
        )
        return true
    }

    private func normalizedFastIntentReleaseTimestamp(_ timestamp: TimeInterval?) -> TimeInterval? {
        guard let releaseTimestamp = timestamp ?? inferredSyntheticFastIntentReleaseTimestamp() else {
            return nil
        }
        // Trackpad touch-presence can be delivered after a scroll sample while carrying an older event
        // timestamp; release validation should not erase fast intent already proven by processed scroll input.
        guard let latest = fastIntentLatestTimestamp,
            let start = fastIntentStartTimestamp,
            releaseTimestamp >= start,
            releaseTimestamp < latest
        else { return releaseTimestamp }

        return latest
    }

    private func inferredSyntheticFastIntentReleaseTimestamp() -> TimeInterval? {
        guard let latest = fastIntentLatestTimestamp else { return nil }
        let delay = activeInput.scrollWheelEndSynthesisDelay
        guard delay.isFinite, delay >= 0 else { return nil }
        return latest + delay
    }

    private func releaseOpenCommitRatioReachesFastIntentThreshold(timestamp: TimeInterval?) -> Bool {
        guard case .reveal = gestureMode else { return false }
        guard fastIntentSampleCount >= 2,
            let elapsed = fastIntentElapsed(at: timestamp),
            elapsed <= Self.fastNormalReleaseIntentWindow,
            let diagnostic = fastIntentCommitDiagnostic,
            diagnostic.distance > 0,
            diagnostic.threshold > 0,
            diagnostic.distance < diagnostic.threshold
        else { return false }

        return diagnostic.distance / diagnostic.threshold >= fastReleaseOpenCommitRatio
    }

    private func fastIntentElapsed(at timestamp: TimeInterval?) -> TimeInterval? {
        fastIntentElapsed(from: fastIntentStartTimestamp, to: timestamp)
    }

    private func fastIntentElapsed(
        from start: TimeInterval?,
        to timestamp: TimeInterval?
    ) -> TimeInterval? {
        guard let start,
            let timestamp,
            timestamp.isFinite,
            timestamp >= start
        else { return nil }
        return timestamp - start
    }

    private var fastIntentCommitDiagnostic: (distance: CGFloat, threshold: CGFloat)? {
        guard let side, let lockedContainerWidth else { return nil }
        let sideConfiguration = activeInteractionConfiguration.sideConfiguration(for: side)
        switch gestureMode {
        case .reveal:
            return (
                mappedMovement(
                    progress: progress,
                    for: side,
                    containerWidth: lockedContainerWidth
                ),
                sideConfiguration.normalOpenThreshold
            )
        case .close(let context):
            let movement = closeMovement(
                context: context,
                side: side,
                containerWidth: lockedContainerWidth
            )
            return (
                context.startMovement - movement,
                min(sideConfiguration.normalOpenThreshold, context.startMovement)
            )
        }
    }

    private var fastIntentModeLabel: String {
        switch gestureMode {
        case .reveal:
            "reveal"
        case .close:
            "close"
        }
    }

    private var visibleSide: SwipeCellSide? {
        guard abs(contentOffset) > Self.visualEpsilon else { return nil }
        return contentOffset > 0 ? .leading : .trailing
    }

    private func closeContribution(_ width: CGFloat, for side: SwipeCellSide) -> CGFloat {
        switch side {
        case .leading:
            -width
        case .trailing:
            width
        }
    }

    private func closeReleaseVelocityX(movementDelta: CGFloat, side: SwipeCellSide) -> CGFloat {
        let delay = activeInput.scrollWheelEndSynthesisDelay
        let duration = delay.isFinite && delay > 0 ? delay : TimeInterval(1.0 / 60.0)
        let speed = movementDelta / duration
        return side == .leading ? -speed : speed
    }

    private mutating func recordCloseReleaseVelocity(
        movementDelta: CGFloat,
        side: SwipeCellSide,
        timestamp: TimeInterval?
    ) {
        let candidate = closeReleaseVelocityX(movementDelta: movementDelta, side: side)
        latestCloseReleaseVelocityX = candidate
        latestCloseReleaseVelocityTimestamp = timestamp
        if abs(candidate) >= abs(peakCloseReleaseVelocityX) {
            peakCloseReleaseVelocityX = candidate
            peakCloseReleaseVelocityTimestamp = timestamp
        }
    }

    private mutating func clearCloseReleaseVelocity() {
        peakCloseReleaseVelocityX = 0
        peakCloseReleaseVelocityTimestamp = nil
        latestCloseReleaseVelocityX = 0
        latestCloseReleaseVelocityTimestamp = nil
    }

    private func releaseCloseVelocityX(timestamp: TimeInterval?) -> CGFloat {
        guard case .close = gestureMode else { return 0 }
        if let elapsed = closeReleaseVelocityElapsed(from: peakCloseReleaseVelocityTimestamp, to: timestamp),
            elapsed <= closeReleaseVelocityConfirmationWindow
        {
            return peakCloseReleaseVelocityX
        }
        if let elapsed = closeReleaseVelocityElapsed(from: latestCloseReleaseVelocityTimestamp, to: timestamp),
            elapsed <= closeReleaseVelocityConfirmationWindow
        {
            return latestCloseReleaseVelocityX
        }
        return 0
    }

    private func closeReleaseVelocityElapsed(
        from start: TimeInterval?,
        to timestamp: TimeInterval?
    ) -> TimeInterval? {
        guard let start,
            let timestamp,
            timestamp.isFinite,
            timestamp >= start
        else { return nil }
        return timestamp - start
    }

    private var closeReleaseVelocityConfirmationWindow: TimeInterval {
        let delay = activeInput.scrollWheelEndSynthesisDelay
        guard delay.isFinite, delay > 0 else { return TimeInterval(1.0 / 60.0) }
        return delay
    }

    private var releaseVelocityX: CGFloat {
        guard case .close = gestureMode else { return 0 }
        return peakCloseReleaseVelocityX
    }

    private var openOriginSeed: (side: SwipeCellSide, movement: CGFloat)? {
        guard let side, case .close(let context) = gestureMode else { return nil }
        return (side, context.startMovement)
    }
}
