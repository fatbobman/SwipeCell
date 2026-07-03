import Foundation
import SwiftUI

struct SwipeCellTemplateActionsModifier<CellID: Hashable>: ViewModifier, Equatable {
    let cellID: CellID

    @Environment(\.swipeCellActionTemplate) private var actionTemplate

    // The resolver stores no action closures. Its key is the row identity; SwiftUI tracks the
    // template environment separately when `body` resolves actions.
    static func == (lhs: SwipeCellTemplateActionsModifier, rhs: SwipeCellTemplateActionsModifier) -> Bool {
        lhs.cellID == rhs.cellID
    }

    func body(content: Content) -> some View {
        let actions = resolvedActions()

        content.modifier(
            SwipeCellActionsModifier(
                cellID: AnyHashable(cellID),
                leadingActions: actions.leading,
                trailingActions: actions.trailing,
                actionWidth: nil,
                revealStyle: nil,
                settlingAnimation: nil
            )
        )
    }

    private func resolvedActions() -> (leading: [SwipeAction], trailing: [SwipeAction]) {
        guard let actionTemplate else {
            #if DEBUG
                SwipeCellDiagnostics.warning(
                    "action-template.missing-scope",
                    message: "swipeCellActions(rowID) requires a SwipeCellActionTemplate in scope; "
                        + "the row falls back to no swipe actions."
                )
            #endif
            return (leading: [], trailing: [])
        }

        return actionTemplate.resolveActions(for: cellID)
    }
}

struct SwipeCellActionsModifier: ViewModifier, Equatable {
    let cellID: AnyHashable
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let actionWidth: CGFloat?
    let revealStyle: SwipeActionsRevealStyle?
    let settlingAnimation: Animation?

    @Environment(\.swipeCellConfiguration) private var configuration
    @Environment(\.swipeCellManager) private var manager
    @Environment(\.swipeCellEditModePolicy) private var editModePolicy
    #if !os(macOS) && !os(watchOS)
        @Environment(\.editMode) private var editMode
    #endif

    init(
        cellID: AnyHashable,
        leadingActions: [SwipeAction],
        trailingActions: [SwipeAction],
        actionWidth: CGFloat?,
        revealStyle: SwipeActionsRevealStyle?,
        settlingAnimation: Animation?
    ) {
        self.cellID = cellID
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
        self.actionWidth = actionWidth
        self.revealStyle = revealStyle
        self.settlingAnimation = settlingAnimation
    }

    static func == (lhs: SwipeCellActionsModifier, rhs: SwipeCellActionsModifier) -> Bool {
        // Keep #17's diff surface on caller-supplied descriptors; resolved groups are rebuilt in
        // `body` so environment configuration can change without becoming part of modifier equality.
        lhs.cellID == rhs.cellID
            && lhs.leadingActions == rhs.leadingActions
            && lhs.trailingActions == rhs.trailingActions
            && lhs.actionWidth == rhs.actionWidth
            && lhs.revealStyle == rhs.revealStyle
            && lhs.settlingAnimation == rhs.settlingAnimation
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        let resolved = SwipeCellResolvedCellConfiguration(
            configuration: configuration,
            actionWidth: actionWidth,
            revealStyle: revealStyle,
            settlingAnimation: settlingAnimation
        )
        let leadingGroup = SwipeActionGroup(
            side: .leading,
            actions: leadingActions,
            actionWidth: resolved.actionWidth,
            configuration: resolved.configuration
        )
        let trailingGroup = SwipeActionGroup(
            side: .trailing,
            actions: trailingActions,
            actionWidth: resolved.actionWidth,
            configuration: resolved.configuration
        )

        SwipeCellActionsHost(
            cellID: cellID,
            configuration: resolved.configuration,
            leadingGroup: leadingGroup,
            trailingGroup: trailingGroup,
            revealStyle: resolved.revealStyle,
            settlingAnimation: resolved.settlingAnimation,
            scopedManager: manager,
            interactionsDisabled: interactionsDisabled,
            content: {
                content
            }
        )
        // EditMode can interrupt the normal reset signal path. Rebuild this wrapper so local
        // SwipeCell state closes immediately; the row content subtree also refreshes on this edge.
        .id(interactionsDisabled)
    }

    private var interactionsDisabled: Bool {
        SwipeCellEditModeGate.isInteractionDisabled(
            policy: editModePolicy,
            editModeState: editModeState
        )
    }

    private var editModeState: SwipeCellEditModeState? {
        // SwiftUI.EditMode is List-row scoped in practice; read it from the row modifier, not scope.
        #if !os(macOS) && !os(watchOS)
            return SwipeCellEditModeState(editMode?.wrappedValue)
        #else
            return nil
        #endif
    }
}

struct SwipeCellActionShellDrawingGroupParameters: Equatable {
    let opaque: Bool
    let colorMode: ColorRenderingMode
}

extension SwipeCellDrawingGroupMode {
    var actionShellDrawingGroupParameters: SwipeCellActionShellDrawingGroupParameters? {
        switch self {
        case .disabled:
            nil
        case .enabled(let opaque, let colorMode):
            SwipeCellActionShellDrawingGroupParameters(opaque: opaque, colorMode: colorMode)
        }
    }
}

