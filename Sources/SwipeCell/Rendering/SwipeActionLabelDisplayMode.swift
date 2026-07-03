import SwiftUI

nonisolated public enum SwipeActionLabelDisplayMode: Equatable, Sendable {
    case iconAndTitle
    case iconOnly
}

private struct SwipeActionLabelDisplayModeEnvironmentKey: EnvironmentKey {
    static let defaultValue: SwipeActionLabelDisplayMode = .iconAndTitle
}

extension EnvironmentValues {
    public var swipeActionLabelDisplayMode: SwipeActionLabelDisplayMode {
        get { self[SwipeActionLabelDisplayModeEnvironmentKey.self] }
        set { self[SwipeActionLabelDisplayModeEnvironmentKey.self] = newValue }
    }
}

extension View {
    public func swipeActionLabelDisplayMode(_ mode: SwipeActionLabelDisplayMode) -> some View {
        environment(\.swipeActionLabelDisplayMode, mode)
    }
}
