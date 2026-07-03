import CoreGraphics

@_spi(ManualDebug) nonisolated public enum SwipeCellInteractionThresholdLevel: Equatable, Sendable {
    case belowNormal
    case normalOpen
    case betweenNormalAndDestructive
    case destructive
}

@_spi(ManualDebug) nonisolated public enum SwipeCellReleaseTarget: Equatable, Sendable {
    case closed
    case open(SwipeCellSide)
    case destructive(SwipeCellSide)
}

@_spi(ManualDebug) nonisolated public enum SwipeCellReleaseClassification: Equatable, Sendable {
    case standard
    case automaticOpen
    case automaticClose
}

@_spi(ManualDebug) nonisolated public struct SwipeCellSettlingTarget: Equatable, Sendable {
    public let releaseTarget: SwipeCellReleaseTarget
    public let contentOffset: CGFloat

    public init(releaseTarget: SwipeCellReleaseTarget, contentOffset: CGFloat) {
        self.releaseTarget = releaseTarget
        self.contentOffset = contentOffset
    }
}

@_spi(ManualDebug) nonisolated public struct SwipeCellInteractionSideConfiguration: Equatable, Sendable {
    public static let disabled = SwipeCellInteractionSideConfiguration(
        isEnabled: false,
        normalOpenExtent: 0
    )

    public let isEnabled: Bool
    public let normalOpenExtent: CGFloat
    public let normalOpenThreshold: CGFloat
    public let allowsDestructive: Bool
    public let destructiveActivationExtent: CGFloat
    public let destructiveHoldExtent: CGFloat

    @available(*, deprecated, renamed: "destructiveActivationExtent")
    public var destructiveThreshold: CGFloat { destructiveActivationExtent }

    @available(*, deprecated, renamed: "destructiveHoldExtent")
    public var destructiveSettlingExtent: CGFloat { destructiveHoldExtent }

    public init(
        isEnabled: Bool = true,
        normalOpenExtent: CGFloat,
        normalOpenThreshold: CGFloat? = nil,
        allowsDestructive: Bool = false,
        destructiveThreshold: CGFloat? = nil,
        destructiveSettlingExtent: CGFloat? = nil
    ) {
        let normalizedExtent = Self.positiveDistance(normalOpenExtent, fallback: 0)
        let normalizedNormalThreshold = Self.positiveDistance(
            normalOpenThreshold ?? normalizedExtent,
            fallback: normalizedExtent
        )
        let destructiveFallback = normalizedExtent + 1
        let normalizedDestructiveActivation = Self.destructiveDistance(
            destructiveThreshold ?? destructiveFallback,
            normalOpenExtent: normalizedExtent,
            fallback: destructiveFallback
        )
        let normalizedDestructiveHoldExtent = max(
            normalizedDestructiveActivation,
            Self.positiveDistance(
                destructiveSettlingExtent ?? normalizedDestructiveActivation,
                fallback: normalizedDestructiveActivation
            )
        )
        let sideIsEnabled = isEnabled && normalizedExtent > 0

        self.isEnabled = sideIsEnabled
        self.normalOpenExtent = sideIsEnabled ? normalizedExtent : 0
        self.normalOpenThreshold = sideIsEnabled ? normalizedNormalThreshold : 0
        self.allowsDestructive = sideIsEnabled && allowsDestructive
        self.destructiveActivationExtent = sideIsEnabled ? normalizedDestructiveActivation : 0
        self.destructiveHoldExtent = sideIsEnabled ? normalizedDestructiveHoldExtent : 0
    }

    private static func positiveDistance(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return max(0, fallback) }
        return value
    }

    private static func destructiveDistance(
        _ value: CGFloat,
        normalOpenExtent: CGFloat,
        fallback: CGFloat
    ) -> CGFloat {
        let candidate = positiveDistance(value, fallback: fallback)
        // Keep destructive-ready distinct from the normal-open rest extent after normalization.
        guard candidate > normalOpenExtent else { return max(normalOpenExtent, fallback) }
        return candidate
    }
}

