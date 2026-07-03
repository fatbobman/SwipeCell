#if !os(macOS) && !os(watchOS)
    import SwiftUI
#endif

/// Scope-level policy for how SwipeCell responds to SwiftUI List edit mode.
nonisolated public enum SwipeCellEditModePolicy: Equatable, Sendable {
    case ignore
    case disableWhenEditing
}

nonisolated enum SwipeCellEditModeState: Equatable, Sendable {
    case inactive
    case transient
    case active

    #if !os(macOS) && !os(watchOS)
        init?(_ editMode: EditMode?) {
            guard let editMode else { return nil }

            switch editMode {
            case .active:
                self = .active
            case .transient:
                self = .transient
            case .inactive:
                self = .inactive
            @unknown default:
                return nil
            }
        }
    #endif
}

struct SwipeCellEditModeGate {
    static func isInteractionDisabled(
        policy: SwipeCellEditModePolicy,
        editModeState: SwipeCellEditModeState?
    ) -> Bool {
        guard case .disableWhenEditing = policy, let editModeState else {
            return false
        }

        switch editModeState {
        case .active, .transient:
            return true
        case .inactive:
            return false
        }
    }

    @discardableResult
    static func resetForDisabledInteractionIfNeeded(manager: SwipeCellManager) -> Bool {
        manager.reset(reason: .editMode)
    }
}
