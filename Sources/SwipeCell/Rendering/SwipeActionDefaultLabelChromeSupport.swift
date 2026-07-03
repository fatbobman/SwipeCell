import SwiftUI

nonisolated struct SwipeActionDefaultLabelMetrics: Equatable, Sendable {
    static let iconSlotSize: CGFloat = SwipeActionDefaultLabelStyle.defaultIconSlotSize
    static let textSlotHeight: CGFloat = SwipeActionDefaultLabelStyle.defaultTextSlotHeight
    static let slotSpacing: CGFloat = SwipeCellDefaultPresentationConfiguration.defaultLabelMetrics.slotSpacing
    static let textHorizontalInset: CGFloat =
        SwipeCellDefaultPresentationConfiguration.defaultLabelMetrics.textHorizontalInset
    static let armedFrontInset: CGFloat = SwipeCellDefaultPresentationConfiguration.defaultLabelMetrics.armedFrontInset
    static let totalSlotHeight: CGFloat = iconSlotSize + slotSpacing + textSlotHeight

    let iconSlotSize: CGFloat
    let textSlotHeight: CGFloat
    let slotSpacing: CGFloat
    let textHorizontalInset: CGFloat
    let armedFrontInset: CGFloat

    var totalSlotHeight: CGFloat {
        iconSlotSize + slotSpacing + textSlotHeight
    }

    var titleSlotCenterY: CGFloat {
        iconSlotSize
            + slotSpacing
            + (textSlotHeight / 2)
    }

    init(
        iconSlotSize: CGFloat = Self.iconSlotSize,
        textSlotHeight: CGFloat = Self.textSlotHeight,
        slotSpacing: CGFloat = Self.slotSpacing,
        textHorizontalInset: CGFloat = Self.textHorizontalInset,
        armedFrontInset: CGFloat = Self.armedFrontInset
    ) {
        self.iconSlotSize = SwipeActionDefaultLabelStyle.sanitizedPositiveMetric(
            iconSlotSize,
            fallback: Self.iconSlotSize
        )
        self.textSlotHeight = SwipeActionDefaultLabelStyle.sanitizedPositiveMetric(
            textSlotHeight,
            fallback: Self.textSlotHeight
        )
        self.slotSpacing = SwipeActionDefaultLabelStyle.sanitizedPositiveMetric(
            slotSpacing,
            fallback: Self.slotSpacing
        )
        self.textHorizontalInset = max(
            0,
            textHorizontalInset.isFinite ? textHorizontalInset : Self.textHorizontalInset
        )
        self.armedFrontInset = max(0, armedFrontInset.isFinite ? armedFrontInset : Self.armedFrontInset)
    }

    init(style: SwipeActionDefaultLabelStyle) {
        self.init(
            iconSlotSize: style.iconSlotSize,
            textSlotHeight: style.textSlotHeight
        )
    }

    func titleSlotWidth(in width: CGFloat) -> CGFloat {
        max(0, width - (textHorizontalInset * 2))
    }
}

/// The action's resting slot width (before any over-swipe expansion), injected by the action shell so the
/// token chrome sizes itself from the rest slot rather than the live, expanding one. 0 means unset, in
/// which case the chrome falls back to its live width.
private struct SwipeActionRestSlotWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct SwipeActionTokenOffsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

/// Render-only bridge from the action shell to the default slot chrome; custom labels keep owning their
/// own destructive release artwork through `SwipeActionContext`.
private struct SwipeActionSuppressesSlotTitleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

/// Fired-collapse fire-face hold (issue #116): `true` only while the coordinator's `takeoverSettlingSide`
/// matches the mounted side — the close settle that follows a destructive fire. The default chromes keep
/// the full fire face (glyph pinned, capsule stretched, siblings receded, title hidden) so a fired action
/// never replays disarm vocabulary; drag-back and release-to-open stay `false` and disarm normally.
/// Render-only bridge like `swipeActionSuppressesSlotTitle`: custom labels do not receive this signal.
private struct SwipeActionHoldsFireFaceKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var swipeActionRestSlotWidth: CGFloat {
        get { self[SwipeActionRestSlotWidthKey.self] }
        set { self[SwipeActionRestSlotWidthKey.self] = newValue }
    }

    var swipeActionTokenOffset: CGFloat {
        get { self[SwipeActionTokenOffsetKey.self] }
        set { self[SwipeActionTokenOffsetKey.self] = newValue }
    }

    var swipeActionSuppressesSlotTitle: CGFloat {
        get { self[SwipeActionSuppressesSlotTitleKey.self] }
        set { self[SwipeActionSuppressesSlotTitleKey.self] = newValue }
    }

    var swipeActionHoldsFireFace: Bool {
        get { self[SwipeActionHoldsFireFaceKey.self] }
        set { self[SwipeActionHoldsFireFaceKey.self] = newValue }
    }
}

/// Pure armed-face target shared by the default slot and token chromes, kept out of the views so Swift
/// Testing can pin the fired-collapse hold contract without rendering.
nonisolated enum SwipeActionArmedIconMotionTarget {
    /// `holdsFireFace` keeps the armed glyph motion through the fired collapse while `isArmed` relaxes;
    /// fired and cancelled must not share motion vocabulary, so only the non-fired paths (both signals
    /// false) release the glyph back toward its resting anchor.
    static func resolve(
        hasIcon: Bool,
        context: SwipeActionContext?,
        holdsFireFace: Bool
    ) -> Bool {
        guard
            hasIcon,
            let context,
            context.isOutermost,
            context.role == .destructive,
            context.isArmed || holdsFireFace
        else {
            return false
        }

        return true
    }
}

