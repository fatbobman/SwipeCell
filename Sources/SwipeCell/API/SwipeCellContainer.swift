import Foundation

/// Declares the host container event-delivery scenario for a SwipeCell scope.
///
/// The API exists on every supported platform, but currently only affects macOS indirect-scroll input.
/// iOS direct-touch handling treats all cases equivalently.
nonisolated public enum SwipeCellContainer: Equatable, Sendable {
    /// System `List` / AppKit `NSTableView` style event delivery.
    case list
    /// SwiftUI `ScrollView`-backed custom rows, including `LazyVStack` and `Grid`.
    case scrollView
}
