import Foundation
import SwiftUI

private struct SwipeCellManagerEnvironmentKey: EnvironmentKey {
    static let defaultValue: SwipeCellManager? = nil
}

private struct SwipeCellEditModePolicyEnvironmentKey: EnvironmentKey {
    static let defaultValue = SwipeCellEditModePolicy.ignore
}

private struct SwipeCellActionTemplateEnvironmentKey: EnvironmentKey {
    static let defaultValue: SwipeCellActionTemplate? = nil
}

extension EnvironmentValues {
    public var swipeCellManager: SwipeCellManager? {
        get { self[SwipeCellManagerEnvironmentKey.self] }
        set { self[SwipeCellManagerEnvironmentKey.self] = newValue }
    }

    var swipeCellEditModePolicy: SwipeCellEditModePolicy {
        get { self[SwipeCellEditModePolicyEnvironmentKey.self] }
        set { self[SwipeCellEditModePolicyEnvironmentKey.self] = newValue }
    }

    var swipeCellActionTemplate: SwipeCellActionTemplate? {
        get { self[SwipeCellActionTemplateEnvironmentKey.self] }
        set { self[SwipeCellActionTemplateEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Establishes a SwipeCell scope that coordinates mutual-exclusion and scroll-driven reset for
    /// the rows inside `self`.
    /// - Parameter container: Host container event-delivery scenario. Currently this only affects macOS
    ///   indirect-scroll normalization; iOS direct touch treats all containers equivalently.
    /// - Parameter minimumScrollResetDelta: Minimum vertical scroll distance (points) that closes an
    ///   open row. This gates the scroll-to-close reset only; it does not affect how far a horizontal
    ///   swipe must travel to reveal actions.
    public func swipeCellScope(
        container: SwipeCellContainer = .list,
        actionTemplate: SwipeCellActionTemplate? = nil,
        editModePolicy: SwipeCellEditModePolicy = .ignore,
        minimumScrollResetDelta: CGFloat? = nil
    ) -> some View {
        modifier(
            OwnedSwipeCellScopeModifier(
                container: container,
                actionTemplate: actionTemplate,
                editModePolicy: editModePolicy,
                minimumScrollResetDelta: minimumScrollResetDelta
            )
        )
    }

    /// Establishes a SwipeCell scope backed by a caller-owned ``SwipeCellManager``.
    /// - Parameter container: Host container event-delivery scenario. Currently this only affects macOS
    ///   indirect-scroll normalization; iOS direct touch treats all containers equivalently.
    /// - Parameter minimumScrollResetDelta: Minimum vertical scroll distance (points) that closes an
    ///   open row; unrelated to the horizontal swipe-reveal threshold.
    public func swipeCellScope(
        manager: SwipeCellManager,
        container: SwipeCellContainer = .list,
        actionTemplate: SwipeCellActionTemplate? = nil,
        editModePolicy: SwipeCellEditModePolicy = .ignore,
        minimumScrollResetDelta: CGFloat? = nil
    ) -> some View {
        modifier(
            SwipeCellScopeModifier(
                manager: manager,
                container: container,
                actionTemplate: actionTemplate,
                editModePolicy: editModePolicy,
                minimumScrollResetDelta: minimumScrollResetDelta
            )
        )
    }

    public func swipeCellActionTemplate(_ template: SwipeCellActionTemplate) -> some View {
        modifier(SwipeCellActionTemplateModifier(actionTemplate: template))
    }

    @_spi(ManualDebug)
    public func swipeCellIdentity<CellID: Hashable>(
        _ cellID: CellID,
        openThreshold: CGFloat? = nil,
        settlingAnimation: Animation? = nil
    ) -> some View {
        modifier(
            SwipeCellIdentityModifier(
                cellID: AnyHashable(cellID),
                openThreshold: openThreshold,
                settlingAnimation: settlingAnimation
            )
        )
    }

    public func swipeCellActions<CellID: Hashable>(
        _ cellID: CellID
    ) -> some View {
        modifier(
            SwipeCellTemplateActionsModifier(
                cellID: cellID
            )
        )
    }

    public func swipeCellActions<CellID: Hashable>(
        _ cellID: CellID,
        leading: [SwipeAction] = [],
        trailing: [SwipeAction] = [],
        actionWidth: CGFloat? = nil,
        revealStyle: SwipeActionsRevealStyle? = nil,
        settlingAnimation: Animation? = nil
    ) -> some View {
        modifier(
            SwipeCellActionsModifier(
                cellID: AnyHashable(cellID),
                leadingActions: leading,
                trailingActions: trailing,
                actionWidth: actionWidth,
                revealStyle: revealStyle,
                settlingAnimation: settlingAnimation
            )
        )
    }
}