struct SwipeActionArmedLabelMotionState<Content: View>: View {
    let hasIcon: Bool
    let context: SwipeActionContext?
    let armedGlyphSlideDuration: TimeInterval
    @ViewBuilder let content: (Bool) -> Content

    @Environment(\.swipeActionHoldsFireFace) private var holdsFireFace
    @State private var renderedArmedIconMotion = false
    @State private var appliedArmChangeID = 0
    @State private var pendingAnimatedArmChangeID: Int?
    @State private var pendingAnimatedArmTarget: Bool?
    @State private var pendingUnmarkedArmChangeID: Int?
    @State private var pendingUnmarkedArmTarget: Bool?
    @State private var hasInitializedArmState = false

    var body: some View {
        content(effectiveArmedIconMotion)
            .onAppear {
                renderedArmedIconMotion = targetArmedIconMotion
                appliedArmChangeID = currentArmChangeID
                pendingAnimatedArmChangeID = nil
                pendingAnimatedArmTarget = nil
                pendingUnmarkedArmChangeID = nil
                pendingUnmarkedArmTarget = nil
                hasInitializedArmState = true
            }
            .onChange(of: targetArmedIconMotion) { _, _ in
                synchronizeRenderedArmedIconMotion()
            }
            .onChange(of: currentArmChangeID) { _, _ in
                synchronizeRenderedArmedIconMotion()
            }
    }

    private var targetArmedIconMotion: Bool {
        SwipeActionArmedIconMotionTarget.resolve(
            hasIcon: hasIcon,
            context: context,
            holdsFireFace: holdsFireFace
        )
    }

    private var effectiveArmedIconMotion: Bool {
        hasInitializedArmState ? renderedArmedIconMotion : targetArmedIconMotion
    }

    private var currentArmChangeID: Int {
        context?.armChangeID ?? 0
    }

    private var hasNewExplicitArmChange: Bool {
        currentArmChangeID != appliedArmChangeID && context?.armChangeKind != nil
    }

    private func synchronizeRenderedArmedIconMotion() {
        let changeID = currentArmChangeID
        let newValue = targetArmedIconMotion

        if hasNewExplicitArmChange {
            appliedArmChangeID = changeID
            pendingUnmarkedArmChangeID = nil
            pendingUnmarkedArmTarget = nil
            pendingAnimatedArmChangeID = changeID
            pendingAnimatedArmTarget = newValue
            // iOS direct-touch disables animations while tracking content. Defer the chrome update so the
            // icon position and title opacity get their own transaction instead of inheriting that hard cut.
            // `armChangeID` is observed separately so enterFire and exitFire both take this animated path.
            DispatchQueue.main.async {
                guard pendingAnimatedArmChangeID == changeID, pendingAnimatedArmTarget == newValue else {
                    return
                }
                withAnimation(.snappy(duration: armedGlyphSlideDuration)) {
                    renderedArmedIconMotion = newValue
                }
                if pendingAnimatedArmChangeID == changeID, pendingAnimatedArmTarget == newValue {
                    pendingAnimatedArmChangeID = nil
                    pendingAnimatedArmTarget = nil
                }
            }
            return
        }

        if pendingAnimatedArmChangeID == changeID {
            guard pendingAnimatedArmTarget != newValue else { return }
            pendingAnimatedArmChangeID = nil
            pendingAnimatedArmTarget = nil
        }

        guard renderedArmedIconMotion != newValue || pendingUnmarkedArmTarget != newValue else {
            appliedArmChangeID = changeID
            return
        }

        pendingUnmarkedArmChangeID = changeID
        pendingUnmarkedArmTarget = newValue
        // A direct `isArmed` flip can arrive one body pass before its explicit enter/exit marker on
        // iOS. Delay the non-marker sync by one turn so a real armChangeID can take the animated path.
        DispatchQueue.main.async {
            guard pendingUnmarkedArmChangeID == changeID, pendingUnmarkedArmTarget == newValue else {
                return
            }
            if pendingAnimatedArmChangeID == changeID {
                return
            }
            renderedArmedIconMotion = newValue
            appliedArmChangeID = changeID
            pendingUnmarkedArmChangeID = nil
            pendingUnmarkedArmTarget = nil
        }
    }
}

extension View {
    func swipeActionArmedIconSlide(
        progress: CGFloat,
        width: CGFloat,
        centerX: CGFloat,
        side: SwipeCellSide?,
        iconSlotSize: CGFloat,
        armedFrontInset: CGFloat
    ) -> some View {
        modifier(
            SwipeActionArmedIconSlide(
                progress: progress,
                width: width,
                centerX: centerX,
                side: side,
                iconSlotSize: iconSlotSize,
                armedFrontInset: armedFrontInset
            )
        )
    }
}

/// Animatable carrier for the destructive arm/disarm icon slide.
///
/// The animated quantity is `progress` (0 = the glyph's base center, 1 = hugging the armed edge), never an
/// absolute, width-derived position. Direct-touch tracking writes row content with animations disabled; animating a
/// width-derived position lets every tracking frame retarget and snap the icon. Driving `animatableData`
/// keeps the slide intact while over-swipe width changes only re-derive the offset for the current progress.
private struct SwipeActionArmedIconSlide: ViewModifier, Animatable {
    var progress: CGFloat
    let width: CGFloat
    let centerX: CGFloat
    let side: SwipeCellSide?
    let iconSlotSize: CGFloat
    let armedFrontInset: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(x: armedOffsetX)
    }

    private var armedOffsetX: CGFloat {
        guard let side else { return 0 }

        let halfSlot = iconSlotSize / 2
        let inset = armedFrontInset
        let edge: CGFloat =
            switch side {
            case .leading:
                max(halfSlot, width - inset - halfSlot)
            case .trailing:
                min(width - halfSlot, inset + halfSlot)
            }
        return (edge - centerX) * progress
    }
}
