import SwiftUI

struct SwipeCellPanGestureModifier: ViewModifier {
    let configuration: SwipeCellConfiguration
    // Layout-resolved engine geometry for side enablement and release decisions. The macOS bridge maps
    // scroll progress onto `containerWidth`; the direct-touch iOS path ignores both bridge-only inputs.
    let interactionConfiguration: SwipeCellInteractionConfiguration
    let container: SwipeCellContainer
    let containerWidth: CGFloat
    let contentOffset: CGFloat
    let isEnabled: Bool
    let onBegan: () -> Void
    let onChanged: (SwipeCellPanValue) -> Void
    let onEnded: (SwipeCellPanValue) -> Void
    let onCancelled: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        #if canImport(UIKit)
            if isEnabled {
                content.gesture(
                    SwipeCellHorizontalPanGesture(
                        configuration: configuration,
                        onBegan: onBegan,
                        onChanged: onChanged,
                        onEnded: onEnded,
                        onCancelled: onCancelled
                    )
                )
            } else {
                content
            }
        #elseif os(macOS)
            if isEnabled {
                content
                    .overlay(
                        SwipeCellScrollWheelPanBridge(
                            isEnabled: isEnabled,
                            input: configuration.input,
                            interactionConfiguration: interactionConfiguration,
                            container: container,
                            containerWidth: containerWidth,
                            contentOffset: contentOffset,
                            onBegan: onBegan,
                            onChanged: onChanged,
                            onEnded: onEnded,
                            onCancelled: onCancelled
                        )
                        // The bridge only samples `scrollWheel` out of band via a shared monitor; it must
                        // not intercept clicks or scrolls, so it stays out of hit-testing (issue #31).
                        .allowsHitTesting(false)
                    )
            } else {
                content
            }
        #else
            content
        #endif
    }
}
