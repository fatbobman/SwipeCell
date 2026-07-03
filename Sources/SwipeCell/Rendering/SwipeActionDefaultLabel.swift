import SwiftUI

struct SwipeActionDefaultLabel: View {
    let title: LocalizedStringKey?
    let systemImage: String?

    @Environment(\.swipeActionContext) private var context
    @Environment(\.swipeActionsRevealStyle) private var revealStyle
    @Environment(\.swipeActionLabelDisplayMode) private var displayMode
    @Environment(\.swipeActionDefaultLabelStyle) private var style

    @ViewBuilder
    var body: some View {
        let label = SwipeActionDefaultLabelChrome(
            hasIcon: systemImage != nil,
            hasTitle: title != nil,
            context: context,
            revealStyle: revealStyle,
            displayMode: displayMode,
            style: style
        ) {
            if let systemImage {
                Image(systemName: systemImage)
            }
        } title: {
            if let title {
                Text(title)
            }
        }

        if let title {
            label
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
        } else {
            label
        }
    }
}

struct SwipeActionDefaultLabelChrome<Icon: View, Title: View>: View {
    let hasIcon: Bool
    let hasTitle: Bool
    let context: SwipeActionContext?
    let revealStyle: SwipeActionsRevealStyle
    let displayMode: SwipeActionLabelDisplayMode
    let style: SwipeActionDefaultLabelStyle
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let title: () -> Title

    @ViewBuilder
    var body: some View {
        switch revealStyle {
        case .slot:
            SwipeActionDefaultSlotLabelChrome(
                hasIcon: hasIcon,
                hasTitle: hasTitle,
                context: context,
                displayMode: displayMode,
                style: style,
                icon: icon,
                title: title
            )
        case .token:
            SwipeActionDefaultTokenLabelChrome(
                hasIcon: hasIcon,
                hasTitle: hasTitle,
                context: context,
                displayMode: displayMode,
                style: style,
                icon: icon,
                title: title
            )
        }
    }
}
