import CoreGraphics
import Foundation
import Testing

@_spi(ManualDebug) @testable import SwipeCell

@Suite("SwipeCell gesture-release settle motion")
struct SwipeCellReleaseSettleMotionTests {
    @Test("fast flick settles at the snappy lower bound")
    func fastFlickSettlesAtLowerBound() {
        let duration = SwipeCellReleaseSettleMotion.settleDuration(
            remainingDistance: 40,
            releaseSpeed: 4000
        )

        #expect(duration == SwipeCellReleaseSettleMotion.minimumDuration)
    }

    @Test("near-still release settles at the gentle upper bound")
    func nearStillReleaseSettlesAtUpperBound() {
        let duration = SwipeCellReleaseSettleMotion.settleDuration(
            remainingDistance: 60,
            releaseSpeed: 0
        )

        #expect(duration == SwipeCellReleaseSettleMotion.maximumDuration)
    }

    @Test("moderate release scales between the bounds by distance over speed")
    func moderateReleaseScalesBetweenBounds() {
        // 60 pt at 200 pt/s ⇒ 0.3s, inside the [0.20, 0.36] window.
        let duration = SwipeCellReleaseSettleMotion.settleDuration(
            remainingDistance: 60,
            releaseSpeed: 200
        )

        #expect(abs(duration - 0.3) < 0.0001)
        #expect(duration > SwipeCellReleaseSettleMotion.minimumDuration)
        #expect(duration < SwipeCellReleaseSettleMotion.maximumDuration)
    }

    @Test("a faster release never produces a slower settle")
    func fasterReleaseIsNeverSlower() {
        let slow = SwipeCellReleaseSettleMotion.settleDuration(remainingDistance: 80, releaseSpeed: 200)
        let fast = SwipeCellReleaseSettleMotion.settleDuration(remainingDistance: 80, releaseSpeed: 1200)

        #expect(fast <= slow)
    }

