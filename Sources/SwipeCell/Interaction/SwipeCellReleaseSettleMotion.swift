import SwiftUI

/// Motion for a gesture-release settle, selected by `SwipeCellConfiguration.Motion.trackingStyle`
/// (issue #28). Deliberately separate from the public `settlingAnimation`, the programmatic reset curve
/// (issue #13).
///
/// `.directTouch` (iOS): the active drag is a `disablesAnimations` 1:1 write (content glued to the
/// finger). Once the release target is resolved, the visible settle is duration-owned: remaining
/// distance/reference geometry chooses the duration, and the configured timing curve keeps shape stable
/// instead of being retargeted by release velocity (issue #79).
///
/// `.indirectScroll` (macOS): the active drag tracks with a stiff spring (`trackingAnimation`), and
/// resolved open/destructive settles stay in that same spring family (`bounce: 0`). Close-to-closed
/// releases use the duration-owned timing curve instead, so a fully closing slot does not inherit the
/// spring tail. All resolved settles are paced by remaining distance instead of synthetic scroll-wheel
/// release velocity.
nonisolated enum SwipeCellReleaseSettleMotion {
    // MARK: - Tuning knobs
    //
    // Motion is selected by `motion.trackingStyle` (direct touch vs indirect scroll).
    //
    // 1. Settle duration window — resolved gesture releases and targetless release fallback map remaining
    //    distance into the snappy end of the configured window; legacy helpers can still pace by speed.
    // 2. `.directTouch` resolved-target settle shape — the configured `settleCurve`, legalized but no
    //    longer velocity-matched.
    // 3. `.indirectScroll` tracking stiffness — `trackingAnimation`'s interactive-spring `response`:
    //    smaller = tighter tracking, larger = more lag but smoother interrupted direction changes.

    /// Fast-flick lower bound: quick, but the deceleration still has room to be felt.
    static var minimumDuration: TimeInterval {
        SwipeCellConfiguration.platformDefault.motion.settleMinDuration
    }

    /// Near-still release upper bound: a long, unhurried settle, closer to an Apple spring's duration.
    static var maximumDuration: TimeInterval {
        SwipeCellConfiguration.platformDefault.motion.settleMaxDuration
    }

    /// Below this pointer speed (points/sec) there is no usable momentum to pace the settle.
    private static let negligibleSpeed: CGFloat = 1
    private static let automaticOpenNoticeableRemainingDistance: CGFloat = 8
    private static let automaticOpenVisibleDistanceFloor: CGFloat = 24
    private static let automaticOpenVisibleExtentRatio: CGFloat = 0.4
    private static let directTouchFastIntentVisibleReleaseReserveFloor: CGFloat = 8
    private static let directTouchFastIntentVisibleReleaseReserveRatio: CGFloat = 0.15
    private static let distancePacedFullExtentDurationRatio = 0.05

    /// Automatic fast-open releases need the same visible settle pacing whether the finger lifts before
    /// or just after the normal commit threshold. The returned value is used only to pace duration; it
    /// never changes the real target offset.
    static func pacedRemainingDistance(
        actualRemainingDistance: CGFloat,
        releaseClassification: SwipeCellReleaseClassification,
        targetOffset: CGFloat
    ) -> CGFloat {
        guard releaseClassification == .automaticOpen,
            actualRemainingDistance.isFinite,
            targetOffset.isFinite,
            actualRemainingDistance >= automaticOpenNoticeableRemainingDistance
        else {
            return actualRemainingDistance
        }

        let targetDistance = abs(targetOffset)
        guard targetDistance > 0 else { return actualRemainingDistance }

        let visibleDistance = max(
            automaticOpenVisibleDistanceFloor,
            targetDistance * automaticOpenVisibleExtentRatio
        )
        return max(actualRemainingDistance, min(visibleDistance, targetDistance))
    }

    /// Minimum distance to keep available for a fast direct-touch settle while the finger is still in its
    /// initial burst window. This preserves a visible release path without expanding the final target.
    static func directTouchFastIntentVisibleReleaseReserveDistance(targetOffset: CGFloat) -> CGFloat {
        let targetDistance = abs(targetOffset)
        guard targetDistance.isFinite, targetDistance > 0 else { return 0 }

        return min(
            targetDistance,
            max(
                directTouchFastIntentVisibleReleaseReserveFloor,
                targetDistance * directTouchFastIntentVisibleReleaseReserveRatio
            )
        )
    }

    /// Settle duration paced by the release, clamped to the snappy-but-bounded window above.
    ///
    /// - Parameters:
    ///   - remainingDistance: unsigned distance (points) from the release offset to the target.
    ///   - releaseSpeed: unsigned pointer speed (points/sec) toward the target. Momentum pointing away
    ///     from the target should arrive as `0` so the settle relaxes to `maximumDuration` rather than
    ///     snapping on a fling the model already resolved against.
    static func settleDuration(
        remainingDistance: CGFloat,
        releaseSpeed: CGFloat,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> TimeInterval {
        guard remainingDistance.isFinite, releaseSpeed.isFinite,
            remainingDistance > 0, releaseSpeed > negligibleSpeed
        else { return motion.settleMaxDuration }

        let projected = TimeInterval(remainingDistance / releaseSpeed)
        return min(max(projected, motion.settleMinDuration), motion.settleMaxDuration)
    }

    /// Distance-only duration for resolved gesture release. Full-extent settles stay near the default
    /// close feel instead of relaxing to `settleMaxDuration`; shorter remaining distances settle at
    /// least as quickly.
    static func distancePacedSettleDuration(
        remainingDistance: CGFloat,
        referenceDistance: CGFloat,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> TimeInterval {
        let minimum = positiveDuration(
            motion.settleMinDuration,
            fallback: SwipeCellConfiguration.platformDefault.motion.settleMinDuration
        )
        let maximum = max(
            minimum,
            positiveDuration(motion.settleMaxDuration, fallback: minimum)
        )
        guard remainingDistance.isFinite, remainingDistance > 0 else { return minimum }

        let reference =
            referenceDistance.isFinite && referenceDistance > 0
            ? referenceDistance
            : remainingDistance
        let progress = min(max(remainingDistance / reference, 0), 1)
        let fullExtentDuration = minimum + (maximum - minimum) * distancePacedFullExtentDurationRatio
        return minimum + (fullExtentDuration - minimum) * TimeInterval(progress)
    }

    /// Gesture-release duration after applying the resolved-target policy. Release speed remains
    /// available for target resolution and diagnostics, but it no longer paces visible settle duration.
    static func gestureSettleDuration(
        remainingDistance: CGFloat,
        releaseSpeed: CGFloat,
        releaseTarget: SwipeCellReleaseTarget,
        referenceDistance: CGFloat,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> TimeInterval {
        distancePacedSettleDuration(
            remainingDistance: remainingDistance,
            referenceDistance: referenceDistance,
            motion: motion
        )
    }

    private static func positiveDuration(_ value: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        guard value.isFinite, value > 0 else { return fallback }
        return value
    }

    /// Maps signed release velocity to the release speed kept for diagnostics and legacy velocity-paced
    /// helpers, by settle kind.
    ///
    /// A closing legacy settle uses speed magnitude: the model has already fixed the target on closed,
    /// so a brisk flick that still points away from `0` should not project to zero momentum and relax to
    /// `settleMaxDuration` — the fast-close-then-reset "pause, then crawl back" defect (issue #28). A
    /// revealing settle keeps the directional projection: momentum pointing away from the revealed
    /// target (e.g. a late reverse flick after prediction already opened the row) reads as no momentum.
    /// Either way this value never moves the resolved target (issue #13 contract).
    static func settleSpeed(
        releaseVelocityX: CGFloat,
        isClosingSettle: Bool,
        contentOffset: CGFloat,
        targetOffset: CGFloat
    ) -> CGFloat {
        if isClosingSettle {
            return abs(releaseVelocityX)
        }

        let travelDirection: CGFloat = targetOffset >= contentOffset ? 1 : -1
        return max(0, releaseVelocityX * travelDirection)
    }

    /// Classification-aware release speed used by release diagnostics and legacy velocity-paced helpers.
    /// Automatic open keeps the release's same-side speed even after a tiny rubber-band overshoot puts
    /// the final open target behind the current offset, preserving the old helper behavior for callers
    /// that still request velocity-paced fallback motion.
    static func settleSpeed(
        releaseVelocityX: CGFloat,
        releaseTarget: SwipeCellReleaseTarget,
        releaseClassification: SwipeCellReleaseClassification,
        contentOffset: CGFloat,
        targetOffset: CGFloat
    ) -> CGFloat {
        if releaseClassification == .automaticOpen,
            case .open(let side) = releaseTarget
        {
            return max(0, releaseVelocityX * directionMultiplier(for: side))
        }

        return settleSpeed(
            releaseVelocityX: releaseVelocityX,
            isClosingSettle: releaseTarget == .closed,
            contentOffset: contentOffset,
            targetOffset: targetOffset
        )
    }

    private static func directionMultiplier(for side: SwipeCellSide) -> CGFloat {
        switch side {
        case .leading:
            1
        case .trailing:
            -1
        }
    }

    /// Floor for the velocity-matched leading control x, so an extreme release still resolves to a
    /// well-formed, monotonic timing curve (`0 < c0x ≤ c1x`).
    private static let minimumCurveProportion: Double = 0.05

    /// Fixed timing curve for duration-owned settles. It legalizes configurable values into the same
    /// monotonic range as `velocityMatchedCurve`, but does not depend on release speed.
    static func durationOwnedCurve(
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> SwipeCellConfiguration.TimingCurve {
        let base = motion.settleCurve
        let c1x = min(max(base.c1x, minimumCurveProportion), 1)
        let c1y = min(max(base.c1y, 0), 1)
        let c0y = min(max(base.c0y, 0), c1y)
        let c0x = min(max(base.c0x, minimumCurveProportion), c1x)
        return SwipeCellConfiguration.TimingCurve(c0x: c0x, c0y: c0y, c1x: c1x, c1y: c1y)
    }

    /// Legacy velocity-matched control curve for a settle of `remainingDistance` released at
    /// `releaseSpeed`.
    ///
    /// Continuity, not just duration: the settle's *initial* value-velocity is made to equal the release
    /// speed, so it picks up where the finger left off instead of starting from the configured fixed
    /// slope (the leftover seam after duration pacing — issue #28). The leading control `c0` is
    /// retargeted to the release slope while the `c1` tail is preserved: a steep (fast) start keeps the
    /// configured `c0y` and pulls `c0x` in, while a gentle (slower) start instead lowers `c0y` — holding
    /// `c0y` would force a minimum slope of `c0y ÷ c1x` and make a mid-speed release start faster than
    /// the finger. Both the (configurable) base tail and the derived start are clamped into a valid,
    /// monotonic range, so the result never crosses the target the way a velocity-seeded spring would —
    /// even for a malformed `settleCurve`. A non-positive / non-finite speed or distance keeps the
    /// configured curve, legalized — the genuine from-rest case (e.g. an away-pointing reveal release).
    static func velocityMatchedCurve(
        remainingDistance: CGFloat,
        releaseSpeed: CGFloat,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> SwipeCellConfiguration.TimingCurve {
        let base = durationOwnedCurve(motion: motion)
        let c1x = base.c1x
        let c1y = base.c1y
        let tailC0y = base.c0y

        let duration = settleDuration(
            remainingDistance: remainingDistance,
            releaseSpeed: releaseSpeed,
            motion: motion
        )
        guard remainingDistance.isFinite, releaseSpeed.isFinite,
            remainingDistance > 0, releaseSpeed > 0, duration > 0
        else {
            // From-rest: keep the configured curve, legalized.
            return base
        }

        // Release speed ÷ the settle's average speed (distance ÷ duration): the normalized slope the
        // curve must start at to continue the finger. Cap `c0y` at `slope × c1x` so a gentle start lowers
        // `c0y` instead of clamping `c0x` to `c1x` (which would force the start faster than the finger at
        // mid speed); floor `c0x` so the curve stays a well-formed monotonic timing curve.
        let normalizedReleaseSlope = Double(releaseSpeed) * duration / Double(remainingDistance)
        let c0y = min(tailC0y, normalizedReleaseSlope * c1x)
        let c0x = max(c0y / normalizedReleaseSlope, minimumCurveProportion)
        return SwipeCellConfiguration.TimingCurve(c0x: c0x, c0y: c0y, c1x: c1x, c1y: c1y)
    }

    private static func durationOwnedTimingAnimation(
        duration: TimeInterval,
        motion: SwipeCellConfiguration.Motion
    ) -> Animation {
        let curve = durationOwnedCurve(motion: motion)
        return .timingCurve(curve.c0x, curve.c0y, curve.c1x, curve.c1y, duration: duration)
    }

    /// The resolved-target gesture-release settle, by `motion.trackingStyle`: `.indirectScroll` keeps a
    /// distance-paced `bounce: 0` spring for open/destructive targets in the same family as
    /// `trackingAnimation`, but closes with the duration-owned timing curve to avoid spring-tail residue.
    /// `.directTouch` uses the same fixed timing curve for all release targets.
    static func animation(
        remainingDistance: CGFloat,
        releaseSpeed: CGFloat,
        releaseTarget: SwipeCellReleaseTarget,
        referenceDistance: CGFloat,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> Animation {
        let duration = gestureSettleDuration(
            remainingDistance: remainingDistance,
            releaseSpeed: releaseSpeed,
            releaseTarget: releaseTarget,
            referenceDistance: referenceDistance,
            motion: motion
        )
        switch motion.trackingStyle {
        case .indirectScroll:
            if releaseTarget == .closed {
                return durationOwnedTimingAnimation(duration: duration, motion: motion)
            }
            return .spring(duration: duration, bounce: 0)
        case .directTouch:
            return durationOwnedTimingAnimation(duration: duration, motion: motion)
        }
    }

    /// Targetless fallback for release settles that reach render without a target-aware override. It
    /// stays in the #79 duration-owned release family by using the remaining distance as its own
    /// reference, rather than falling back to the public reset animation or legacy velocity pacing.
    static func fallbackReleaseSettleAnimation(
        remainingDistance: CGFloat,
        motion: SwipeCellConfiguration.Motion = SwipeCellConfiguration.platformDefault.motion
    ) -> Animation {
        let duration = distancePacedSettleDuration(
            remainingDistance: remainingDistance,
            referenceDistance: remainingDistance,
            motion: motion
        )
        switch motion.trackingStyle {
        case .indirectScroll:
            return .spring(duration: duration, bounce: 0)
        case .directTouch:
            return durationOwnedTimingAnimation(duration: duration, motion: motion)
        }
    }

    /// Active-drag tracking: a stiff `bounce: 0` interactive spring so the offset follows the finger
    /// closely while carrying velocity into the release settle, and so an interrupting gesture retargets
    /// the in-flight settle instead of jumping it. Lower `response` = tighter tracking; larger = more lag
    /// but smoother direction changes. Main A tuning knob alongside the settle duration bounds.
    static func trackingAnimation() -> Animation {
        .interactiveSpring(response: 0.15, dampingFraction: 1, blendDuration: 0)
    }
}