@_spi(ManualDebug) nonisolated public struct SwipeCellInteractionConfiguration: Equatable, Sendable {
    public let leading: SwipeCellInteractionSideConfiguration
    public let trailing: SwipeCellInteractionSideConfiguration

    public init(
        leading: SwipeCellInteractionSideConfiguration,
        trailing: SwipeCellInteractionSideConfiguration
    ) {
        self.leading = leading
        self.trailing = trailing
    }

    public static func symmetric(
        normalOpenExtent: CGFloat,
        normalOpenThreshold: CGFloat? = nil
    ) -> SwipeCellInteractionConfiguration {
        let sideConfiguration = SwipeCellInteractionSideConfiguration(
            normalOpenExtent: normalOpenExtent,
            normalOpenThreshold: normalOpenThreshold
        )
        return SwipeCellInteractionConfiguration(
            leading: sideConfiguration,
            trailing: sideConfiguration
        )
    }

    public func sideConfiguration(for side: SwipeCellSide) -> SwipeCellInteractionSideConfiguration {
        switch side {
        case .leading:
            leading
        case .trailing:
            trailing
        }
    }
}

@_spi(ManualDebug) nonisolated public struct SwipeCellInteractionSnapshot: Equatable, Sendable {
    public let pointerActive: Bool
    public let interactionSide: SwipeCellSide
    public let translationWidth: CGFloat
    public let activeOffset: CGFloat
    public let effectiveMovement: CGFloat
    public let normalOpenProgress: CGFloat
    public let deformationProgress: CGFloat
    public let isArmed: Bool
    public let thresholdLevel: SwipeCellInteractionThresholdLevel
    public let releaseTarget: SwipeCellReleaseTarget?
    public let releaseClassification: SwipeCellReleaseClassification
    public let settlingTarget: SwipeCellSettlingTarget?

    public init(
        pointerActive: Bool,
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        activeOffset: CGFloat,
        effectiveMovement: CGFloat,
        normalOpenProgress: CGFloat,
        thresholdLevel: SwipeCellInteractionThresholdLevel,
        releaseTarget: SwipeCellReleaseTarget?,
        releaseClassification: SwipeCellReleaseClassification = .standard,
        settlingTarget: SwipeCellSettlingTarget?,
        deformationProgress: CGFloat = 0,
        isArmed: Bool = false
    ) {
        self.pointerActive = pointerActive
        self.interactionSide = interactionSide
        self.translationWidth = translationWidth
        self.activeOffset = activeOffset
        self.effectiveMovement = effectiveMovement
        self.normalOpenProgress = normalOpenProgress
        self.deformationProgress = deformationProgress
        self.isArmed = isArmed
        self.thresholdLevel = thresholdLevel
        self.releaseTarget = releaseTarget
        self.releaseClassification = releaseClassification
        self.settlingTarget = settlingTarget
    }

    @available(*, deprecated, renamed: "deformationProgress")
    public var destructiveProgress: CGFloat { deformationProgress }

    @available(*, deprecated, renamed: "isArmed")
    public var isDestructiveArmed: Bool { isArmed }
}

