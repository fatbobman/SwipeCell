import Foundation

nonisolated struct SwipeCellPanIntent {
    static func isHorizontal(
        velocity: CGPoint,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> Bool {
        abs(velocity.x) > abs(velocity.y) + max(0, motion.horizontalOwnershipBias)
    }

    static func isHorizontal(
        translation: CGPoint,
        velocity: CGPoint,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> Bool {
        if abs(velocity.x) != abs(velocity.y) {
            return isHorizontal(velocity: velocity, motion: motion)
        }

        return abs(translation.x) > abs(translation.y) + max(0, motion.horizontalOwnershipBias)
    }

    /// Scroll-wheel input carries a single signed displacement, not separate translation and
    /// velocity signals. Horizontal intent is just the dominant axis of that delta; an exact tie
    /// stays vertical so ambiguous scrolls fall through to the List.
    static func isHorizontal(delta: CGSize) -> Bool {
        abs(delta.width) > abs(delta.height)
    }

    static func predictedEndTranslation(
        translation: CGSize,
        velocity: CGPoint,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> CGSize {
        CGSize(
            width: translation.width + (velocity.x * motion.releasePredictionDuration),
            height: translation.height + (velocity.y * motion.releasePredictionDuration)
        )
    }
}

nonisolated struct SwipeCellPanValue: Equatable {
    let translation: CGSize
    let predictedEndTranslation: CGSize
    /// Internal release gate for indirect input. Direct touch keeps the default `true`; macOS
    /// scroll-wheel can set this to `false` when a fast flick reaches the destructive distance without
    /// sustained physical continuation.
    let allowsDestructiveRelease: Bool
    /// Internal normal-open / close commit hint for indirect input. macOS scroll-wheel active movement
    /// stays step-capped for visual smoothness, but release can still see that the uncapped physical
    /// impulse outran the capped visual movement, mirroring iOS's bounded fast-prediction branch.
    let bypassesNormalReleaseThreshold: Bool
    /// Signed pointer velocity (points/sec) at this gesture sample. Carried outside the pure interaction
    /// model so input-specific fast intent, prediction, diagnostics, and legacy motion fallbacks can use
    /// it without making release-target decisions depend on velocity (issue #13). Defaults to `.zero`
    /// for callers that exercise only the model decision.
    let velocity: CGPoint
    /// Internal seed for macOS scroll-wheel close-from-current-offset. Direct touch and closed-origin
    /// scroll reveal leave this empty, preserving the existing normal-open baseline.
    let openOriginSide: SwipeCellSide?
    let openOriginMovement: CGFloat?
    let timestamp: TimeInterval?

    init(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        allowsDestructiveRelease: Bool = true,
        bypassesNormalReleaseThreshold: Bool = false,
        velocity: CGPoint = .zero,
        openOriginSide: SwipeCellSide? = nil,
        openOriginMovement: CGFloat? = nil,
        timestamp: TimeInterval? = nil
    ) {
        self.translation = translation
        self.predictedEndTranslation = predictedEndTranslation
        self.allowsDestructiveRelease = allowsDestructiveRelease
        self.bypassesNormalReleaseThreshold = bypassesNormalReleaseThreshold
        self.velocity = velocity
        self.openOriginSide = openOriginSide
        self.openOriginMovement = openOriginMovement
        self.timestamp = timestamp
    }
}
