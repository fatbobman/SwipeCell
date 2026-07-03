import SwiftUI

nonisolated struct SwipeCellPanelGeometry: Equatable {
    let containerSize: CGSize
    let contentOffset: CGFloat

    var contentProposalSize: CGSize {
        containerSize
    }

    var contentFrame: CGRect {
        CGRect(
            origin: CGPoint(x: contentOffset, y: 0),
            size: contentProposalSize
        )
    }

    var actionBackgroundFrame: CGRect {
        CGRect(origin: .zero, size: containerSize)
    }

    func exposedSide(at point: CGPoint) -> SwipeCellSide? {
        let containerFrame = CGRect(origin: .zero, size: containerSize)
        guard containerFrame.contains(point) else { return nil }

        if contentOffset > 0, point.x < min(contentOffset, containerSize.width) {
            return .leading
        }

        if contentOffset < 0, point.x > max(containerSize.width + contentOffset, 0) {
            return .trailing
        }

        return nil
    }
}

struct SwipeCellActionTapGate {
    enum Resolution: Equatable {
        case ignored
        case immediate
        case afterCollapse
        case triggerAndHoldOpen

        var didTrigger: Bool {
            self != .ignored
        }
    }

    @discardableResult
    static func resolve<CellID: Hashable>(
        _ side: SwipeCellSide,
        for cellID: CellID,
        manager: SwipeCellManager,
        isInteractionEnabled: Bool = true,
        fireTiming: SwipeActionFireTiming = .immediate
    ) -> Resolution {
        guard
            isInteractionEnabled,
            manager.ownsActiveCell(cellID),
            case .open(let openSide) = manager.phase,
            openSide == side,
            manager.markTriggering(side, for: cellID)
        else {
            return .ignored
        }

        return switch fireTiming {
        case .immediate: .immediate
        case .afterCollapse: .afterCollapse
        case .triggerAndHoldOpen: .triggerAndHoldOpen
        }
    }
}

struct SwipeCellContentTapGate {
    enum Resolution: Equatable {
        case ignored
        case closedOwner
        case closedForeignOwner

        var didConsumeTap: Bool {
            self != .ignored
        }
    }

    @discardableResult
    static func close<CellID: Hashable>(
        for cellID: CellID,
        manager: SwipeCellManager,
        isInteractionEnabled: Bool = true,
        onOwnerClose: () -> Void
    ) -> Resolution {
        guard isInteractionEnabled else { return .ignored }

        if manager.ownsActiveCell(cellID) {
            onOwnerClose()
            return manager.close(cellID, reason: .tapContent) ? .closedOwner : .ignored
        }

        if manager.closeForeignVisibleOwner(from: cellID, reason: .tapContent) {
            return .closedForeignOwner
        }

        return .ignored
    }
}

struct SwipeCellContentTapCloseModifier<CellID: Hashable>: ViewModifier {
    let cellID: CellID
    let manager: SwipeCellManager?
    let isInteractionEnabled: Bool
    let canContentTapClose: () -> Bool
    let onOwnerClose: () -> Void

    func body(content: Content) -> some View {
        if isInteractionEnabled, let manager, manager.shouldConsumeContentTap(for: cellID) {
            content.highPriorityGesture(
                TapGesture().onEnded {
                    guard canContentTapClose() else { return }
                    SwipeCellContentTapGate.close(
                        for: cellID,
                        manager: manager,
                        isInteractionEnabled: isInteractionEnabled,
                        onOwnerClose: onOwnerClose
                    )
                }
            )
        } else {
            content
        }
    }
}

struct SwipeCellActionPresentation {
    let isVisible: Bool
    let allowsHitTesting: Bool

    static func visibleSide<CellID: Hashable>(
        for cellID: CellID,
        manager: SwipeCellManager
    ) -> SwipeCellSide? {
        guard manager.ownsActiveCell(cellID) else { return nil }

        switch manager.phase {
        case .revealing:
            return manager.activeSide
        case .open(let side), .triggering(let side):
            return side
        case .closed, .resetting:
            return nil
        }
    }

    init<CellID: Hashable>(
        side: SwipeCellSide,
        cellID: CellID,
        manager: SwipeCellManager
    ) {
        let isVisible = Self.visibleSide(for: cellID, manager: manager) == side
        let allowsHitTesting =
            switch manager.phase {
            case .open(let openSide), .triggering(let openSide):
                openSide == side
            default:
                false
            }

        self.isVisible = isVisible
        self.allowsHitTesting = isVisible && allowsHitTesting
    }
}

struct SwipeCellActionShell<CellID: Hashable, Content: View>: View {
    let cellID: CellID
    let manager: SwipeCellManager
    let contentOffset: CGFloat
    let normalOpenProgress: CGFloat
    let deformationProgress: CGFloat
    let isArmed: Bool
    let armChangeID: Int
    let armChangeKind: SwipeActionArmChangeKind?
    let hapticEvent: SwipeCellHapticEvent?
    let containerWidth: CGFloat
    let leadingGroup: SwipeActionGroup
    let trailingGroup: SwipeActionGroup
    let configuration: SwipeCellConfiguration
    let revealStyle: SwipeActionsRevealStyle
    let settlingSide: SwipeCellSide?
    let takeoverSettlingSide: SwipeCellSide?
    let closeToken: Int
    let closeAnimation: Animation
    let isInteractionEnabled: Bool
    let canContentTapClose: () -> Bool
    let onContentTap: () -> Void
    let onPinnedCloseCompletion: (Int) -> Void
    let onActionTap: (SwipeCellSide, SwipeAction) -> Void
    @ViewBuilder let content: () -> Content

