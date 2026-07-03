import CoreGraphics

/// A normalized, validated action set for one side, plus the interaction geometry derived from it.
///
/// Normalization enforces the contract's structural rules (≤3 per side; only index 0 may be
/// `.destructive`) and derives the side's interaction configuration from the action set, so the
/// engine never hand-fills `allowsDestructive` or the open extent. Exposed through
/// `@_spi(ManualDebug)` so Swift Testing can exercise the rules without the public surface, mirroring
/// the interaction-model layer.
@_spi(ManualDebug)
public struct SwipeActionGroup: Equatable {
    /// At most three actions per side (contract D3 / D4).
    public static let maximumActionCount = 3
    /// Default iOS resting width of a single action, in points.
    public static var defaultActionWidth: CGFloat {
        SwipeCellConfiguration.iOSDefault.geometry.defaultActionWidth
    }

    public let side: SwipeCellSide
    public let actions: [SwipeAction]
    public let actionWidth: CGFloat
    private let geometry: SwipeCellConfiguration.Geometry
    private let emitsDiagnostics: Bool

    public var count: Int { actions.count }
    public var isEmpty: Bool { actions.isEmpty }

    /// The side allows a destructive full-swipe only when its outermost action is `.destructive`.
    public var allowsDestructive: Bool { actions.first?.role.isDestructive == true }

    /// Resting reveal width. Siblings are equal-width, so this is `width × count`, not a per-item sum.
    public var normalOpenExtent: CGFloat { actionWidth * CGFloat(count) }

    /// Drag distance required to commit the side open.
    ///
    /// iOS keeps the native ratio-based behavior, while macOS can use an absolute scroll-wheel
    /// distance so action count does not make the commit progressively deeper.
    public var normalOpenThreshold: CGFloat {
        geometry.normalOpenCommitThreshold.resolvedDistance(for: normalOpenExtent)
    }

    /// - Parameter emitsDiagnostics: when `true` (production default), recoverable violations are offered
    ///   to the internal diagnostics helper. Output remains gated by private DEBUG environment switches.
    ///   Tests pass `false` to verify the degraded outcome without diagnostics noise.
    public init(
        side: SwipeCellSide,
        actions: [SwipeAction],
        actionWidth: CGFloat? = nil,
        configuration: SwipeCellConfiguration = .platformDefault,
        emitsDiagnostics: Bool = true
    ) {
        self.side = side
        self.actions = Self.normalize(actions, emitsDiagnostics: emitsDiagnostics)
        self.actionWidth = Self.resolveActionWidth(
            actionWidth,
            fallback: configuration.geometry.defaultActionWidth
        )
        self.geometry = configuration.geometry
        self.emitsDiagnostics = emitsDiagnostics
    }

    /// Bridge: this side's descriptor → the engine's side configuration.
    ///
    /// Only width-independent facts are resolved here. Destructive activation depends on the
    /// container width and is resolved at layout time; until then the interaction model's own
    /// normalization supplies safe defaults, so this bridge must not hand-fill it.
    public func interactionSideConfiguration() -> SwipeCellInteractionSideConfiguration {
        guard !isEmpty else { return .disabled }
        return SwipeCellInteractionSideConfiguration(
            normalOpenExtent: normalOpenExtent,
            normalOpenThreshold: normalOpenThreshold,
            allowsDestructive: allowsDestructive
        )
    }

    /// Bridge used by the rendered action path after the row width is known.
    ///
    /// The destructive activation boundary resolves only after layout, because row-fraction policies
    /// and the reachable upper bound both depend on the container width.
    public func interactionSideConfiguration(containerWidth: CGFloat) -> SwipeCellInteractionSideConfiguration {
        guard !isEmpty else { return .disabled }

        guard allowsDestructive else {
            return interactionSideConfiguration()
        }

        guard let destructive = actions.first?.role.destructiveConfiguration else {
            return interactionSideConfiguration()
        }

        guard
            let activationExtent = Self.resolveDestructiveActivationExtent(
                containerWidth: containerWidth,
                actionWidth: actionWidth,
                normalOpenExtent: normalOpenExtent,
                side: side,
                activation: destructive.activation,
                geometry: geometry,
                emitsDiagnostics: emitsDiagnostics
            )
        else {
            return interactionSideConfiguration().withoutDestructiveArming()
        }

        return SwipeCellInteractionSideConfiguration(
            normalOpenExtent: normalOpenExtent,
            normalOpenThreshold: normalOpenThreshold,
            allowsDestructive: true,
            destructiveThreshold: activationExtent,
            destructiveSettlingExtent: activationExtent
        )
    }

    /// Bridge: a pair of side groups → the engine's interaction configuration. This is what the
    /// declarative entry feeds the identity engine, replacing the identity path's hardcoded symmetric
    /// configuration once the action path is wired.
    public static func interactionConfiguration(
        leading: SwipeActionGroup,
        trailing: SwipeActionGroup
    ) -> SwipeCellInteractionConfiguration {
        SwipeCellInteractionConfiguration(
            leading: leading.interactionSideConfiguration(),
            trailing: trailing.interactionSideConfiguration()
        )
    }

    /// Layout-resolved bridge for the rendered action path.
    public static func interactionConfiguration(
        leading: SwipeActionGroup,
        trailing: SwipeActionGroup,
        containerWidth: CGFloat
    ) -> SwipeCellInteractionConfiguration {
        SwipeCellInteractionConfiguration(
            leading: leading.interactionSideConfiguration(containerWidth: containerWidth),
            trailing: trailing.interactionSideConfiguration(containerWidth: containerWidth)
        )
    }

