import CoreGraphics
import Foundation
import SwiftUI

/// Public role kind exposed through `SwipeActionContext`.
///
/// Configuration payloads stay on `SwipeActionRole`; labels receive only the semantic kind so
/// per-row interaction state does not leak layout or trigger policy.
nonisolated public enum SwipeActionRoleKind: Equatable, Sendable {
    case normal
    case destructive
}

/// When an action's work runs relative to the row collapsing.
nonisolated public enum SwipeActionFireTiming: Equatable, Sendable {
    /// Run as soon as the action is triggered (default).
    case immediate
    /// Collapse the row first, then run — keeps a delete/removal from fighting the close animation.
    case afterCollapse
    /// Run immediately, then keep the row in its triggering/open presentation until the caller closes it.
    case triggerAndHoldOpen
}

/// Destructive full-swipe activation for one action.
nonisolated public enum SwipeActionActivation: Equatable, Sendable {
    /// Resolve from the current side's `SwipeCellConfiguration.geometry.destructiveActivationDefaults`.
    case automatic
    /// Resolve to `offset / actionWidth == multiplier`.
    case actionWidthMultiplier(CGFloat)
    /// Resolve to `normalOpenExtent + distance`.
    case openExtentPlusDistance(CGFloat)
    /// Resolve to `normalOpenExtent + actionWidth * widths`.
    case openExtentPlusActionWidths(CGFloat)
    /// Resolve to `containerWidth * fraction`.
    case rowWidthFraction(CGFloat)

    var explicitGeometry: SwipeCellDestructiveActivationGeometry? {
        switch self {
        case .automatic:
            nil
        case .actionWidthMultiplier(let multiplier):
            .actionWidthMultiplier(multiplier)
        case .openExtentPlusDistance(let distance):
            .openExtentPlusDistance(distance)
        case .openExtentPlusActionWidths(let widths):
            .openExtentPlusActionWidths(widths)
        case .rowWidthFraction(let fraction):
            .rowWidthFraction(fraction)
        }
    }
}

/// Completion policy for a destructive full-swipe trigger.
nonisolated public enum SwipeActionCompletion: Equatable, Sendable {
    case directTrigger
    case triggerAfterReset
    case triggerHoldExpanded
}

/// Configuration carried by `.destructive`.
nonisolated public struct SwipeActionDestructive: Equatable, Sendable {
    public var activation: SwipeActionActivation
    public var completion: SwipeActionCompletion

    public init(
        activation: SwipeActionActivation = .automatic,
        completion: SwipeActionCompletion = .directTrigger
    ) {
        self.activation = activation
        self.completion = completion
    }
}

/// Whether an action is an ordinary tap target or the destructive full-swipe slot.
///
/// Only the outermost (index 0) action on a side may be `.destructive`; `SwipeActionGroup` demotes
/// any inner destructive declaration to `.normal(.immediate)`.
nonisolated public enum SwipeActionRole: Equatable, Sendable {
    case normal(SwipeActionFireTiming = .immediate)
    case destructive(SwipeActionDestructive = .init())

    public var kind: SwipeActionRoleKind {
        switch self {
        case .normal:
            .normal
        case .destructive:
            .destructive
        }
    }

    var isDestructive: Bool {
        kind == .destructive
    }

    var normalFireTiming: SwipeActionFireTiming {
        switch self {
        case .normal(let timing):
            timing
        case .destructive:
            .immediate
        }
    }
}

/// Imperative control handed to destructive actions that need to resolve asynchronously.
public final class SwipeActionTriggerController {
    public private(set) var isResolved = false

    private let collapseHandler: () -> Void
    private let holdExpandedHandler: () -> Void

    init(
        collapse: @escaping () -> Void,
        holdExpanded: @escaping () -> Void
    ) {
        self.collapseHandler = collapse
        self.holdExpandedHandler = holdExpanded
    }

    public func collapse() {
        guard !isResolved else { return }
        isResolved = true
        collapseHandler()
    }

    public func holdExpanded() {
        guard !isResolved else { return }
        isResolved = true
        holdExpandedHandler()
    }

    static func detached() -> SwipeActionTriggerController {
        SwipeActionTriggerController(collapse: {}, holdExpanded: {})
    }
}