    init(
        cellID: CellID,
        manager: SwipeCellManager,
        contentOffset: CGFloat,
        normalOpenProgress: CGFloat = 0,
        deformationProgress: CGFloat = 0,
        isArmed: Bool = false,
        armChangeID: Int = 0,
        armChangeKind: SwipeActionArmChangeKind? = nil,
        hapticEvent: SwipeCellHapticEvent? = nil,
        containerWidth: CGFloat = 0,
        leadingGroup: SwipeActionGroup,
        trailingGroup: SwipeActionGroup,
        configuration: SwipeCellConfiguration = .platformDefault,
        revealStyle: SwipeActionsRevealStyle = .slot,
        settlingSide: SwipeCellSide? = nil,
        takeoverSettlingSide: SwipeCellSide? = nil,
        closeToken: Int = 0,
        closeAnimation: Animation = .default,
        isInteractionEnabled: Bool = true,
        canContentTapClose: @escaping () -> Bool = { true },
        onContentTap: @escaping () -> Void,
        onPinnedCloseCompletion: @escaping (Int) -> Void = { _ in },
        onActionTap: @escaping (SwipeCellSide, SwipeAction) -> Void = { _, _ in },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cellID = cellID
        self.manager = manager
        self.contentOffset = contentOffset
        self.normalOpenProgress = normalOpenProgress
        self.deformationProgress = deformationProgress
        self.isArmed = isArmed
        self.armChangeID = armChangeID
        self.armChangeKind = armChangeKind
        self.hapticEvent = hapticEvent
        self.containerWidth = containerWidth
        self.leadingGroup = leadingGroup
        self.trailingGroup = trailingGroup
        self.configuration = configuration
        self.revealStyle = revealStyle
        self.settlingSide = settlingSide
        self.takeoverSettlingSide = takeoverSettlingSide
        self.closeToken = closeToken
        self.closeAnimation = closeAnimation
        self.isInteractionEnabled = isInteractionEnabled
        self.canContentTapClose = canContentTapClose
        self.onContentTap = onContentTap
        self.onPinnedCloseCompletion = onPinnedCloseCompletion
        self.onActionTap = onActionTap
        self.content = content
    }

    var body: some View {
        content()
            .transformEnvironment(\.swipeCellNormalOpenProgress) { progress in
                progress = normalOpenProgress
            }
            .contentShape(Rectangle())
            .modifier(
                SwipeCellContentTapCloseModifier(
                    cellID: cellID,
                    manager: manager,
                    isInteractionEnabled: isInteractionEnabled,
                    canContentTapClose: canContentTapClose,
                    onOwnerClose: onContentTap
                )
            )
            .offset(x: contentOffset)
            .background {
                // Background keeps actions out of the row's size calculation while staying below content.
                ZStack {
                    actionLayer
                }
                // Fired-collapse fire-face hold (issue #116): `takeoverSettlingSide` is raised only by the
                // close settle that follows a destructive fire, so the mounted side's default chrome holds
                // its armed face instead of playing disarm vocabulary. Render-only — release/reset
                // ownership, settle pacing, and manager phases stay untouched.
                .environment(\.swipeActionHoldsFireFace, holdsFireFaceForVisibleSide)
            }
            .modifier(
                SwipeCellSensoryFeedbackModifier(
                    event: hapticEvent,
                    policy: configuration.feedback.hapticPolicy
                )
            )
            .clipped()
            .modifier(
                SwipeCellPinnedCloseAnimationModifier(
                    token: closeToken,
                    animation: closeAnimation,
                    onCompletion: onPinnedCloseCompletion
                )
            )
    }