struct SwipeCellActionShellDrawingGroupModifier: ViewModifier, Equatable {
    let mode: SwipeCellDrawingGroupMode

    @ViewBuilder
    func body(content: Content) -> some View {
        if let parameters = mode.actionShellDrawingGroupParameters {
            content.drawingGroup(opaque: parameters.opaque, colorMode: parameters.colorMode)
        } else {
            content
        }
    }
}

extension View {
    func swipeCellActionShellDrawingGroup(_ mode: SwipeCellDrawingGroupMode) -> some View {
        modifier(SwipeCellActionShellDrawingGroupModifier(mode: mode))
    }
}

private struct SwipeCellActionsHost<Content: View>: View {
    let cellID: AnyHashable
    let configuration: SwipeCellConfiguration
    let leadingGroup: SwipeActionGroup
    let trailingGroup: SwipeActionGroup
    let revealStyle: SwipeActionsRevealStyle
    let settlingAnimation: Animation
    let scopedManager: SwipeCellManager?
    let interactionsDisabled: Bool
    @ViewBuilder let content: () -> Content

    @State private var ownedManager = SwipeCellManager()
    @State private var coordinator = SwipeCellInteractionCoordinator()
    @State private var containerSize = CGSize.zero
    @State private var programmaticOpenRegistration: SwipeCellProgrammaticOpenRegistration?

    var body: some View {
        let activeManager = resolvedManager
        let inputs = SwipeCellInteractionInputs(
            cellID: cellID,
            manager: activeManager,
            configuration: configuration,
            settlingAnimation: settlingAnimation,
            isInteractionEnabled: !interactionsDisabled,
            destructiveTrigger: destructiveTrigger(for:)
        )
        let rendered = SwipeCellActionShell(
            cellID: cellID,
            manager: activeManager,
            contentOffset: coordinator.contentOffset,
            normalOpenProgress: coordinator.normalOpenProgress,
            deformationProgress: coordinator.deformationProgress,
            isArmed: coordinator.isArmed,
            armChangeID: coordinator.armChangeID,
            armChangeKind: coordinator.armChangeKind,
            hapticEvent: coordinator.hapticEvent,
            containerWidth: containerSize.width,
            leadingGroup: leadingGroup,
            trailingGroup: trailingGroup,
            configuration: configuration,
            revealStyle: revealStyle,
            settlingSide: coordinator.settlingSide,
            takeoverSettlingSide: coordinator.takeoverSettlingSide,
            closeToken: coordinator.closeToken,
            closeAnimation: inputs.settlingAnimation,
            isInteractionEnabled: inputs.isInteractionEnabled,
            canContentTapClose: { inputs.isInteractionEnabled && coordinator.canTapClose },
            onContentTap: { coordinator.beginContentTapClose(inputs) },
            onPinnedCloseCompletion: { token in
                coordinator.completePinnedClose(token: token)
            },
            onActionTap: { side, action in
                handleActionTap(
                    side: side,
                    action: action,
                    manager: activeManager,
                    inputs: inputs
                )
            },
            content: {
                content()
            }
        )
        .swipeCellActionShellDrawingGroup(configuration.rendering.actionShellDrawingGroup)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { _, size in
            guard size != .zero else { return }
            containerSize = size
        }
        .onAppear {
            activeManager.applyConfiguration(configuration)
            coordinator.hostAppeared(inputs)
            registerProgrammaticOpenTarget(
                manager: activeManager,
                inputs: inputs,
                model: interactionModel
            )
            SwipeCellEditModeResetGate.resetManagerIfNeeded(
                interactionsDisabled: interactionsDisabled,
                inputs: inputs
            )
        }
        .onDisappear {
            coordinator.hostDisappeared(inputs)
            unregisterProgrammaticOpenTarget()
        }
        .onChange(of: configuration) { _, newConfiguration in
            activeManager.applyConfiguration(newConfiguration)
        }
        .onChange(of: programmaticOpenRegistrationState(manager: activeManager)) { _, _ in
            registerProgrammaticOpenTarget(
                manager: activeManager,
                inputs: inputs,
                model: interactionModel
            )
        }
        .onChange(of: interactionsDisabled) { _, isDisabled in
            guard isDisabled else { return }
            SwipeCellEditModeResetGate.resetManagerIfNeeded(
                interactionsDisabled: interactionsDisabled,
                inputs: inputs
            )
        }
        .onChange(of: activeManager.resetGeneration) { _, generation in
            guard !interactionsDisabled else { return }
            coordinator.handleResetGenerationChange(generation, inputs: inputs)
        }

        rendered.modifier(
            SwipeCellPanGestureModifier(
                configuration: configuration,
                // The macOS bridge locks `containerWidth` at began for row-width gain. A zero
                // pre-layout width simply prevents scroll-swipe begin; destructive geometry resolves
                // when the measured width arrives on a later pass.
                interactionConfiguration: interactionModel.configuration,
                container: activeManager.container,
                containerWidth: containerSize.width,
                contentOffset: coordinator.contentOffset,
                // Keep the gesture/scroll bridge mounted while row-local automatic suppression flips;
                // callbacks guard consumption so animation does not rebuild this modifier branch.
                isEnabled: inputs.isInteractionEnabled,
                onBegan: { coordinator.panBegan(inputs, model: interactionModel) },
                onChanged: { value in
                    coordinator.panChanged(value, model: interactionModel, inputs: inputs)
                },
                onEnded: { value in
                    coordinator.panEnded(value, model: interactionModel, inputs: inputs)
                },
                onCancelled: { coordinator.panCancelled(inputs) }
            )
        )
    }

