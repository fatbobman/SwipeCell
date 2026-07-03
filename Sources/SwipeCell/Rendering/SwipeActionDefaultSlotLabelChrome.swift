import SwiftUI

struct SwipeActionDefaultSlotLabelChrome<Icon: View, Title: View>: View {
    let hasIcon: Bool
    let hasTitle: Bool
    let context: SwipeActionContext?
    let displayMode: SwipeActionLabelDisplayMode
    let style: SwipeActionDefaultLabelStyle
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let title: () -> Title

    @Environment(\.swipeCellConfiguration) private var configuration
    @Environment(\.swipeActionSuppressesSlotTitle) private var suppressesSlotTitle

    private var metrics: SwipeActionDefaultLabelMetrics {
        SwipeActionDefaultLabelMetrics(style: style)
    }

    var body: some View {
        SwipeActionArmedLabelMotionState(
            hasIcon: hasIcon,
            context: context,
            armedGlyphSlideDuration: slotChrome.armedGlyphSlideDuration
        ) { armedIconMotion in
            GeometryReader { proxy in
                fixedSlots(width: proxy.size.width, armedIconMotion: armedIconMotion)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func fixedSlots(width: CGFloat, armedIconMotion: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: width, height: metrics.totalSlotHeight)

            if hasIcon {
                icon()
                    .font(style.iconFont)
                    .frame(
                        width: metrics.iconSlotSize,
                        height: metrics.iconSlotSize
                    )
                    .position(x: width / 2, y: iconCenterY)
                    .swipeActionArmedIconSlide(
                        progress: armedIconMotion ? 1 : 0,
                        width: width,
                        centerX: width / 2,
                        side: context?.side,
                        iconSlotSize: metrics.iconSlotSize,
                        armedFrontInset: metrics.armedFrontInset
                    )
            }

            if hasTitle {
                title()
                    .font(style.titleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(width: metrics.titleSlotWidth(in: width), height: metrics.textSlotHeight)
                    .position(x: width / 2, y: metrics.titleSlotCenterY)
                    .opacity(slotTitleOpacity(armedIconMotion: armedIconMotion))
            }
        }
        .frame(width: width, height: metrics.totalSlotHeight)
    }

    private var slotChrome: SwipeCellDefaultPresentationConfiguration.SlotChromeSeed {
        SwipeCellDefaultPresentationConfiguration.slotChrome(for: configuration)
    }

    private var iconCenterY: CGFloat {
        // Only display-mode title suppression re-centers the lone icon. Arming also hides the title, but
        // the icon must hold its resting Y so the destructive slide reads as horizontal motion alone, not
        // a vertical drop.
        guard hasTitle, displayMode == .iconOnly else {
            return metrics.iconSlotSize / 2
        }

        return metrics.totalSlotHeight / 2
    }

    private func slotTitleOpacity(armedIconMotion: Bool) -> Double {
        if displayMode == .iconOnly && hasIcon {
            return 0
        }

        let base = armedIconMotion ? slotChrome.armedTitleOpacity : 1.0
        return base * (1.0 - Double(suppressesSlotTitle))
    }
}