/// A declarative description of one swipe action.
///
/// In a side's `[SwipeAction]`, index 0 is the outermost slot — against the screen edge, the
/// full-swipe slot — mirroring Apple's `swipeActions`. Equal-width siblings are a layout invariant,
/// so an action declares its content and behavior, not its geometry.
public struct SwipeAction: Identifiable, Equatable {
    /// Defaults to a fresh `UUID`; pass a domain id when rebuilt inline actions need to retain
    /// button identity across renders. A stable id does not freeze action or label closures.
    public var id: AnyHashable
    public var role: SwipeActionRole
    public var tint: SwipeActionTint
    public var title: LocalizedStringKey?
    public var systemImage: String?
    public var action: () -> Void {
        get { handler.perform }
        set { handler = SwipeActionHandler(newValue) }
    }

    var handler: SwipeActionHandler
    var controlledAction: ((SwipeActionTriggerController) -> Void)?
    var makeLabel: (SwipeActionContext) -> AnyView

    public var fireTiming: SwipeActionFireTiming {
        get { role.normalFireTiming }
        set {
            guard case .normal = role else { return }
            role = .normal(newValue)
        }
    }

    var buttonTapFireTiming: SwipeActionFireTiming {
        switch role {
        case .normal(let timing):
            return timing
        case .destructive(let destructive):
            // Button taps never enter the full-swipe controller path. Completion policies that need a
            // collapse boundary degrade to after-collapse instead of holding a direct-tap row open.
            return switch destructive.completion {
            case .directTrigger:
                .immediate
            case .triggerAfterReset, .triggerHoldExpanded:
                .afterCollapse
            }
        }
    }

