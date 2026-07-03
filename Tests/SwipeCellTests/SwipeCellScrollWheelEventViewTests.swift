#if os(macOS)
    import AppKit
    import CoreGraphics
    import Foundation
    import Testing

    @_spi(ManualDebug) @testable import SwipeCell

    @MainActor
    @Suite("SwipeCell scroll wheel event view")
    struct SwipeCellScrollWheelEventViewTests {
        @Test("active scroll keeps began input scale while configuration updates")
        func activeScrollKeepsBeganInputScaleWhileConfigurationUpdates() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -50, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
            #expect(values.last?.translation.width == -50)

            view.configure(
                isEnabled: true,
                input: input(lineScale: 10),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -10, height: 0),
                    phase: .changed,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.1
                )
            )
            #expect(values.last?.translation.width == -60)

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    phase: .ended,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.2
                )
            )
            #expect(values.last?.translation.width == -60)

            values.removeAll()
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -10, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 100.0
                )
            )
            #expect(values.last?.translation.width == -100)

            _ = view.handleScrollWheelSample(
                rawDelta: .zero,
                phase: .ended,
                hasPreciseScrollingDeltas: false,
                timestamp: 100.1
            )
        }

        @Test("active scroll keeps began reference distance while configuration updates")
        func activeScrollKeepsBeganReferenceDistanceWhileConfigurationUpdates() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1, referenceRevealDistance: 100),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -50, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
            #expect(values.last?.translation.width == -50)

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1, referenceRevealDistance: 600),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -50, height: 0),
                    phase: .changed,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.1
                )
            )
            #expect(values.last?.translation.width == -100)

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    phase: .ended,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.2
                )
            )

            values.removeAll()
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -60, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 100.0
                )
            )
            #expect(values.last?.translation.width == -10)

            _ = view.handleScrollWheelSample(
                rawDelta: .zero,
                phase: .ended,
                hasPreciseScrollingDeltas: false,
                timestamp: 100.1
            )
        }

        @Test("disabling active scroll clears the began input scale")
        func disablingActiveScrollClearsBeganInputScale() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            var cancelCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: { cancelCount += 1 }
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -50, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false
                )
            )
            #expect(values.last?.translation.width == -50)

            view.configure(
                isEnabled: false,
                input: input(lineScale: 10),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: { cancelCount += 1 }
            )
            #expect(cancelCount == 1)

            view.configure(
                isEnabled: true,
                input: input(lineScale: 10),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: { cancelCount += 1 }
            )

            values.removeAll()
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -10, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false
                )
            )
            #expect(values.last?.translation.width == -100)

            _ = view.handleScrollWheelSample(
                rawDelta: .zero,
                phase: .ended,
                hasPreciseScrollingDeltas: false
            )
        }

        @Test("post-release cooldown consumes residual horizontal begin")
        func postReleaseCooldownConsumesResidualHorizontalBegin() {
            let view = SwipeCellScrollWheelEventView()
            var beganCount = 0
            var values: [SwipeCellPanValue] = []
            var endedCount = 0
            let testInput = input(lineScale: 1, endSynthesisDelay: 0.12)

            view.configure(
                isEnabled: true,
                input: testInput,
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                contentOffset: -100,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    phase: .ended,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.04
                )
            )
            #expect(beganCount == 1)
            #expect(endedCount == 1)

            view.configure(
                isEnabled: true,
                input: testInput,
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                contentOffset: 0,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            values.removeAll()
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.10
                )
            )
            #expect(beganCount == 1)
            #expect(endedCount == 1)
            #expect(values.isEmpty)

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.24
                )
            )
            #expect(beganCount == 2)
            #expect(values.last?.translation.width == -20)

            _ = view.handleScrollWheelSample(
                rawDelta: .zero,
                phase: .ended,
                hasPreciseScrollingDeltas: false,
                timestamp: 1.25
            )
        }

        @Test("post-release cooldown lets vertical scroll fall through")
        func postReleaseCooldownLetsVerticalScrollFallThrough() {
            let view = SwipeCellScrollWheelEventView()
            var beganCount = 0
            var values: [SwipeCellPanValue] = []
            let testInput = input(lineScale: 1, endSynthesisDelay: 0.12)

            view.configure(
                isEnabled: true,
                input: testInput,
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                contentOffset: -100,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 2.0
                )
            )
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    phase: .ended,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 2.04
                )
            )

            values.removeAll()
            #expect(
                !view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 0, height: 20),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 2.10
                )
            )
            #expect(beganCount == 1)
            #expect(values.isEmpty)

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 2.11
                )
            )
            #expect(beganCount == 1)
            #expect(values.isEmpty)
        }

        @Test("post-release cooldown consumes residual after destructive release")
        func postReleaseCooldownConsumesResidualAfterDestructiveRelease() {
            let view = SwipeCellScrollWheelEventView()
            var beganCount = 0
            var values: [SwipeCellPanValue] = []
            let testInput = input(lineScale: 1, endSynthesisDelay: 0.12)
            let destructiveSide = SwipeCellInteractionSideConfiguration(
                normalOpenExtent: 100,
                normalOpenThreshold: 50,
                allowsDestructive: true,
                destructiveThreshold: 140,
                destructiveSettlingExtent: 160
            )

            view.configure(
                isEnabled: true,
                input: testInput,
                interactionConfiguration: SwipeCellInteractionConfiguration(
                    leading: destructiveSide,
                    trailing: destructiveSide
                ),
                containerWidth: 300,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -200, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 3.0
                )
            )
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -10, height: 0),
                    phase: .changed,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 3.02
                )
            )
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    phase: .ended,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 3.04
                )
            )
            #expect(values.last?.allowsDestructiveRelease == true)

            values.removeAll()
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 3.10
                )
            )
            #expect(beganCount == 1)
            #expect(values.isEmpty)
        }

        @Test("disabling the bridge clears post-release cooldown")
        func disablingBridgeClearsPostReleaseCooldown() {
            let view = SwipeCellScrollWheelEventView()
            var beganCount = 0
            var values: [SwipeCellPanValue] = []
            let testInput = input(lineScale: 1, endSynthesisDelay: 0.12)

            view.configure(
                isEnabled: true,
                input: testInput,
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                contentOffset: -100,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 4.0
                )
            )
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    phase: .ended,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 4.04
                )
            )

            view.configure(
                isEnabled: false,
                input: testInput,
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                contentOffset: 0,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )
            view.configure(
                isEnabled: true,
                input: testInput,
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                contentOffset: 0,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            values.removeAll()
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 4.10
                )
            )
            #expect(beganCount == 2)
            #expect(values.last?.translation.width == -20)
        }

        @Test("timer-synthesized release starts post-release cooldown")
        func timerSynthesizedReleaseStartsPostReleaseCooldown() {
            let view = SwipeCellScrollWheelEventView()
            var beganCount = 0
            var values: [SwipeCellPanValue] = []
            var endedCount = 0
            let testInput = input(lineScale: 1, endSynthesisDelay: 0.01)

            view.configure(
                isEnabled: true,
                input: testInput,
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                contentOffset: -100,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false
                )
            )
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
            #expect(beganCount == 1)
            #expect(endedCount == 1)

            view.configure(
                isEnabled: true,
                input: testInput,
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                contentOffset: 0,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            values.removeAll()
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -20, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false
                )
            )
            #expect(beganCount == 1)
            #expect(endedCount == 1)
            #expect(values.isEmpty)
        }

        @Test("scroll view destructive arm latches through momentum until real ended")
        func scrollViewDestructiveArmLatchesThroughMomentumUntilRealEnded() {
            let view = SwipeCellScrollWheelEventView()
            var beganCount = 0
            var values: [SwipeCellPanValue] = []
            var endedCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: destructiveInteractionConfiguration(),
                container: .scrollView,
                containerWidth: 300,
                onBegan: { beganCount += 1 },
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -130, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 5.0
                )
            )
            #expect(beganCount == 1)
            #expect(values.last?.allowsDestructiveRelease == false)
            let countAfterArm = values.count

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    momentumPhase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 5.03
                )
            )
            #expect(values.count == countAfterArm)
            #expect(endedCount == 0)

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    phase: .ended,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 5.10
                )
            )
            #expect(endedCount == 1)
            #expect(values.last?.allowsDestructiveRelease == true)
        }

        @Test("scroll view stationary touch presence commits on touch ended")
        func scrollViewStationaryTouchPresenceCommitsOnTouchEnded() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            var endedCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: destructiveInteractionConfiguration(),
                container: .scrollView,
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -130, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 6.0
                )
            )
            let countAfterArm = values.count

            #expect(!view.handleIndirectTouchPresence(.active, timestamp: 6.01))
            #expect(view.handleIndirectTouchPresence(.stationary, timestamp: 6.04))
            #expect(values.count == countAfterArm)
            #expect(endedCount == 0)

            #expect(view.handleIndirectTouchPresence(.ended, timestamp: 6.10))
            #expect(endedCount == 1)
            #expect(values.last?.allowsDestructiveRelease == true)
        }

        @Test("scroll view touch presence suspends synthetic release below destructive")
        func scrollViewTouchPresenceSuspendsSyntheticReleaseBelowDestructive() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            var endedCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1, endSynthesisDelay: 0.01),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                container: .scrollView,
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -50, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 9.0
                )
            )
            #expect(!view.handleIndirectTouchPresence(.active, timestamp: 9.01))
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
            #expect(endedCount == 0)
            #expect(values.last?.translation.width == -50)

            #expect(view.handleIndirectTouchPresence(.ended, timestamp: 9.10))
            #expect(endedCount == 1)
            #expect(values.last?.translation.width == -50)
        }

        @Test("scroll view touch presence suspends momentum release below destructive")
        func scrollViewTouchPresenceSuspendsMomentumReleaseBelowDestructive() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            var endedCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                container: .scrollView,
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -50, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 10.0
                )
            )
            #expect(!view.handleIndirectTouchPresence(.active, timestamp: 10.01))
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    momentumPhase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 10.03
                )
            )
            #expect(endedCount == 0)
            #expect(values.last?.translation.width == -50)

            #expect(view.handleIndirectTouchPresence(.ended, timestamp: 10.10))
            #expect(endedCount == 1)
            #expect(values.last?.translation.width == -50)
        }

        @Test("scroll view touch ended before hold keeps flick suppression")
        func scrollViewTouchEndedBeforeHoldKeepsFlickSuppression() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            var endedCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: destructiveInteractionConfiguration(),
                container: .scrollView,
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -130, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 7.0
                )
            )
            #expect(!view.handleIndirectTouchPresence(.active, timestamp: 7.01))
            #expect(view.handleIndirectTouchPresence(.ended, timestamp: 7.04))
            #expect(endedCount == 1)
            #expect(values.last?.allowsDestructiveRelease == false)
        }

        @Test("list ignores touch presence and keeps existing release")
        func listIgnoresTouchPresenceAndKeepsExistingRelease() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            var endedCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: destructiveInteractionConfiguration(),
                container: .list,
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -130, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 8.0
                )
            )
            #expect(!view.handleIndirectTouchPresence(.active, timestamp: 8.01))
            #expect(!view.handleIndirectTouchPresence(.stationary, timestamp: 8.04))
            #expect(!view.handleIndirectTouchPresence(.ended, timestamp: 8.10))
            #expect(endedCount == 0)

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    momentumPhase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 8.12
                )
            )
            #expect(endedCount == 1)
            #expect(values.last?.allowsDestructiveRelease == false)
        }

        @Test("touch observer path remains hit-test transparent")
        func touchObserverPathRemainsHitTestTransparent() {
            let view = SwipeCellScrollWheelEventView(
                frame: NSRect(x: 0, y: 0, width: 320, height: 44)
            )

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: destructiveInteractionConfiguration(),
                container: .scrollView,
                containerWidth: 320,
                onBegan: {},
                onChanged: { _ in },
                onEnded: { _ in },
                onCancelled: {}
            )

            #expect(view.hitTest(NSPoint(x: 20, y: 20)) == nil)
        }

        @Test("scroll view destructive arm suspends synthetic release while latched")
        func scrollViewDestructiveArmSuspendsSyntheticReleaseWhileLatched() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            var endedCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1, endSynthesisDelay: 0.01),
                interactionConfiguration: destructiveInteractionConfiguration(),
                container: .scrollView,
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -130, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false
                )
            )
            let countAfterArm = values.count
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))

            #expect(values.count == countAfterArm)
            #expect(endedCount == 0)

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: .zero,
                    phase: .ended,
                    hasPreciseScrollingDeltas: false
                )
            )
            #expect(endedCount == 1)
            #expect(values.last?.allowsDestructiveRelease == true)
        }

        @Test("scroll view destructive latch lets synthetic release resume after reverse cancel")
        func scrollViewDestructiveLatchLetsSyntheticReleaseResumeAfterReverseCancel() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            var endedCount = 0

            view.configure(
                isEnabled: true,
                input: input(lineScale: 1, endSynthesisDelay: 0.01),
                interactionConfiguration: destructiveInteractionConfiguration(),
                container: .scrollView,
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: {
                    values.append($0)
                    endedCount += 1
                },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -130, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false
                )
            )
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
            #expect(endedCount == 0)

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 80, height: 0),
                    phase: .changed,
                    hasPreciseScrollingDeltas: false
                )
            )
            #expect(values.last?.translation.width == -50)
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))

            #expect(endedCount == 1)
            #expect(values.last?.translation.width == -50)
        }

        @Test("clear horizontal begin starts a swipe")
        func clearHorizontalBeginStartsSwipe() {
            let view = makeRoutingView()
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -50, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
        }

        @Test("vertical-dominant begin falls through")
        func verticalDominantBeginFallsThrough() {
            let view = makeRoutingView()
            var changes = 0
            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { _ in changes += 1 },
                onEnded: { _ in },
                onCancelled: {}
            )

            #expect(
                !view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 10, height: 40),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
            #expect(changes == 0)
        }

        @Test("exact-tie begin falls through")
        func exactTieBeginFallsThrough() {
            let view = makeRoutingView()
            #expect(
                !view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 20, height: 20),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
        }

        @Test("below start-delta horizontal begin falls through")
        func belowStartDeltaHorizontalBeginFallsThrough() {
            let view = makeRoutingView()
            #expect(
                !view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 0.5, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
        }

        @Test("disabled target side begin falls through")
        func disabledTargetSideBeginFallsThrough() {
            let view = SwipeCellScrollWheelEventView()
            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: SwipeCellInteractionConfiguration(
                    leading: .disabled,
                    trailing: SwipeCellInteractionSideConfiguration(normalOpenExtent: 100)
                ),
                containerWidth: 300,
                onBegan: {},
                onChanged: { _ in },
                onEnded: { _ in },
                onCancelled: {}
            )

            // A leading-direction (positive width) scroll cannot reveal the disabled leading side.
            #expect(
                !view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 50, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
        }

        @Test("active vertical sample is a no-op")
        func activeVerticalSampleIsNoOp() {
            let view = SwipeCellScrollWheelEventView()
            var values: [SwipeCellPanValue] = []
            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { values.append($0) },
                onEnded: { values.append($0) },
                onCancelled: {}
            )

            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -50, height: 0),
                    phase: .began,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.0
                )
            )
            #expect(values.last?.translation.width == -50)
            let changeCountAfterBegin = values.count

            // A vertical-dominant sample during an active swipe is a no-op: it must not move the row or
            // emit a new value.
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: 0, height: 40),
                    phase: .changed,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.05
                )
            )
            #expect(values.count == changeCountAfterBegin)
            #expect(values.last?.translation.width == -50)

            // Horizontal samples still drive the accumulator; the no-op contributed nothing.
            #expect(
                view.handleScrollWheelSample(
                    rawDelta: CGSize(width: -10, height: 0),
                    phase: .changed,
                    hasPreciseScrollingDeltas: false,
                    timestamp: 1.10
                )
            )
            #expect(values.last?.translation.width == -60)

            _ = view.handleScrollWheelSample(
                rawDelta: .zero,
                phase: .ended,
                hasPreciseScrollingDeltas: false,
                timestamp: 1.12
            )
            #expect(values.last?.translation.width == -60)
        }

        private func makeRoutingView() -> SwipeCellScrollWheelEventView {
            let view = SwipeCellScrollWheelEventView()
            view.configure(
                isEnabled: true,
                input: input(lineScale: 1),
                interactionConfiguration: .symmetric(normalOpenExtent: 100),
                containerWidth: 300,
                onBegan: {},
                onChanged: { _ in },
                onEnded: { _ in },
                onCancelled: {}
            )
            return view
        }

        private func input(
            lineScale: CGFloat,
            endSynthesisDelay: TimeInterval = 60,
            referenceRevealDistance: CGFloat = 100
        ) -> SwipeCellConfiguration.PlatformInput {
            SwipeCellConfiguration.PlatformInput(
                scrollWheelTrackpadScale: 1,
                scrollWheelLineScale: lineScale,
                scrollWheelMinStartDelta: 1,
                scrollWheelEndSynthesisDelay: endSynthesisDelay,
                scrollWheelReferenceRevealDistance: referenceRevealDistance,
                scrollWheelMaxProgressStep: 2
            )
        }

        private func destructiveInteractionConfiguration() -> SwipeCellInteractionConfiguration {
            let destructiveSide = SwipeCellInteractionSideConfiguration(
                normalOpenExtent: 100,
                normalOpenThreshold: 50,
                allowsDestructive: true,
                destructiveThreshold: 180,
                destructiveSettlingExtent: 220
            )
            return SwipeCellInteractionConfiguration(
                leading: .disabled,
                trailing: destructiveSide
            )
        }
    }
#endif