    @Test("degenerate inputs fall back to the gentle bound")
    func degenerateInputsFallBackToGentleBound() {
        #expect(
            SwipeCellReleaseSettleMotion.settleDuration(remainingDistance: 0, releaseSpeed: 1000)
                == SwipeCellReleaseSettleMotion.maximumDuration
        )
        #expect(
            SwipeCellReleaseSettleMotion.settleDuration(
                remainingDistance: .infinity,
                releaseSpeed: 1000
            ) == SwipeCellReleaseSettleMotion.maximumDuration
        )
        #expect(
            SwipeCellReleaseSettleMotion.settleDuration(remainingDistance: 50, releaseSpeed: .nan)
                == SwipeCellReleaseSettleMotion.maximumDuration
        )
    }

    @Test("automatic open paces a heavy flick against a visible settle distance")
    func automaticOpenPacesHeavyFlickAgainstVisibleSettleDistance() {
        let distance = SwipeCellReleaseSettleMotion.pacedRemainingDistance(
            actualRemainingDistance: 12,
            releaseClassification: .automaticOpen,
            targetOffset: 100
        )

        #expect(distance == 40)
    }

    @Test("automatic open does not manufacture settle when already at rest")
    func automaticOpenDoesNotManufactureSettleWhenAlreadyAtRest() {
        let distance = SwipeCellReleaseSettleMotion.pacedRemainingDistance(
            actualRemainingDistance: 4,
            releaseClassification: .automaticOpen,
            targetOffset: 100
        )

        #expect(distance == 4)
    }

    @Test("standard release uses the actual remaining distance")
    func standardReleaseUsesActualRemainingDistance() {
        let distance = SwipeCellReleaseSettleMotion.pacedRemainingDistance(
            actualRemainingDistance: 12,
            releaseClassification: .standard,
            targetOffset: 100
        )

        #expect(distance == 12)
    }

    @Test("a closing settle paces by release-speed magnitude, sign-free")
    func closingSettlePacesByMagnitude() {
        // Trailing row resetting to 0. A brisk flick that still points outward (away from 0) and one
        // pointing back at 0 both keep their full energy, so neither stalls into the gentle bound.
        let awayFromClosed = SwipeCellReleaseSettleMotion.settleSpeed(
            releaseVelocityX: -2400,
            isClosingSettle: true,
            contentOffset: -120,
            targetOffset: 0
        )
        let towardClosed = SwipeCellReleaseSettleMotion.settleSpeed(
            releaseVelocityX: 2400,
            isClosingSettle: true,
            contentOffset: -120,
            targetOffset: 0
        )

        #expect(awayFromClosed == 2400)
        #expect(towardClosed == 2400)
    }

    @Test("a fast flick that resolves to closed no longer settles at the gentle bound")
    func fastClosingDoesNotRelaxToGentleBound() {
        // The #28 fast-close-then-reset defect: the old directional projection zeroed this away-pointing
        // flick, so the reset crawled back at `settleMaxDuration`. Magnitude pacing keeps it snappy.
        let speed = SwipeCellReleaseSettleMotion.settleSpeed(
            releaseVelocityX: -3000,
            isClosingSettle: true,
            contentOffset: -160,
            targetOffset: 0
        )
        let duration = SwipeCellReleaseSettleMotion.settleDuration(remainingDistance: 160, releaseSpeed: speed)

        #expect(duration == SwipeCellReleaseSettleMotion.minimumDuration)
    }

    @Test("a revealing settle keeps the directional projection so an away flick cannot slam open")
    func revealingSettleKeepsDirectionalProjection() {
        // Trailing reveal target at -200. A flick back toward 0 points away from the target and must read
        // as no momentum; a flick deeper into the row keeps its speed.
        let awayFromOpen = SwipeCellReleaseSettleMotion.settleSpeed(
            releaseVelocityX: 2000,
            isClosingSettle: false,
            contentOffset: -120,
            targetOffset: -200
        )
        let intoOpen = SwipeCellReleaseSettleMotion.settleSpeed(
            releaseVelocityX: -2000,
            isClosingSettle: false,
            contentOffset: -120,
            targetOffset: -200
        )

        #expect(awayFromOpen == 0)
        #expect(intoOpen == 2000)
    }

    @Test("automatic open keeps same-side speed after a tiny endpoint overshoot")
    func automaticOpenKeepsSameSideSpeedAfterEndpointOvershoot() {
        let automatic = SwipeCellReleaseSettleMotion.settleSpeed(
            releaseVelocityX: 3000,
            releaseTarget: .open(.leading),
            releaseClassification: .automaticOpen,
            contentOffset: 102,
            targetOffset: 100
        )
        let standard = SwipeCellReleaseSettleMotion.settleSpeed(
            releaseVelocityX: 3000,
            releaseTarget: .open(.leading),
            releaseClassification: .standard,
            contentOffset: 102,
            targetOffset: 100
        )

        #expect(automatic == 3000)
        #expect(standard == 0)
    }

    @Test("for a fixed close distance, a faster release is never slower")
    func fasterCloseIsNeverSlower() {
        let distance: CGFloat = 140
        let slow = SwipeCellReleaseSettleMotion.settleDuration(
            remainingDistance: distance,
            releaseSpeed: SwipeCellReleaseSettleMotion.settleSpeed(
                releaseVelocityX: -300,
                isClosingSettle: true,
                contentOffset: -distance,
                targetOffset: 0
            )
        )
        let fast = SwipeCellReleaseSettleMotion.settleDuration(
            remainingDistance: distance,
            releaseSpeed: SwipeCellReleaseSettleMotion.settleSpeed(
                releaseVelocityX: -2400,
                isClosingSettle: true,
                contentOffset: -distance,
                targetOffset: 0
            )
        )

        #expect(fast <= slow)
    }

    @Test("indirect-scroll ordinary release duration ignores synthetic release velocity")
    func indirectScrollOrdinaryReleaseDurationIgnoresSyntheticReleaseVelocity() {
        let motion = SwipeCellConfiguration.macOSDefault.motion
        for releaseTarget in [SwipeCellReleaseTarget.open(.trailing), .closed] {
            let stalled = SwipeCellReleaseSettleMotion.gestureSettleDuration(
                remainingDistance: 120,
                releaseSpeed: 0,
                releaseTarget: releaseTarget,
                referenceDistance: 120,
                motion: motion
            )
            let fast = SwipeCellReleaseSettleMotion.gestureSettleDuration(
                remainingDistance: 120,
                releaseSpeed: 4_000,
                releaseTarget: releaseTarget,
                referenceDistance: 120,
                motion: motion
            )

            #expect(stalled == fast)
            #expect(stalled < motion.settleMaxDuration)
        }
    }

    @Test("indirect-scroll distance duration is monotonic and bounded away from the gentle max")
    func indirectScrollDistanceDurationIsMonotonic() {
        let motion = SwipeCellConfiguration.macOSDefault.motion
        let short = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 24,
            releaseSpeed: 0,
            releaseTarget: .closed,
            referenceDistance: 120,
            motion: motion
        )
        let long = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 96,
            releaseSpeed: 0,
            releaseTarget: .closed,
            referenceDistance: 120,
            motion: motion
        )

        #expect(short <= long)
        #expect(long < motion.settleMaxDuration)
    }

    @Test("destructive indirect-scroll release ignores synthetic release velocity")
    func destructiveIndirectScrollReleaseIgnoresSyntheticReleaseVelocity() {
        let motion = SwipeCellConfiguration.macOSDefault.motion
        let stalled = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 120,
            releaseSpeed: 0,
            releaseTarget: .destructive(.trailing),
            referenceDistance: 120,
            motion: motion
        )
        let fast = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 120,
            releaseSpeed: 4_000,
            releaseTarget: .destructive(.trailing),
            referenceDistance: 120,
            motion: motion
        )

        #expect(stalled == fast)
        #expect(stalled < motion.settleMaxDuration)
    }

    @Test("destructive indirect-scroll duration is monotonic and bounded away from the gentle max")
    func destructiveIndirectScrollDurationIsMonotonic() {
        let motion = SwipeCellConfiguration.macOSDefault.motion
        let short = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 32,
            releaseSpeed: 0,
            releaseTarget: .destructive(.trailing),
            referenceDistance: 160,
            motion: motion
        )
        let full = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 160,
            releaseSpeed: 0,
            releaseTarget: .destructive(.trailing),
            referenceDistance: 160,
            motion: motion
        )

        #expect(short <= full)
        #expect(full < motion.settleMaxDuration)
    }

    @Test("direct-touch ordinary release duration ignores release speed")
    func directTouchOrdinaryReleaseDurationIgnoresReleaseSpeed() {
        let motion = SwipeCellConfiguration.iOSDefault.motion
        for releaseTarget in [SwipeCellReleaseTarget.open(.trailing), .closed] {
            let stalled = SwipeCellReleaseSettleMotion.gestureSettleDuration(
                remainingDistance: 120,
                releaseSpeed: 0,
                releaseTarget: releaseTarget,
                referenceDistance: 120,
                motion: motion
            )
            let fast = SwipeCellReleaseSettleMotion.gestureSettleDuration(
                remainingDistance: 120,
                releaseSpeed: 4_000,
                releaseTarget: releaseTarget,
                referenceDistance: 120,
                motion: motion
            )

            #expect(stalled == fast)
            #expect(stalled < motion.settleMaxDuration)
        }
    }

    @Test("direct-touch destructive release duration ignores release speed")
    func directTouchDestructiveReleaseDurationIgnoresReleaseSpeed() {
        let motion = SwipeCellConfiguration.iOSDefault.motion
        let stalled = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 120,
            releaseSpeed: 0,
            releaseTarget: .destructive(.trailing),
            referenceDistance: 120,
            motion: motion
        )
        let fast = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 120,
            releaseSpeed: 4_000,
            releaseTarget: .destructive(.trailing),
            referenceDistance: 120,
            motion: motion
        )

        #expect(stalled == fast)
        #expect(stalled < motion.settleMaxDuration)
    }

    @Test("direct-touch distance duration is monotonic and bounded away from the gentle max")
    func directTouchDistanceDurationIsMonotonic() {
        let motion = SwipeCellConfiguration.iOSDefault.motion
        let short = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 32,
            releaseSpeed: 4_000,
            releaseTarget: .open(.trailing),
            referenceDistance: 160,
            motion: motion
        )
        let full = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: 160,
            releaseSpeed: 0,
            releaseTarget: .open(.trailing),
            referenceDistance: 160,
            motion: motion
        )

        #expect(short <= full)
        #expect(full < motion.settleMaxDuration)
    }

    @Test("direct-touch resolved release animation ignores release speed")
    func directTouchResolvedReleaseAnimationIgnoresReleaseSpeed() {
        let motion = SwipeCellConfiguration.iOSDefault.motion
        let stalled = SwipeCellReleaseSettleMotion.animation(
            remainingDistance: 120,
            releaseSpeed: 0,
            releaseTarget: .closed,
            referenceDistance: 120,
            motion: motion
        )
        let fast = SwipeCellReleaseSettleMotion.animation(
            remainingDistance: 120,
            releaseSpeed: 4_000,
            releaseTarget: .closed,
            referenceDistance: 120,
            motion: motion
        )

        #expect(stalled == fast)
    }

    @Test("indirect-scroll closed release uses timing curve")
    func indirectScrollClosedReleaseUsesTimingCurve() {
        let indirectMotion = SwipeCellConfiguration.macOSDefault.motion
        var timingMotion = indirectMotion
        timingMotion.trackingStyle = .directTouch

        let closed = SwipeCellReleaseSettleMotion.animation(
            remainingDistance: 120,
            releaseSpeed: 4_000,
            releaseTarget: .closed,
            referenceDistance: 120,
            motion: indirectMotion
        )
        let expectedTiming = SwipeCellReleaseSettleMotion.animation(
            remainingDistance: 120,
            releaseSpeed: 4_000,
            releaseTarget: .closed,
            referenceDistance: 120,
            motion: timingMotion
        )
        let open = SwipeCellReleaseSettleMotion.animation(
            remainingDistance: 120,
            releaseSpeed: 4_000,
            releaseTarget: .open(.trailing),
            referenceDistance: 120,
            motion: indirectMotion
        )

        #expect(closed == expectedTiming)
        #expect(closed != open)
    }

    @Test("targetless fallback release settle stays duration-owned")
    func targetlessFallbackReleaseSettleStaysDurationOwned() {
        let directMotion = SwipeCellConfiguration.iOSDefault.motion
        let indirectMotion = SwipeCellConfiguration.macOSDefault.motion

        let directFallback = SwipeCellReleaseSettleMotion.fallbackReleaseSettleAnimation(
            remainingDistance: 120,
            motion: directMotion
        )
        let directTargetAware = SwipeCellReleaseSettleMotion.animation(
            remainingDistance: 120,
            releaseSpeed: 4_000,
            releaseTarget: .closed,
            referenceDistance: 120,
            motion: directMotion
        )
        let indirectFallback = SwipeCellReleaseSettleMotion.fallbackReleaseSettleAnimation(
            remainingDistance: 120,
            motion: indirectMotion
        )
        let indirectTargetAware = SwipeCellReleaseSettleMotion.animation(
            remainingDistance: 120,
            releaseSpeed: 4_000,
            releaseTarget: .open(.trailing),
            referenceDistance: 120,
            motion: indirectMotion
        )

        #expect(directFallback == directTargetAware)
        #expect(indirectFallback == indirectTargetAware)
    }

    @Test("direct-touch release metrics keep speed diagnostic but not duration pacing")
    func directTouchReleaseMetricsKeepSpeedDiagnosticButNotDurationPacing() {
        let motion = SwipeCellConfiguration.iOSDefault.motion
        let stalled = SwipeCellGestureReleaseResolver.releaseSettleMetrics(
            releaseVelocity: .zero,
            releaseTarget: .closed,
            contentOffset: -120,
            targetOffset: 0,
            referenceDistance: 120,
            motion: motion
        )
        let fast = SwipeCellGestureReleaseResolver.releaseSettleMetrics(
            releaseVelocity: CGPoint(x: -4_000, y: 0),
            releaseTarget: .closed,
            contentOffset: -120,
            targetOffset: 0,
            referenceDistance: 120,
            motion: motion
        )

        #expect(stalled.releaseSpeed == 0)
        #expect(fast.releaseSpeed == 4_000)
        #expect(stalled.settleDuration == fast.settleDuration)
    }

    @Test("release settle plan wraps the existing metrics and animation outputs")
    func releaseSettlePlanWrapsExistingMetricsAndAnimationOutputs() {
        struct Scenario {
            let releaseVelocity: CGPoint
            let releaseTarget: SwipeCellReleaseTarget
            let releaseClassification: SwipeCellReleaseClassification
            let contentOffset: CGFloat
            let targetOffset: CGFloat
            let referenceDistance: CGFloat
            let motion: SwipeCellConfiguration.Motion
        }

        let scenarios = [
            Scenario(
                releaseVelocity: CGPoint(x: 680, y: 0),
                releaseTarget: .closed,
                releaseClassification: .standard,
                contentOffset: -72,
                targetOffset: 0,
                referenceDistance: 96,
                motion: SwipeCellConfiguration.iOSDefault.motion
            ),
            Scenario(
                releaseVelocity: CGPoint(x: -520, y: 0),
                releaseTarget: .open(.trailing),
                releaseClassification: .standard,
                contentOffset: -40,
                targetOffset: -96,
                referenceDistance: 96,
                motion: SwipeCellConfiguration.iOSDefault.motion
            ),
            Scenario(
                releaseVelocity: CGPoint(x: -2_400, y: 0),
                releaseTarget: .open(.trailing),
                releaseClassification: .automaticOpen,
                contentOffset: -84,
                targetOffset: -96,
                referenceDistance: 96,
                motion: SwipeCellConfiguration.macOSDefault.motion
            ),
            Scenario(
                releaseVelocity: CGPoint(x: -1_800, y: 0),
                releaseTarget: .destructive(.trailing),
                releaseClassification: .standard,
                contentOffset: -132,
                targetOffset: -180,
                referenceDistance: 180,
                motion: SwipeCellConfiguration.macOSDefault.motion
            ),
        ]

        for scenario in scenarios {
            let plan = SwipeCellGestureReleaseResolver.releaseSettlePlan(
                releaseVelocity: scenario.releaseVelocity,
                releaseTarget: scenario.releaseTarget,
                releaseClassification: scenario.releaseClassification,
                contentOffset: scenario.contentOffset,
                targetOffset: scenario.targetOffset,
                referenceDistance: scenario.referenceDistance,
                motion: scenario.motion
            )
            let metrics = SwipeCellGestureReleaseResolver.releaseSettleMetrics(
                releaseVelocity: scenario.releaseVelocity,
                releaseTarget: scenario.releaseTarget,
                releaseClassification: scenario.releaseClassification,
                contentOffset: scenario.contentOffset,
                targetOffset: scenario.targetOffset,
                referenceDistance: scenario.referenceDistance,
                motion: scenario.motion
            )
            let animation = SwipeCellGestureReleaseResolver.animation(
                metrics: metrics,
                motion: scenario.motion
            )

            #expect(plan.metrics == metrics)
            #expect(plan.animation == animation)
        }
    }

    @Test("release animation helper delegates to the settle plan output")
    func releaseAnimationHelperDelegatesToSettlePlanOutput() {
        let motion = SwipeCellConfiguration.iOSDefault.motion
        let plan = SwipeCellGestureReleaseResolver.releaseSettlePlan(
            releaseVelocity: CGPoint(x: -1_200, y: 0),
            releaseTarget: .open(.trailing),
            releaseClassification: .automaticOpen,
            contentOffset: -24,
            targetOffset: -96,
            referenceDistance: 96,
            motion: motion
        )
        let animation = SwipeCellGestureReleaseResolver.animation(
            releaseVelocity: CGPoint(x: -1_200, y: 0),
            releaseTarget: .open(.trailing),
            releaseClassification: .automaticOpen,
            contentOffset: -24,
            targetOffset: -96,
            referenceDistance: 96,
            motion: motion
        )

        #expect(animation == plan.animation)
    }

    @Test("release reference distance follows ordinary and destructive targets")
    func releaseReferenceDistanceFollowsResolvedTarget() {
        let sideConfiguration = SwipeCellInteractionSideConfiguration(
            normalOpenExtent: 80,
            allowsDestructive: true,
            destructiveThreshold: 150,
            destructiveSettlingExtent: 180
        )

        #expect(
            SwipeCellGestureReleaseResolver.referenceDistance(
                releaseTarget: .open(.trailing),
                sideConfiguration: sideConfiguration,
                contentOffset: -40,
                targetOffset: -80
            ) == 80
        )
        #expect(
            SwipeCellGestureReleaseResolver.referenceDistance(
                releaseTarget: .closed,
                sideConfiguration: sideConfiguration,
                contentOffset: -40,
                targetOffset: 0
            ) == 80
        )
        #expect(
            SwipeCellGestureReleaseResolver.referenceDistance(
                releaseTarget: .destructive(.trailing),
                sideConfiguration: sideConfiguration,
                contentOffset: -120,
                targetOffset: -180
            ) == 180
        )
    }

    // MARK: - Legacy velocity-matched curve helper

    @Test("a fast release matches the settle's initial slope to the release velocity")
    func fastReleaseMatchesInitialSlope() {
        // 100 pt at 1500 pt/s clamps the duration to the lower bound (0.28s), so the normalized start
        // slope is 1500 × 0.28 ÷ 100 = 4.2: the curve leaves the release offset at the finger's speed.
        let base = SwipeCellConfiguration.platformDefault.motion.settleCurve
        let curve = SwipeCellReleaseSettleMotion.velocityMatchedCurve(
            remainingDistance: 100,
            releaseSpeed: 1500
        )

        #expect(abs(curve.c0y / curve.c0x - 4.2) < 1e-9)
        #expect(curve.c0y == base.c0y)
        #expect(curve.c1x == base.c1x)
        #expect(curve.c1y == base.c1y)
    }

    @Test("a mid-speed release matches the start slope instead of starting faster than the finger")
    func midSpeedReleaseMatchesInitialSlope() {
        // 120 pt at 400 pt/s ⇒ duration 0.30s, normalized start slope 400 × 0.30 ÷ 120 = 1.0. Holding
        // the configured c0y would clamp c0x to c1x and force slope c0y ÷ c1x ≈ 1.42 — a start faster
        // than the finger (the mid-speed residual). Lowering c0y keeps the start at the finger's speed.
        let curve = SwipeCellReleaseSettleMotion.velocityMatchedCurve(
            remainingDistance: 120,
            releaseSpeed: 400
        )

        #expect(abs(curve.c0y / curve.c0x - 1.0) < 1e-9)
    }

    @Test("a from-rest release keeps the configured curve")
    func fromRestReleaseKeepsConfiguredCurve() {
        // No usable release speed (an away-pointing reveal release paced at 0): nothing to continue, so
        // the configured curve stands rather than synthesizing a slope.
        let base = SwipeCellConfiguration.platformDefault.motion.settleCurve
        let curve = SwipeCellReleaseSettleMotion.velocityMatchedCurve(
            remainingDistance: 100,
            releaseSpeed: 0
        )

        #expect(curve == base)
    }

    @Test("an extreme release floors the leading control but stays a valid monotonic curve")
    func extremeReleaseStaysValidCurve() {
        let base = SwipeCellConfiguration.platformDefault.motion.settleCurve
        let curve = SwipeCellReleaseSettleMotion.velocityMatchedCurve(
            remainingDistance: 50,
            releaseSpeed: 100_000
        )

        // Steeper start than the configured curve, but still `0 < c0x ≤ c1x` so the timing curve is
        // well-formed and never overshoots the target.
        #expect(curve.c0x < base.c0x)
        #expect(curve.c0x > 0)
        #expect(curve.c0x <= curve.c1x)
    }

    @Test("a slow release lowers c0y to match a gentle slope without breaking monotonicity")
    func slowReleaseMatchesGentleSlope() {
        // 200 pt at 50 pt/s ⇒ duration 0.70s, slope 0.175. c0x holds at c1x (its upper bound) and c0y
        // drops so the start slope still equals the release velocity rather than the 1.42 floor.
        let base = SwipeCellConfiguration.platformDefault.motion.settleCurve
        let curve = SwipeCellReleaseSettleMotion.velocityMatchedCurve(
            remainingDistance: 200,
            releaseSpeed: 50
        )

        #expect(curve.c0x == base.c1x)
        #expect(abs(curve.c0y / curve.c0x - 0.175) < 1e-9)
    }

    @Test("platform defaults select the tracking style by input modality")
    func platformDefaultsSelectTrackingStyle() {
        #expect(SwipeCellConfiguration.iOSDefault.motion.trackingStyle == .directTouch)
        #expect(SwipeCellConfiguration.macOSDefault.motion.trackingStyle == .indirectScroll)
    }

    @Test("a malformed settleCurve still resolves to a well-formed monotonic curve")
    func malformedBaseCurveIsLegalized() {
        // c1x ≤ 0 and c1y < c0y would otherwise pass straight through to an invalid, non-monotonic
        // timing curve. Legalizing the base keeps the result well-formed (`0 < c0x ≤ c1x ≤ 1`,
        // `0 ≤ c0y ≤ c1y ≤ 1`).
        let motion = SwipeCellConfiguration.Motion(
            settleCurve: SwipeCellConfiguration.TimingCurve(c0x: 0.8, c0y: 0.9, c1x: -0.2, c1y: 0.3)
        )
        let curve = SwipeCellReleaseSettleMotion.velocityMatchedCurve(
            remainingDistance: 100,
            releaseSpeed: 800,
            motion: motion
        )

        #expect(curve.c0x > 0)
        #expect(curve.c0x <= curve.c1x)
        #expect(curve.c1x <= 1)
        #expect(curve.c0y >= 0)
        #expect(curve.c0y <= curve.c1y)
        #expect(curve.c1y <= 1)
    }
}
