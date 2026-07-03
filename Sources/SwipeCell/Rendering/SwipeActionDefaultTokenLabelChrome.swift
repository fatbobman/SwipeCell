import SwiftUI

struct SwipeActionDefaultTokenLabelChrome<Icon: View, Title: View>: View {
    let hasIcon: Bool
    let hasTitle: Bool
    let context: SwipeActionContext?
    let displayMode: SwipeActionLabelDisplayMode
    let style: SwipeActionDefaultLabelStyle
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let title: () -> Title

    @Environment(\.swipeActionTint) private var actionTint
    @Environment(\.swipeActionRestSlotWidth) private var restSlotWidth
    @Environment(\.swipeActionTokenOffset) private var tokenOffset
    @Environment(\.swipeActionHoldsFireFace) private var holdsFireFace
    @Environment(\.swipeCellConfiguration) private var configuration

    private var metrics: SwipeActionDefaultLabelMetrics {
        SwipeActionDefaultLabelMetrics(style: style)
    }

    var body: some View {
        SwipeActionArmedLabelMotionState(
            hasIcon: hasIcon,
            context: context,
            armedGlyphSlideDuration: tokenChrome.armedGlyphSlideDuration
        ) { armedIconMotion in
            GeometryReader { proxy in
                fixedSlots(width: proxy.size.width, armedIconMotion: armedIconMotion)
                    .offset(x: tokenOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func fixedSlots(width: CGFloat, armedIconMotion: Bool) -> some View {
        let layout = tokenLayout
        // Token size comes from the resting slot, not the live (over-swipe-expanded) width, so its height
        // never grows mid-stretch; only the capsule frame responds to the expanding live slot.
        let restWidth = restSlotWidth > 0 ? restSlotWidth : width
        let position = evenGapPosition
        let count = context?.count ?? 1
        let tokenSize = layout.restingSize(slotWidth: restWidth)
        let capsuleFrame = layout.capsuleFrame(
            restSlotWidth: restWidth,
            liveSlotWidth: width,
            position: position,
            count: count,
            stretchProgress: tokenStretchProgress
        )
        let total = tokenSize.height + layout.titleSpacing + metrics.textSlotHeight
        // A visible title pushes the token up; a lone token centers in the label region.
        let centerY = tokenTitleVisible ? tokenSize.height / 2 : total / 2
        // Icon and title stay centered on the capsule as it stretches, so they never drift toward an edge
        // while over-swiping. The capsule frame is derived in the live (expanding) slot space; at rest, and
        // for non-stretching tokens, it collapses to the even-gap resting frame, so this is the resting
        // token center. Only the arm state change — not the stretch — slides the glyph to the fire edge.
        let contentCenterX = hasIcon ? capsuleFrame.midX : width / 2

        return ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: width, height: total)

            if hasIcon {
                if tokenChrome.drawsTokenTint {
                    // Token is its own layer so the glyph can slide to the fire edge independently while the
                    // capsule fills the slot — a single icon+background view cannot decouple the two.
                    Capsule()
                        .fill(actionTint)
                        .frame(
                            width: capsuleFrame.width,
                            height: capsuleFrame.height
                        )
                        .position(x: capsuleFrame.midX, y: centerY)
                }

                icon()
                    .font(style.iconFont)
                    .frame(width: metrics.iconSlotSize, height: metrics.iconSlotSize)
                    .position(x: contentCenterX, y: centerY)
                    // Match the slot chrome: the glyph stays centered on the capsule through the over-swipe
                    // and only slides to the content-facing fire edge when the destructive action arms,
                    // animating back on disarm — driven by the armed state, not the continuous deformation.
                    .swipeActionArmedIconSlide(
                        progress: armedIconMotion ? 1 : 0,
                        width: width,
                        centerX: contentCenterX,
                        side: context?.side,
                        iconSlotSize: metrics.iconSlotSize,
                        armedFrontInset: metrics.armedFrontInset
                    )
            }

            if hasTitle {
                tokenTitle(
                    width: width,
                    tokenSize: tokenSize,
                    total: total,
                    centerX: contentCenterX,
                    armedIconMotion: armedIconMotion
                )
            }
        }
        .frame(width: width, height: total)
        // Non-destructive tokens only fade (no resize) as the destructive arms, so all tokens keep the
        // height they settled at on open.
        .opacity(tokenRecedeOpacity)
    }

    /// Left-to-right token position within the side's HStack: leading keeps array order, trailing reverses,
    /// so position 0 is always the token nearest the left region edge.
    private var evenGapPosition: Int {
        guard let context else { return 0 }
        switch context.side {
        case .leading:
            return context.index
        case .trailing:
            return max(0, context.count - 1 - context.index)
        }
    }

    @ViewBuilder
    private func tokenTitle(
        width: CGFloat,
        tokenSize: CGSize,
        total: CGFloat,
        centerX: CGFloat,
        armedIconMotion: Bool
    ) -> some View {
        if hasIcon {
            title()
                .font(style.titleFont)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                // System swipe tokens caption the icon in a secondary label color, not the white glyph tint.
                .foregroundStyle(Color.secondary)
                .frame(width: metrics.titleSlotWidth(in: width), height: metrics.textSlotHeight)
                // Title sits below the rest token; derived from token height (not the live width) so it never drifts
                // down when the live slot expands during over-swipe.
                .position(
                    x: centerX,
                    y: tokenSize.height + tokenLayout.titleSpacing + (metrics.textSlotHeight / 2)
                )
                .opacity(tokenTitleOpacity(armedIconMotion: armedIconMotion))
        } else {
            // title-only fallback: a tint capsule keeps a readable, identifiable chrome instead of an empty
            // token, and never blanks while the destructive action is armed.
            title()
                .font(style.titleFont)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(width: tokenSize.width, height: tokenSize.height)
                .background(actionTint, in: Capsule())
                .position(x: width / 2, y: total / 2)
        }
    }

    private var tokenLayout: SwipeActionTokenLayout {
        SwipeActionTokenLayout(
            metrics: metrics,
            profile: resolvedTokenProfile
        )
    }

    private var resolvedTokenProfile: SwipeActionTokenProfile {
        configuration.style.tokenProfile.sanitized(
            fallback: SwipeCellConfiguration.platformDefault.style.tokenProfile
        )
    }

    private var tokenChrome: SwipeCellDefaultPresentationConfiguration.TokenChromeSeed {
        SwipeCellDefaultPresentationConfiguration.tokenChrome(for: resolvedTokenProfile)
    }

    private var tokenTitleVisible: Bool {
        hasTitle && displayMode != .iconOnly
    }

    private func tokenTitleOpacity(armedIconMotion: Bool) -> Double {
        guard displayMode != .iconOnly else { return 0 }
        // Hide on arm together with the glyph slide, matching the slot chrome; restore on disarm.
        return armedIconMotion ? tokenChrome.armedTitleOpacity : 1
    }

    private var tokenStretchProgress: CGFloat {
        SwipeActionTokenChromeFace.stretchProgress(context: context, holdsFireFace: holdsFireFace)
    }

    private var tokenRecedeProgress: CGFloat {
        SwipeActionTokenChromeFace.recedeProgress(context: context, holdsFireFace: holdsFireFace)
    }

    private var tokenRecedeOpacity: Double {
        1 - (tokenChrome.nonDestructiveRecedeMaxFade * Double(tokenRecedeProgress))
    }
}

/// Pure fire-face progressions for the `.token` default chrome (issue #116), kept out of the view so
/// Swift Testing can pin the fired-collapse hold contract without rendering.
nonisolated enum SwipeActionTokenChromeFace {
    /// 1 while armed or fired-collapse holding — the capsule keeps filling the live slot, so during the
    /// collapse it tracks the shrinking width and the fire face retreats as one rigid piece. Otherwise the
    /// stretch follows the continuous deformation band.
    static func stretchProgress(context: SwipeActionContext?, holdsFireFace: Bool) -> CGFloat {
        guard
            let context,
            context.isOutermost,
            context.role == .destructive
        else {
            return 0
        }

        if context.isArmed || holdsFireFace {
            return 1
        }

        return context.deformationProgress
    }

    /// Non-destructive tokens fade behind the arming destructive capsule so the destructive takeover reads
    /// as the dominant action. They keep their full size — only opacity changes — so every token holds the
    /// height it settled at on open; sizes change only during open/close, matching the system Mail row.
    /// The fired-collapse hold pins the fade at 1: receded siblings must not fade back in while the fired
    /// side retreats.
    static func recedeProgress(context: SwipeActionContext?, holdsFireFace: Bool) -> CGFloat {
        guard let context else { return 0 }
        guard !(context.isOutermost && context.role == .destructive) else { return 0 }

        if context.isArmed || holdsFireFace {
            return 1
        }

        return min(max(context.deformationProgress, 0), 1)
    }
}

/// Pure geometry for the `.token` default token chrome (issues #40, #41, and #43).
///
/// The token profile owns the visible chrome size while the action slot stays the hit target. Keeping the
/// math here lets Swift Testing pin clamp, stretch, and fire-slide contracts directly, without rendering.
nonisolated struct SwipeActionTokenLayout: Equatable, Sendable {
    let metrics: SwipeActionDefaultLabelMetrics
    let profile: SwipeActionTokenProfile

    init(
        metrics: SwipeActionDefaultLabelMetrics,
        profile: SwipeActionTokenProfile = .iOSDefault
    ) {
        self.metrics = metrics
        self.profile = profile.sanitized(fallback: .iOSDefault)
    }

    var titleSpacing: CGFloat {
        profile.titleSpacing
    }

    /// Token size fitted to the resting action slot. Width clamps to the slot's safe available space and
    /// never below the icon slot; height follows the profile unless a very narrow slot forces a smaller
    /// capsule that still preserves a valid rounded shape.
    func restingSize(slotWidth: CGFloat) -> CGSize {
        let fitWidth = slotWidth - (profile.stretchHorizontalInset * 2)
        let effectiveWidth = min(profile.restingWidth, max(metrics.iconSlotSize, fitWidth))
        let effectiveHeight = min(
            max(metrics.iconSlotSize, profile.restingHeight),
            effectiveWidth
        )
        return CGSize(width: effectiveWidth, height: effectiveHeight)
    }

    /// Resting visual frame inside an action slot, including the even-gap distribution offset.
    func restingFrame(slotWidth: CGFloat, position: Int, count: Int) -> CGRect {
        let safeSlotWidth = Self.positiveDistance(
            slotWidth,
            fallback: profile.restingWidth + (profile.stretchHorizontalInset * 2)
        )
        let size = restingSize(slotWidth: safeSlotWidth)
        let centerX =
            (safeSlotWidth / 2)
            + evenGapOffset(
                slotWidth: safeSlotWidth,
                position: position,
                count: count
            )

        return CGRect(
            x: centerX - (size.width / 2),
            y: 0,
            width: size.width,
            height: size.height
        )
    }

    /// Capsule frame for destructive stretch, derived from edges so *both* resting gaps stay fixed.
    ///
    /// The outermost destructive token grows to fill the over-swipe-expanded live slot while keeping its
    /// resting margin on both sides — the gap to the physical row edge and the gap to the nearest sibling /
    /// content never change (system Mail). Only the slot's expansion lengthens the capsule in between.
    ///
    /// The math is side-agnostic. The live slot's coordinate space already pins its physical row edge
    /// (leading keeps `x == 0`; trailing keeps `x == liveSlotWidth`), so holding the resting left margin and
    /// growing the right edge to `liveSlotWidth - rightMargin` resolves, on screen, to a fixed outer edge and
    /// an inner edge that follows content — mirrored for either side. The side is carried only through
    /// `position` (and thus the resting frame's even-gap offset), never branched on here.
    func capsuleFrame(
        restSlotWidth: CGFloat,
        liveSlotWidth: CGFloat,
        position: Int,
        count: Int,
        stretchProgress: CGFloat
    ) -> CGRect {
        let safeRestSlotWidth = Self.positiveDistance(
            restSlotWidth,
            fallback: profile.restingWidth + (profile.stretchHorizontalInset * 2)
        )
        let restingFrame = restingFrame(
            slotWidth: safeRestSlotWidth,
            position: position,
            count: count
        )

        // `stretchProgress` only gates whether this token stretches at all (non-destructive / non-outermost
        // tokens pass 0): the fill tracks the live slot width directly, so the fixed outer edge never lags
        // behind the drag the way a progress-interpolated width would.
        guard Self.clamp(stretchProgress) > 0 else {
            return restingFrame
        }

        let safeLiveSlotWidth = max(
            safeRestSlotWidth,
            Self.positiveDistance(liveSlotWidth, fallback: safeRestSlotWidth)
        )

        let rightMargin = max(0, safeRestSlotWidth - restingFrame.maxX)
        let maxX = max(restingFrame.maxX, safeLiveSlotWidth - rightMargin)

        return CGRect(
            x: restingFrame.minX,
            y: 0,
            width: maxX - restingFrame.minX,
            height: restingFrame.height
        )
    }

    /// Horizontal shift from a token's slot center to its evenly-distributed position, so that across
    /// `count` equal slots every gap is equal — content↔token, token↔token, and token↔edge — as in the
    /// system Mail row. `position` is the left-to-right index (0 = nearest the left region edge); the shift
    /// is symmetric about the middle, so it applies unchanged to either side. A single token stays centered.
    func evenGapOffset(slotWidth: CGFloat, position: Int, count: Int) -> CGFloat {
        guard count > 1 else { return 0 }
        let tokenWidth = restingSize(slotWidth: slotWidth).width
        let n = CGFloat(count)
        let p = CGFloat(position)
        return (slotWidth - tokenWidth) * (((n - 1) / 2) - p) / (n + 1)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    private static func positiveDistance(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return fallback }
        return value
    }
}
