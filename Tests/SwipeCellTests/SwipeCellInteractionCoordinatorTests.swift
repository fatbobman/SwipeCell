import Foundation
import SwiftUI
import Testing

@_spi(ManualDebug) @testable import SwipeCell

/// Regression coverage for the pan → ownership boundary (issue #56). The coordinator must not let a
/// closed-origin pan toward a disabled / empty side claim ownership, since that would replace and reset
/// another row that is currently held/open. These tests assert the manager-level ownership outcome,
/// which is what the user perceives as the held row vanishing.
@MainActor
@Suite("SwipeCellInteractionCoordinator")
struct SwipeCellInteractionCoordinatorTests {
    /// A row whose leading side has no actions and whose trailing side opens normally — the demo shape
    /// that exposed the bug.
    private func trailingOnlyModel() -> SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: .disabled,
                trailing: SwipeCellInteractionSideConfiguration(normalOpenExtent: 80)
            ),
            motion: SwipeCellConfiguration.platformDefault.motion
        )
    }

    private func directTouchSymmetricModel() -> SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            ),
            motion: SwipeCellConfiguration.iOSDefault.motion
        )
    }

    private func indirectScrollSymmetricModel() -> SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            ),
            motion: SwipeCellConfiguration.macOSDefault.motion
        )
    }

    private func directTouchDestructiveModel() -> SwipeCellInteractionModel {
        let sideConfiguration = SwipeCellInteractionSideConfiguration(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            allowsDestructive: true,
            destructiveThreshold: 150,
            destructiveSettlingExtent: 180
        )
        return SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: sideConfiguration,
                trailing: sideConfiguration
            ),
            motion: SwipeCellConfiguration.iOSDefault.motion
        )
    }

    private func inputs(
        for cellID: AnyHashable,
        manager: SwipeCellManager,
        configuration: SwipeCellConfiguration = .iOSDefault,
        settlingAnimation: Animation = .default
    ) -> SwipeCellInteractionInputs {
        SwipeCellInteractionInputs(
            cellID: cellID,
            manager: manager,
            configuration: configuration,
            settlingAnimation: settlingAnimation
        )
    }

    private func panChanged(
        _ coordinator: SwipeCellInteractionCoordinator,
        width: CGFloat,
        predictedWidth: CGFloat? = nil,
        velocityX: CGFloat = 0,
        timestamp: TimeInterval,
        model: SwipeCellInteractionModel,
        inputs: SwipeCellInteractionInputs
    ) {
        let prediction = predictedWidth ?? width
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: width, height: 0),
                predictedEndTranslation: CGSize(width: prediction, height: 0),
                velocity: CGPoint(x: velocityX, y: 0),
                timestamp: timestamp
            ),
            model: model,
            inputs: inputs
        )
    }

    private func openOnlyLargeStepRampAtOpen() -> (
        SwipeCellManager,
        SwipeCellInteractionCoordinator,
        SwipeCellInteractionModel,
        SwipeCellInteractionInputs
    ) {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        panChanged(
            coordinator,
            width: 65,
            predictedWidth: 220,
            velocityX: 620,
            timestamp: 1.01,
            model: model,
            inputs: inputs
        )
        panChanged(coordinator, width: 65, timestamp: 1.20, model: model, inputs: inputs)
        panChanged(coordinator, width: 83, timestamp: 1.21, model: model, inputs: inputs)
        panChanged(coordinator, width: 100, timestamp: 1.22, model: model, inputs: inputs)

        #expect(abs(coordinator.contentOffset - 100) < 0.0001)
        return (manager, coordinator, model, inputs)
    }

    @Test("direct-touch fast preflight commits before release and ignores later low eligibility")
    func directTouchFastPreflightCommitsBeforeReleaseAndIgnoresLaterLowEligibility() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -6, height: 0),
                predictedEndTranslation: CGSize(width: -70, height: 0),
                velocity: CGPoint(x: -900, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        #expect(coordinator.contentOffset < 0)
        #expect(abs(coordinator.contentOffset) < 6)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -10, height: 0),
                predictedEndTranslation: CGSize(width: -90, height: 0),
                velocity: CGPoint(x: -950, y: 0),
                timestamp: 1.02
            ),
            model: model,
            inputs: inputs
        )
        #expect(coordinator.contentOffset < 0)
        #expect(abs(coordinator.contentOffset) < 10)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -14, height: 0),
                predictedEndTranslation: CGSize(width: -100, height: 0),
                velocity: CGPoint(x: -980, y: 0),
                timestamp: 1.03
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(coordinator.normalOpenProgress == 1)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -12, height: 0),
                predictedEndTranslation: CGSize(width: -12, height: 0),
                velocity: .zero,
                timestamp: 1.10
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(coordinator.normalOpenProgress == 1)

        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: -12, height: 0),
                predictedEndTranslation: CGSize(width: -12, height: 0),
                velocity: .zero,
                timestamp: 1.11
            ),
            model: model,
            inputs: inputs
        )
        await drainMainQueue()

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(manager.phase == .open(.trailing))
    }

    @Test("direct-touch preflight time cap falls back to normal tracking")
    func directTouchPreflightTimeCapFallsBackToNormalTracking() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -14, height: 0),
                predictedEndTranslation: CGSize(width: -70, height: 0),
                velocity: CGPoint(x: -300, y: 0),
                timestamp: 1.13
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == -14)
    }

    @Test("direct-touch slow drag bypasses fast preflight")
    func directTouchSlowDragBypassesFastPreflight() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -24, height: 0),
                velocity: CGPoint(x: -80, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == -20)
        #expect(abs(coordinator.normalOpenProgress - 0.2) < 0.0001)
    }

    @Test("direct-touch first large manual sample enters visible ramp")
    func directTouchFirstLargeManualSampleEntersVisibleRamp() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 65, height: 0),
                predictedEndTranslation: CGSize(width: 220, height: 0),
                velocity: CGPoint(x: 620, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 22.75) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.2275) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 65, height: 0),
                predictedEndTranslation: CGSize(width: 65, height: 0),
                velocity: .zero,
                timestamp: 1.20
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 22.75) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 83, height: 0),
                predictedEndTranslation: CGSize(width: 83, height: 0),
                velocity: .zero,
                timestamp: 1.21
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset > 22.75)
        #expect(coordinator.contentOffset < 83)
        #expect(coordinator.contentOffset < 100)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 100, height: 0),
                predictedEndTranslation: CGSize(width: 100, height: 0),
                velocity: .zero,
                timestamp: 1.22
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 100) < 0.0001)
        #expect(coordinator.normalOpenProgress == 1)
    }

    @Test("direct-touch ordinary delayed first large sample stays one to one")
    func directTouchOrdinaryDelayedFirstLargeSampleStaysOneToOne() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 65, height: 0),
                predictedEndTranslation: CGSize(width: 65, height: 0),
                velocity: .zero,
                timestamp: 1.20
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == 65)
        #expect(abs(coordinator.normalOpenProgress - 0.65) < 0.0001)
    }

    @Test("direct-touch destructive large-step ramp recovers before activation")
    func directTouchDestructiveLargeStepRampRecoversBeforeActivation() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchDestructiveModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 130, height: 0),
                predictedEndTranslation: CGSize(width: 220, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 25) < 0.0001)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 130, height: 0),
                predictedEndTranslation: CGSize(width: 130, height: 0),
                velocity: .zero,
                timestamp: 1.20
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 25) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 140, height: 0),
                predictedEndTranslation: CGSize(width: 140, height: 0),
                velocity: .zero,
                timestamp: 1.21
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset > 25)
        #expect(coordinator.contentOffset < 140)
        #expect(coordinator.isArmed == false)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 150, height: 0),
                predictedEndTranslation: CGSize(width: 150, height: 0),
                velocity: .zero,
                timestamp: 1.22
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 150) < 0.0001)
        #expect(coordinator.deformationProgress == 1)
        #expect(coordinator.isArmed == true)
    }

    @Test("direct-touch long fast drag exits preflight from manual baseline and recovers by open")
    func directTouchLongFastDragExitsPreflightFromManualBaselineAndRecoversByOpen() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 6, height: 0),
                predictedEndTranslation: CGSize(width: 180, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        #expect(coordinator.contentOffset > 0)
        #expect(coordinator.contentOffset < 6)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 65, height: 0),
                predictedEndTranslation: CGSize(width: 240, height: 0),
                velocity: CGPoint(x: 750, y: 0),
                timestamp: 1.05
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 22.75) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.2275) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 85, height: 0),
                predictedEndTranslation: CGSize(width: 300, height: 0),
                velocity: CGPoint(x: 860, y: 0),
                timestamp: 1.06
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 22.75) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.2275) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 100, height: 0),
                predictedEndTranslation: CGSize(width: 300, height: 0),
                velocity: CGPoint(x: 860, y: 0),
                timestamp: 1.07
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset > 22.75)
        #expect(coordinator.contentOffset < 60)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 210, height: 0),
                predictedEndTranslation: CGSize(width: 300, height: 0),
                velocity: CGPoint(x: 860, y: 0),
                timestamp: 1.08
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset > 30)
        #expect(coordinator.contentOffset < 100)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 260, height: 0),
                predictedEndTranslation: CGSize(width: 320, height: 0),
                velocity: CGPoint(x: 860, y: 0),
                timestamp: 1.09
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset > 40)
        #expect(coordinator.contentOffset < 100)

        let recoveryTranslations: [CGFloat] = [310, 360, 410, 460]
        for (index, translation) in recoveryTranslations.enumerated() {
            coordinator.panChanged(
                SwipeCellPanValue(
                    translation: CGSize(width: translation, height: 0),
                    predictedEndTranslation: CGSize(width: translation + 60, height: 0),
                    velocity: CGPoint(x: 860, y: 0),
                    timestamp: 1.10 + TimeInterval(index) * 0.01
                ),
                model: model,
                inputs: inputs
            )
        }

        #expect(coordinator.contentOffset >= 100)
        #expect(coordinator.normalOpenProgress == 1)
    }

    @Test("direct-touch open-only manual handoff does not jump on the baseline sample")
    func directTouchOpenOnlyManualHandoffDoesNotJumpOnBaselineSample() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 64,
                normalOpenThreshold: 32
            ),
            motion: SwipeCellConfiguration.iOSDefault.motion
        )
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 8.333, height: 0),
                predictedEndTranslation: CGSize(width: 107.985, height: 0),
                velocity: CGPoint(x: 398.605, y: 0),
                timestamp: 1.016
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset - 2.91655) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 10.667, height: 0),
                predictedEndTranslation: CGSize(width: 138.644, height: 0),
                velocity: CGPoint(x: 511.908, y: 0),
                timestamp: 1.074
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset - 3.73345) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 65.667, height: 0),
                predictedEndTranslation: CGSize(width: 221.623, height: 0),
                velocity: CGPoint(x: 623.826, y: 0),
                timestamp: 1.083
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset - 3.73345) < 0.0001)
        #expect(coordinator.contentOffset < 64)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 83.667, height: 0),
                predictedEndTranslation: CGSize(width: 313.534, height: 0),
                velocity: CGPoint(x: 919.471, y: 0),
                timestamp: 1.099
            ),
            model: model,
            inputs: inputs
        )
        #expect(coordinator.contentOffset > 3.73345)
        #expect(coordinator.contentOffset < 64)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 141.667, height: 0),
                predictedEndTranslation: CGSize(width: 277.641, height: 0),
                velocity: CGPoint(x: 543.897, y: 0),
                timestamp: 1.183
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset > 3.73345)
        #expect(coordinator.contentOffset < 64)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 300, height: 0),
                predictedEndTranslation: CGSize(width: 360, height: 0),
                velocity: CGPoint(x: 543.897, y: 0),
                timestamp: 1.200
            ),
            model: model,
            inputs: inputs
        )
        #expect(coordinator.contentOffset < 64)

        let recoveryTranslations: [CGFloat] = [360, 420, 480, 540, 600, 660, 720]
        for (index, translation) in recoveryTranslations.enumerated() {
            coordinator.panChanged(
                SwipeCellPanValue(
                    translation: CGSize(width: translation, height: 0),
                    predictedEndTranslation: CGSize(width: translation + 60, height: 0),
                    velocity: CGPoint(x: 543.897, y: 0),
                    timestamp: 1.210 + TimeInterval(index) * 0.01
                ),
                model: model,
                inputs: inputs
            )
        }

        #expect(coordinator.contentOffset >= 64)
        #expect(coordinator.normalOpenProgress == 1)
    }

    @Test("direct-touch open-only visible debt recovery is debt aware, frame capped, and eased in")
    func directTouchOpenOnlyVisibleDebtRecoveryIsDebtAwareFrameCappedAndEasedIn() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 64,
                normalOpenThreshold: 64
            ),
            motion: SwipeCellConfiguration.iOSDefault.motion
        )
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 45.714285714, height: 0),
                predictedEndTranslation: CGSize(width: 160, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset - 16) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 135.5, height: 0),
                predictedEndTranslation: CGSize(width: 220, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.02
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset - 16) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 135.5, height: 0),
                predictedEndTranslation: CGSize(width: 220, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.03
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset - 16) < 0.0001)

        let baselineVisible = coordinator.contentOffset
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 160.5, height: 0),
                predictedEndTranslation: CGSize(width: 260, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.04
            ),
            model: model,
            inputs: inputs
        )
        let firstRecoveredVisible = coordinator.contentOffset
        #expect(firstRecoveredVisible > baselineVisible)
        #expect(firstRecoveredVisible - baselineVisible <= 5.3)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 185.5, height: 0),
                predictedEndTranslation: CGSize(width: 280, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.05
            ),
            model: model,
            inputs: inputs
        )
        let secondRecoveredVisible = coordinator.contentOffset
        #expect(secondRecoveredVisible > firstRecoveredVisible)
        #expect(secondRecoveredVisible - firstRecoveredVisible <= 6.9)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 210.5, height: 0),
                predictedEndTranslation: CGSize(width: 300, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.06
            ),
            model: model,
            inputs: inputs
        )
        let thirdRecoveredVisible = coordinator.contentOffset
        #expect(thirdRecoveredVisible > secondRecoveredVisible)
        #expect(thirdRecoveredVisible - secondRecoveredVisible <= 8.1)
        #expect(thirdRecoveredVisible < 64)
    }

    @Test("direct-touch open-only manual fallback reaches open when baseline starts beyond open")
    func directTouchOpenOnlyManualFallbackReachesOpenWhenBaselineStartsBeyondOpen() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 6, height: 0),
                predictedEndTranslation: CGSize(width: 180, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 120, height: 0),
                predictedEndTranslation: CGSize(width: 260, height: 0),
                velocity: CGPoint(x: 760, y: 0),
                timestamp: 1.05
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 25) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.25) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 120, height: 0),
                predictedEndTranslation: CGSize(width: 260, height: 0),
                velocity: CGPoint(x: 760, y: 0),
                timestamp: 1.06
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 25) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.25) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 220, height: 0),
                predictedEndTranslation: CGSize(width: 280, height: 0),
                velocity: CGPoint(x: 760, y: 0),
                timestamp: 1.07
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset > 25)
        #expect(coordinator.contentOffset < 100)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 380, height: 0),
                predictedEndTranslation: CGSize(width: 420, height: 0),
                velocity: CGPoint(x: 760, y: 0),
                timestamp: 1.08
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset > 40)
        #expect(coordinator.contentOffset < 100)

        let recoveryTranslations: [CGFloat] = [460, 540, 620, 700, 780]
        for (index, translation) in recoveryTranslations.enumerated() {
            coordinator.panChanged(
                SwipeCellPanValue(
                    translation: CGSize(width: translation, height: 0),
                    predictedEndTranslation: CGSize(width: translation + 40, height: 0),
                    velocity: CGPoint(x: 760, y: 0),
                    timestamp: 1.09 + TimeInterval(index) * 0.01
                ),
                model: model,
                inputs: inputs
            )
        }

        #expect(coordinator.contentOffset >= 100)
        #expect(coordinator.contentOffset < 120)
        #expect(coordinator.normalOpenProgress == 1)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch open-only large-step ramp hands off at open for pause and reverse")
    func directTouchOpenOnlyLargeStepRampHandsOffAtOpenForPauseAndReverse() {
        let (_, coordinator, model, inputs) = openOnlyLargeStepRampAtOpen()

        panChanged(coordinator, width: 100, timestamp: 1.23, model: model, inputs: inputs)
        #expect(abs(coordinator.contentOffset - 100) < 0.0001)

        panChanged(coordinator, width: 96, timestamp: 1.24, model: model, inputs: inputs)
        #expect(abs(coordinator.contentOffset - 96) < 0.0001)

        panChanged(coordinator, width: 112, timestamp: 1.25, model: model, inputs: inputs)
        #expect(coordinator.contentOffset > 100)
        #expect(coordinator.contentOffset < 112)
    }

    @Test("direct-touch open-only manual handoff stops debt shaping once open is reached")
    func directTouchOpenOnlyManualHandoffStopsDebtShapingOnceOpenIsReached() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 64,
                normalOpenThreshold: 64
            ),
            motion: SwipeCellConfiguration.iOSDefault.motion
        )
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        panChanged(
            coordinator,
            width: 45.714285714,
            predictedWidth: 160,
            velocityX: 700,
            timestamp: 1.01,
            model: model,
            inputs: inputs
        )
        panChanged(
            coordinator,
            width: 135.5,
            predictedWidth: 220,
            velocityX: 700,
            timestamp: 1.02,
            model: model,
            inputs: inputs
        )
        panChanged(
            coordinator,
            width: 135.5,
            predictedWidth: 220,
            velocityX: 700,
            timestamp: 1.03,
            model: model,
            inputs: inputs
        )

        var handoffWidth: CGFloat = 135.5
        for (index, width) in [160.5, 185.5, 210.5, 235.5, 260.5, 285.5, 310.5, 335.5, 360.5]
            .enumerated()
        {
            panChanged(
                coordinator,
                width: width,
                predictedWidth: width + 60,
                velocityX: 700,
                timestamp: 1.04 + TimeInterval(index) * 0.01,
                model: model,
                inputs: inputs
            )
            handoffWidth = width
            if coordinator.contentOffset >= 64 {
                break
            }
        }

        let handoffOffset = coordinator.contentOffset
        #expect(handoffOffset >= 64)

        panChanged(
            coordinator,
            width: handoffWidth,
            predictedWidth: handoffWidth + 60,
            timestamp: 1.20,
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset - handoffOffset) < 0.0001)
    }

    @Test("direct-touch open-only over-open release settles to normal open")
    func directTouchOpenOnlyOverOpenReleaseSettlesToNormalOpen() async {
        let (manager, coordinator, model, inputs) = openOnlyLargeStepRampAtOpen()

        panChanged(coordinator, width: 112, timestamp: 1.23, model: model, inputs: inputs)
        #expect(coordinator.contentOffset > 100)

        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: 112, height: 0),
                predictedEndTranslation: CGSize(width: 112, height: 0),
                velocity: .zero,
                timestamp: 1.24
            ),
            model: model,
            inputs: inputs
        )
        await drainMainQueue()

        #expect(abs(coordinator.contentOffset - 100) < 0.0001)
        #expect(manager.phase == .open(.leading))
    }

    @Test("direct-touch destructive manual fallback recovers suppressed preflight before activation")
    func directTouchDestructiveManualFallbackRecoversSuppressedPreflightBeforeActivation() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchDestructiveModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 6, height: 0),
                predictedEndTranslation: CGSize(width: 180, height: 0),
                velocity: CGPoint(x: 700, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        #expect(coordinator.contentOffset > 0)
        #expect(coordinator.contentOffset < 6)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 65, height: 0),
                predictedEndTranslation: CGSize(width: 240, height: 0),
                velocity: CGPoint(x: 750, y: 0),
                timestamp: 1.05
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 22.75) < 0.0001)
        #expect(coordinator.isArmed == false)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 150, height: 0),
                predictedEndTranslation: CGSize(width: 150, height: 0),
                velocity: .zero,
                timestamp: 1.12
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 150) < 0.0001)
        #expect(coordinator.deformationProgress == 1)
        #expect(coordinator.isArmed == true)
    }

    @Test("direct-touch medium prediction drag exits preflight without auto open")
    func directTouchMediumPredictionDragExitsPreflightWithoutAutoOpen() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -4, height: 0),
                predictedEndTranslation: CGSize(width: -60, height: 0),
                velocity: CGPoint(x: -420, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        #expect(coordinator.contentOffset < 0)
        #expect(abs(coordinator.contentOffset) < 4)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -18, height: 0),
                predictedEndTranslation: CGSize(width: -90, height: 0),
                velocity: CGPoint(x: -500, y: 0),
                timestamp: 1.05
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 6.3) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.063) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -28, height: 0),
                predictedEndTranslation: CGSize(width: -95, height: 0),
                velocity: CGPoint(x: -520, y: 0),
                timestamp: 1.06
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 6.3) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.063) < 0.0001)
    }

    @Test("direct-touch open-origin drag bypasses closed-origin fast preflight")
    func directTouchOpenOriginDragBypassesClosedOriginFastPreflight() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        manager.beginInteraction(for: "A", side: .trailing)
        manager.open(.trailing, for: "A")
        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 20, height: 0),
                predictedEndTranslation: CGSize(width: 100, height: 0),
                velocity: CGPoint(x: 800, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == -80)
        #expect(abs(coordinator.normalOpenProgress - 0.8) < 0.0001)
    }

    @Test("direct-touch fast close defers manager reset until visible settle")
    func directTouchFastCloseDefersManagerResetUntilVisibleSettle() async {
        // Case: IOS-CLOSE-FAST
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(
            for: "A",
            manager: manager,
            configuration: instantDirectTouchConfiguration(),
            settlingAnimation: .linear(duration: 0)
        )

        manager.beginInteraction(for: "A", side: .trailing)
        manager.open(.trailing, for: "A")

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 122, height: 0),
                predictedEndTranslation: CGSize(width: 950, height: 0),
                velocity: CGPoint(x: 3_400, y: 0),
                timestamp: 1.08
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 15) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.15) < 0.0001)

        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: 122, height: 0),
                predictedEndTranslation: CGSize(width: 950, height: 0),
                velocity: CGPoint(x: 3_400, y: 0),
                timestamp: 1.09
            ),
            model: model,
            inputs: inputs
        )

        #expect(manager.phase == .open(.trailing))
        #expect(manager.resettingCellID == nil)
        #expect(abs(coordinator.contentOffset + 15) < 0.0001)

        await drainMainQueue()

        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .closed)
        #expect(manager.activeCellID == nil)
        #expect(manager.resettingCellID == nil)
    }

    @Test("direct-touch stale owner release collapses local UI without retargeting current owner")
    func directTouchStaleOwnerReleaseCollapsesLocalUIWithoutRetargetingCurrentOwner() async {
        // Case: STALE-IOS-RELEASE
        let manager = SwipeCellManager()
        let oldOwner = SwipeCellInteractionCoordinator()
        let newOwner = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let oldInputs = inputs(
            for: "A",
            manager: manager,
            configuration: instantDirectTouchConfiguration(),
            settlingAnimation: .linear(duration: 0)
        )
        let newInputs = inputs(
            for: "B",
            manager: manager,
            configuration: instantDirectTouchConfiguration(),
            settlingAnimation: .linear(duration: 0)
        )

        oldOwner.panBegan(oldInputs, model: model, timestamp: 1)
        oldOwner.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 1.1
            ),
            model: model,
            inputs: oldInputs
        )

        newOwner.panBegan(newInputs, model: model, timestamp: 2)
        newOwner.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 80, height: 0),
                predictedEndTranslation: CGSize(width: 80, height: 0),
                timestamp: 2.1
            ),
            model: model,
            inputs: newInputs
        )

        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(oldOwner.contentOffset == -80)

        oldOwner.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 2.2
            ),
            model: model,
            inputs: oldInputs
        )

        await drainMainQueue()

        #expect(oldOwner.contentOffset == 0)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.phase == .revealing)
        #expect(manager.resettingCellID == AnyHashable("A"))

        if let token = oldOwner.pendingCloseToken {
            oldOwner.completePinnedClose(token: token)
        }
        #expect(manager.resettingCellID == nil)
    }

    @Test("indirect-scroll stale owner release stays inert until reset token close")
    func indirectScrollStaleOwnerReleaseStaysInertUntilResetTokenClose() {
        // Case: STALE-MAC-RELEASE
        let manager = SwipeCellManager()
        let oldOwner = SwipeCellInteractionCoordinator()
        let newOwner = SwipeCellInteractionCoordinator()
        let model = indirectScrollSymmetricModel()
        let oldInputs = inputs(for: "A", manager: manager, configuration: .macOSDefault)
        let newInputs = inputs(for: "B", manager: manager, configuration: .macOSDefault)

        oldOwner.panBegan(oldInputs, model: model, timestamp: 1)
        oldOwner.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 1.1
            ),
            model: model,
            inputs: oldInputs
        )

        newOwner.panBegan(newInputs, model: model, timestamp: 2)
        newOwner.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 80, height: 0),
                predictedEndTranslation: CGSize(width: 80, height: 0),
                timestamp: 2.1
            ),
            model: model,
            inputs: newInputs
        )

        oldOwner.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 2.2
            ),
            model: model,
            inputs: oldInputs
        )

        #expect(oldOwner.contentOffset == -80)
        #expect(oldOwner.pendingCloseDriver == nil)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.phase == .revealing)
        #expect(manager.resettingCellID == AnyHashable("A"))
    }

    @Test("direct-touch committed fast open cancels on clear reversal")
    func directTouchCommittedFastOpenCancelsOnClearReversal() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -10, height: 0),
                predictedEndTranslation: CGSize(width: -90, height: 0),
                velocity: CGPoint(x: -900, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -110, height: 0),
                velocity: CGPoint(x: -950, y: 0),
                timestamp: 1.02
            ),
            model: model,
            inputs: inputs
        )

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -24, height: 0),
                predictedEndTranslation: CGSize(width: -120, height: 0),
                velocity: CGPoint(x: -980, y: 0),
                timestamp: 1.03
            ),
            model: model,
            inputs: inputs
        )

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 2, height: 0),
                predictedEndTranslation: CGSize(width: 2, height: 0),
                velocity: CGPoint(x: 600, y: 0),
                timestamp: 1.04
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.normalOpenProgress == 0)

        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: 2, height: 0),
                predictedEndTranslation: CGSize(width: 2, height: 0),
                velocity: CGPoint(x: 600, y: 0),
                timestamp: 1.05
            ),
            model: model,
            inputs: inputs
        )
        await drainMainQueue()

        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .closed)
    }

    @Test("direct-touch committed fast open does not fall back before open extent")
    func directTouchCommittedFastOpenDoesNotFallBackBeforeOpenExtent() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchSymmetricModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -120, height: 0),
                velocity: CGPoint(x: -900, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -120, height: 0),
                velocity: CGPoint(x: -950, y: 0),
                timestamp: 1.02
            ),
            model: model,
            inputs: inputs
        )

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -45, height: 0),
                predictedEndTranslation: CGSize(width: -130, height: 0),
                velocity: CGPoint(x: -980, y: 0),
                timestamp: 1.03
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                velocity: .zero,
                timestamp: 1.15
            ),
            model: model,
            inputs: inputs
        )
        #expect(abs(coordinator.contentOffset + 100) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -30, height: 0),
                predictedEndTranslation: CGSize(width: -30, height: 0),
                velocity: .zero,
                timestamp: 1.17
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(coordinator.normalOpenProgress == 1)
    }

    @Test("direct-touch committed fast open ignores raw overdrag before continuation handoff")
    func directTouchCommittedFastOpenIgnoresRawOverdragBeforeContinuationHandoff() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchDestructiveModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -120, height: 0),
                velocity: CGPoint(x: -900, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        #expect(coordinator.contentOffset < 0)
        #expect(abs(coordinator.contentOffset) < 20)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -120, height: 0),
                velocity: CGPoint(x: -950, y: 0),
                timestamp: 1.02
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset < 0)
        #expect(abs(coordinator.contentOffset) < 40)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -45, height: 0),
                predictedEndTranslation: CGSize(width: -130, height: 0),
                velocity: CGPoint(x: -980, y: 0),
                timestamp: 1.03
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -130, height: 0),
                predictedEndTranslation: CGSize(width: -130, height: 0),
                velocity: .zero,
                timestamp: 1.10
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(coordinator.normalOpenProgress == 1)
        #expect(coordinator.deformationProgress == 0)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -142, height: 0),
                predictedEndTranslation: CGSize(width: -142, height: 0),
                velocity: .zero,
                timestamp: 1.12
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(coordinator.normalOpenProgress == 1)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -190, height: 0),
                predictedEndTranslation: CGSize(width: -190, height: 0),
                velocity: .zero,
                timestamp: 1.13
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)

        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: -190, height: 0),
                predictedEndTranslation: CGSize(width: -500, height: 0),
                velocity: CGPoint(x: -2_000, y: 0),
                timestamp: 1.13
            ),
            model: model,
            inputs: inputs
        )
        await drainMainQueue()

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(manager.phase == .open(.trailing))
    }

    @Test("direct-touch committed fast open hands off sustained outward continuation")
    func directTouchCommittedFastOpenHandsOffSustainedOutwardContinuation() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchDestructiveModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -120, height: 0),
                velocity: CGPoint(x: -900, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -120, height: 0),
                velocity: CGPoint(x: -950, y: 0),
                timestamp: 1.02
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -45, height: 0),
                predictedEndTranslation: CGSize(width: -130, height: 0),
                velocity: CGPoint(x: -980, y: 0),
                timestamp: 1.03
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -130, height: 0),
                predictedEndTranslation: CGSize(width: -130, height: 0),
                velocity: .zero,
                timestamp: 1.16
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 100) < 0.0001)
        #expect(coordinator.deformationProgress == 0)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -150, height: 0),
                predictedEndTranslation: CGSize(width: -150, height: 0),
                velocity: .zero,
                timestamp: 1.18
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset) > 100)
        #expect(abs(coordinator.contentOffset + 150) < 0.0001)
        #expect(coordinator.deformationProgress > 0)
        #expect(coordinator.isArmed == true)
    }

    @Test("direct-touch provisional fast sustained drag recovers debt before destructive activation")
    func directTouchProvisionalFastSustainedDragRecoversDebtBeforeDestructiveActivation() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = directTouchDestructiveModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -6, height: 0),
                predictedEndTranslation: CGSize(width: -140, height: 0),
                velocity: CGPoint(x: -900, y: 0),
                timestamp: 1.01
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -45, height: 0),
                predictedEndTranslation: CGSize(width: -190, height: 0),
                velocity: CGPoint(x: -950, y: 0),
                timestamp: 1.02
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset < 0)
        #expect(abs(coordinator.contentOffset) < 45)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -130, height: 0),
                predictedEndTranslation: CGSize(width: -210, height: 0),
                velocity: CGPoint(x: -600, y: 0),
                timestamp: 1.05
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset) < 130)
        #expect(coordinator.isArmed == false)

        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -150, height: 0),
                predictedEndTranslation: CGSize(width: -150, height: 0),
                velocity: .zero,
                timestamp: 1.07
            ),
            model: model,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 150) < 0.0001)
        #expect(coordinator.deformationProgress == 1)
        #expect(coordinator.isArmed == true)
    }

    @Test("disabled-side foreign pan does not replace or reset a held owner")
    func disabledSideForeignPanPreservesHeldOwner() {
        let manager = SwipeCellManager()
        // A is the active trailing owner (the held/open row in the repro).
        manager.beginInteraction(for: "A", side: .trailing)
        manager.open(.trailing, for: "A")
        #expect(manager.resetGeneration == 0)

        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let foreignInputs = inputs(for: "B", manager: manager)

        coordinator.panBegan(foreignInputs, model: model)
        // Leading direction (positive width) toward B's disabled side: an invalid reveal attempt.
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 40, height: 0),
                predictedEndTranslation: CGSize(width: 40, height: 0)
            ),
            model: model,
            inputs: foreignInputs
        )

        // A stays the visible owner; B never became active and no reset was published.
        #expect(manager.activeCellID == AnyHashable("A"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .open(.trailing))
        #expect(manager.resetGeneration == 0)
        #expect(manager.resettingCellID == nil)
        // The blocked attempt leaves no local offset or arm state on B.
        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("enabled-side foreign pan claims ownership and animates the previous owner closed")
    func enabledSideForeignPanReplacesOwnerWithAnimatedReset() {
        // Case: RESET-FOREIGN-OWNER
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .trailing)
        manager.open(.trailing, for: "A")

        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let foreignInputs = inputs(for: "B", manager: manager)

        coordinator.panBegan(foreignInputs, model: model)
        // Trailing direction (negative width) toward B's enabled side: a valid reveal that replaces A.
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0)
            ),
            model: model,
            inputs: foreignInputs
        )

        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .revealing)
        #expect(manager.resetGeneration == 1)
        #expect(manager.lastResetReason == .replacedByAnotherCell)
        #expect(manager.resettingCellID == AnyHashable("A"))
        // A still closes through the existing animated visible-reset path.
        #expect(manager.resetRequest(for: 1)?.animated == true)
    }

    @Test("same-row open-origin reverse close keeps ownership without a reset")
    func sameRowReverseCloseKeepsOwnership() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .trailing)
        manager.open(.trailing, for: "A")

        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let ownerInputs = inputs(for: "A", manager: manager)

        // Owner-origin gesture seeds the visible trailing side.
        coordinator.panBegan(ownerInputs, model: model)
        // Reverse toward center (positive width) from a trailing-open row: still an enabled-side
        // interaction on the visible owner side, so it keeps engaging without flipping to the empty side.
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 20, height: 0),
                predictedEndTranslation: CGSize(width: 20, height: 0)
            ),
            model: model,
            inputs: ownerInputs
        )

        #expect(manager.activeCellID == AnyHashable("A"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .revealing)
        #expect(manager.resetGeneration == 0)
        #expect(manager.resettingCellID == nil)
    }

    #if DEBUG
        @Test("validation host lifecycle flags visible coordinator disappearance")
        func validationHostLifecycleFlagsVisibleCoordinatorDisappearance() {
            let manager = SwipeCellManager()
            let coordinator = SwipeCellInteractionCoordinator()
            let model = trailingOnlyModel()
            let inputs = inputs(for: "A", manager: manager)

            coordinator.panBegan(inputs, model: model)
            coordinator.panChanged(
                SwipeCellPanValue(
                    translation: CGSize(width: -40, height: 0),
                    predictedEndTranslation: CGSize(width: -40, height: 0)
                ),
                model: model,
                inputs: inputs
            )

            let verdict = SwipeCellValidationDiagnostics.hostLifecycleVerdict(
                event: "host.disappear",
                contentOffset: coordinator.contentOffset,
                visibleSide: coordinator.currentVisibleSide(inputs)
            )

            #expect(coordinator.contentOffset == -40)
            #expect(verdict == .suspect("coordinator-recreated-while-visible"))
        }
    #endif

    @Test("animated forced reset pins close token until view completion")
    func animatedForcedResetPinsCloseTokenUntilViewCompletion() async {
        // Case: RESET-DUPLICATE-CLOSE
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                timestamp: 1.31
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.closeToken == 0)
        #expect(coordinator.contentOffset == -40)
        #expect(manager.close("A", reason: .tapContent))
        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)
        await drainMainQueue()

        #expect(coordinator.closeToken == 1)
        #expect(coordinator.lastForcedResetCloseDriver == .pinnedValueToken)
        #expect(coordinator.pendingCloseDriver == .pinnedValueToken)
        #expect(coordinator.pendingCloseToken == 1)
        #expect(coordinator.pendingMacOSResetTokenCloseEpoch == nil)
        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.settlingSide == .trailing)
        #expect(manager.resettingCellID == AnyHashable("A"))

        coordinator.completePinnedClose(token: 0)
        #expect(coordinator.pendingCloseToken == 1)
        #expect(coordinator.settlingSide == .trailing)
        #expect(manager.resettingCellID == AnyHashable("A"))

        coordinator.completePinnedClose(token: 1)
        #expect(coordinator.pendingCloseToken == nil)
        #expect(coordinator.pendingCloseDriver == nil)
        #expect(coordinator.settlingSide == nil)
        #expect(manager.resettingCellID == nil)

        coordinator.completePinnedClose(token: 1)
        #expect(coordinator.closeToken == 1)
        #expect(manager.resettingCellID == nil)
    }

    @Test("indirect-scroll reset-token forced reset uses macOS close driver")
    func indirectScrollResetTokenForcedResetUsesMacOSCloseDriver() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let inputs = inputs(
            for: "A",
            manager: manager,
            configuration: .macOSDefault,
            settlingAnimation: .linear(duration: 10)
        )

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                timestamp: 1.31
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.closeToken == 0)
        #expect(coordinator.contentOffset == -40)
        #expect(manager.close("A", reason: .tapContent))
        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)
        await drainMainQueue()

        #expect(coordinator.closeToken == 0)
        #expect(coordinator.lastForcedResetCloseDriver == .macOSResetTokenClose)
        #if DEBUG
            #expect(coordinator.lastMacOSResetTokenCloseTerminalState == "visible-complete")
            #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
        #endif
        #expect(coordinator.pendingCloseToken == nil)
        #expect(coordinator.pendingCloseDriver == nil)
        #expect(coordinator.pendingMacOSResetTokenCloseEpoch == nil)
        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.settlingSide == nil)
        #expect(manager.resettingCellID == nil)

        coordinator.completePinnedClose(token: 1)
        #if DEBUG
            #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
        #endif
        #expect(manager.resettingCellID == nil)

        coordinator.hostDisappeared(inputs)
        #expect(coordinator.pendingCloseDriver == nil)
        #expect(coordinator.pendingMacOSResetTokenCloseEpoch == nil)
        #expect(coordinator.settlingSide == nil)
        #if DEBUG
            #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
        #endif
        #expect(manager.resettingCellID == nil)

        coordinator.hostDisappeared(inputs)
        #expect(manager.resettingCellID == nil)
    }

    @Test("indirect-scroll content tap close claims macOS close driver before manager reset")
    func indirectScrollContentTapCloseClaimsMacOSCloseDriverBeforeManagerReset() async {
        // Case: RESET-CONTENT-TAP
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        coordinator.pausesMacOSResetTokenCloseCompletionForTesting = true
        let model = trailingOnlyModel()
        let inputs = inputs(
            for: "A",
            manager: manager,
            configuration: .macOSDefault,
            settlingAnimation: .linear(duration: 10)
        )

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                timestamp: 1.31
            ),
            model: model,
            inputs: inputs
        )
        #expect(manager.open(.trailing, for: "A"))

        let resolution = SwipeCellContentTapGate.close(for: "A", manager: manager) {
            coordinator.beginContentTapClose(inputs)
        }
        await drainMainQueue()

        #expect(resolution == .closedOwner)
        #expect(coordinator.closeToken == 0)
        #expect(coordinator.lastForcedResetCloseDriver == .macOSContentTapClose)
        #expect(coordinator.pendingCloseDriver == .macOSContentTapClose)
        #expect(coordinator.pendingMacOSResetTokenCloseEpoch == 1)
        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.settlingSide == .trailing)
        #expect(manager.phase == .resetting(.tapContent))
        #expect(manager.resettingCellID == AnyHashable("A"))

        coordinator.hostDisappeared(inputs)
        #if DEBUG
            #expect(coordinator.lastMacOSResetTokenCloseTerminalState == "detached-cleanup")
            #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
        #endif
        #expect(coordinator.pendingCloseDriver == nil)
        #expect(manager.resettingCellID == nil)
    }

    @Test("macOS close detach terminal cleans up exactly once")
    func macOSCloseDetachTerminalCleansUpExactlyOnce() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        coordinator.pausesMacOSResetTokenCloseCompletionForTesting = true
        let model = trailingOnlyModel()
        let inputs = inputs(
            for: "A",
            manager: manager,
            configuration: .macOSDefault,
            settlingAnimation: .linear(duration: 10)
        )

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                timestamp: 1.31
            ),
            model: model,
            inputs: inputs
        )
        #expect(manager.close("A", reason: .tapContent))
        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)
        await drainMainQueue()

        #expect(coordinator.pendingCloseDriver == .macOSResetTokenClose)
        #expect(coordinator.pendingMacOSResetTokenCloseEpoch == 1)
        #expect(coordinator.settlingSide == .trailing)
        #expect(manager.resettingCellID == AnyHashable("A"))

        coordinator.hostDisappeared(inputs)

        #if DEBUG
            #expect(coordinator.lastMacOSResetTokenCloseTerminalState == "detached-cleanup")
            #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
        #endif
        #expect(coordinator.pendingCloseDriver == nil)
        #expect(coordinator.pendingMacOSResetTokenCloseEpoch == nil)
        #expect(coordinator.settlingSide == nil)
        #expect(manager.resettingCellID == nil)

        coordinator.hostDisappeared(inputs)
        #if DEBUG
            #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
        #endif
    }

    @Test("macOS close ignores local takeover until visible completion")
    func macOSCloseIgnoresLocalTakeoverUntilVisibleCompletion() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        coordinator.pausesMacOSResetTokenCloseCompletionForTesting = true
        let model = trailingOnlyModel()
        let inputs = inputs(
            for: "A",
            manager: manager,
            configuration: .macOSDefault,
            settlingAnimation: .linear(duration: 10)
        )

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                timestamp: 1.31
            ),
            model: model,
            inputs: inputs
        )
        #expect(manager.close("A", reason: .tapContent))
        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)
        await drainMainQueue()

        #expect(coordinator.pendingCloseDriver == .macOSResetTokenClose)
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(coordinator.isAutomaticInputSuppressed)

        coordinator.panBegan(inputs, model: model, timestamp: 2)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -20, height: 0),
                timestamp: 2.1
            ),
            model: model,
            inputs: inputs
        )

        #if DEBUG
            #expect(coordinator.lastMacOSResetTokenCloseTerminalState == nil)
            #expect(coordinator.macOSResetTokenCloseTerminalCount == 0)
        #endif
        #expect(coordinator.pendingCloseDriver == .macOSResetTokenClose)
        #expect(coordinator.pendingMacOSResetTokenCloseEpoch == 1)
        #expect(coordinator.contentOffset == 0)
        #expect(manager.activeCellID == nil)
        #expect(manager.resettingCellID == AnyHashable("A"))

        coordinator.hostDisappeared(inputs)
        #if DEBUG
            #expect(coordinator.lastMacOSResetTokenCloseTerminalState == "detached-cleanup")
            #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
        #endif
        #expect(coordinator.pendingCloseDriver == nil)
        #expect(coordinator.pendingMacOSResetTokenCloseEpoch == nil)
        #expect(manager.resettingCellID == nil)
        #expect(coordinator.isAutomaticInputSuppressed == false)
    }

    @Test("active drag is ignored while pending pinned close owns the animation")
    func activeDragIsIgnoredWhilePendingPinnedCloseOwnsAnimation() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                timestamp: 1.31
            ),
            model: model,
            inputs: inputs
        )
        #expect(manager.close("A", reason: .tapContent))
        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)
        await drainMainQueue()
        #expect(coordinator.pendingCloseToken == 1)
        #expect(coordinator.isAutomaticInputSuppressed)

        coordinator.panBegan(inputs, model: model, timestamp: 2)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -20, height: 0),
                timestamp: 2.31
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.closeToken == 1)
        #expect(coordinator.pendingCloseToken == 1)
        #expect(coordinator.contentOffset == 0)
        #expect(manager.activeCellID == nil)
        #expect(manager.resettingCellID == AnyHashable("A"))

        coordinator.completePinnedClose(token: 1)
        #expect(manager.activeCellID == nil)
        #expect(manager.resettingCellID == nil)
        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.isAutomaticInputSuppressed == false)
    }

    @Test("release settle does not change pinned close token")
    func releaseSettleDoesNotChangePinnedCloseToken() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                timestamp: 1.31
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: -40, height: 0),
                predictedEndTranslation: CGSize(width: -40, height: 0),
                timestamp: 1.32
            ),
            model: model,
            inputs: inputs
        )
        await drainMainQueue()

        #expect(coordinator.closeToken == 0)
        #expect(coordinator.pendingCloseToken == nil)
    }

    @Test("release settle ignores follow-up pan until visible target is applied")
    func releaseSettleIgnoresFollowUpPanUntilVisibleTargetIsApplied() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 1.2
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 1.3
            ),
            model: model,
            inputs: inputs
        )

        #expect(manager.phase == .revealing)
        #expect(coordinator.isAutomaticInputSuppressed)

        coordinator.panBegan(inputs, model: model, timestamp: 2)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -20, height: 0),
                timestamp: 2.1
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == -80)
        #expect(manager.phase == .revealing)

        await drainMainQueue()

        #expect(coordinator.contentOffset == -80)
        #expect(manager.phase == .open(.trailing))
        #expect(coordinator.isAutomaticInputSuppressed == false)
    }

    @Test("release settle suppresses current row only")
    func releaseSettleSuppressesCurrentRowOnly() async {
        let manager = SwipeCellManager()
        let currentCoordinator = SwipeCellInteractionCoordinator()
        let foreignCoordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let currentInputs = inputs(for: "A", manager: manager)
        let foreignInputs = inputs(for: "B", manager: manager)

        currentCoordinator.panBegan(currentInputs, model: model, timestamp: 1)
        currentCoordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 1.2
            ),
            model: model,
            inputs: currentInputs
        )
        currentCoordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 1.3
            ),
            model: model,
            inputs: currentInputs
        )

        #expect(currentCoordinator.isAutomaticInputSuppressed)
        currentCoordinator.panBegan(currentInputs, model: model, timestamp: 2)
        currentCoordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -20, height: 0),
                timestamp: 2.1
            ),
            model: model,
            inputs: currentInputs
        )
        #expect(currentCoordinator.contentOffset == -80)

        foreignCoordinator.panBegan(foreignInputs, model: model, timestamp: 2.2)
        foreignCoordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -20, height: 0),
                predictedEndTranslation: CGSize(width: -20, height: 0),
                timestamp: 2.3
            ),
            model: model,
            inputs: foreignInputs
        )

        #expect(foreignCoordinator.contentOffset == -20)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .revealing)
        #expect(manager.resettingCellID == AnyHashable("A"))

        await drainMainQueue()

        #expect(currentCoordinator.isAutomaticInputSuppressed == false)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.phase == .revealing)
    }

    @Test("open then close restores manager state after visible settle")
    func openThenCloseRestoresManagerStateAfterVisibleSettle() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let model = trailingOnlyModel()
        let inputs = inputs(for: "A", manager: manager)

        coordinator.panBegan(inputs, model: model, timestamp: 1)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 1.2
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: -80, height: 0),
                predictedEndTranslation: CGSize(width: -80, height: 0),
                timestamp: 1.3
            ),
            model: model,
            inputs: inputs
        )
        await drainMainQueue()

        #expect(coordinator.contentOffset == -80)
        #expect(manager.phase == .open(.trailing))
        #expect(coordinator.isAutomaticInputSuppressed == false)

        coordinator.panBegan(inputs, model: model, timestamp: 2)
        coordinator.panChanged(
            SwipeCellPanValue(
                translation: CGSize(width: 80, height: 0),
                predictedEndTranslation: CGSize(width: 80, height: 0),
                timestamp: 2.2
            ),
            model: model,
            inputs: inputs
        )
        coordinator.panEnded(
            SwipeCellPanValue(
                translation: CGSize(width: 80, height: 0),
                predictedEndTranslation: CGSize(width: 80, height: 0),
                timestamp: 2.3
            ),
            model: model,
            inputs: inputs
        )

        #expect(coordinator.isAutomaticInputSuppressed)

        await drainMainQueue()

        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .closed)
        #expect(manager.activeCellID == nil)
        #expect(manager.resettingCellID == nil)
        #expect(coordinator.isAutomaticInputSuppressed == false)
    }

    private func instantDirectTouchConfiguration() -> SwipeCellConfiguration {
        var configuration = SwipeCellConfiguration.iOSDefault
        configuration.motion = SwipeCellConfiguration.Motion(settleMinDuration: 0, settleMaxDuration: 0)
        return configuration
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}
