import CoreGraphics
import Foundation
import Testing

@_spi(ManualDebug) @testable import SwipeCell

/// Covers the issue #27 macOS gain model: scroll-wheel input is accumulated as
/// device-normalized physical-phase distance, mapped to normal open first, and only then mapped onto
/// the container width locked at `began` for post-open extra movement.
@Suite("SwipeCell scroll wheel pan accumulator")
struct SwipeCellScrollWheelPanAccumulatorTests {
    @Test("the same physical input before open does not scale with cell width")
    func samePhysicalInputBeforeOpenDoesNotScaleWithCellWidth() {
        for containerWidth in [CGFloat(200), CGFloat(400)] {
            var accumulator = makeAccumulator(
                normalOpenExtent: 72,
                containerWidth: containerWidth,
                referenceRevealDistance: 100,
                maxProgressStep: 1
            )

            // progress = 50 / 100 = 0.5, so translation is half of the normal-open extent, not row width.
            #expect(
                accumulator.handle(sample(width: -50, phase: .began))
                    == .began(panValue(width: -36))
            )
        }
    }

    @Test("full normal reveal cost is the reference distance before row-width gain")
    func normalRevealCostIsReferenceDistanceBeforeRowWidthGain() {
        let normalOpenExtent = CGFloat(72)
        var narrow = makeAccumulator(
            normalOpenExtent: normalOpenExtent,
            containerWidth: 144,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )
        var wide = makeAccumulator(
            normalOpenExtent: normalOpenExtent,
            containerWidth: 288,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        #expect(narrow.handle(sample(width: -100, phase: .began)) == .began(panValue(width: -72)))
        #expect(wide.handle(sample(width: -100, phase: .began)) == .began(panValue(width: -72)))
    }

    @Test("post-open extra movement maps onto row width, not hold extent")
    func postOpenExtraMovementUsesRowWidthAsGainDenominator() {
        var accumulator = SwipeCellScrollWheelPanAccumulator(
            input: .init(
                scrollWheelMinStartDelta: 1,
                scrollWheelReferenceRevealDistance: 100,
                scrollWheelMaxProgressStep: 2
            ),
            interactionConfiguration: SwipeCellInteractionConfiguration(
                leading: .disabled,
                trailing: SwipeCellInteractionSideConfiguration(
                    normalOpenExtent: 100,
                    allowsDestructive: true,
                    destructiveThreshold: 360,
                    destructiveSettlingExtent: 480
                )
            ),
            containerWidth: 300
        )

        // progress = 150 / 100 = 1.5, so synthetic translation is normalOpenExtent
        // + 0.5 * row width (250), not 0.5 * destructiveHoldExtent (240).
        #expect(accumulator.handle(sample(width: -150, phase: .began)) == .began(panValue(width: -250)))
    }

    @Test("fast scroll into destructive distance suppresses destructive release")
    func fastScrollIntoDestructiveDistanceSuppressesDestructiveRelease() {
        var accumulator = makeDestructiveAccumulator()

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(
            accumulator.finishActiveGesture()
                == .ended(panValue(width: -190, allowsDestructiveRelease: false))
        )
    }

    @Test("scroll view destructive arm latches on momentum without release")
    func scrollViewDestructiveArmLatchesOnMomentumWithoutRelease() {
        var accumulator = makeDestructiveAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(accumulator.handle(sample(width: 0, momentumPhase: .began)) == .latched)
        #expect(accumulator.isActive)
    }

    @Test("scroll view latched destructive arm commits on real ended")
    func scrollViewLatchedDestructiveArmCommitsOnRealEnded() {
        // Case: MAC-SV-DESTRUCT-HOLD
        var accumulator = makeDestructiveAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(accumulator.handle(sample(width: 0, momentumPhase: .began)) == .latched)
        #expect(
            accumulator.handle(sample(width: 0, phase: .ended))
                == .ended(panValue(width: -190, allowsDestructiveRelease: true))
        )
        #expect(!accumulator.isActive)
    }

    @Test("scroll view stationary touch presence confirms destructive hold")
    func scrollViewStationaryTouchPresenceConfirmsDestructiveHold() {
        var accumulator = makeDestructiveAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(
            accumulator.handleTouchPresence(touchSample(.active))
                == .ignored
        )
        #expect(
            accumulator.handleTouchPresence(touchSample(.stationary))
                == .latched
        )
        #expect(
            accumulator.handleTouchPresence(touchSample(.ended))
                == .ended(panValue(width: -190, allowsDestructiveRelease: true))
        )
        #expect(!accumulator.isActive)
    }

    @Test("scroll view touch presence holds non-destructive position through momentum")
    func scrollViewTouchPresenceHoldsNonDestructivePositionThroughMomentum() {
        var accumulator = makeAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -50, phase: .began))
                == .began(panValue(width: -50))
        )
        #expect(accumulator.handleTouchPresence(touchSample(.active)) == .ignored)
        #expect(accumulator.handle(sample(width: 0, momentumPhase: .began)) == .latched)
        #expect(accumulator.isActive)
        #expect(
            accumulator.handleTouchPresence(touchSample(.ended))
                == .ended(panValue(width: -50))
        )
        #expect(!accumulator.isActive)
    }

    @Test("scroll view touch presence holds non-destructive position through synthetic finish")
    func scrollViewTouchPresenceHoldsNonDestructivePositionThroughSyntheticFinish() {
        var accumulator = makeAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -50, phase: .began))
                == .began(panValue(width: -50))
        )
        #expect(accumulator.handleTouchPresence(touchSample(.active)) == .ignored)
        #expect(accumulator.finishActiveGesture() == .latched)
        #expect(accumulator.isActive)
        #expect(
            accumulator.handleTouchPresence(touchSample(.ended))
                == .ended(panValue(width: -50))
        )
        #expect(!accumulator.isActive)
    }

    @Test("scroll view touch ended before hold keeps flick suppression")
    func scrollViewTouchEndedBeforeHoldKeepsFlickSuppression() {
        var accumulator = makeDestructiveAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(accumulator.handleTouchPresence(touchSample(.active)) == .ignored)
        #expect(
            accumulator.handleTouchPresence(touchSample(.ended))
                == .ended(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(!accumulator.isActive)
    }

    @Test("unmatched touch ended keeps the scroll-wheel fallback active")
    func unmatchedTouchEndedKeepsScrollWheelFallbackActive() {
        var accumulator = makeDestructiveAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(accumulator.handleTouchPresence(touchSample(.ended)) == .ignored)
        #expect(accumulator.isActive)
        #expect(accumulator.handle(sample(width: 0, momentumPhase: .began)) == .latched)
    }

    @Test("scroll view immediate ended after destructive arm keeps flick suppression")
    func scrollViewImmediateEndedAfterDestructiveArmKeepsFlickSuppression() {
        var accumulator = makeDestructiveAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(
            accumulator.handle(sample(width: 0, phase: .ended))
                == .ended(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(accumulator.handle(sample(width: 0, momentumPhase: .began)) == .ignored)
    }

    @Test("scroll view latched destructive arm clears after reverse crosses back inside threshold")
    func scrollViewLatchedDestructiveArmClearsAfterReverseCrossesBackInsideThreshold() {
        var accumulator = makeDestructiveAccumulator(container: .scrollView)

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(accumulator.handle(sample(width: 0, momentumPhase: .began)) == .latched)
        #expect(
            accumulator.handle(sample(width: 80, phase: .changed))
                == .changed(panValue(width: -50, allowsDestructiveRelease: true))
        )
        #expect(
            accumulator.finishActiveGesture()
                == .ended(panValue(width: -50, allowsDestructiveRelease: true))
        )
    }

    @Test("list destructive arm still finishes on momentum")
    func listDestructiveArmStillFinishesOnMomentum() {
        var accumulator = makeDestructiveAccumulator()

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(
            accumulator.handle(sample(width: 0, momentumPhase: .began))
                == .ended(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(!accumulator.isActive)
    }

    @Test("list ignores touch presence and keeps scroll-wheel release semantics")
    func listIgnoresTouchPresenceAndKeepsScrollWheelReleaseSemantics() {
        var accumulator = makeDestructiveAccumulator()

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(accumulator.handleTouchPresence(touchSample(.active)) == .ignored)
        #expect(accumulator.handleTouchPresence(touchSample(.stationary)) == .ignored)
        #expect(accumulator.handleTouchPresence(touchSample(.ended)) == .ignored)
        #expect(
            accumulator.handle(sample(width: 0, momentumPhase: .began))
                == .ended(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(!accumulator.isActive)
    }

    @Test("scroll view reveal continuing from an open row arms destructive via the open origin")
    func scrollViewRevealFromOpenArmsDestructiveViaOpenOrigin() {
        // Row already open at the normal extent (100). A further reveal of 80 reaches absolute 180, the
        // destructive extent — but only when the open origin counts. Translation alone (80 < 180) is the
        // pre-fix under-measurement that left the armed row reverting on momentum / synthetic end.
        var accumulator = makeDestructiveAccumulator(container: .scrollView, contentOffset: -100)

        #expect(
            accumulator.handle(sample(width: -80, phase: .began))
                == .began(panValue(width: -80, allowsDestructiveRelease: false))
        )
        #expect(accumulator.handle(sample(width: 0, momentumPhase: .began)) == .latched)
        #expect(accumulator.isActive)
    }

    @Test("reveal from an open row does not arm destructive below the open-origin absolute distance")
    func revealFromOpenStaysBelowDestructiveUntilAbsoluteDistance() {
        // Same open origin (100) but only a 40 reveal: absolute 140 < 180, so the row must not arm and
        // momentum settles normally — the open-origin seed widens the gate, it does not bypass it.
        var accumulator = makeDestructiveAccumulator(container: .scrollView, contentOffset: -100)

        #expect(
            accumulator.handle(sample(width: -40, phase: .began))
                == .began(panValue(width: -40, allowsDestructiveRelease: true))
        )
        #expect(
            accumulator.handle(sample(width: 0, momentumPhase: .began))
                == .ended(panValue(width: -40, allowsDestructiveRelease: true))
        )
    }

    @Test("continued physical scroll after arm permits destructive release")
    func continuedPhysicalScrollAfterArmPermitsDestructiveRelease() {
        var accumulator = makeDestructiveAccumulator()

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )
        #expect(
            accumulator.handle(sample(width: -1, phase: .changed))
                == .changed(panValue(width: -193, allowsDestructiveRelease: true))
        )
        #expect(
            accumulator.finishActiveGesture()
                == .ended(panValue(width: -193, allowsDestructiveRelease: true))
        )
    }

    @Test("active updates keep destructive release gate on began geometry")
    func activeUpdatesKeepDestructiveReleaseGateOnBeganGeometry() {
        let input = SwipeCellConfiguration.PlatformInput(
            scrollWheelMinStartDelta: 1,
            scrollWheelReferenceRevealDistance: 100,
            scrollWheelMaxProgressStep: 2
        )
        var accumulator = SwipeCellScrollWheelPanAccumulator(
            input: input,
            interactionConfiguration: destructiveConfiguration(threshold: 180),
            containerWidth: 300
        )

        #expect(
            accumulator.handle(sample(width: -130, phase: .began))
                == .began(panValue(width: -190, allowsDestructiveRelease: false))
        )

        accumulator.update(
            input: input,
            interactionConfiguration: destructiveConfiguration(threshold: 260),
            container: .list,
            containerWidth: 500
        )

        #expect(
            accumulator.finishActiveGesture()
                == .ended(panValue(width: -190, allowsDestructiveRelease: false))
        )

        #expect(accumulator.handle(sample(width: -125, phase: .began)) == .began(panValue(width: -225)))
    }

    @Test("scroll view slow deltas use the slow reference and match list movement")
    func scrollViewSlowDeltasUseSlowReferenceAndMatchListMovement() throws {
        // Case: MAC-SV-OPEN-SLOW
        var list = makeDestructiveAccumulator(
            normalOpenExtent: 168,
            threshold: 256,
            referenceRevealDistance: 48,
            maxProgressStep: 1
        )
        var scrollView = makeDestructiveAccumulator(
            normalOpenExtent: 168,
            threshold: 256,
            container: .scrollView,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            maxProgressStep: 1
        )

        var latestScrollValue: SwipeCellPanValue?
        for index in 0..<8 {
            let phase: SwipeCellScrollWheelPhase = index == 0 ? .began : .changed
            let listValue = try activeValue(list.handle(sample(width: -8, phase: phase)))
            let scrollValue = try activeValue(scrollView.handle(sample(width: -8, phase: phase)))

            #expect(abs(listValue.translation.width - scrollValue.translation.width) < 0.0001)
            latestScrollValue = scrollValue
        }

        let value = try #require(latestScrollValue)
        #expect(abs(value.translation.width + 268) < 0.0001)
        #expect(!value.allowsDestructiveRelease)
    }

    @Test("scroll view fast deltas preserve fast reference mapping")
    func scrollViewFastDeltasPreserveFastReferenceMapping() throws {
        // Case: MAC-SV-OPEN-FAST
        var adaptive = makeAccumulator(
            normalOpenExtent: 168,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            maxProgressStep: 1,
            container: .scrollView
        )
        var constantFast = makeAccumulator(
            normalOpenExtent: 168,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 600,
            maxProgressStep: 1,
            container: .scrollView
        )

        let adaptiveValue = try beganValue(adaptive.handle(sample(width: -50, phase: .began)))
        let constantFastValue = try beganValue(constantFast.handle(sample(width: -50, phase: .began)))

        #expect(abs(adaptiveValue.translation.width - constantFastValue.translation.width) < 0.0001)
        #expect(abs(adaptiveValue.translation.width + 14) < 0.0001)
    }

    @Test("adaptive visual cap does not bypass the half threshold")
    func adaptiveVisualCapDoesNotBypassHalfThreshold() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            maxProgressStep: 0.2,
            container: .scrollView
        )

        let value = try beganValue(accumulator.handle(sample(width: -20, phase: .began)))

        #expect(value.translation.width == -20)
        #expect(!value.bypassesNormalReleaseThreshold)
    }

    @Test("raw fast reference cap still bypasses the half threshold")
    func rawFastReferenceCapStillBypassesHalfThreshold() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            maxProgressStep: 0.2,
            container: .scrollView
        )

        let value = try beganValue(accumulator.handle(sample(width: -200, phase: .began)))

        #expect(value.translation.width == -20)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("scroll view fast release bar is independent from the fast reference")
    func scrollViewFastReleaseBarIsIndependentFromFastReference() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 168,
            normalOpenThreshold: 84,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            fastReleaseIntentDistance: 36,
            maxProgressStep: 1,
            container: .scrollView
        )

        _ = try beganValue(accumulator.handle(sample(width: -1, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: -29, phase: .changed, timestamp: 1.035)))
        let value = try changedValue(accumulator.handle(sample(width: -6, phase: .changed, timestamp: 1.067)))

        #expect(abs(value.translation.width) < 84)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("invalid fast release bar falls back to the fast reference threshold")
    func invalidFastReleaseBarFallsBackToFastReferenceThreshold() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 168,
            normalOpenThreshold: 84,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            fastReleaseIntentDistance: .nan,
            maxProgressStep: 1,
            container: .scrollView
        )

        _ = try beganValue(accumulator.handle(sample(width: -1, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: -29, phase: .changed, timestamp: 1.035)))
        let value = try changedValue(accumulator.handle(sample(width: -6, phase: .changed, timestamp: 1.067)))

        #expect(abs(value.translation.width) < 84)
        #expect(!value.bypassesNormalReleaseThreshold)
    }

    @Test("quick release near the open threshold can bypass in scroll view")
    func quickReleaseNearOpenThresholdBypassesInScrollView() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 168,
            normalOpenThreshold: 84,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            fastReleaseIntentDistance: 36,
            fastReleaseOpenCommitRatio: 0.8,
            maxProgressStep: 0.2,
            container: .scrollView
        )

        _ = try beganValue(accumulator.handle(sample(width: -1, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: -16, phase: .changed, timestamp: 1.033)))
        _ = try changedValue(accumulator.handle(sample(width: -13, phase: .changed, timestamp: 1.053)))
        let value = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.053)))

        #expect(abs(value.translation.width + 70.7) < 0.0001)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("quick release near the tuned scroll view ratio can bypass")
    func quickReleaseNearTunedScrollViewRatioBypasses() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 168,
            normalOpenThreshold: 84,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            fastReleaseIntentDistance: 36,
            fastReleaseOpenCommitRatio: 0.44,
            maxProgressStep: 0.2,
            container: .scrollView
        )

        _ = try beganValue(accumulator.handle(sample(width: -1, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: -23, phase: .changed, timestamp: 1.05)))
        let value = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.05)))

        #expect(abs(value.translation.width + 37.1) < 0.0001)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("near-open release does not bypass after the fast window expires")
    func nearOpenReleaseDoesNotBypassAfterFastWindowExpires() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 168,
            normalOpenThreshold: 84,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            fastReleaseIntentDistance: 36,
            fastReleaseOpenCommitRatio: 0.8,
            maxProgressStep: 0.2,
            container: .scrollView
        )

        _ = try beganValue(accumulator.handle(sample(width: -1, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: -16, phase: .changed, timestamp: 1.033)))
        _ = try changedValue(accumulator.handle(sample(width: -13, phase: .changed, timestamp: 1.053)))
        let value = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.25)))

        #expect(abs(value.translation.width + 70.7) < 0.0001)
        #expect(!value.bypassesNormalReleaseThreshold)
    }

    @Test("open-origin close uses the same adaptive slow reference")
    func openOriginCloseUsesAdaptiveSlowReference() throws {
        // Case: MAC-SV-CLOSE-MANUAL
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            maxProgressStep: 1,
            container: .scrollView,
            contentOffset: -100
        )

        let value = try beganValue(accumulator.handle(sample(width: 8, phase: .began)))

        #expect(abs(value.translation.width - 16.6667) < 0.0001)
        #expect(value.openOriginSide == SwipeCellSide.trailing)
        #expect(value.openOriginMovement == 100)
    }

    @Test("active gesture keeps the adaptive input locked")
    func activeGestureKeepsAdaptiveInputLocked() throws {
        let initialInput = SwipeCellConfiguration.PlatformInput(
            scrollWheelMinStartDelta: 1,
            scrollWheelReferenceRevealDistance: 600,
            scrollWheelSlowReferenceRevealDistance: 48,
            scrollWheelMaxProgressStep: 1
        )
        var accumulator = SwipeCellScrollWheelPanAccumulator(
            input: initialInput,
            interactionConfiguration: .symmetric(normalOpenExtent: 100),
            container: .scrollView,
            containerWidth: 300
        )

        _ = try beganValue(accumulator.handle(sample(width: -8, phase: .began)))

        accumulator.update(
            input: SwipeCellConfiguration.PlatformInput(
                scrollWheelMinStartDelta: 1,
                scrollWheelReferenceRevealDistance: 600,
                scrollWheelSlowReferenceRevealDistance: 4,
                scrollWheelMaxProgressStep: 1
            ),
            interactionConfiguration: .symmetric(normalOpenExtent: 100),
            container: .scrollView,
            containerWidth: 300
        )

        let value = try changedValue(accumulator.handle(sample(width: -8, phase: .changed)))

        #expect(abs(value.translation.width + 33.3333) < 0.0001)
    }

    @Test("a single fast event is capped to the max progress step")
    func fastEventCappedToMaxProgressStep() {
        var accumulator = makeAccumulator(containerWidth: 200, referenceRevealDistance: 100, maxProgressStep: 0.2)

        // step = referenceRevealDistance * maxProgressStep = 20, so the first frame advances
        // by 0.2 of normal open instead of jumping to row-width movement.
        #expect(
            accumulator.handle(sample(width: 1000, phase: .began))
                == .began(panValue(width: 20, bypassesNormalReleaseThreshold: true))
        )
        #expect(
            accumulator.handle(sample(width: 1000, phase: .changed))
                == .changed(panValue(width: 40, bypassesNormalReleaseThreshold: true))
        )
    }

    @Test("fast reveal bypass ignores the half threshold while active movement stays capped")
    func fastRevealBypassIgnoresHalfThresholdWhileActiveMovementStaysCapped() throws {
        // Case: MAC-LIST-OPEN-FAST
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 0.2
        )

        let value = try beganValue(accumulator.handle(sample(width: 25, phase: .began)))

        #expect(value.translation.width == 20)
        #expect(value.predictedEndTranslation == value.translation)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("slow reveal below the half threshold does not bypass")
    func slowRevealBelowHalfThresholdDoesNotBypass() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        let value = try beganValue(accumulator.handle(sample(width: 40, phase: .began)))

        #expect(value.translation.width == 40)
        #expect(!value.bypassesNormalReleaseThreshold)
    }

    @Test("single sample quick reveal release bypasses the half threshold")
    func singleSampleQuickRevealReleaseBypassesHalfThreshold() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        _ = try beganValue(accumulator.handle(sample(width: 15, phase: .began, timestamp: 1.0)))
        let value = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.08)))

        #expect(value.translation.width == 15)
        #expect(value.predictedEndTranslation == value.translation)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("single low-signal reveal release does not bypass")
    func singleLowSignalRevealReleaseDoesNotBypass() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        _ = try beganValue(accumulator.handle(sample(width: 1, phase: .began, timestamp: 1.0)))
        let value = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.08)))

        #expect(value.translation.width == 1)
        #expect(!value.bypassesNormalReleaseThreshold)
    }

    @Test("single sample quick reveal release also works when momentum starts")
    func singleSampleQuickRevealReleaseWorksWhenMomentumStarts() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        _ = try beganValue(accumulator.handle(sample(width: 15, phase: .began, timestamp: 1.0)))
        let value = try endedValue(
            accumulator.handle(
                sample(width: 0, momentumPhase: .began, timestamp: 1.08)
            )
        )

        #expect(value.translation.width == 15)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("short burst reveal bypasses even when no single event is capped")
    func shortBurstRevealBypassesWithoutSingleEventCap() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        _ = try beganValue(accumulator.handle(sample(width: 8, phase: .began, timestamp: 1.0)))
        let value = try changedValue(accumulator.handle(sample(width: 8, phase: .changed, timestamp: 1.14)))

        #expect(value.translation.width == 16)
        #expect(value.predictedEndTranslation == value.translation)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("slow reveal with the same distance does not bypass")
    func slowRevealWithSameDistanceDoesNotBypass() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        _ = try beganValue(accumulator.handle(sample(width: 8, phase: .began, timestamp: 1.0)))
        let value = try changedValue(accumulator.handle(sample(width: 8, phase: .changed, timestamp: 1.25)))

        #expect(value.translation.width == 16)
        #expect(!value.bypassesNormalReleaseThreshold)
    }

    @Test("later short burst reveal restarts the fast window")
    func laterShortBurstRevealRestartsFastWindow() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        _ = try beganValue(accumulator.handle(sample(width: 7, phase: .began, timestamp: 1.0)))
        let slow = try changedValue(accumulator.handle(sample(width: 8, phase: .changed, timestamp: 1.25)))
        #expect(abs(slow.translation.width - 15) < 0.0001)
        #expect(!slow.bypassesNormalReleaseThreshold)

        let burst = try changedValue(accumulator.handle(sample(width: 8, phase: .changed, timestamp: 1.29)))
        #expect(abs(burst.translation.width - 23) < 0.0001)
        #expect(burst.bypassesNormalReleaseThreshold)
    }

    @Test("active burst reveal bypasses after a timely synthetic release")
    func activeBurstRevealBypassesAfterTimelySyntheticRelease() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 144,
            normalOpenThreshold: 72,
            containerWidth: 200,
            referenceRevealDistance: 48,
            maxProgressStep: 0.2
        )

        _ = try beganValue(accumulator.handle(sample(width: 11, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: 2, phase: .changed, timestamp: 1.039)))
        let active = try changedValue(accumulator.handle(sample(width: 1, phase: .changed, timestamp: 1.067)))
        #expect(active.bypassesNormalReleaseThreshold)

        let ended = try endedValue(accumulator.finishActiveGesture())
        #expect(abs(ended.translation.width - 37.8) < 0.0001)
        #expect(ended.bypassesNormalReleaseThreshold)
    }

    @Test("active burst reveal does not bypass after a stale synthetic release")
    func activeBurstRevealDoesNotBypassAfterStaleSyntheticRelease() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 144,
            normalOpenThreshold: 72,
            containerWidth: 200,
            referenceRevealDistance: 48,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.2
        )

        _ = try beganValue(accumulator.handle(sample(width: 11, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: 2, phase: .changed, timestamp: 1.039)))
        _ = try changedValue(accumulator.handle(sample(width: 1, phase: .changed, timestamp: 1.067)))

        let ended = try endedValue(accumulator.finishActiveGesture())
        #expect(abs(ended.translation.width - 37.8) < 0.0001)
        #expect(!ended.bypassesNormalReleaseThreshold)
    }

    @Test("active burst reveal does not bypass after a late release")
    func activeBurstRevealDoesNotBypassAfterLateRelease() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 144,
            normalOpenThreshold: 72,
            containerWidth: 200,
            referenceRevealDistance: 48,
            maxProgressStep: 0.2
        )

        _ = try beganValue(accumulator.handle(sample(width: 11, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: 2, phase: .changed, timestamp: 1.039)))
        _ = try changedValue(accumulator.handle(sample(width: 1, phase: .changed, timestamp: 1.067)))

        let ended = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.25)))
        #expect(abs(ended.translation.width - 37.8) < 0.0001)
        #expect(!ended.bypassesNormalReleaseThreshold)
    }

    @Test("active burst reveal bypasses when release is near the trigger")
    func activeBurstRevealBypassesWhenReleaseIsNearTrigger() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 144,
            normalOpenThreshold: 72,
            containerWidth: 200,
            referenceRevealDistance: 48,
            maxProgressStep: 0.2
        )

        _ = try beganValue(accumulator.handle(sample(width: 11, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: 2, phase: .changed, timestamp: 1.039)))
        _ = try changedValue(accumulator.handle(sample(width: 1, phase: .changed, timestamp: 1.067)))

        let ended = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.10)))
        #expect(abs(ended.translation.width - 37.8) < 0.0001)
        #expect(ended.bypassesNormalReleaseThreshold)
    }

    @Test("touch ended timestamp older than latest scroll sample preserves fast intent")
    func touchEndedTimestampOlderThanLatestScrollSamplePreservesFastIntent() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 72,
            normalOpenThreshold: 36,
            containerWidth: 300,
            referenceRevealDistance: 600,
            slowReferenceRevealDistance: 48,
            fastReleaseIntentDistance: 2,
            fastReleaseOpenCommitRatio: 0.44,
            maxProgressStep: 0.2,
            container: .scrollView
        )

        _ = try beganValue(accumulator.handle(sample(width: -1, phase: .began, timestamp: 1.0)))
        #expect(accumulator.handleTouchPresence(touchSample(.active, timestamp: 1.017)) == .ignored)
        let active = try changedValue(accumulator.handle(sample(width: -12, phase: .changed, timestamp: 1.05)))
        #expect(abs(active.translation.width + 15.9) < 0.0001)
        #expect(active.bypassesNormalReleaseThreshold)

        let ended = try endedValue(
            accumulator.handleTouchPresence(touchSample(.ended, timestamp: 1.048))
        )
        #expect(abs(ended.translation.width + 15.9) < 0.0001)
        #expect(ended.bypassesNormalReleaseThreshold)
    }

    @Test("reverse contribution clears the reveal fast window")
    func reverseContributionClearsRevealFastWindow() throws {
        var accumulator = makeAccumulator(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            containerWidth: 200,
            referenceRevealDistance: 100,
            maxProgressStep: 1
        )

        _ = try beganValue(accumulator.handle(sample(width: 8, phase: .began, timestamp: 1.0)))
        let reverse = try changedValue(accumulator.handle(sample(width: -1, phase: .changed, timestamp: 1.04)))
        #expect(abs(reverse.translation.width - 7) < 0.0001)
        #expect(!reverse.bypassesNormalReleaseThreshold)

        let nextToward = try changedValue(accumulator.handle(sample(width: 8, phase: .changed, timestamp: 1.08)))
        #expect(abs(nextToward.translation.width - 15) < 0.0001)
        #expect(!nextToward.bypassesNormalReleaseThreshold)
    }

    @Test("container width must be measurable before begin and then stays locked")
    func containerWidthMustBeMeasurableAndLocksAtBegin() {
        let input = SwipeCellConfiguration.PlatformInput(
            scrollWheelMinStartDelta: 1,
            scrollWheelReferenceRevealDistance: 100,
            scrollWheelMaxProgressStep: 1
        )
        let interactionConfiguration = SwipeCellInteractionConfiguration.symmetric(normalOpenExtent: 100)
        var accumulator = SwipeCellScrollWheelPanAccumulator(
            input: input,
            interactionConfiguration: interactionConfiguration,
            containerWidth: 0
        )

        #expect(accumulator.handle(sample(width: 25, phase: .began)) == .ignored)

        accumulator.update(
            input: input,
            interactionConfiguration: interactionConfiguration,
            container: .list,
            containerWidth: 200
        )
        #expect(accumulator.handle(sample(width: 100, phase: .began)) == .began(panValue(width: 100)))

        accumulator.update(
            input: input,
            interactionConfiguration: interactionConfiguration,
            container: .list,
            containerWidth: 400
        )
        // Extra progress is now 0.25. The active gesture keeps the original 200pt width, so the
        // translation is 150 instead of jumping to 200.
        #expect(accumulator.handle(sample(width: 25, phase: .changed)) == .changed(panValue(width: 150)))
    }

    @Test("momentum never starts or deepens the reveal")
    func momentumNeverStartsOrDeepensReveal() {
        var accumulator = makeAccumulator(containerWidth: 100, referenceRevealDistance: 100, maxProgressStep: 1)

        #expect(accumulator.handle(sample(width: -40, momentumPhase: .changed)) == .ignored)
        #expect(!accumulator.isActive)

        #expect(accumulator.handle(sample(width: -50, phase: .began)) == .began(panValue(width: -50)))
        #expect(accumulator.handle(sample(width: -1000, momentumPhase: .changed)) == .ended(panValue(width: -50)))
        #expect(!accumulator.isActive)
    }

    @Test("vertical and ambiguous scroll fall through to the list")
    func verticalAndAmbiguousScrollFallThrough() {
        var accumulator = makeAccumulator()

        #expect(accumulator.handle(sample(width: 4, height: 10, phase: .began)) == .ignored)
        #expect(accumulator.handle(sample(width: 8, height: 8, phase: .changed)) == .ignored)
        #expect(!accumulator.isActive)
    }

    @Test("scroll toward a disabled side does not begin")
    func scrollTowardDisabledSideDoesNotBegin() {
        var accumulator = SwipeCellScrollWheelPanAccumulator(
            input: .init(scrollWheelReferenceRevealDistance: 100, scrollWheelMaxProgressStep: 1),
            interactionConfiguration: SwipeCellInteractionConfiguration(
                leading: .disabled,
                trailing: SwipeCellInteractionSideConfiguration(normalOpenExtent: 100)
            ),
            containerWidth: 100
        )

        #expect(accumulator.handle(sample(width: 30, phase: .began)) == .ignored)
        #expect(!accumulator.isActive)

        #expect(accumulator.handle(sample(width: -30, phase: .began)) == .began(panValue(width: -30)))
        #expect(accumulator.isActive)
    }

    @Test("visible trailing reverse scroll closes from normal open")
    func visibleTrailingReverseScrollClosesFromNormalOpen() throws {
        var accumulator = makeAccumulator(
            containerWidth: 300,
            referenceRevealDistance: 100,
            maxProgressStep: 1,
            contentOffset: -100
        )

        let value = try beganValue(accumulator.handle(sample(width: 40, phase: .began)))

        #expect(value.translation.width == 40)
        #expect(value.openOriginSide == SwipeCellSide.trailing)
        #expect(value.openOriginMovement == 100)
        #expect(value.velocity.x > 0)
    }

    @Test("visible destructive hold reverse scroll starts from current hold movement")
    func visibleDestructiveHoldReverseScrollStartsFromCurrentMovement() throws {
        var accumulator = makeDestructiveAccumulator(contentOffset: -220)

        let value = try beganValue(accumulator.handle(sample(width: 20, phase: .began)))

        #expect(value.translation.width == 60)
        #expect(value.openOriginSide == SwipeCellSide.trailing)
        #expect(value.openOriginMovement == 220)
    }

    @Test("visible trailing closes even when opposite leading side is disabled")
    func visibleTrailingClosesWhenOppositeLeadingSideIsDisabled() throws {
        var accumulator = SwipeCellScrollWheelPanAccumulator(
            input: .init(scrollWheelReferenceRevealDistance: 100, scrollWheelMaxProgressStep: 1),
            interactionConfiguration: SwipeCellInteractionConfiguration(
                leading: .disabled,
                trailing: SwipeCellInteractionSideConfiguration(normalOpenExtent: 100)
            ),
            containerWidth: 200,
            contentOffset: -100
        )

        let value = try beganValue(accumulator.handle(sample(width: 20, phase: .began)))

        #expect(value.translation.width == 20)
        #expect(value.openOriginSide == SwipeCellSide.trailing)
    }

    @Test("active close floors at closed without revealing the opposite side")
    func activeCloseFloorsAtClosedWithoutRevealingOppositeSide() throws {
        var accumulator = makeAccumulator(
            referenceRevealDistance: 100,
            maxProgressStep: 2,
            contentOffset: -40
        )

        let began = try beganValue(accumulator.handle(sample(width: 120, phase: .began)))
        let changed = try changedValue(accumulator.handle(sample(width: 80, phase: .changed)))

        #expect(began.translation.width == 40)
        #expect(changed.translation.width == 40)
        #expect(changed.openOriginSide == SwipeCellSide.trailing)
        #expect(changed.openOriginMovement == 40)
    }

    @Test("open-origin close release velocity uses raw impulse while active movement stays capped")
    func openOriginCloseReleaseVelocityUsesRawImpulseWhileActiveMovementStaysCapped() throws {
        var accumulator = makeAccumulator(
            normalOpenThreshold: 50,
            referenceRevealDistance: 100,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.1,
            contentOffset: -100
        )

        let value = try beganValue(accumulator.handle(sample(width: 25, phase: .began)))

        #expect(value.translation.width == 20)
        #expect(value.velocity.x == 250)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("short burst open-origin close bypasses without a capped event")
    func shortBurstOpenOriginCloseBypassesWithoutCappedEvent() throws {
        var accumulator = makeAccumulator(
            normalOpenThreshold: 50,
            referenceRevealDistance: 100,
            maxProgressStep: 1,
            contentOffset: -100
        )

        _ = try beganValue(accumulator.handle(sample(width: 8, phase: .began, timestamp: 2.0)))
        let value = try changedValue(accumulator.handle(sample(width: 8, phase: .changed, timestamp: 2.14)))

        #expect(value.translation.width == 16)
        #expect(value.openOriginSide == SwipeCellSide.trailing)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("single sample quick open-origin close release bypasses the half threshold")
    func singleSampleQuickOpenOriginCloseReleaseBypassesHalfThreshold() throws {
        // Case: MAC-LIST-CLOSE-FAST
        var accumulator = makeAccumulator(
            normalOpenThreshold: 50,
            referenceRevealDistance: 100,
            maxProgressStep: 1,
            contentOffset: -100
        )

        _ = try beganValue(accumulator.handle(sample(width: 15, phase: .began, timestamp: 2.0)))
        let value = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 2.08)))

        #expect(value.translation.width == 15)
        #expect(value.openOriginSide == SwipeCellSide.trailing)
        #expect(value.bypassesNormalReleaseThreshold)
    }

    @Test("single low-signal open-origin close release does not bypass")
    func singleLowSignalOpenOriginCloseReleaseDoesNotBypass() throws {
        var accumulator = makeAccumulator(
            normalOpenThreshold: 50,
            referenceRevealDistance: 100,
            maxProgressStep: 1,
            contentOffset: -100
        )

        _ = try beganValue(accumulator.handle(sample(width: 1, phase: .began, timestamp: 2.0)))
        let value = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 2.08)))

        #expect(value.translation.width == 1)
        #expect(value.openOriginSide == SwipeCellSide.trailing)
        #expect(!value.bypassesNormalReleaseThreshold)
    }

    @Test("reverse contribution clears the open-origin close fast window")
    func reverseContributionClearsOpenOriginCloseFastWindow() throws {
        var accumulator = makeAccumulator(
            normalOpenThreshold: 50,
            referenceRevealDistance: 100,
            maxProgressStep: 1,
            contentOffset: -100
        )

        _ = try beganValue(accumulator.handle(sample(width: 1, phase: .began, timestamp: 2.0)))
        let reverse = try changedValue(accumulator.handle(sample(width: -0.5, phase: .changed, timestamp: 2.04)))
        #expect(reverse.translation.width == 1)
        #expect(reverse.openOriginSide == SwipeCellSide.trailing)
        #expect(!reverse.bypassesNormalReleaseThreshold)

        let value = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 2.08)))
        #expect(value.translation.width == 1)
        #expect(value.openOriginSide == SwipeCellSide.trailing)
        #expect(!value.bypassesNormalReleaseThreshold)
    }

    @Test("later short burst open-origin close restarts the fast window")
    func laterShortBurstOpenOriginCloseRestartsFastWindow() throws {
        var accumulator = makeAccumulator(
            normalOpenThreshold: 50,
            referenceRevealDistance: 100,
            maxProgressStep: 1,
            contentOffset: -100
        )

        _ = try beganValue(accumulator.handle(sample(width: 7, phase: .began, timestamp: 2.0)))
        let slow = try changedValue(accumulator.handle(sample(width: 8, phase: .changed, timestamp: 2.25)))
        #expect(slow.translation.width == 15)
        #expect(!slow.bypassesNormalReleaseThreshold)

        let burst = try changedValue(accumulator.handle(sample(width: 8, phase: .changed, timestamp: 2.29)))
        #expect(burst.translation.width == 23)
        #expect(burst.openOriginSide == SwipeCellSide.trailing)
        #expect(burst.bypassesNormalReleaseThreshold)
    }

    @Test("active burst open-origin close bypasses after a timely synthetic release")
    func activeBurstOpenOriginCloseBypassesAfterTimelySyntheticRelease() throws {
        var accumulator = makeAccumulator(
            normalOpenThreshold: 72,
            referenceRevealDistance: 48,
            maxProgressStep: 0.2,
            contentOffset: -144
        )

        _ = try beganValue(accumulator.handle(sample(width: 11, phase: .began, timestamp: 2.0)))
        _ = try changedValue(accumulator.handle(sample(width: 2, phase: .changed, timestamp: 2.039)))
        let active = try changedValue(accumulator.handle(sample(width: 1, phase: .changed, timestamp: 2.067)))
        #expect(active.openOriginSide == SwipeCellSide.trailing)
        #expect(active.bypassesNormalReleaseThreshold)

        let ended = try endedValue(accumulator.finishActiveGesture())
        #expect(ended.openOriginSide == SwipeCellSide.trailing)
        #expect(ended.bypassesNormalReleaseThreshold)
    }

    @Test("active burst open-origin close does not bypass after a stale synthetic release")
    func activeBurstOpenOriginCloseDoesNotBypassAfterStaleSyntheticRelease() throws {
        var accumulator = makeAccumulator(
            normalOpenThreshold: 72,
            referenceRevealDistance: 48,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.2,
            contentOffset: -144
        )

        _ = try beganValue(accumulator.handle(sample(width: 11, phase: .began, timestamp: 2.0)))
        _ = try changedValue(accumulator.handle(sample(width: 2, phase: .changed, timestamp: 2.039)))
        let active = try changedValue(accumulator.handle(sample(width: 1, phase: .changed, timestamp: 2.067)))
        #expect(active.openOriginSide == SwipeCellSide.trailing)
        #expect(active.bypassesNormalReleaseThreshold)

        let ended = try endedValue(accumulator.finishActiveGesture())
        #expect(ended.openOriginSide == SwipeCellSide.trailing)
        #expect(!ended.bypassesNormalReleaseThreshold)
    }

    @Test("active burst open-origin close bypasses when release is near the trigger")
    func activeBurstOpenOriginCloseBypassesWhenReleaseIsNearTrigger() throws {
        var accumulator = makeAccumulator(
            normalOpenThreshold: 72,
            referenceRevealDistance: 48,
            maxProgressStep: 0.2,
            contentOffset: -144
        )

        _ = try beganValue(accumulator.handle(sample(width: 11, phase: .began, timestamp: 2.0)))
        _ = try changedValue(accumulator.handle(sample(width: 2, phase: .changed, timestamp: 2.039)))
        _ = try changedValue(accumulator.handle(sample(width: 1, phase: .changed, timestamp: 2.067)))

        let ended = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 2.10)))
        #expect(ended.openOriginSide == SwipeCellSide.trailing)
        #expect(ended.bypassesNormalReleaseThreshold)
    }

    @Test("fast open-origin close release speed is greater than slow close")
    func fastOpenOriginCloseReleaseSpeedIsGreaterThanSlowClose() throws {
        var slow = makeAccumulator(
            referenceRevealDistance: 100,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.1,
            contentOffset: -100
        )
        var fast = makeAccumulator(
            referenceRevealDistance: 100,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.1,
            contentOffset: -100
        )

        let slowValue = try beganValue(slow.handle(sample(width: 10, phase: .began)))
        let fastValue = try beganValue(fast.handle(sample(width: 100, phase: .began)))

        #expect(slowValue.velocity.x > 0)
        #expect(fastValue.velocity.x > slowValue.velocity.x)
        #expect(fastValue.translation.width == 20)
    }

    @Test("ended tail does not amplify open-origin close release velocity")
    func endedTailDoesNotAmplifyOpenOriginCloseReleaseVelocity() throws {
        var accumulator = makeAccumulator(
            referenceRevealDistance: 100,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.1,
            contentOffset: -100
        )

        let began = try beganValue(accumulator.handle(sample(width: 20, phase: .began, timestamp: 1.0)))
        let ended = try endedValue(accumulator.handle(sample(width: 200, phase: .ended, timestamp: 1.05)))

        #expect(ended.translation.width == 40)
        #expect(ended.velocity.x == began.velocity.x)
    }

    @Test("opposite delta clears open-origin close release velocity")
    func oppositeDeltaClearsOpenOriginCloseReleaseVelocity() throws {
        var accumulator = makeAccumulator(
            referenceRevealDistance: 100,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.1,
            contentOffset: -100
        )

        let began = try beganValue(accumulator.handle(sample(width: 20, phase: .began, timestamp: 1.0)))
        let changed = try changedValue(accumulator.handle(sample(width: -200, phase: .changed, timestamp: 1.02)))

        #expect(changed.translation.width == began.translation.width)
        #expect(changed.velocity.x == 0)
    }

    @Test("synthetic open-origin close release does not reuse active peak velocity")
    func syntheticOpenOriginCloseReleaseDoesNotReuseActivePeakVelocity() throws {
        var accumulator = makeAccumulator(
            referenceRevealDistance: 100,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.1,
            contentOffset: -100
        )

        let active = try beganValue(accumulator.handle(sample(width: 20, phase: .began, timestamp: 1.0)))
        #expect(active.velocity.x > 0)

        let ended = try endedValue(accumulator.finishActiveGesture())
        #expect(ended.translation.width == active.translation.width)
        #expect(ended.velocity.x == 0)
    }

    @Test("stale open-origin close release velocity expires before release")
    func staleOpenOriginCloseReleaseVelocityExpiresBeforeRelease() throws {
        var accumulator = makeAccumulator(
            referenceRevealDistance: 100,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.1,
            contentOffset: -100
        )

        _ = try beganValue(accumulator.handle(sample(width: 20, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: 5, phase: .changed, timestamp: 1.03)))

        let ended = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.14)))
        #expect(ended.velocity.x == 0)
    }

    @Test("recent latest close velocity paces open-origin close release after peak expires")
    func recentLatestCloseVelocityPacesOpenOriginCloseReleaseAfterPeakExpires() throws {
        var accumulator = makeAccumulator(
            referenceRevealDistance: 100,
            maxProgressStep: 0.2,
            endSynthesisDelay: 0.1,
            contentOffset: -100
        )

        _ = try beganValue(accumulator.handle(sample(width: 20, phase: .began, timestamp: 1.0)))
        _ = try changedValue(accumulator.handle(sample(width: 5, phase: .changed, timestamp: 1.08)))

        let ended = try endedValue(accumulator.handle(sample(width: 0, phase: .ended, timestamp: 1.15)))
        #expect(ended.velocity.x == 50)
    }

    @Test("reversing past the origin floors at closed and re-reveals on re-advance")
    func reversingPastOriginFloorsAtClosed() {
        var accumulator = makeAccumulator(containerWidth: 100, referenceRevealDistance: 100, maxProgressStep: 1)

        #expect(accumulator.handle(sample(width: 40, phase: .began)) == .began(panValue(width: 40)))
        #expect(accumulator.handle(sample(width: -90, phase: .changed)) == .changed(panValue(width: 0)))
        #expect(accumulator.handle(sample(width: 25, phase: .changed)) == .changed(panValue(width: 25)))
    }

    @Test("a phase-less scroll accumulates then can be finished explicitly")
    func phaseLessScrollFinishesExplicitly() {
        var accumulator = makeAccumulator(containerWidth: 100, referenceRevealDistance: 100, maxProgressStep: 1)

        #expect(accumulator.handle(sample(width: 30)) == .began(panValue(width: 30)))
        #expect(accumulator.handle(sample(width: 20)) == .changed(panValue(width: 50)))
        #expect(accumulator.finishActiveGesture() == .ended(panValue(width: 50)))
        #expect(!accumulator.isActive)
    }

    @Test("an ended event folds in its final delta")
    func endedEventFoldsInFinalDelta() {
        var accumulator = makeAccumulator(containerWidth: 100, referenceRevealDistance: 100, maxProgressStep: 1)

        #expect(accumulator.handle(sample(width: 30, phase: .began)) == .began(panValue(width: 30)))
        #expect(accumulator.handle(sample(width: 10, phase: .ended)) == .ended(panValue(width: 40)))
        #expect(!accumulator.isActive)
    }

    @Test("cancel only fires for an active scroll")
    func cancelOnlyFiresForActiveScroll() {
        var accumulator = makeAccumulator()

        #expect(accumulator.cancelActiveGesture() == .ignored)
        #expect(accumulator.handle(sample(width: 10, phase: .began)) == .began(panValue(width: 10)))
        #expect(accumulator.cancelActiveGesture() == .cancelled)
        #expect(!accumulator.isActive)
    }

    private func makeAccumulator(
        normalOpenExtent: CGFloat = 100,
        normalOpenThreshold: CGFloat? = nil,
        containerWidth: CGFloat = 100,
        referenceRevealDistance: CGFloat = 100,
        slowReferenceRevealDistance: CGFloat? = nil,
        adaptiveLowerDelta: CGFloat = 20,
        adaptiveUpperDelta: CGFloat = 40,
        fastReleaseIntentDistance: CGFloat? = nil,
        fastReleaseOpenCommitRatio: CGFloat = 1,
        maxProgressStep: CGFloat = 1,
        minStartDelta: CGFloat = 1,
        endSynthesisDelay: TimeInterval = 0.12,
        container: SwipeCellContainer = .list,
        contentOffset: CGFloat = 0
    ) -> SwipeCellScrollWheelPanAccumulator {
        SwipeCellScrollWheelPanAccumulator(
            input: .init(
                scrollWheelMinStartDelta: minStartDelta,
                scrollWheelEndSynthesisDelay: endSynthesisDelay,
                scrollWheelReferenceRevealDistance: referenceRevealDistance,
                scrollWheelSlowReferenceRevealDistance: slowReferenceRevealDistance,
                scrollWheelAdaptiveLowerDelta: adaptiveLowerDelta,
                scrollWheelAdaptiveUpperDelta: adaptiveUpperDelta,
                scrollWheelFastReleaseIntentDistance: fastReleaseIntentDistance,
                scrollWheelFastReleaseOpenCommitRatio: fastReleaseOpenCommitRatio,
                scrollWheelMaxProgressStep: maxProgressStep
            ),
            interactionConfiguration: .symmetric(
                normalOpenExtent: normalOpenExtent,
                normalOpenThreshold: normalOpenThreshold
            ),
            container: container,
            containerWidth: containerWidth,
            contentOffset: contentOffset
        )
    }

    private func makeDestructiveAccumulator(
        normalOpenExtent: CGFloat = 100,
        threshold: CGFloat = 180,
        containerWidth: CGFloat = 300,
        container: SwipeCellContainer = .list,
        contentOffset: CGFloat = 0,
        referenceRevealDistance: CGFloat = 100,
        slowReferenceRevealDistance: CGFloat? = nil,
        adaptiveLowerDelta: CGFloat = 20,
        adaptiveUpperDelta: CGFloat = 40,
        fastReleaseIntentDistance: CGFloat? = nil,
        fastReleaseOpenCommitRatio: CGFloat = 1,
        maxProgressStep: CGFloat = 2
    ) -> SwipeCellScrollWheelPanAccumulator {
        SwipeCellScrollWheelPanAccumulator(
            input: .init(
                scrollWheelMinStartDelta: 1,
                scrollWheelReferenceRevealDistance: referenceRevealDistance,
                scrollWheelSlowReferenceRevealDistance: slowReferenceRevealDistance,
                scrollWheelAdaptiveLowerDelta: adaptiveLowerDelta,
                scrollWheelAdaptiveUpperDelta: adaptiveUpperDelta,
                scrollWheelFastReleaseIntentDistance: fastReleaseIntentDistance,
                scrollWheelFastReleaseOpenCommitRatio: fastReleaseOpenCommitRatio,
                scrollWheelMaxProgressStep: maxProgressStep
            ),
            interactionConfiguration: destructiveConfiguration(
                normalOpenExtent: normalOpenExtent,
                threshold: threshold
            ),
            container: container,
            containerWidth: containerWidth,
            contentOffset: contentOffset
        )
    }

    private func destructiveConfiguration(
        normalOpenExtent: CGFloat = 100,
        threshold: CGFloat
    ) -> SwipeCellInteractionConfiguration {
        SwipeCellInteractionConfiguration(
            leading: .disabled,
            trailing: SwipeCellInteractionSideConfiguration(
                normalOpenExtent: normalOpenExtent,
                allowsDestructive: true,
                destructiveThreshold: threshold,
                destructiveSettlingExtent: 220
            )
        )
    }

    private func sample(
        width: CGFloat,
        height: CGFloat = 0,
        phase: SwipeCellScrollWheelPhase = .none,
        momentumPhase: SwipeCellScrollWheelPhase = .none,
        timestamp: TimeInterval? = nil
    ) -> SwipeCellScrollWheelSample {
        SwipeCellScrollWheelSample(
            delta: CGSize(width: width, height: height),
            phase: phase,
            momentumPhase: momentumPhase,
            timestamp: timestamp
        )
    }

    private func touchSample(
        _ phase: SwipeCellIndirectTouchPresencePhase,
        timestamp: TimeInterval? = nil
    ) -> SwipeCellIndirectTouchPresenceSample {
        SwipeCellIndirectTouchPresenceSample(phase: phase, timestamp: timestamp)
    }

    private func panValue(
        width: CGFloat,
        allowsDestructiveRelease: Bool = true,
        bypassesNormalReleaseThreshold: Bool = false
    ) -> SwipeCellPanValue {
        let translation = CGSize(width: width, height: 0)
        return SwipeCellPanValue(
            translation: translation,
            predictedEndTranslation: translation,
            allowsDestructiveRelease: allowsDestructiveRelease,
            bypassesNormalReleaseThreshold: bypassesNormalReleaseThreshold,
            velocity: .zero
        )
    }

    private func beganValue(_ event: SwipeCellScrollWheelPanEvent) throws -> SwipeCellPanValue {
        guard case .began(let value) = event else {
            Issue.record("Expected began event, got \(event)")
            throw TestFailure()
        }
        return value
    }

    private func changedValue(_ event: SwipeCellScrollWheelPanEvent) throws -> SwipeCellPanValue {
        guard case .changed(let value) = event else {
            Issue.record("Expected changed event, got \(event)")
            throw TestFailure()
        }
        return value
    }

    private func endedValue(_ event: SwipeCellScrollWheelPanEvent) throws -> SwipeCellPanValue {
        guard case .ended(let value) = event else {
            Issue.record("Expected ended event, got \(event)")
            throw TestFailure()
        }
        return value
    }

    private func activeValue(_ event: SwipeCellScrollWheelPanEvent) throws -> SwipeCellPanValue {
        switch event {
        case .began(let value), .changed(let value):
            return value
        default:
            Issue.record("Expected active event, got \(event)")
            throw TestFailure()
        }
    }

    private struct TestFailure: Error {}
}
