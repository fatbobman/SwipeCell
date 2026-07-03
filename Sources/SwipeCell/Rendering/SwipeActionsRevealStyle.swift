import SwiftUI

nonisolated public enum SwipeActionsRevealStyle: Equatable, Sendable {
    case slot
    case token
}

private struct SwipeActionsRevealStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue: SwipeActionsRevealStyle = .slot
}

extension EnvironmentValues {
    var swipeActionsRevealStyle: SwipeActionsRevealStyle {
        get { self[SwipeActionsRevealStyleEnvironmentKey.self] }
        set { self[SwipeActionsRevealStyleEnvironmentKey.self] = newValue }
    }
}
