import Foundation
import SwiftUI

struct SwipeCellIdentityModifier: ViewModifier {
    let cellID: AnyHashable
    let openThreshold: CGFloat?
    let settlingAnimation: Animation?

    @Environment(\.swipeCellConfiguration) private var configuration
    @Environment(\.swipeCellManager) private var manager
    @Environment(\.swipeCellEditModePolicy) private var editModePolicy
    #if !os(macOS) && !os(watchOS)
        @Environment(\.editMode) private var editMode
    #endif

    @ViewBuilder
    func body(content: Content) -> some View {
        let resolved = SwipeCellResolvedCellConfiguration(
            configuration: configuration,
            settlingAnimation: settlingAnimation,
            openThreshold: openThreshold
        )

        SwipeCellIdentityHost(
            cellID: cellID,
            configuration: resolved.configuration,
            openThreshold: resolved.openThreshold,
            settlingAnimation: resolved.settlingAnimation,
            manager: manager,
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
        #if !os(macOS) && !os(watchOS)
            return SwipeCellEditModeState(editMode?.wrappedValue)
        #else
            return nil
        #endif
    }
}

private struct SwipeCellIdentityHost<Content: View>: View {
    let cellID: AnyHashable
    let configuration: SwipeCellConfiguration
    let openThreshold: CGFloat
    let settlingAnimation: Animation
    let manager: SwipeCellManager?
    let interactionsDisabled: Bool
    @ViewBuilder let content: () -> Content

    @State private var coordinator = SwipeCellInteractionCoordinator()
    @State private var containerSize = CGSize.zero

    var body: some View {
        let inputs = SwipeCellInteractionInputs(
            cellID: cellID,
            manager: manager,
            configuration: configuration,
            settlingAnimation: settlingAnimation,
            isInteractionEnabled: !interactionsDisabled
        )
        let normalOpenProgress = coordinator.normalOpenProgress

        content()
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { _, size in
                guard size != .zero else { return }
                containerSize = size
            }
            .transformEnvironment(\.swipeCellNormalOpenProgress) { progress in
                progress = normalOpenProgress
            }
            .contentShape(Rectangle())
            .modifier(
                SwipeCellContentTapCloseModifier(
                    cellID: cellID,
                    manager: manager,
                    isInteractionEnabled: inputs.isInteractionEnabled,
                    canContentTapClose: { inputs.isInteractionEnabled && coordinator.canTapClose },
                    onOwnerClose: { coordinator.beginContentTapClose(inputs) }
                )
            )
            .modifier(
                SwipeCellPanGestureModifier(
                    configuration: configuration,
                    interactionConfiguration: interactionModel.configuration,
                    container: manager?.container ?? .list,
                    containerWidth: containerSize.width,
                    contentOffset: coordinator.contentOffset,
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
            .offset(x: coordinator.contentOffset)
            .modifier(
                SwipeCellPinnedCloseAnimationModifier(
                    token: coordinator.closeToken,
                    animation: inputs.settlingAnimation,
                    onCompletion: { token in
                        coordinator.completePinnedClose(token: token)
                    }
                )
            )
            .onAppear {
                coordinator.hostAppeared(inputs)
                SwipeCellEditModeResetGate.resetManagerIfNeeded(
                    interactionsDisabled: interactionsDisabled,
                    inputs: inputs
                )
            }
            .onDisappear {
                coordinator.hostDisappeared(inputs)
            }
            .onChange(of: interactionsDisabled) { _, isDisabled in
                guard isDisabled else { return }
                SwipeCellEditModeResetGate.resetManagerIfNeeded(
                    interactionsDisabled: interactionsDisabled,
                    inputs: inputs
                )
            }
            .onChange(of: manager?.resetGeneration ?? 0) { _, generation in
                guard !interactionsDisabled else { return }
                coordinator.handleResetGenerationChange(generation, inputs: inputs)
            }
    }

    private var interactionModel: SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: openThreshold,
                normalOpenThreshold: openThreshold
            ),
            motion: configuration.motion
        )
    }
}