    /// Structured convenience: the library renders the label from `title` / `systemImage`.
    public init(
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole = .normal(),
        tint: Color = .accentColor,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            id: UUID(),
            title,
            systemImage: systemImage,
            role: role,
            tint: SwipeActionTint(tint),
            fireTiming: fireTiming,
            action: action
        )
    }

    /// Structured convenience accepting any SwiftUI shape style as the action chrome tint.
    public init<Style: ShapeStyle>(
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole = .normal(),
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            id: UUID(),
            title,
            systemImage: systemImage,
            role: role,
            tint: SwipeActionTint(tint),
            fireTiming: fireTiming,
            action: action
        )
    }

    /// Structured convenience with caller-supplied action identity.
    public init<ID: Hashable>(
        id: ID,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole = .normal(),
        tint: Color = .accentColor,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(UUID()),
            action: action,
            controlledAction: nil
        ) { _ in
            AnyView(
                SwipeActionDefaultLabel(
                    title: title,
                    systemImage: systemImage
                )
            )
        }
    }

    /// Structured convenience with caller-supplied identity and arbitrary SwiftUI shape style.
    public init<ID: Hashable, Style: ShapeStyle>(
        id: ID,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole = .normal(),
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(UUID()),
            action: action,
            controlledAction: nil
        ) { _ in
            AnyView(
                SwipeActionDefaultLabel(
                    title: title,
                    systemImage: systemImage
                )
            )
        }
    }

    /// Structured convenience with stable action identity and a separate value passed to the handler.
    public init<ID: Hashable, Value: Hashable>(
        id: ID,
        value: Value,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole = .normal(),
        tint: Color = .accentColor,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (Value) -> Void
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(value),
            action: {
                action(value)
            },
            controlledAction: nil,
            makeLabel: { _ in
                AnyView(
                    SwipeActionDefaultLabel(
                        title: title,
                        systemImage: systemImage
                    )
                )
            }
        )
    }

    /// Structured convenience with stable action identity, handler value, and arbitrary SwiftUI shape style.
    public init<ID: Hashable, Value: Hashable, Style: ShapeStyle>(
        id: ID,
        value: Value,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole = .normal(),
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (Value) -> Void
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(value),
            action: {
                action(value)
            },
            controlledAction: nil,
            makeLabel: { _ in
                AnyView(
                    SwipeActionDefaultLabel(
                        title: title,
                        systemImage: systemImage
                    )
                )
            }
        )
    }

    /// Structured convenience for destructive actions that need the trigger controller.
    public init(
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole,
        tint: Color = .accentColor,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (SwipeActionTriggerController) -> Void
    ) {
        self.init(
            id: UUID(),
            title,
            systemImage: systemImage,
            role: role,
            tint: SwipeActionTint(tint),
            fireTiming: fireTiming,
            action: action
        )
    }

    /// Structured destructive convenience accepting any SwiftUI shape style as the action chrome tint.
    public init<Style: ShapeStyle>(
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole,
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (SwipeActionTriggerController) -> Void
    ) {
        self.init(
            id: UUID(),
            title,
            systemImage: systemImage,
            role: role,
            tint: SwipeActionTint(tint),
            fireTiming: fireTiming,
            action: action
        )
    }

    /// Structured convenience with caller-supplied identity and trigger-controller access.
    public init<ID: Hashable>(
        id: ID,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole,
        tint: Color = .accentColor,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (SwipeActionTriggerController) -> Void
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(UUID()),
            action: {
                action(.detached())
            },
            controlledAction: action,
            makeLabel: { _ in
                AnyView(
                    SwipeActionDefaultLabel(
                        title: title,
                        systemImage: systemImage
                    )
                )
            }
        )
    }

    /// Structured destructive convenience with caller-supplied identity and arbitrary SwiftUI shape style.
    public init<ID: Hashable, Style: ShapeStyle>(
        id: ID,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole,
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (SwipeActionTriggerController) -> Void
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(UUID()),
            action: {
                action(.detached())
            },
            controlledAction: action,
            makeLabel: { _ in
                AnyView(
                    SwipeActionDefaultLabel(
                        title: title,
                        systemImage: systemImage
                    )
                )
            }
        )
    }

    /// Structured trigger-controller convenience with stable action identity and handler value.
    public init<ID: Hashable, Value: Hashable>(
        id: ID,
        value: Value,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole,
        tint: Color = .accentColor,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (Value, SwipeActionTriggerController) -> Void
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(value),
            action: {
                action(value, .detached())
            },
            controlledAction: { controller in
                action(value, controller)
            },
            makeLabel: { _ in
                AnyView(
                    SwipeActionDefaultLabel(
                        title: title,
                        systemImage: systemImage
                    )
                )
            }
        )
    }

    /// Structured trigger-controller convenience with stable action identity, handler value, and shape style.
    public init<ID: Hashable, Value: Hashable, Style: ShapeStyle>(
        id: ID,
        value: Value,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole,
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (Value, SwipeActionTriggerController) -> Void
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(value),
            action: {
                action(value, .detached())
            },
            controlledAction: { controller in
                action(value, controller)
            },
            makeLabel: { _ in
                AnyView(
                    SwipeActionDefaultLabel(
                        title: title,
                        systemImage: systemImage
                    )
                )
            }
        )
    }

    /// Custom-label convenience for actions that need the published per-button context.
    public init<Label: View>(
        role: SwipeActionRole = .normal(),
        tint: Color = .clear,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping (SwipeActionContext) -> Label
    ) {
        self.init(
            id: UUID(),
            role: role,
            tint: SwipeActionTint(tint),
            fireTiming: fireTiming,
            action: action,
            label: label
        )
    }

    /// Custom-label convenience accepting any SwiftUI shape style as the action chrome tint.
    public init<Style: ShapeStyle, Label: View>(
        role: SwipeActionRole = .normal(),
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping (SwipeActionContext) -> Label
    ) {
        self.init(
            id: UUID(),
            role: role,
            tint: tint,
            fireTiming: fireTiming,
            action: action,
            label: label
        )
    }

    /// Custom-label convenience with caller-supplied identity.
    public init<ID: Hashable, Label: View>(
        id: ID,
        role: SwipeActionRole = .normal(),
        tint: Color = .clear,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping (SwipeActionContext) -> Label
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: nil,
            systemImage: nil,
            handlerKey: AnyHashable(UUID()),
            action: action,
            controlledAction: nil
        ) { context in
            AnyView(label(context))
        }
    }

    /// Custom-label convenience with caller-supplied identity and arbitrary SwiftUI shape style.
    public init<ID: Hashable, Style: ShapeStyle, Label: View>(
        id: ID,
        role: SwipeActionRole = .normal(),
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping (SwipeActionContext) -> Label
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: nil,
            systemImage: nil,
            handlerKey: AnyHashable(UUID()),
            action: action,
            controlledAction: nil
        ) { context in
            AnyView(label(context))
        }
    }

    /// Custom-label convenience with trigger-controller access for custom destructive labels.
    public init<Label: View>(
        role: SwipeActionRole,
        tint: Color = .clear,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (SwipeActionTriggerController) -> Void,
        @ViewBuilder label: @escaping (SwipeActionContext) -> Label
    ) {
        self.init(
            id: UUID(),
            role: role,
            tint: SwipeActionTint(tint),
            fireTiming: fireTiming,
            action: action,
            label: label
        )
    }

    /// Custom-label convenience with trigger-controller access and arbitrary SwiftUI shape style.
    public init<Style: ShapeStyle, Label: View>(
        role: SwipeActionRole,
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (SwipeActionTriggerController) -> Void,
        @ViewBuilder label: @escaping (SwipeActionContext) -> Label
    ) {
        self.init(
            id: UUID(),
            role: role,
            tint: tint,
            fireTiming: fireTiming,
            action: action,
            label: label
        )
    }

    /// Custom-label convenience with caller-supplied identity and trigger-controller access.
    public init<ID: Hashable, Label: View>(
        id: ID,
        role: SwipeActionRole,
        tint: Color = .clear,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (SwipeActionTriggerController) -> Void,
        @ViewBuilder label: @escaping (SwipeActionContext) -> Label
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: nil,
            systemImage: nil,
            handlerKey: AnyHashable(UUID()),
            action: {
                action(.detached())
            },
            controlledAction: action,
            makeLabel: { context in
                AnyView(label(context))
            }
        )
    }

    /// Custom-label convenience with caller-supplied identity, trigger-controller access, and shape style.
    public init<ID: Hashable, Style: ShapeStyle, Label: View>(
        id: ID,
        role: SwipeActionRole,
        tint: Style,
        fireTiming: SwipeActionFireTiming? = nil,
        action: @escaping (SwipeActionTriggerController) -> Void,
        @ViewBuilder label: @escaping (SwipeActionContext) -> Label
    ) {
        self.init(
            resolvedID: AnyHashable(id),
            role: Self.resolvedRole(role, fireTiming: fireTiming),
            tint: SwipeActionTint(tint),
            title: nil,
            systemImage: nil,
            handlerKey: AnyHashable(UUID()),
            action: {
                action(.detached())
            },
            controlledAction: action,
            makeLabel: { context in
                AnyView(label(context))
            }
        )
    }

    func label(for context: SwipeActionContext) -> AnyView {
        makeLabel(context)
    }

    @discardableResult
    func trigger(with controller: SwipeActionTriggerController) -> Bool {
        guard let controlledAction else {
            handler.perform()
            return false
        }

        controlledAction(controller)
        return true
    }

    private static func resolvedRole(
        _ role: SwipeActionRole,
        fireTiming: SwipeActionFireTiming?
    ) -> SwipeActionRole {
        guard let fireTiming else { return role }

        switch role {
        case .normal:
            return .normal(fireTiming)
        case .destructive:
            return role
        }
    }

    init(
        resolvedID id: AnyHashable,
        role: SwipeActionRole,
        tint: SwipeActionTint,
        title: LocalizedStringKey?,
        systemImage: String?,
        handlerKey: AnyHashable,
        action: @escaping () -> Void,
        controlledAction: ((SwipeActionTriggerController) -> Void)?,
        makeLabel: @escaping (SwipeActionContext) -> AnyView
    ) {
        self.id = id
        self.role = role
        self.tint = tint
        self.title = title
        self.systemImage = systemImage
        self.handler = SwipeActionHandler(key: handlerKey, perform: action)
        self.controlledAction = controlledAction
        self.makeLabel = makeLabel
    }

    /// `makeLabel` and `controlledAction` are excluded by design. Labels must be pure functions of
    /// `SwipeActionContext`; controller closures stay on non-stable inline paths in this milestone.
    public static func == (lhs: SwipeAction, rhs: SwipeAction) -> Bool {
        lhs.id == rhs.id
            && lhs.role == rhs.role
            && lhs.tint == rhs.tint
            && lhs.title == rhs.title
            && lhs.systemImage == rhs.systemImage
            && lhs.handler == rhs.handler
    }
}

struct SwipeActionHandler: Equatable {
    let key: AnyHashable
    let perform: () -> Void

    init(
        key: AnyHashable = AnyHashable(UUID()),
        perform: @escaping () -> Void
    ) {
        self.key = key
        self.perform = perform
    }

    init(_ perform: @escaping () -> Void) {
        self.init(key: AnyHashable(UUID()), perform: perform)
    }

    static func == (lhs: SwipeActionHandler, rhs: SwipeActionHandler) -> Bool {
        lhs.key == rhs.key
    }
}
