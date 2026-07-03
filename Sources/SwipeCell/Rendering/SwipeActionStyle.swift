import SwiftUI

public protocol SwipeActionStyle {
    associatedtype Body: View

    @ViewBuilder
    func makeBody(configuration: SwipeActionStyleConfiguration) -> Body
}

public struct SwipeActionStyleConfiguration {
    public struct Label: View {
        private let content: AnyView

        init<Content: View>(@ViewBuilder content: () -> Content) {
            self.content = AnyView(content())
        }

        public var body: some View {
            content
        }
    }

    public let label: Label
    public let context: SwipeActionContext
    public let tint: SwipeActionTint
}

public struct DefaultSwipeActionStyle: SwipeActionStyle {
    public init() {}

    public func makeBody(configuration: SwipeActionStyleConfiguration) -> some View {
        DefaultSwipeActionStyleBody(configuration: configuration)
    }
}

private struct DefaultSwipeActionStyleBody: View {
    let configuration: SwipeActionStyleConfiguration

    @Environment(\.swipeActionsRevealStyle) private var revealStyle
    @Environment(\.swipeCellConfiguration) private var swipeCellConfiguration

    var body: some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // `.token` default labels draw their own token tint; custom labels that need a filled
                // slot should own that chrome or provide a custom SwipeActionStyle.
                if revealStyle == .slot, slotChrome.drawsFullSlotTint {
                    Rectangle().fill(configuration.tint)
                }
            }
            .opacity(opacity(for: configuration.context))
    }

    private var slotChrome: SwipeCellDefaultPresentationConfiguration.SlotChromeSeed {
        SwipeCellDefaultPresentationConfiguration.slotChrome(for: swipeCellConfiguration)
    }

    private func opacity(for context: SwipeActionContext) -> Double {
        guard context.role != .destructive else { return 1 }
        return 1 - (swipeCellConfiguration.style.deformationOpacityFalloff * Double(context.deformationProgress))
    }
}

struct AnySwipeActionStyle {
    private let makeBody: (SwipeActionStyleConfiguration) -> AnyView

    init<Style: SwipeActionStyle>(_ style: Style) {
        self.makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: SwipeActionStyleConfiguration) -> AnyView {
        makeBody(configuration)
    }
}

private struct SwipeActionStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue = AnySwipeActionStyle(DefaultSwipeActionStyle())
}

private struct SwipeActionTintEnvironmentKey: EnvironmentKey {
    static let defaultValue = SwipeActionTint(Color.accentColor)
}

extension EnvironmentValues {
    var swipeActionStyle: AnySwipeActionStyle {
        get { self[SwipeActionStyleEnvironmentKey.self] }
        set { self[SwipeActionStyleEnvironmentKey.self] = newValue }
    }

    var swipeActionTint: SwipeActionTint {
        get { self[SwipeActionTintEnvironmentKey.self] }
        set { self[SwipeActionTintEnvironmentKey.self] = newValue }
    }
}

extension View {
    public func swipeActionStyle(_ style: some SwipeActionStyle) -> some View {
        environment(\.swipeActionStyle, AnySwipeActionStyle(style))
    }
}