@_spi(ManualDebug) nonisolated public struct SwipeCellInteractionModel: Equatable, Sendable {
    public let configuration: SwipeCellInteractionConfiguration
    public let motion: SwipeCellConfiguration.Motion

    public init(
        configuration: SwipeCellInteractionConfiguration,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) {
        self.configuration = configuration
        self.motion = motion
    }

    public func snapshot(
        startSide: SwipeCellSide?,
        lockedSide: SwipeCellSide? = nil,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat? = nil,
        openOriginMovement: CGFloat? = nil,
        bypassesNormalReleaseThreshold: Bool = false,
        pointerActive: Bool
    ) -> SwipeCellInteractionSnapshot {
        // A fresh gesture (no open-side start) locks to the side committed on its first frame, so a
        // mid-drag reversal collapses toward closed instead of flipping sides and revealing the
        // opposite actions. An open-side restoration carries its own lock through startSide.
        let interactionSide = startSide ?? lockedSide ?? Self.side(for: translationWidth)
        let sideConfiguration = configuration.sideConfiguration(for: interactionSide)
        let movement = effectiveMovement(
            startSide: startSide,
            interactionSide: interactionSide,
            translationWidth: translationWidth,
            openOriginMovement: openOriginMovement,
            sideConfiguration: sideConfiguration
        )
        let normalReleaseDecision =
            pointerActive
            ? NormalReleaseDecision(movement: movement, classification: .standard)
            : normalReleaseDecisionMovement(
                startSide: startSide,
                interactionSide: interactionSide,
                translationWidth: translationWidth,
                predictedEndTranslationWidth: predictedEndTranslationWidth,
                movement: movement,
                bypassesNormalReleaseThreshold: bypassesNormalReleaseThreshold,
                sideConfiguration: sideConfiguration
            )
        let thresholdLevel = thresholdLevel(
            pointerActive: pointerActive,
            actualMovement: movement,
            normalReleaseMovement: normalReleaseDecision.movement,
            sideConfiguration: sideConfiguration
        )

        let releaseTargetValue: SwipeCellReleaseTarget?
        if pointerActive {
            releaseTargetValue = nil
        } else {
            releaseTargetValue = releaseTarget(
                startSide: startSide,
                interactionSide: interactionSide,
                translationWidth: translationWidth,
                predictedEndTranslationWidth: predictedEndTranslationWidth,
                openOriginMovement: openOriginMovement,
                actualMovement: movement,
                normalReleaseMovement: normalReleaseDecision.movement,
                bypassesNormalReleaseThreshold: bypassesNormalReleaseThreshold,
                sideConfiguration: sideConfiguration
            )
        }

        let settlingTargetValue: SwipeCellSettlingTarget?
        if let releaseTargetValue {
            settlingTargetValue = settlingTarget(
                for: releaseTargetValue,
                sideConfiguration: sideConfiguration
            )
        } else {
            settlingTargetValue = nil
        }

        return SwipeCellInteractionSnapshot(
            pointerActive: pointerActive,
            interactionSide: interactionSide,
            translationWidth: translationWidth,
            activeOffset: Self.signedOffset(movement, for: interactionSide),
            effectiveMovement: movement,
            normalOpenProgress: normalOpenProgress(
                movement: movement,
                sideConfiguration: sideConfiguration
            ),
            thresholdLevel: thresholdLevel,
            releaseTarget: releaseTargetValue,
            releaseClassification: releaseClassification(
                normalReleaseDecision: normalReleaseDecision,
                releaseTarget: releaseTargetValue,
                startSide: startSide,
                interactionSide: interactionSide,
                translationWidth: translationWidth,
                predictedEndTranslationWidth: predictedEndTranslationWidth,
                openOriginMovement: openOriginMovement,
                actualMovement: movement,
                sideConfiguration: sideConfiguration
            ),
            settlingTarget: settlingTargetValue,
            deformationProgress: deformationProgress(
                movement: movement,
                sideConfiguration: sideConfiguration
            ),
            isArmed: isArmed(movement: movement, sideConfiguration: sideConfiguration)
        )
    }

    private struct NormalReleaseDecision: Equatable, Sendable {
        let movement: CGFloat
        let classification: SwipeCellReleaseClassification
    }

    private func effectiveMovement(
        startSide: SwipeCellSide?,
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        openOriginMovement: CGFloat?,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        guard sideConfiguration.isEnabled else { return 0 }

        let proposedMovement: CGFloat
        if startSide != nil {
            let baseline = openOriginBaseline(
                openOriginMovement,
                sideConfiguration: sideConfiguration
            )
            // An open-side gesture keeps its semantic side; reverse movement collapses toward center.
            proposedMovement = max(
                0,
                baseline
                    + Self.movement(translationWidth, toward: interactionSide)
            )
        } else {
            // Toward the resolved side, so a reversal on a side-locked fresh gesture clamps to zero
            // instead of re-opening as the opposite side. Without a lock the side tracks the sign, so
            // this equals the raw magnitude.
            proposedMovement = max(0, Self.movement(translationWidth, toward: interactionSide))
        }

        return Self.rubberBandedMovement(
            proposedMovement,
            sideConfiguration: sideConfiguration,
            motion: motion
        )
    }

    private func openOriginBaseline(
        _ openOriginMovement: CGFloat?,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        // Open-origin close seeds the current visual movement; older open-side gestures keep normal open.
        guard let openOriginMovement, openOriginMovement.isFinite, openOriginMovement > 0 else {
            return sideConfiguration.normalOpenExtent
        }

        return openOriginMovement
    }

    private func normalReleaseDecisionMovement(
        startSide: SwipeCellSide?,
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat?,
        movement: CGFloat,
        bypassesNormalReleaseThreshold: Bool,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> NormalReleaseDecision {
        guard sideConfiguration.isEnabled else {
            return NormalReleaseDecision(movement: 0, classification: .standard)
        }

        // Resolve fast-open intent alongside the normal-threshold commit path. A heavy flick can push
        // the active offset a few rubber-banded points past the open endpoint before release; keep that
        // as automatic intent, while excluding deeper overdrag that is already visually held open.
        let qualifiesForFastOpen =
            motion.trackingStyle == .directTouch
            && startSide == nil
            && movement <= directTouchAutomaticOpenMovementCeiling(sideConfiguration: sideConfiguration)
            && qualifiesForDirectTouchFastOpen(
                interactionSide: interactionSide,
                translationWidth: translationWidth,
                predictedEndTranslationWidth: predictedEndTranslationWidth,
                movement: movement,
                sideConfiguration: sideConfiguration
            )
        let classification: SwipeCellReleaseClassification =
            qualifiesForFastOpen ? .automaticOpen : .standard

        guard movement < sideConfiguration.normalOpenThreshold else {
            return NormalReleaseDecision(movement: movement, classification: classification)
        }

        if bypassesNormalReleaseThreshold, movement > 0 {
            return NormalReleaseDecision(
                movement: sideConfiguration.normalOpenThreshold,
                classification: .standard
            )
        }

        guard qualifiesForFastOpen else {
            return NormalReleaseDecision(movement: movement, classification: .standard)
        }

        return NormalReleaseDecision(
            movement: sideConfiguration.normalOpenThreshold,
            classification: .automaticOpen
        )
    }

    private func releaseClassification(
        normalReleaseDecision: NormalReleaseDecision,
        releaseTarget: SwipeCellReleaseTarget?,
        startSide: SwipeCellSide?,
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat?,
        openOriginMovement: CGFloat?,
        actualMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> SwipeCellReleaseClassification {
        if case .automaticOpen = normalReleaseDecision.classification,
            case .open = releaseTarget
        {
            return .automaticOpen
        }

        if case .closed = releaseTarget,
            startSide != nil,
            qualifiesForDirectTouchFastOpenOriginClose(
                interactionSide: interactionSide,
                translationWidth: translationWidth,
                predictedEndTranslationWidth: predictedEndTranslationWidth,
                openOriginMovement: openOriginMovement,
                actualMovement: actualMovement,
                sideConfiguration: sideConfiguration
            )
        {
            return .automaticClose
        }

        return .standard
    }

    private func directTouchAutomaticOpenMovementCeiling(
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        sideConfiguration.normalOpenExtent
            + directTouchAutomaticOpenEndpointOvershootAllowance(sideConfiguration: sideConfiguration)
    }

    private func directTouchAutomaticOpenEndpointOvershootAllowance(
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        min(
            sideConfiguration.normalOpenThreshold,
            max(0, sideConfiguration.normalOpenExtent * motion.rubberBandCoefficient)
        )
    }

    private func qualifiesForDirectTouchFastOpen(
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat?,
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        guard let predictedEndTranslationWidth,
            predictedEndTranslationWidth.isFinite
        else {
            return false
        }

        let actualTowardSide = Self.movement(translationWidth, toward: interactionSide)
        let predictedTowardSide = Self.movement(predictedEndTranslationWidth, toward: interactionSide)
        let predictionGain = predictedTowardSide - actualTowardSide
        let fastOpenActualFloor = Self.directTouchAutomaticReleaseActualFloor(
            sideConfiguration: sideConfiguration
        )
        let fastOpenPredictionGainFloor = Self.directTouchAutomaticReleasePredictionGainFloor(
            sideConfiguration: sideConfiguration
        )

        // Automatic fast-open is intentionally close to a `.distance(1)` actual gate, but still requires
        // a substantial same-side prediction gain so slow drags keep the normal 0.5 threshold.
        return movement >= fastOpenActualFloor
            && predictionGain >= fastOpenPredictionGainFloor
            && predictedTowardSide >= sideConfiguration.normalOpenThreshold
    }

    private static func directTouchAutomaticReleaseActualFloor(
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        min(sideConfiguration.normalOpenThreshold, 1)
    }

    private static func directTouchAutomaticReleasePredictionGainFloor(
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        min(
            sideConfiguration.normalOpenThreshold,
            max(12, sideConfiguration.normalOpenThreshold * 0.3)
        )
    }

    private func thresholdLevel(
        pointerActive: Bool,
        actualMovement: CGFloat,
        normalReleaseMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> SwipeCellInteractionThresholdLevel {
        guard sideConfiguration.isEnabled else { return .belowNormal }

        if sideConfiguration.allowsDestructive,
            actualMovement >= sideConfiguration.destructiveActivationExtent
        {
            return .destructive
        }

        if sideConfiguration.allowsDestructive,
            actualMovement >= sideConfiguration.normalOpenExtent
        {
            return .betweenNormalAndDestructive
        }

        let normalMovement = pointerActive ? actualMovement : normalReleaseMovement
        guard normalMovement >= sideConfiguration.normalOpenThreshold else {
            return .belowNormal
        }

        return .normalOpen
    }

    private func releaseTarget(
        startSide: SwipeCellSide?,
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat?,
        openOriginMovement: CGFloat?,
        actualMovement: CGFloat,
        normalReleaseMovement: CGFloat,
        bypassesNormalReleaseThreshold: Bool,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> SwipeCellReleaseTarget {
        guard sideConfiguration.isEnabled else { return .closed }

        if startSide != nil {
            guard
                !shouldCloseOpenOriginRelease(
                    interactionSide: interactionSide,
                    translationWidth: translationWidth,
                    predictedEndTranslationWidth: predictedEndTranslationWidth,
                    openOriginMovement: openOriginMovement,
                    actualMovement: actualMovement,
                    bypassesNormalReleaseThreshold: bypassesNormalReleaseThreshold,
                    sideConfiguration: sideConfiguration
                )
            else {
                return .closed
            }
        } else {
            guard normalReleaseMovement >= sideConfiguration.normalOpenThreshold else {
                return .closed
            }
        }

        // Destructive fire is still an actual-position commitment; prediction may only promote an iOS
        // direct-touch flick to ordinary open.
        if isArmed(movement: actualMovement, sideConfiguration: sideConfiguration) {
            return .destructive(interactionSide)
        }

        return .open(interactionSide)
    }

    private func shouldCloseOpenOriginRelease(
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat?,
        openOriginMovement: CGFloat?,
        actualMovement: CGFloat,
        bypassesNormalReleaseThreshold: Bool,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        let resetDistance = Self.resetDistance(translationWidth, from: interactionSide)
        guard resetDistance > 0 else { return false }

        let baseline = openOriginBaseline(
            openOriginMovement,
            sideConfiguration: sideConfiguration
        )
        let closeThreshold = min(sideConfiguration.normalOpenThreshold, baseline)
        let actualCloseDistance = max(resetDistance, baseline - actualMovement)

        guard actualCloseDistance < closeThreshold else {
            return true
        }

        if bypassesNormalReleaseThreshold {
            return true
        }

        guard motion.trackingStyle == .directTouch else {
            return false
        }

        return qualifiesForDirectTouchFastClose(
            interactionSide: interactionSide,
            translationWidth: translationWidth,
            predictedEndTranslationWidth: predictedEndTranslationWidth,
            actualCloseDistance: actualCloseDistance,
            closeThreshold: closeThreshold,
            sideConfiguration: sideConfiguration
        )
    }

    private func qualifiesForDirectTouchFastClose(
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat?,
        actualCloseDistance: CGFloat,
        closeThreshold: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        guard let predictedEndTranslationWidth,
            predictedEndTranslationWidth.isFinite
        else {
            return false
        }

        let predictedCloseDistance = Self.resetDistance(
            predictedEndTranslationWidth,
            from: interactionSide
        )
        let predictionGain =
            predictedCloseDistance
            - Self.resetDistance(
                translationWidth,
                from: interactionSide
            )
        let fastCloseActualFloor = Self.directTouchAutomaticReleaseActualFloor(
            sideConfiguration: sideConfiguration
        )
        let fastClosePredictionGainFloor = Self.directTouchAutomaticReleasePredictionGainFloor(
            sideConfiguration: sideConfiguration
        )

        // Mirror fast-open: automatic close can commit from a minimal real reset gesture, then the settle
        // owns the close target instead of continuing to track drag distance.
        return actualCloseDistance >= fastCloseActualFloor
            && predictionGain >= fastClosePredictionGainFloor
            && predictedCloseDistance >= closeThreshold
    }

    private func qualifiesForDirectTouchFastOpenOriginClose(
        interactionSide: SwipeCellSide,
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat?,
        openOriginMovement: CGFloat?,
        actualMovement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        guard motion.trackingStyle == .directTouch else { return false }

        let resetDistance = Self.resetDistance(translationWidth, from: interactionSide)
        guard resetDistance > 0 else { return false }

        let baseline = openOriginBaseline(
            openOriginMovement,
            sideConfiguration: sideConfiguration
        )
        let closeThreshold = min(sideConfiguration.normalOpenThreshold, baseline)
        let actualCloseDistance = max(resetDistance, baseline - actualMovement)
        return qualifiesForDirectTouchFastClose(
            interactionSide: interactionSide,
            translationWidth: translationWidth,
            predictedEndTranslationWidth: predictedEndTranslationWidth,
            actualCloseDistance: actualCloseDistance,
            closeThreshold: closeThreshold,
            sideConfiguration: sideConfiguration
        )
    }

    private func settlingTarget(
        for releaseTarget: SwipeCellReleaseTarget,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> SwipeCellSettlingTarget {
        let offset =
            switch releaseTarget {
            case .closed:
                CGFloat.zero
            case .open(let side):
                Self.signedOffset(sideConfiguration.normalOpenExtent, for: side)
            case .destructive(let side):
                Self.signedOffset(sideConfiguration.destructiveHoldExtent, for: side)
            }

        return SwipeCellSettlingTarget(
            releaseTarget: releaseTarget,
            contentOffset: offset
        )
    }

    private func normalOpenProgress(
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        guard sideConfiguration.isEnabled else { return 0 }
        return min(max(movement / sideConfiguration.normalOpenExtent, 0), 1)
    }

    private func deformationProgress(
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        guard sideConfiguration.isEnabled, sideConfiguration.allowsDestructive else { return 0 }

        let start = sideConfiguration.normalOpenExtent
        let span = sideConfiguration.destructiveActivationExtent - start
        guard span > 0 else { return movement >= sideConfiguration.destructiveActivationExtent ? 1 : 0 }

        return min(max((movement - start) / span, 0), 1)
    }

    private func isArmed(
        movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> Bool {
        sideConfiguration.isEnabled && sideConfiguration.allowsDestructive
            && movement >= sideConfiguration.destructiveActivationExtent
    }

    private static func side(for width: CGFloat) -> SwipeCellSide {
        width >= 0 ? .leading : .trailing
    }

    private static func movement(_ width: CGFloat, toward side: SwipeCellSide) -> CGFloat {
        switch side {
        case .leading:
            width
        case .trailing:
            -width
        }
    }

    private static func resetDistance(_ width: CGFloat, from side: SwipeCellSide) -> CGFloat {
        max(0, -movement(width, toward: side))
    }

    private static func rubberBandedMovement(
        _ movement: CGFloat,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        motion: SwipeCellConfiguration.Motion
    ) -> CGFloat {
        let limit = activeMovementLimit(sideConfiguration: sideConfiguration)
        guard limit > 0, movement > limit else { return movement }

        // Keep active drag bounded to the side's reveal range; the small capped overshoot gives a
        // rubber-band hint without letting content outrun the rendered action area.
        let overshoot = movement - limit
        let rubberBand = min(
            overshoot * motion.rubberBandCoefficient,
            motion.maxRubberBandDistance
        )
        return limit + rubberBand
    }

    private static func activeMovementLimit(
        sideConfiguration: SwipeCellInteractionSideConfiguration
    ) -> CGFloat {
        if sideConfiguration.allowsDestructive {
            sideConfiguration.destructiveHoldExtent
        } else {
            sideConfiguration.normalOpenExtent
        }
    }

    private static func signedOffset(_ movement: CGFloat, for side: SwipeCellSide) -> CGFloat {
        switch side {
        case .leading:
            movement
        case .trailing:
            -movement
        }
    }
}
