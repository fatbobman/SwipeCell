import Foundation
import SwiftUI

struct OwnedSwipeCellScopeModifier: ViewModifier {
    @State private var manager = SwipeCellManager()
    let container: SwipeCellContainer
    let actionTemplate: SwipeCellActionTemplate?
    let editModePolicy: SwipeCellEditModePolicy
    let minimumScrollResetDelta: CGFloat?

    func body(content: Content) -> some View {
        content.modifier(
            SwipeCellScopeModifier(
                manager: manager,
                container: container,
                actionTemplate: actionTemplate,
                editModePolicy: editModePolicy,
                minimumScrollResetDelta: minimumScrollResetDelta
            )
        )
    }
}

struct SwipeCellScopeModifier: ViewModifier {
    let manager: SwipeCellManager
    let container: SwipeCellContainer
    let actionTemplate: SwipeCellActionTemplate?
    let editModePolicy: SwipeCellEditModePolicy
    let minimumScrollResetDelta: CGFloat?

    @Environment(\.swipeCellConfiguration) private var configuration

    func body(content: Content) -> some View {
        let scopeContext = SwipeCellScopeContext(
            container: container,
            configuration: configuration.resolved(for: container)
        )
        let resolvedMinimumScrollResetDelta =
            minimumScrollResetDelta ?? scopeContext.configuration.timing.minimumScrollResetDelta

        scopedContent(content)
            .swipeCellParentScrollDisabled(manager)
            .environment(\.swipeCellConfiguration, scopeContext.configuration)
            .environment(\.swipeCellManager, manager)
            .environment(\.swipeCellEditModePolicy, editModePolicy)
            .onAppear {
                manager.applyScope(
                    container: scopeContext.container,
                    configuration: scopeContext.configuration
                )
            }
            .onChange(of: scopeContext) { _, newContext in
                manager.applyScope(
                    container: newContext.container,
                    configuration: newContext.configuration
                )
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldY, newY in
                guard abs(newY - oldY) >= max(0, resolvedMinimumScrollResetDelta) else { return }
                guard manager.canResetForScroll() else { return }
                manager.reset(reason: .scroll)
            }
    }

    @ViewBuilder
    private func scopedContent(_ content: Content) -> some View {
        if let actionTemplate {
            content.environment(\.swipeCellActionTemplate, actionTemplate)
        } else {
            content
        }
    }
}

private struct SwipeCellScopeContext: Equatable {
    let container: SwipeCellContainer
    let configuration: SwipeCellConfiguration
}

extension View {
    /// Disables the enclosing `List` / `ScrollView` scrolling while a *sustained* horizontal swipe drag
    /// is active. macOS only: the `scrollWheel` bridge samples out of band and cannot block the parent
    /// itself, so the scope holds the container still here (issue #31). A fast flick releases before the
    /// activation delay and is never locked, avoiding a `.scrollDisabled` toggle hitch on fast settle.
    /// Other platforms drive ownership through the direct-touch gesture and leave scrolling untouched.
    @ViewBuilder
    fileprivate func swipeCellParentScrollDisabled(_ manager: SwipeCellManager) -> some View {
        #if os(macOS)
            modifier(SwipeCellParentScrollLock(manager: manager))
        #else
            self
        #endif
    }
}

#if os(macOS)
    /// Locks parent scrolling only once a swipe drag has been sustained past a short delay. A fast flick
    /// (especially fast close) releases before the delay, so `.scrollDisabled` never toggles and its
    /// `NSScrollView` reconfiguration cannot hitch the settle frame. While a fast drag stays unlocked, any
    /// parent scroll-to-close noise is absorbed by `SwipeCellManager.suppressScrollReset`, refreshed every
    /// `panChanged`.
    private struct SwipeCellParentScrollLock: ViewModifier {
        let manager: SwipeCellManager
        @State private var locksParentScroll = false

        // A flick that releases within this delay is never locked; a sustained drag past it is. Tunable.
        private static let activationDelay = Duration.milliseconds(160)

        func body(content: Content) -> some View {
            content
                .scrollDisabled(locksParentScroll)
                .task(id: manager.hasActiveSwipeDrag) {
                    guard manager.hasActiveSwipeDrag else {
                        locksParentScroll = false
                        return
                    }
                    // A drag that ends before the delay cancels this task; the rebuilt task clears the
                    // lock through the guard above, so a fast flick is never disabled.
                    try? await Task.sleep(for: Self.activationDelay)
                    guard !Task.isCancelled else { return }
                    locksParentScroll = true
                }
        }
    }
#endif

struct SwipeCellActionTemplateModifier: ViewModifier {
    let actionTemplate: SwipeCellActionTemplate

    func body(content: Content) -> some View {
        content.environment(\.swipeCellActionTemplate, actionTemplate)
    }
}