    private var resolvedManager: SwipeCellManager {
        scopedManager ?? ownedManager
    }

    private var interactionModel: SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: SwipeActionGroup.interactionConfiguration(
                leading: leadingGroup,
                trailing: trailingGroup,
                containerWidth: containerSize.width
            ),
            motion: configuration.motion
        )
    }

    private func programmaticOpenRegistrationState(
        manager: SwipeCellManager
    ) -> SwipeCellProgrammaticOpenRegistrationState {
        SwipeCellProgrammaticOpenRegistrationState(
            managerID: ObjectIdentifier(manager),
            cellID: cellID,
            capabilities: programmaticOpenCapabilities,
            leadingOpenExtent: leadingGroup.normalOpenExtent,
            trailingOpenExtent: trailingGroup.normalOpenExtent,
            settlingAnimation: settlingAnimation
        )
    }

    private var programmaticOpenCapabilities: SwipeCellProgrammaticOpenCapabilities {
        SwipeCellProgrammaticOpenCapabilities(
            canOpenLeading: !interactionsDisabled && !leadingGroup.isEmpty,
            canOpenTrailing: !interactionsDisabled && !trailingGroup.isEmpty
        )
    }

    private func registerProgrammaticOpenTarget(
        manager activeManager: SwipeCellManager,
        inputs: SwipeCellInteractionInputs,
        model: SwipeCellInteractionModel
    ) {
        unregisterProgrammaticOpenTarget()

        let cellID = inputs.cellID
        let configuration = inputs.configuration
        let settlingAnimation = inputs.settlingAnimation
        let isInteractionEnabled = inputs.isInteractionEnabled
        let destructiveTrigger = inputs.destructiveTrigger
        let registrationID = activeManager.registerProgrammaticOpenTarget(
            for: cellID,
            capabilities: programmaticOpenCapabilities
        ) { [weak activeManager] request in
            guard let activeManager else { return }
            let requestInputs = SwipeCellInteractionInputs(
                cellID: cellID,
                manager: activeManager,
                configuration: configuration,
                settlingAnimation: settlingAnimation,
                isInteractionEnabled: isInteractionEnabled,
                destructiveTrigger: destructiveTrigger
            )
            coordinator.applyProgrammaticOpen(request, model: model, inputs: requestInputs)
        }
        programmaticOpenRegistration = SwipeCellProgrammaticOpenRegistration(
            manager: activeManager,
            cellID: cellID,
            registrationID: registrationID
        )
    }

    private func unregisterProgrammaticOpenTarget() {
        guard let registration = programmaticOpenRegistration else { return }

        registration.manager.unregisterProgrammaticOpenTarget(
            for: registration.cellID,
            registrationID: registration.registrationID
        )
        programmaticOpenRegistration = nil
    }

    private func destructiveTrigger(for side: SwipeCellSide) -> SwipeCellDestructiveTrigger? {
        let group =
            switch side {
            case .leading:
                leadingGroup
            case .trailing:
                trailingGroup
            }

        guard let action = group.actions.first,
            case .destructive(let destructive) = action.role
        else {
            return nil
        }

        return SwipeCellDestructiveTrigger(
            action: action,
            completion: destructive.completion
        )
    }

    private func handleActionTap(
        side: SwipeCellSide,
        action: SwipeAction,
        manager: SwipeCellManager,
        inputs: SwipeCellInteractionInputs
    ) {
        let resolution = SwipeCellActionTapGate.resolve(
            side,
            for: cellID,
            manager: manager,
            isInteractionEnabled: inputs.isInteractionEnabled,
            fireTiming: action.buttonTapFireTiming
        )

        switch resolution {
        case .ignored:
            return
        case .immediate, .afterCollapse, .triggerAndHoldOpen:
            coordinator.performActionTap(
                resolution: resolution,
                inputs: inputs
            ) {
                action.action()
            }
        }
    }

}

private struct SwipeCellProgrammaticOpenRegistration {
    let manager: SwipeCellManager
    let cellID: AnyHashable
    let registrationID: Int
}

private struct SwipeCellProgrammaticOpenRegistrationState: Equatable {
    let managerID: ObjectIdentifier
    let cellID: AnyHashable
    let capabilities: SwipeCellProgrammaticOpenCapabilities
    let leadingOpenExtent: CGFloat
    let trailingOpenExtent: CGFloat
    let settlingAnimation: Animation
}