    private static func normalize(
        _ actions: [SwipeAction],
        emitsDiagnostics: Bool
    ) -> [SwipeAction] {
        var normalized = actions

        if normalized.count > maximumActionCount {
            #if DEBUG
                SwipeCellDiagnostics.warning(
                    "action-group.maximum-count.\(normalized.count)",
                    enabled: emitsDiagnostics,
                    message: "a side accepts at most \(maximumActionCount) actions; "
                        + "\(normalized.count - maximumActionCount) extra action(s) are dropped."
                )
            #endif
            normalized = Array(normalized.prefix(maximumActionCount))
        }

        // Only the outermost slot owns destructive full-swipe; demote inner declarations so payload
        // configuration cannot accidentally arm an inner action.
        for index in normalized.indices where index != 0 && normalized[index].role.isDestructive {
            #if DEBUG
                SwipeCellDiagnostics.warning(
                    "action-group.inner-destructive.\(index)",
                    enabled: emitsDiagnostics,
                    message: "only the outermost (index 0) action may be .destructive; "
                        + "the action at index \(index) is demoted to .normal(.immediate)."
                )
            #endif
            normalized[index].role = .normal(.immediate)
        }

        return normalized
    }

    private static func resolveActionWidth(_ width: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let width, width.isFinite, width > 0 else { return fallback }
        return width
    }

    static func resolveDestructiveActivationExtent(
        containerWidth: CGFloat,
        actionWidth: CGFloat,
        normalOpenExtent: CGFloat,
        side: SwipeCellSide,
        activation: SwipeActionActivation,
        geometry: SwipeCellConfiguration.Geometry = .init(),
        emitsDiagnostics: Bool
    ) -> CGFloat? {
        // A non-positive / non-finite container width is a pre-layout state, not a misconfiguration:
        // resolve to "no destructive arming" silently so a `body` pass before the row has a measured
        // width does not trip the diagnostic. A later pass with a real width resolves the extent.
        guard containerWidth.isFinite, containerWidth > 0 else {
            #if DEBUG
                SwipeCellDiagnostics.layoutFallback(
                    "destructive-activation.unmeasured-container.\(side)",
                    enabled: emitsDiagnostics,
                    message: "destructive activation waits for a finite row width; "
                        + "the outermost action falls back to ordinary open behavior."
                )
            #endif
            return nil
        }

        let maximumActivationExtent = containerWidth * geometry.maxFullSwipeActivationFraction
        guard maximumActivationExtent > normalOpenExtent else {
            #if DEBUG
                SwipeCellDiagnostics.layoutFallback(
                    "destructive-activation.cannot-fit.\(side)",
                    enabled: emitsDiagnostics,
                    message: "destructive activation cannot fit in this row; "
                        + "the outermost action falls back to ordinary open behavior."
                )
            #endif
            return nil
        }

        let minimumActivationExtent = normalOpenExtent + max(actionWidth * 0.01, 1)
        let activationGeometry =
            activation.explicitGeometry
            ?? geometry.destructiveActivationDefaults.geometry(for: side)
        let declaredExtent = Self.declaredDestructiveActivationExtent(
            activationGeometry,
            containerWidth: containerWidth,
            actionWidth: actionWidth,
            normalOpenExtent: normalOpenExtent
        )
        let resolvedDeclaredExtent = declaredExtent ?? minimumActivationExtent

        #if DEBUG
            if declaredExtent == nil {
                SwipeCellDiagnostics.warning(
                    "destructive-activation.invalid-geometry.\(side)",
                    enabled: emitsDiagnostics,
                    message: "destructive activation geometry must resolve to a finite distance."
                )
            }
        #endif

        let lowerBoundedExtent: CGFloat
        if resolvedDeclaredExtent <= normalOpenExtent {
            #if DEBUG
                SwipeCellDiagnostics.warning(
                    "destructive-activation.before-open.\(side)",
                    enabled: emitsDiagnostics,
                    message: "destructive activation must sit beyond the normal open extent."
                )
            #endif
            lowerBoundedExtent = minimumActivationExtent
        } else {
            lowerBoundedExtent = resolvedDeclaredExtent
        }

        #if DEBUG
            if lowerBoundedExtent > maximumActivationExtent {
                SwipeCellDiagnostics.warning(
                    "destructive-activation.above-row-limit.\(side)",
                    enabled: emitsDiagnostics,
                    message: "destructive activation exceeds the row-width limit and is clamped."
                )
            }
        #endif

        return min(lowerBoundedExtent, maximumActivationExtent)
    }

    private static func declaredDestructiveActivationExtent(
        _ geometry: SwipeCellDestructiveActivationGeometry,
        containerWidth: CGFloat,
        actionWidth: CGFloat,
        normalOpenExtent: CGFloat
    ) -> CGFloat? {
        let declaredExtent =
            switch geometry {
            case .actionWidthMultiplier(let multiplier):
                multiplier * actionWidth
            case .openExtentPlusDistance(let distance):
                normalOpenExtent + distance
            case .openExtentPlusActionWidths(let widths):
                normalOpenExtent + actionWidth * widths
            case .rowWidthFraction(let fraction):
                containerWidth * fraction
            }

        guard declaredExtent.isFinite else { return nil }
        return declaredExtent
    }
}

extension SwipeActionRole {
    fileprivate var destructiveConfiguration: SwipeActionDestructive? {
        switch self {
        case .normal:
            nil
        case .destructive(let configuration):
            configuration
        }
    }
}

extension SwipeCellInteractionSideConfiguration {
    fileprivate func withoutDestructiveArming() -> SwipeCellInteractionSideConfiguration {
        SwipeCellInteractionSideConfiguration(
            isEnabled: isEnabled,
            normalOpenExtent: normalOpenExtent,
            normalOpenThreshold: normalOpenThreshold,
            allowsDestructive: false
        )
    }
}
