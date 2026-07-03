import CoreGraphics
import SwiftUI
import Testing

@_spi(ManualDebug) @testable import SwipeCell

@MainActor
@Suite("SwipeCell edit mode policy")
struct SwipeCellEditModePolicyTests {
    @Test("default policy ignores every edit mode state")
    func defaultPolicyIgnoresEveryEditModeState() {
        let states: [SwipeCellEditModeState?] = [nil, .inactive, .transient, .active]

        for state in states {
            #expect(
                SwipeCellEditModeGate.isInteractionDisabled(
                    policy: .ignore,
                    editModeState: state
                ) == false
            )
        }
    }

    @Test("disable policy treats active and transient as disabled")
    func disablePolicyTreatsActiveAndTransientAsDisabled() {
        #expect(
            SwipeCellEditModeGate.isInteractionDisabled(
                policy: .disableWhenEditing,
                editModeState: nil
            ) == false
        )
        #expect(
            SwipeCellEditModeGate.isInteractionDisabled(
                policy: .disableWhenEditing,
                editModeState: .inactive
            ) == false
        )
        #expect(
            SwipeCellEditModeGate.isInteractionDisabled(
                policy: .disableWhenEditing,
                editModeState: .transient
            ) == true
        )
        #expect(
            SwipeCellEditModeGate.isInteractionDisabled(
                policy: .disableWhenEditing,
                editModeState: .active
            ) == true
        )
    }

    @Test("disabled edit mode reset uses editMode reason only when an owner exists")
    func disabledEditModeResetRequiresOwner() {
        let manager = SwipeCellManager()

        #expect(SwipeCellEditModeGate.resetForDisabledInteractionIfNeeded(manager: manager) == false)
        #expect(manager.resetGeneration == 0)
        #expect(manager.phase == .closed)

        manager.beginInteraction(for: "row", side: .trailing)
        manager.open(.trailing, for: "row")

        #expect(SwipeCellEditModeGate.resetForDisabledInteractionIfNeeded(manager: manager) == true)
        #expect(manager.activeCellID == nil)
        #expect(manager.activeSide == nil)
        #expect(manager.resettingCellID == AnyHashable("row"))
        #expect(manager.phase == .resetting(.editMode))
        #expect(manager.resetGeneration == 1)
        #expect(manager.lastResetReason == .editMode)

        #expect(SwipeCellEditModeGate.resetForDisabledInteractionIfNeeded(manager: manager) == false)
        #expect(manager.resetGeneration == 1)
    }

    @Test("disabled interaction ignores pan callbacks")
    func disabledInteractionIgnoresPanCallbacks() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            isInteractionEnabled: false
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 200),
            model: destructiveModel,
            inputs: inputs
        )
        coordinator.panEnded(
            panValue(width: 200),
            model: destructiveModel,
            inputs: inputs
        )
        coordinator.panCancelled(inputs)

        #expect(manager.activeCellID == nil)
        #expect(manager.phase == .closed)
        #expect(manager.resetGeneration == 0)
        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.normalOpenProgress == 0)
        #expect(coordinator.isArmed == false)
        #expect(coordinator.hapticEvent == nil)
    }

    @Test("disabled interaction blocks action and content tap gates")
    func disabledInteractionBlocksTapGates() {
        let manager = SwipeCellManager()
        var contentClosePrepared = false

        manager.beginInteraction(for: "row", side: .leading)
        manager.open(.leading, for: "row")

        let actionResolution = SwipeCellActionTapGate.resolve(
            .leading,
            for: "row",
            manager: manager,
            isInteractionEnabled: false
        )

        let contentClose = SwipeCellContentTapGate.close(
            for: "row",
            manager: manager,
            isInteractionEnabled: false
        ) {
            contentClosePrepared = true
        }

        #expect(actionResolution == .ignored)
        #expect(contentClose == .ignored)
        #expect(contentClosePrepared == false)
        #expect(manager.activeCellID == AnyHashable("row"))
        #expect(manager.phase == .open(.leading))
    }

    @Test("edit mode reset clears manager without animating the old coordinator")
    func editModeResetClearsManagerWithoutAnimatingOldCoordinator() async {
        let manager = SwipeCellManager()
        let owner = SwipeCellInteractionCoordinator()
        let ownerInputs = SwipeCellInteractionInputs(
            cellID: "owner",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )

        owner.panBegan(ownerInputs)
        owner.panChanged(
            panValue(width: 100),
            model: destructiveModel,
            inputs: ownerInputs
        )
        owner.panEnded(
            panValue(width: 100),
            model: destructiveModel,
            inputs: ownerInputs
        )

        try? await Task.sleep(for: .milliseconds(50))

        #expect(manager.phase == .open(.leading))
        #expect(owner.contentOffset == 100)

        let foreignInputs = SwipeCellInteractionInputs(
            cellID: "foreign",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            isInteractionEnabled: false
        )
        let reset = SwipeCellEditModeResetGate.resetManagerIfNeeded(
            interactionsDisabled: true,
            inputs: foreignInputs
        )

        #expect(reset == true)
        #expect(manager.phase == .resetting(.editMode))
        #expect(manager.resettingCellID == AnyHashable("owner"))
        #expect(owner.contentOffset == 100)
        #expect(owner.normalOpenProgress == 1)
    }

    private var destructiveModel: SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: destructiveSide,
                trailing: destructiveSide
            )
        )
    }

    private var destructiveSide: SwipeCellInteractionSideConfiguration {
        SwipeCellInteractionSideConfiguration(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            allowsDestructive: true,
            destructiveThreshold: 150,
            destructiveSettlingExtent: 180
        )
    }

    private func panValue(width: CGFloat) -> SwipeCellPanValue {
        SwipeCellPanValue(
            translation: CGSize(width: width, height: 0),
            predictedEndTranslation: CGSize(width: width, height: 0),
            velocity: CGPoint(x: width, y: 0)
        )
    }
}