    @ViewBuilder
    private var actionLayer: some View {
        // Build only the active or settling side, so over-swipes cannot reveal stale opposite-side content.
        switch visibleSide {
        case .some(.leading):
            HStack(spacing: 0) {
                actionGroup(side: .leading, group: leadingGroup, isVisible: true)

                Spacer(minLength: 0)
            }
        case .some(.trailing):
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                actionGroup(side: .trailing, group: trailingGroup, isVisible: true)
            }
        case .none:
            EmptyView()
        }
    }

    private var visibleSide: SwipeCellSide? {
        if let visibleSide = SwipeCellActionPresentation.visibleSide(for: cellID, manager: manager) {
            return visibleSide
        }

        if let settlingSide {
            return settlingSide
        }

        guard abs(contentOffset) > 0.5 else { return nil }
        return contentOffset > 0 ? .leading : .trailing
    }

    private var holdsFireFaceForVisibleSide: Bool {
        guard let takeoverSettlingSide else { return false }
        return takeoverSettlingSide == visibleSide
    }

    @ViewBuilder
    private func actionGroup(
        side: SwipeCellSide,
        group: SwipeActionGroup,
        isVisible: Bool
    ) -> some View {
        let slots = orderedSlots(for: side, group: group)

        if slots.isEmpty {
            EmptyView()
        } else if let overlaySlot = destructiveOverlaySlot(in: slots, group: group) {
            let overlayPresentation = slotPresentation(for: overlaySlot, side: side, group: group)
            let overlayActive = overlayPresentation.isTakeoverActive

            // Keep resting slots underneath so takeover reads as destructive coverage instead of a
            // sibling layout jump. The front layer stays mounted while inactive so armed chrome can
            // animate across the fire boundary instead of being recreated already armed.
            ZStack(alignment: actionGroupAlignment(for: side)) {
                HStack(spacing: 0) {
                    ForEach(slots, id: \.id) { slot in
                        let slotPresentation = slotPresentation(for: slot, side: side, group: group)
                        let isOverlaySlot = slot.index == overlaySlot.index

                        actionButton(
                            slot: slot,
                            side: side,
                            group: group,
                            presentation: slotPresentation,
                            isVisible: isVisible && !isOverlaySlot && slotPresentation.isVisible,
                            isAccessibilityVisible: isVisible && !isOverlaySlot && !overlayActive
                                && slotPresentation.isAccessibilityVisible,
                            isInteractionEnabled: isInteractionEnabled && !isOverlaySlot && !overlayActive
                                && slotPresentation.allowsHitTesting,
                            width: overlayActive
                                ? underlayWidth(for: slot, overlaySlot: overlaySlot, group: group)
                                : nil,
                            suppressesSlotTitle: overlayActive ? false : nil
                        )
                    }
                }
                .frame(
                    width: actionGroupWidth(for: group),
                    alignment: actionGroupAlignment(for: side)
                )

                actionButton(
                    slot: overlaySlot,
                    side: side,
                    group: group,
                    presentation: overlayPresentation,
                    isVisible: isVisible && overlayPresentation.isVisible,
                    isAccessibilityVisible: isVisible && overlayPresentation.isAccessibilityVisible,
                    isInteractionEnabled: isInteractionEnabled && overlayPresentation.allowsHitTesting,
                    zIndex: Double(group.count + 1),
                    usesTakeoverCoverage: overlayPresentation.isTakeoverActive,
                    takeoverBaseWidth: group.count > 1
                        ? sharedDestructiveOverdragWidth(for: group)
                        : ordinaryOutermostWidth(for: group)
                )
            }
            .frame(
                width: actionGroupWidth(for: group),
                alignment: actionGroupAlignment(for: side)
            )
        } else {
            HStack(spacing: 0) {
                ForEach(slots, id: \.id) { slot in
                    let slotPresentation = slotPresentation(for: slot, side: side, group: group)

                    actionButton(
                        slot: slot,
                        side: side,
                        group: group,
                        presentation: slotPresentation,
                        isVisible: isVisible && slotPresentation.isVisible,
                        isAccessibilityVisible: isVisible && slotPresentation.isAccessibilityVisible,
                        isInteractionEnabled: isInteractionEnabled && slotPresentation.allowsHitTesting
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(
        slot: SwipeActionSlot,
        side: SwipeCellSide,
        group: SwipeActionGroup,
        presentation: SwipeActionSlotPresentation,
        isVisible: Bool,
        isAccessibilityVisible: Bool,
        isInteractionEnabled: Bool,
        width: CGFloat? = nil,
        zIndex: Double? = nil,
        suppressesSlotTitle: Bool? = nil,
        usesTakeoverCoverage: Bool = false,
        takeoverBaseWidth: CGFloat? = nil
    ) -> some View {
        let resolvedWidth = width ?? presentation.width
        SwipeActionButton(
            cellID: cellID,
            manager: manager,
            side: side,
            action: slot.action,
            context: context(
                side: side,
                index: slot.index,
                role: slot.action.role.kind,
                group: group
            ),
            width: resolvedWidth,
            slotDistance: group.actionWidth,
            configuration: configuration,
            revealStyle: revealStyle,
            revealProgress: presentation.revealProgress,
            tokenOffset: tokenOffset(for: slot, side: side, group: group),
            contentOffset: contentOffset,
            zIndex: zIndex ?? presentation.zIndex,
            suppressesSlotTitle: suppressesSlotTitle ?? presentation.suppressesSlotTitle,
            usesTakeoverCoverage: usesTakeoverCoverage,
            takeoverBaseWidth: takeoverBaseWidth ?? resolvedWidth,
            takeoverIsActive: usesTakeoverCoverage,
            isVisible: isVisible,
            isAccessibilityVisible: isAccessibilityVisible,
            isInteractionEnabled: isInteractionEnabled,
            onTap: {
                onActionTap(side, slot.action)
            }
        )
    }

    private func destructiveOverlaySlot(
        in slots: [SwipeActionSlot],
        group: SwipeActionGroup
    ) -> SwipeActionSlot? {
        guard revealStyle == .slot, group.allowsDestructive else {
            return nil
        }

        guard let outermost = slots.first(where: { $0.index == 0 }) else {
            return nil
        }

        guard outermost.action.role.kind == .destructive else {
            return nil
        }

        return outermost
    }

    private func actionGroupWidth(for group: SwipeActionGroup) -> CGFloat {
        let revealedWidth = abs(finiteDistance(contentOffset))
        let normalOpenExtent = positiveDistance(group.normalOpenExtent)

        return normalOpenExtent + max(0, revealedWidth - normalOpenExtent)
    }

    private func underlayWidth(
        for slot: SwipeActionSlot,
        overlaySlot: SwipeActionSlot,
        group: SwipeActionGroup
    ) -> CGFloat {
        if group.count > 1 {
            return sharedDestructiveOverdragWidth(for: group)
        }

        guard slot.index == overlaySlot.index else {
            return group.actionWidth
        }

        return ordinaryOutermostWidth(for: group)
    }

    private func ordinaryOutermostWidth(for group: SwipeActionGroup) -> CGFloat {
        let revealedWidth = abs(finiteDistance(contentOffset))
        let normalOpenExtent = positiveDistance(group.normalOpenExtent)
        let overswipeExpansion = max(0, revealedWidth - normalOpenExtent)

        return positiveDistance(group.actionWidth) + overswipeExpansion
    }

    private func sharedDestructiveOverdragWidth(for group: SwipeActionGroup) -> CGFloat {
        let actionWidth = positiveDistance(group.actionWidth)
        let count = max(group.count, 1)
        let revealedWidth = abs(finiteDistance(contentOffset))
        let normalOpenExtent = positiveDistance(group.normalOpenExtent)
        let overswipeExpansion = max(0, revealedWidth - normalOpenExtent)

        return actionWidth + (overswipeExpansion / CGFloat(count))
    }

    private func actionGroupAlignment(for side: SwipeCellSide) -> Alignment {
        switch side {
        case .leading:
            .leading
        case .trailing:
            .trailing
        }
    }

    private func orderedSlots(
        for side: SwipeCellSide,
        group: SwipeActionGroup
    ) -> [SwipeActionSlot] {
        let slots = group.actions.enumerated().map { index, action in
            SwipeActionSlot(index: index, action: action)
        }

        switch side {
        case .leading:
            return slots
        case .trailing:
            return slots.reversed()
        }
    }

    private func context(
        side: SwipeCellSide,
        index: Int,
        role: SwipeActionRoleKind,
        group: SwipeActionGroup
    ) -> SwipeActionContext {
        SwipeActionContext(
            side: side,
            index: index,
            count: group.count,
            isOutermost: index == 0,
            role: role,
            normalOpenProgress: normalOpenProgress,
            deformationProgress: deformationProgress,
            isArmed: isArmed,
            armChangeID: armChangeID,
            armChangeKind: armChangeKind
        )
    }

    private func slotPresentation(
        for slot: SwipeActionSlot,
        side: SwipeCellSide,
        group: SwipeActionGroup
    ) -> SwipeActionSlotPresentation {
        SwipeActionSlotPresentation.resolve(
            revealStyle: revealStyle,
            side: side,
            slotIndex: slot.index,
            slotCount: group.count,
            role: slot.action.role.kind,
            groupAllowsDestructive: group.allowsDestructive,
            normalOpenProgress: normalOpenProgress,
            contentOffset: contentOffset,
            actionWidth: group.actionWidth,
            normalOpenExtent: group.normalOpenExtent,
            deformationProgress: deformationProgress,
            isArmed: isArmed,
            isTriggering: isTriggering(side: side),
            isTakeoverSettling: takeoverSettlingSide == side
        )
    }

    private func isTriggering(side: SwipeCellSide) -> Bool {
        guard case .triggering(let triggeringSide) = manager.phase else {
            return false
        }

        return triggeringSide == side
    }

    private func tokenOffset(
        for slot: SwipeActionSlot,
        side: SwipeCellSide,
        group: SwipeActionGroup
    ) -> CGFloat {
        SwipeCellTokenOrdinaryOverOpenOffset.offset(
            side: side,
            slotIndex: slot.index,
            revealStyle: revealStyle,
            allowsDestructive: group.allowsDestructive,
            contentOffset: contentOffset,
            normalOpenExtent: group.normalOpenExtent
        )
    }

    private func positiveDistance(_ value: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return 0 }
        return value
    }

    private func finiteDistance(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return value
    }
}

/// Pure per-slot presentation derived from existing interaction state. It may change default chrome
/// geometry, coverage, and availability, but must not own activation, release, or manager transitions.
nonisolated struct SwipeActionSlotPresentation: Equatable, Sendable {
    let width: CGFloat
    let revealProgress: CGFloat
    let zIndex: Double
    let isVisible: Bool
    let allowsHitTesting: Bool
    let isAccessibilityVisible: Bool
    let suppressesSlotTitle: Bool
    let isTakeoverActive: Bool

    static func resolve(
        revealStyle: SwipeActionsRevealStyle,
        side _: SwipeCellSide,
        slotIndex: Int,
        slotCount: Int,
        role: SwipeActionRoleKind,
        groupAllowsDestructive: Bool,
        normalOpenProgress: CGFloat,
        contentOffset: CGFloat,
        actionWidth: CGFloat,
        normalOpenExtent: CGFloat,
        deformationProgress: CGFloat,
        isArmed: Bool,
        isTriggering: Bool,
        isTakeoverSettling: Bool
    ) -> SwipeActionSlotPresentation {
        let takeover = isSlotDestructiveTakeover(
            revealStyle: revealStyle,
            groupAllowsDestructive: groupAllowsDestructive,
            slotCount: slotCount,
            deformationProgress: deformationProgress,
            isArmed: isArmed,
            isTriggering: isTriggering,
            isTakeoverSettling: isTakeoverSettling
        )
        let isCoveredSibling = takeover && slotIndex != 0
        let suppressesSlotTitle = suppressesDestructiveSlotTitle(
            revealStyle: revealStyle,
            groupAllowsDestructive: groupAllowsDestructive,
            slotIndex: slotIndex,
            role: role,
            deformationProgress: deformationProgress,
            isArmed: isArmed,
            isTriggering: isTriggering,
            isTakeoverSettling: isTakeoverSettling
        )
        let ordinaryRevealProgress = SwipeActionSlotRevealProgress.progress(
            for: revealStyle,
            normalOpenProgress: normalOpenProgress,
            contentOffset: contentOffset,
            actionWidth: actionWidth,
            normalOpenExtent: normalOpenExtent,
            slotIndex: slotIndex,
            slotCount: slotCount
        )
        let revealProgress =
            takeover && slotIndex == 0
            ? 1
            : SwipeActionTokenFireFaceRevealProgress.progress(
                for: revealStyle,
                ordinaryProgress: ordinaryRevealProgress,
                holdsFireFace: isTakeoverSettling
            )

        return SwipeActionSlotPresentation(
            width: width(
                revealStyle: revealStyle,
                slotIndex: slotIndex,
                slotCount: slotCount,
                role: role,
                groupAllowsDestructive: groupAllowsDestructive,
                contentOffset: contentOffset,
                actionWidth: actionWidth,
                normalOpenExtent: normalOpenExtent,
                deformationProgress: deformationProgress,
                isArmed: isArmed,
                isTriggering: isTriggering,
                isTakeoverSettling: isTakeoverSettling
            ),
            revealProgress: revealProgress,
            zIndex: zIndex(slotIndex: slotIndex, slotCount: slotCount),
            isVisible: true,
            allowsHitTesting: !isCoveredSibling,
            isAccessibilityVisible: !isCoveredSibling,
            suppressesSlotTitle: suppressesSlotTitle,
            isTakeoverActive: takeover
        )
    }

    private static func width(
        revealStyle: SwipeActionsRevealStyle,
        slotIndex: Int,
        slotCount: Int,
        role: SwipeActionRoleKind,
        groupAllowsDestructive: Bool,
        contentOffset: CGFloat,
        actionWidth: CGFloat,
        normalOpenExtent: CGFloat,
        deformationProgress: CGFloat,
        isArmed: Bool,
        isTriggering: Bool,
        isTakeoverSettling: Bool
    ) -> CGFloat {
        let safeActionWidth = positiveDistance(actionWidth)
        let revealedWidth = abs(finiteDistance(contentOffset))
        let safeNormalOpenExtent = positiveDistance(normalOpenExtent)
        let overswipeExpansion = max(0, revealedWidth - safeNormalOpenExtent)
        let ordinaryWidth = ordinarySlotWidth(
            revealStyle: revealStyle,
            slotIndex: slotIndex,
            groupAllowsDestructive: groupAllowsDestructive,
            slotCount: slotCount,
            actionWidth: safeActionWidth,
            overswipeExpansion: overswipeExpansion
        )

        guard slotIndex == 0 else {
            return ordinaryWidth
        }

        let takeoverProgress = destructiveTakeoverCoverageProgress(
            revealStyle: revealStyle,
            groupAllowsDestructive: groupAllowsDestructive,
            slotCount: slotCount,
            deformationProgress: deformationProgress,
            isArmed: isArmed,
            isTriggering: isTriggering,
            isTakeoverSettling: isTakeoverSettling
        )

        if role == .destructive, takeoverProgress > 0 {
            return ordinaryWidth + ((revealedWidth - ordinaryWidth) * takeoverProgress)
        }

        // Geometry-only coverage: ordinary over-drag follows the finger, while arming remains model-owned.
        return ordinaryWidth
    }

    private static func ordinarySlotWidth(
        revealStyle: SwipeActionsRevealStyle,
        slotIndex: Int,
        groupAllowsDestructive: Bool,
        slotCount: Int,
        actionWidth: CGFloat,
        overswipeExpansion: CGFloat
    ) -> CGFloat {
        guard revealStyle == .slot, groupAllowsDestructive, slotCount > 1 else {
            return slotIndex == 0 ? actionWidth + overswipeExpansion : actionWidth
        }

        return actionWidth + (overswipeExpansion / CGFloat(slotCount))
    }

    private static func isSlotDestructiveTakeover(
        revealStyle: SwipeActionsRevealStyle,
        groupAllowsDestructive: Bool,
        slotCount: Int,
        deformationProgress: CGFloat,
        isArmed: Bool,
        isTriggering: Bool,
        isTakeoverSettling: Bool
    ) -> Bool {
        destructiveTakeoverCoverageProgress(
            revealStyle: revealStyle,
            groupAllowsDestructive: groupAllowsDestructive,
            slotCount: slotCount,
            deformationProgress: deformationProgress,
            isArmed: isArmed,
            isTriggering: isTriggering,
            isTakeoverSettling: isTakeoverSettling
        ) > 0
    }

    private static func destructiveTakeoverCoverageProgress(
        revealStyle: SwipeActionsRevealStyle,
        groupAllowsDestructive: Bool,
        slotCount: Int,
        deformationProgress: CGFloat,
        isArmed: Bool,
        isTriggering: Bool,
        isTakeoverSettling: Bool
    ) -> CGFloat {
        guard revealStyle == .slot, groupAllowsDestructive else { return 0 }
        guard !(isArmed || isTriggering || isTakeoverSettling) else { return 1 }

        let progress = min(max(finiteDistance(deformationProgress), 0), 1)
        guard slotCount > 1 else { return progress }

        // Multi-action destructive rows use the open-to-fire span only for shared slot stretch. The
        // destructive coverage starts at the same fire boundary that drives the armed icon slide, so
        // the solid expansion and glyph motion read as one combined transition.
        return progress >= 1 ? 1 : 0
    }

    private static func suppressesDestructiveSlotTitle(
        revealStyle: SwipeActionsRevealStyle,
        groupAllowsDestructive: Bool,
        slotIndex: Int,
        role: SwipeActionRoleKind,
        deformationProgress: CGFloat,
        isArmed: Bool,
        isTriggering: Bool,
        isTakeoverSettling: Bool
    ) -> Bool {
        guard
            revealStyle == .slot,
            groupAllowsDestructive,
            slotIndex == 0,
            role == .destructive
        else {
            return false
        }

        // Single-action destructive coverage follows the reverse deformation band for geometry, but
        // default-title suppression belongs to the fire/trigger/hold face so the title restores below it.
        if isArmed || isTriggering || isTakeoverSettling {
            return true
        }

        return min(max(finiteDistance(deformationProgress), 0), 1) >= 1
    }

    private static func zIndex(slotIndex: Int, slotCount: Int) -> Double {
        Double(max(0, slotCount - max(0, slotIndex)))
    }

    private static func positiveDistance(_ value: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return 0 }
        return value
    }

    private static func finiteDistance(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return value
    }
}

private struct SwipeActionSlot: Identifiable {
    let index: Int
    let action: SwipeAction

    var id: AnyHashable {
        action.id
    }
}

nonisolated struct SwipeActionSlotRevealProgress {
    static func progress(
        for revealStyle: SwipeActionsRevealStyle,
        normalOpenProgress: CGFloat,
        contentOffset: CGFloat,
        actionWidth: CGFloat,
        normalOpenExtent: CGFloat,
        slotIndex: Int,
        slotCount: Int = 1
    ) -> CGFloat {
        switch revealStyle {
        case .slot:
            stackedSlotProgress(
                contentOffset: contentOffset,
                actionWidth: actionWidth,
                normalOpenExtent: normalOpenExtent,
                slotIndex: slotIndex,
                slotCount: slotCount
            )
        case .token:
            slotLocalProgress(
                contentOffset: contentOffset,
                actionWidth: actionWidth,
                normalOpenExtent: normalOpenExtent,
                slotIndex: slotIndex
            )
        }
    }

    private static func slotLocalProgress(
        contentOffset: CGFloat,
        actionWidth: CGFloat,
        normalOpenExtent: CGFloat,
        slotIndex: Int
    ) -> CGFloat {
        guard actionWidth > 0, normalOpenExtent > 0 else { return 0 }

        // Slot indices are semantic outermost order; trailing may render reversed, but reveal math must not.
        let revealedWidth = min(abs(contentOffset), normalOpenExtent)
        let slotStart = CGFloat(max(slotIndex, 0)) * actionWidth
        let progress = (revealedWidth - slotStart) / actionWidth

        return min(max(progress, 0), 1)
    }

    private static func stackedSlotProgress(
        contentOffset: CGFloat,
        actionWidth: CGFloat,
        normalOpenExtent: CGFloat,
        slotIndex _: Int,
        slotCount: Int
    ) -> CGFloat {
        guard actionWidth > 0, normalOpenExtent > 0 else { return 0 }

        let visibleWidth = stackedVisibleWidth(
            contentOffset: contentOffset,
            actionWidth: actionWidth,
            slotCount: slotCount
        )
        let progress = visibleWidth / actionWidth

        return min(max(progress, 0), 1)
    }

    static func stackedVisibleWidth(
        contentOffset: CGFloat,
        actionWidth: CGFloat,
        slotCount: Int
    ) -> CGFloat {
        guard actionWidth > 0, slotCount > 0 else { return 0 }

        let normalOpenExtent = actionWidth * CGFloat(slotCount)
        let revealedWidth = min(abs(contentOffset), normalOpenExtent)
        let visibleWidth = revealedWidth / CGFloat(slotCount)

        return min(max(visibleWidth, 0), actionWidth)
    }
}

nonisolated enum SwipeActionTokenFireFaceRevealProgress {
    /// Fired-collapse hold covers the action-level token transform as well as the default chrome.
    /// Holding `revealProgress` at 1 keeps outer scale/opacity from playing ordinary close vocabulary
    /// while the side envelope retreats.
    static func progress(
        for revealStyle: SwipeActionsRevealStyle,
        ordinaryProgress: CGFloat,
        holdsFireFace: Bool
    ) -> CGFloat {
        guard revealStyle == .token, holdsFireFace else { return ordinaryProgress }
        return 1
    }
}

/// Local visual offset for default `.token` token chrome during non-destructive ordinary over-open.
///
/// The token group rides the content edge one-to-one: all damping and the bounded cap already live in
/// the content rubber band (`SwipeCellInteractionModel.rubberBandedMovement`), so `contentOffset` is the
/// single motion source and must not be re-clamped here. This type only cancels the slot-origin drift
/// that outermost coverage expansion adds, keeping the group pinned to the content edge with stable
/// relative gaps.
nonisolated struct SwipeCellTokenOrdinaryOverOpenOffset {
    static func offset(
        side: SwipeCellSide,
        slotIndex: Int,
        revealStyle: SwipeActionsRevealStyle,
        allowsDestructive: Bool,
        contentOffset: CGFloat,
        normalOpenExtent: CGFloat
    ) -> CGFloat {
        guard revealStyle == .token, !allowsDestructive, normalOpenExtent > 0 else { return 0 }

        let revealedWidth = movement(contentOffset, toward: side)
        let extra = max(0, revealedWidth - normalOpenExtent)
        guard extra > 0 else { return 0 }

        let groupOffset = signed(extra, for: side)
        return groupOffset - slotOriginDisplacement(side: side, slotIndex: slotIndex, extra: extra)
    }

    private static func movement(_ contentOffset: CGFloat, toward side: SwipeCellSide) -> CGFloat {
        switch side {
        case .leading:
            max(0, contentOffset)
        case .trailing:
            max(0, -contentOffset)
        }
    }

    private static func signed(_ distance: CGFloat, for side: SwipeCellSide) -> CGFloat {
        switch side {
        case .leading:
            distance
        case .trailing:
            -distance
        }
    }

    private static func slotOriginDisplacement(
        side: SwipeCellSide,
        slotIndex: Int,
        extra: CGFloat
    ) -> CGFloat {
        switch side {
        case .leading:
            slotIndex == 0 ? 0 : extra
        case .trailing:
            -extra
        }
    }
}

private struct SwipeActionButton<CellID: Hashable>: View {
    let cellID: CellID
    let manager: SwipeCellManager
    let side: SwipeCellSide
    let action: SwipeAction
    let context: SwipeActionContext
    let width: CGFloat
    let slotDistance: CGFloat
    let configuration: SwipeCellConfiguration
    let revealStyle: SwipeActionsRevealStyle
    let revealProgress: CGFloat
    let tokenOffset: CGFloat
    let contentOffset: CGFloat
    let zIndex: Double
    let suppressesSlotTitle: Bool
    let usesTakeoverCoverage: Bool
    let takeoverBaseWidth: CGFloat
    let takeoverIsActive: Bool
    let isVisible: Bool
    let isAccessibilityVisible: Bool
    let isInteractionEnabled: Bool
    let onTap: () -> Void

    @Environment(\.swipeActionStyle) private var actionStyle
    @State private var animatedTakeoverProgress: CGFloat
    @State private var animatedTitleSuppression: CGFloat

    private var armedGlyphSlideDuration: TimeInterval {
        SwipeCellDefaultPresentationConfiguration.slotChrome(for: configuration).armedGlyphSlideDuration
    }

    init(
        cellID: CellID,
        manager: SwipeCellManager,
        side: SwipeCellSide,
        action: SwipeAction,
        context: SwipeActionContext,
        width: CGFloat,
        slotDistance: CGFloat,
        configuration: SwipeCellConfiguration,
        revealStyle: SwipeActionsRevealStyle,
        revealProgress: CGFloat,
        tokenOffset: CGFloat,
        contentOffset: CGFloat,
        zIndex: Double,
        suppressesSlotTitle: Bool,
        usesTakeoverCoverage: Bool,
        takeoverBaseWidth: CGFloat,
        takeoverIsActive: Bool,
        isVisible: Bool,
        isAccessibilityVisible: Bool,
        isInteractionEnabled: Bool,
        onTap: @escaping () -> Void
    ) {
        self.cellID = cellID
        self.manager = manager
        self.side = side
        self.action = action
        self.context = context
        self.width = width
        self.slotDistance = slotDistance
        self.configuration = configuration
        self.revealStyle = revealStyle
        self.revealProgress = revealProgress
        self.tokenOffset = tokenOffset
        self.contentOffset = contentOffset
        self.zIndex = zIndex
        self.suppressesSlotTitle = suppressesSlotTitle
        self.usesTakeoverCoverage = usesTakeoverCoverage
        self.takeoverBaseWidth = takeoverBaseWidth
        self.takeoverIsActive = takeoverIsActive
        self.isVisible = isVisible
        self.isAccessibilityVisible = isAccessibilityVisible
        self.isInteractionEnabled = isInteractionEnabled
        self.onTap = onTap
        self._animatedTakeoverProgress = State(initialValue: takeoverIsActive ? 1 : 0)
        self._animatedTitleSuppression = State(initialValue: suppressesSlotTitle ? 1 : 0)
    }

    var body: some View {
        let presentation = SwipeCellActionPresentation(
            side: side,
            cellID: cellID,
            manager: manager
        )

        Button(role: buttonRole) {
            onTap()
        } label: {
            actionStyle.makeBody(configuration: styleConfiguration)
                .environment(\.swipeCellConfiguration, configuration)
                .environment(\.swipeActionsRevealStyle, revealStyle)
                .environment(\.swipeActionTint, action.tint)
                .environment(\.swipeActionSuppressesSlotTitle, animatedTitleSuppression)
                // Resting slot width, so the token sizes its disc from the rest slot instead of the
                // live width that expands under over-swipe.
                .environment(\.swipeActionRestSlotWidth, slotDistance)
                .environment(\.swipeActionTokenOffset, tokenOffset)
        }
        .buttonStyle(.plain)
        .modifier(
            AnimatedTakeoverFrame(
                progress: animatedTakeoverProgress,
                baseWidth: takeoverBaseWidth,
                fullWidth: abs(contentOffset.isFinite ? contentOffset : 0)
            )
        )
        .frame(maxHeight: .infinity)
        .zIndex(zIndex)
        .modifier(
            SwipeActionRevealStyleModifier(
                side: side,
                width: slotDistance,
                progress: revealProgress,
                contentOffset: contentOffset,
                slotIndex: context.index,
                slotCount: context.count,
                usesTakeoverCoverage: usesTakeoverCoverage,
                configuration: configuration,
                revealStyle: revealStyle
            )
        )
        .opacity(isVisible ? 1 : 0)
        .accessibilityHidden(!isAccessibilityVisible)
        .allowsHitTesting(isInteractionEnabled && isVisible && presentation.allowsHitTesting)
        .onChange(of: takeoverIsActive) { _, newValue in
            let target: CGFloat = newValue ? 1 : 0
            guard animatedTakeoverProgress != target else { return }
            let duration = armedGlyphSlideDuration
            DispatchQueue.main.async {
                withAnimation(.snappy(duration: duration)) {
                    animatedTakeoverProgress = target
                }
            }
        }
        .onChange(of: suppressesSlotTitle) { _, newValue in
            let target: CGFloat = newValue ? 1 : 0
            guard animatedTitleSuppression != target else { return }
            let duration = armedGlyphSlideDuration
            DispatchQueue.main.async {
                withAnimation(.snappy(duration: duration)) {
                    animatedTitleSuppression = target
                }
            }
        }
    }

    private var styleConfiguration: SwipeActionStyleConfiguration {
        SwipeActionStyleConfiguration(
            label: SwipeActionStyleConfiguration.Label {
                action.label(for: context)
                    .environment(\.swipeActionContext, context)
                    .environment(\.swipeActionsRevealStyle, revealStyle)
                    .environment(\.swipeActionTint, action.tint)
            },
            context: context,
            tint: action.tint
        )
    }

    private var buttonRole: ButtonRole? {
        context.role == .destructive ? .destructive : nil
    }
}

private struct SwipeActionRevealStyleModifier: ViewModifier {
    let side: SwipeCellSide
    let width: CGFloat
    let progress: CGFloat
    let contentOffset: CGFloat
    let slotIndex: Int
    let slotCount: Int
    let usesTakeoverCoverage: Bool
    let configuration: SwipeCellConfiguration
    let revealStyle: SwipeActionsRevealStyle

    func body(content: Content) -> some View {
        switch revealStyle {
        case .slot:
            content.offset(x: slotOffset)
        case .token:
            // Center anchor pops each token in place; an edge anchor would sweep distant tokens sideways.
            content
                .scaleEffect(scale, anchor: .center)
                .opacity(opacity)
        }
    }

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var slotOffset: CGFloat {
        guard !usesTakeoverCoverage else { return 0 }

        let visibleWidth = SwipeActionSlotRevealProgress.stackedVisibleWidth(
            contentOffset: contentOffset,
            actionWidth: width,
            slotCount: slotCount
        )
        // Ordinary `.slot` stacks divide the currently exposed side width evenly between layers.
        // Later slots therefore move farther per point of drag, so every layer reaches its resting
        // full-width segment at the same normal-open position and close folds back symmetrically.
        let distance = (CGFloat(max(0, slotIndex)) + 1) * max(0, width - visibleWidth)

        switch side {
        case .leading:
            return -distance
        case .trailing:
            return distance
        }
    }

    private var scale: CGFloat {
        configuration.style.tokenRevealMinScale
            + ((1 - configuration.style.tokenRevealMinScale) * clampedProgress)
    }

    private var opacity: Double {
        configuration.style.tokenRevealMinOpacity
            + ((1 - configuration.style.tokenRevealMinOpacity) * Double(clampedProgress))
    }
}

/// Frame-width interpolator for destructive takeover transitions.  Binary `progress` (0 or 1) flips
/// at the fire boundary; SwiftUI interpolates `animatableData` so the solid chrome expands / contracts
/// in the same transaction that drives the armed icon slide, rather than snapping on a `Bool` edge.
private struct AnimatedTakeoverFrame: ViewModifier, Animatable {
    var progress: CGFloat
    let baseWidth: CGFloat
    let fullWidth: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let clamped = min(max(progress, 0), 1)
        let w = baseWidth + (fullWidth - baseWidth) * clamped
        content.frame(width: w)
    }
}

nonisolated enum SwipeCellHapticFeedbackImpactWeight: Equatable, Sendable {
    case light
    case medium
    case heavy
}

nonisolated enum SwipeCellHapticFeedbackRequest: Equatable, Sendable {
    case impact(weight: SwipeCellHapticFeedbackImpactWeight, intensity: Double)
    case selection
}

extension SwipeCellHapticPolicy {
    func feedbackRequest(for kind: SwipeCellHapticEventKind) -> SwipeCellHapticFeedbackRequest? {
        switch (self, kind) {
        case (.disabled, _):
            return nil
        case (.subtle, .arm):
            return .impact(weight: .light, intensity: 0.7)
        case (.standard, .arm):
            return .impact(weight: .medium, intensity: 1)
        case (.prominent, .arm):
            return .impact(weight: .heavy, intensity: 1)
        case (.subtle, .disarm), (.standard, .disarm), (.prominent, .disarm):
            return .selection
        }
    }
}

private struct SwipeCellSensoryFeedbackModifier: ViewModifier {
    let event: SwipeCellHapticEvent?
    let policy: SwipeCellHapticPolicy

    func body(content: Content) -> some View {
        #if os(iOS)
            content.sensoryFeedback(trigger: event) { _, newEvent in
                feedback(for: newEvent)
            }
        #else
            content
        #endif
    }

    #if os(iOS)
        private func feedback(for event: SwipeCellHapticEvent?) -> SensoryFeedback? {
            guard
                let event,
                let request = policy.feedbackRequest(for: event.kind)
            else { return nil }

            switch request {
            case .impact(.light, let intensity):
                return .impact(weight: .light, intensity: intensity)
            case .impact(.medium, let intensity):
                return .impact(weight: .medium, intensity: intensity)
            case .impact(.heavy, let intensity):
                return .impact(weight: .heavy, intensity: intensity)
            case .selection:
                return .selection
            }
        }
    #endif
}
