import Foundation

struct SwipeCellEditModeResetGate {
    @discardableResult
    static func resetManagerIfNeeded(
        interactionsDisabled: Bool,
        inputs: SwipeCellInteractionInputs
    ) -> Bool {
        guard interactionsDisabled, let manager = inputs.manager else { return false }

        return SwipeCellEditModeGate.resetForDisabledInteractionIfNeeded(manager: manager)
    }
}
