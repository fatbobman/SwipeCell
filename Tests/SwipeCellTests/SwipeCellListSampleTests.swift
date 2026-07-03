import SwiftUI
import Testing

@_spi(ManualDebug) @testable import SwipeCell

#if canImport(AppKit)
    import AppKit
#endif

@MainActor
@Suite("SwipeCell List sample")
struct SwipeCellListSampleTests {
    @Test("List scope sample type-checks")
    func listScopeSampleTypeChecks() {
        _ = Issue1ListScopeSample().body
    }

    @Test("tap and button sample type-checks")
    func tapAndButtonSampleTypeChecks() {
        _ = IssueTapAndButtonSample().body
    }

    @Test("action shell sample type-checks")
    func actionShellSampleTypeChecks() {
        _ = Issue2ActionShellSample().body
    }

    @Test("public swipe actions sample type-checks")
    func publicSwipeActionsSampleTypeChecks() {
        _ = Issue8SwipeCellActionsSample().body
    }

    @Test("template injected swipe actions sample type-checks")
    func templateInjectedSwipeActionsSampleTypeChecks() {
        _ = Issue17ActionTemplateSample().body
    }

    @Test("container scenario scope overloads type-check")
    func containerScenarioScopeOverloadsTypeCheck() {
        _ = Issue69OwnedContainerScopeSample().body
        _ = Issue69CallerOwnedContainerScopeSample().body
    }

    @Test("normal open progress environment defaults to zero and clamps")
    func normalOpenProgressEnvironmentDefaultsToZeroAndClamps() {
        var values = EnvironmentValues()

        #expect(values.swipeCellNormalOpenProgress == 0)

        values.swipeCellNormalOpenProgress = 0.42
        #expect(values.swipeCellNormalOpenProgress == 0.42)

        values.swipeCellNormalOpenProgress = 1.4
        #expect(values.swipeCellNormalOpenProgress == 1)

        values.swipeCellNormalOpenProgress = -0.2
        #expect(values.swipeCellNormalOpenProgress == 0)
    }

    @Test("slot reveal progress balances visible width across layers")
    func slotRevealProgressBalancesVisibleWidthAcrossLayers() {
        let actionWidth: CGFloat = 60

        let earlyFront = revealProgress(
            .slot,
            contentOffset: 12,
            actionWidth: actionWidth,
            normalOpenExtent: actionWidth * 3,
            slotIndex: 0,
            slotCount: 3
        )
        let earlyMiddle = revealProgress(
            .slot,
            contentOffset: 12,
            actionWidth: actionWidth,
            normalOpenExtent: actionWidth * 3,
            slotIndex: 1,
            slotCount: 3
        )
        let earlyBack = revealProgress(
            .slot,
            contentOffset: 12,
            actionWidth: actionWidth,
            normalOpenExtent: actionWidth * 3,
            slotIndex: 2,
            slotCount: 3
        )

        #expect(abs(earlyFront - (1.0 / 15.0)) < 0.001)
        #expect(earlyFront == earlyMiddle)
        #expect(earlyMiddle == earlyBack)

        let oneThirdOpen = revealProgress(
            .slot,
            contentOffset: 60,
            actionWidth: actionWidth,
            normalOpenExtent: actionWidth * 3,
            slotIndex: 0,
            slotCount: 3
        )

        #expect(abs(oneThirdOpen - (1.0 / 3.0)) < 0.001)
        #expect(
            abs(
                revealProgress(
                    .slot,
                    contentOffset: 60,
                    actionWidth: actionWidth,
                    normalOpenExtent: actionWidth * 3,
                    slotIndex: 1,
                    slotCount: 3
                ) - oneThirdOpen
            ) < 0.001
        )
        #expect(
            revealProgress(
                .slot,
                contentOffset: actionWidth * 3,
                actionWidth: actionWidth,
                normalOpenExtent: actionWidth * 3,
                slotIndex: 0,
                slotCount: 3
            ) == 1
        )
        #expect(
            abs(
                revealProgress(
                    .slot,
                    contentOffset: 12,
                    actionWidth: actionWidth,
                    normalOpenExtent: actionWidth * 2,
                    slotIndex: 0,
                    slotCount: 2
                ) - 0.1
            ) < 0.001
        )
        #expect(
            abs(
                revealProgress(
                    .slot,
                    contentOffset: 60,
                    actionWidth: actionWidth,
                    normalOpenExtent: actionWidth * 2,
                    slotIndex: 0,
                    slotCount: 2
                ) - 0.5
            ) < 0.001
        )
    }

    @Test("slot reveal progress mirrors trailing without reversing or desynchronizing layers")
    func slotRevealProgressMirrorsTrailingWithoutReversingOrDesynchronizingLayers() {
        #expect(abs(revealProgress(.slot, contentOffset: -64, slotIndex: 0, slotCount: 3) - (1.0 / 3.0)) < 0.001)
        #expect(
            abs(revealProgress(.slot, contentOffset: -64, slotIndex: 1, slotCount: 3) - (1.0 / 3.0))
                < 0.001
        )
        #expect(
            abs(revealProgress(.slot, contentOffset: -64, slotIndex: 2, slotCount: 3) - (1.0 / 3.0))
                < 0.001
        )
        #expect(
            revealProgress(.slot, contentOffset: -256, slotIndex: 0, slotCount: 3) == 1
        )
    }

    @Test("token reveal style keeps sequential slot progress")
    func tokenRevealStyleKeepsSequentialSlotProgress() {
        #expect(revealProgress(.token, contentOffset: 32, slotIndex: 0) == 0.5)
        #expect(revealProgress(.token, contentOffset: 32, slotIndex: 1) == 0)
        #expect(revealProgress(.token, contentOffset: 96, slotIndex: 1) == 0.5)
        #expect(revealProgress(.token, contentOffset: -96, slotIndex: 1) == 0.5)
        #expect(revealProgress(.token, contentOffset: -256, slotIndex: 2) == 1)
    }

    @Test("single action reveal matches group progress for slot and token")
    func singleActionRevealMatchesGroupProgressForSlotAndToken() {
        let actionWidth: CGFloat = 64

        for style in [SwipeActionsRevealStyle.slot, .token] {
            #expect(
                abs(
                    revealProgress(
                        style,
                        contentOffset: 32,
                        actionWidth: actionWidth,
                        normalOpenExtent: actionWidth,
                        slotIndex: 0,
                        slotCount: 1
                    ) - 0.5
                ) < 0.001
            )
        }
    }

    @Test("slot presentation stacks outermost above siblings on both sides")
    func slotPresentationStacksOutermostAboveSiblingsOnBothSides() {
        let leadingOuter = slotPresentation(.leading, slotIndex: 0)
        let leadingInner = slotPresentation(.leading, slotIndex: 2)
        let trailingOuter = slotPresentation(.trailing, slotIndex: 0)
        let trailingInner = slotPresentation(.trailing, slotIndex: 2)

        #expect(leadingOuter.zIndex > leadingInner.zIndex)
        #expect(trailingOuter.zIndex > trailingInner.zIndex)
        #expect(leadingOuter.zIndex == trailingOuter.zIndex)
        #expect(leadingInner.zIndex == trailingInner.zIndex)
        #expect(leadingOuter.allowsHitTesting)
        #expect(leadingInner.allowsHitTesting)
    }

    @Test("slot destructive takeover expands outermost and covers siblings")
    func slotDestructiveTakeoverExpandsOutermostAndCoversSiblings() {
        let outer = slotPresentation(
            .trailing,
            slotIndex: 0,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -220,
            isArmed: true
        )
        let sibling = slotPresentation(
            .trailing,
            slotIndex: 1,
            groupAllowsDestructive: true,
            contentOffset: -220,
            isArmed: true
        )

        #expect(outer.width == 220)
        #expect(outer.revealProgress == 1)
        #expect(outer.isVisible)
        #expect(outer.allowsHitTesting)
        #expect(outer.isAccessibilityVisible)
        #expect(outer.suppressesSlotTitle)
        #expect(outer.isTakeoverActive)

        #expect(abs(sibling.width - (64 + (28.0 / 3.0))) < 0.001)
        #expect(sibling.isVisible)
        #expect(sibling.allowsHitTesting == false)
        #expect(sibling.isAccessibilityVisible == false)
        #expect(sibling.isTakeoverActive)
    }

    @Test("multi-action destructive lead-in stretches slots before takeover")
    func multiActionDestructiveLeadInStretchesSlotsBeforeTakeover() {
        let outer = slotPresentation(
            .trailing,
            slotIndex: 0,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -220,
            deformationProgress: 0.25
        )
        let sibling = slotPresentation(
            .trailing,
            slotIndex: 1,
            groupAllowsDestructive: true,
            contentOffset: -220,
            deformationProgress: 0.25
        )
        let expectedSharedWidth = 64 + (28.0 / 3.0)

        #expect(abs(outer.width - expectedSharedWidth) < 0.001)
        #expect(abs(sibling.width - expectedSharedWidth) < 0.001)
        #expect(outer.isTakeoverActive == false)
        #expect(sibling.allowsHitTesting)
        #expect(sibling.isAccessibilityVisible)
        #expect(outer.suppressesSlotTitle == false)
    }

    @Test("multi-action destructive waits until fire boundary before takeover")
    func multiActionDestructiveWaitsUntilFireBoundaryBeforeTakeover() {
        let outer = slotPresentation(
            .trailing,
            slotIndex: 0,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -220,
            deformationProgress: 0.5
        )
        let sibling = slotPresentation(
            .trailing,
            slotIndex: 1,
            groupAllowsDestructive: true,
            contentOffset: -220,
            deformationProgress: 0.5
        )

        let sharedWidth = 64 + (28.0 / 3.0)
        #expect(abs(outer.width - sharedWidth) < 0.001)
        #expect(abs(sibling.width - sharedWidth) < 0.001)
        #expect(outer.suppressesSlotTitle == false)
        #expect(outer.isTakeoverActive == false)
        #expect(sibling.allowsHitTesting)
        #expect(sibling.isAccessibilityVisible)
    }

    @Test("single destructive reverse disarm restores title below fire boundary")
    func singleDestructiveReverseDisarmRestoresTitleBelowFireBoundary() {
        let single = slotPresentation(
            .trailing,
            slotIndex: 0,
            slotCount: 1,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -112,
            actionWidth: 64,
            normalOpenExtent: 64,
            deformationProgress: 0.5,
            isArmed: false
        )
        let multi = slotPresentation(
            .trailing,
            slotIndex: 0,
            slotCount: 3,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -220,
            deformationProgress: 0.5,
            isArmed: false
        )

        #expect(single.isTakeoverActive)
        #expect(single.suppressesSlotTitle == false)
        #expect(single.allowsHitTesting)
        #expect(single.isAccessibilityVisible)
        #expect(multi.isTakeoverActive == false)
        #expect(multi.suppressesSlotTitle == false)
    }

    @Test("single destructive fire and hold still suppress title")
    func singleDestructiveFireAndHoldStillSuppressTitle() {
        let fire = slotPresentation(
            .trailing,
            slotIndex: 0,
            slotCount: 1,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -128,
            actionWidth: 64,
            normalOpenExtent: 64,
            deformationProgress: 1,
            isArmed: false
        )
        let triggering = slotPresentation(
            .trailing,
            slotIndex: 0,
            slotCount: 1,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -128,
            actionWidth: 64,
            normalOpenExtent: 64,
            deformationProgress: 0,
            isTriggering: true
        )
        let settling = slotPresentation(
            .trailing,
            slotIndex: 0,
            slotCount: 1,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -48,
            actionWidth: 64,
            normalOpenExtent: 64,
            deformationProgress: 0,
            isTakeoverSettling: true
        )

        #expect(fire.suppressesSlotTitle)
        #expect(triggering.suppressesSlotTitle)
        #expect(settling.suppressesSlotTitle)
    }

    @Test("slot disarm restores ordinary sibling presentation")
    func slotDisarmRestoresOrdinarySiblingPresentation() {
        let sibling = slotPresentation(
            .trailing,
            slotIndex: 1,
            groupAllowsDestructive: true,
            contentOffset: -192,
            isArmed: false
        )

        #expect(sibling.isVisible)
        #expect(sibling.allowsHitTesting)
        #expect(sibling.isAccessibilityVisible)
        #expect(sibling.revealProgress == 1)
        #expect(sibling.suppressesSlotTitle == false)
        #expect(sibling.isTakeoverActive == false)
    }

    @Test("slot destructive triggering keeps takeover and suppresses title")
    func slotDestructiveTriggeringKeepsTakeoverAndSuppressesTitle() {
        let outer = slotPresentation(
            .trailing,
            slotIndex: 0,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -192,
            isArmed: false,
            isTriggering: true
        )
        let sibling = slotPresentation(
            .trailing,
            slotIndex: 1,
            groupAllowsDestructive: true,
            contentOffset: -192,
            isArmed: false,
            isTriggering: true
        )

        #expect(outer.width == 192)
        #expect(outer.suppressesSlotTitle)
        #expect(outer.isTakeoverActive)
        #expect(sibling.isVisible)
        #expect(sibling.allowsHitTesting == false)
    }

    @Test("slot destructive fire position keeps takeover and suppresses title")
    func slotDestructiveFirePositionKeepsTakeoverAndSuppressesTitle() {
        let outer = slotPresentation(
            .trailing,
            slotIndex: 0,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -192,
            deformationProgress: 1,
            isArmed: false,
            isTriggering: false
        )
        let sibling = slotPresentation(
            .trailing,
            slotIndex: 1,
            groupAllowsDestructive: true,
            contentOffset: -192,
            deformationProgress: 1,
            isArmed: false,
            isTriggering: false
        )

        #expect(outer.width == 192)
        #expect(outer.suppressesSlotTitle)
        #expect(outer.isTakeoverActive)
        #expect(sibling.isVisible)
        #expect(sibling.allowsHitTesting == false)
        #expect(sibling.isAccessibilityVisible == false)
    }

    @Test("slot destructive takeover settling follows live exposed width")
    func slotDestructiveTakeoverSettlingFollowsLiveExposedWidth() {
        let outer = slotPresentation(
            .trailing,
            slotIndex: 0,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: -120,
            deformationProgress: 0,
            isArmed: false,
            isTriggering: false,
            isTakeoverSettling: true
        )

        #expect(outer.width == 120)
        #expect(outer.suppressesSlotTitle)
        #expect(outer.isTakeoverActive)
    }

    @Test("slot destructive takeover settling keeps title suppressed")
    func slotDestructiveTakeoverSettlingKeepsTitleSuppressed() {
        let outer = slotPresentation(
            .trailing,
            slotIndex: 0,
            role: .destructive,
            groupAllowsDestructive: true,
            contentOffset: 0,
            deformationProgress: 0,
            isArmed: false,
            isTriggering: false,
            isTakeoverSettling: true
        )
        let sibling = slotPresentation(
            .trailing,
            slotIndex: 1,
            groupAllowsDestructive: true,
            contentOffset: 0,
            deformationProgress: 0,
            isArmed: false,
            isTriggering: false,
            isTakeoverSettling: true
        )

        #expect(outer.width == 0)
        #expect(outer.suppressesSlotTitle)
        #expect(outer.isTakeoverActive)
        #expect(sibling.isVisible)
        #expect(sibling.allowsHitTesting == false)
        #expect(sibling.isAccessibilityVisible == false)
    }

    @Test("takeover stays slot-only and requires outermost destructive group")
    func takeoverStaysSlotOnlyAndRequiresOutermostDestructiveGroup() {
        let tokenSibling = slotPresentation(
            .trailing,
            revealStyle: .token,
            slotIndex: 1,
            groupAllowsDestructive: true,
            contentOffset: -220,
            isArmed: true
        )
        let nonDestructiveSlot = slotPresentation(
            .trailing,
            slotIndex: 1,
            groupAllowsDestructive: false,
            contentOffset: -220,
            isArmed: true
        )

        #expect(tokenSibling.isVisible)
        #expect(tokenSibling.allowsHitTesting)
        #expect(nonDestructiveSlot.isVisible)
        #expect(nonDestructiveSlot.allowsHitTesting)
    }

    @Test("fire-face hold environment defaults to false")
    func fireFaceHoldEnvironmentDefaultsToFalse() {
        var values = EnvironmentValues()

        #expect(values.swipeActionHoldsFireFace == false)

        values.swipeActionHoldsFireFace = true
        #expect(values.swipeActionHoldsFireFace)
    }

    @Test("armed icon motion holds through fired collapse while armed relaxes")
    func armedIconMotionHoldsThroughFiredCollapseWhileArmedRelaxes() {
        // Fired collapse: the forced reset relaxes `isArmed` while the hold signal keeps the glyph pinned.
        let collapsing = firedCollapseContext(isOutermost: true, role: .destructive)

        #expect(
            SwipeActionArmedIconMotionTarget.resolve(
                hasIcon: true,
                context: collapsing,
                holdsFireFace: true
            )
        )
        // The same relaxed context without the hold is a disarm path and must release the glyph.
        #expect(
            !SwipeActionArmedIconMotionTarget.resolve(
                hasIcon: true,
                context: collapsing,
                holdsFireFace: false
            )
        )
        // Armed gating is unchanged when no hold is active.
        let armed = SwipeActionContext(
            side: .trailing,
            index: 0,
            count: 2,
            isOutermost: true,
            role: .destructive,
            normalOpenProgress: 1,
            deformationProgress: 1,
            isArmed: true,
            armChangeID: 1,
            armChangeKind: .enterFire
        )
        #expect(
            SwipeActionArmedIconMotionTarget.resolve(
                hasIcon: true,
                context: armed,
                holdsFireFace: false
            )
        )
    }

    @Test("fire-face hold keeps outermost destructive icon gating")
    func fireFaceHoldKeepsOutermostDestructiveIconGating() {
        // The hold only preserves an armed face that could exist; it must not invent one for
        // non-destructive siblings, inner slots, or icon-less labels.
        #expect(
            !SwipeActionArmedIconMotionTarget.resolve(
                hasIcon: true,
                context: firedCollapseContext(isOutermost: false, role: .normal),
                holdsFireFace: true
            )
        )
        #expect(
            !SwipeActionArmedIconMotionTarget.resolve(
                hasIcon: true,
                context: firedCollapseContext(isOutermost: false, role: .destructive),
                holdsFireFace: true
            )
        )
        #expect(
            !SwipeActionArmedIconMotionTarget.resolve(
                hasIcon: false,
                context: firedCollapseContext(isOutermost: true, role: .destructive),
                holdsFireFace: true
            )
        )
        #expect(
            !SwipeActionArmedIconMotionTarget.resolve(
                hasIcon: true,
                context: nil,
                holdsFireFace: true
            )
        )
    }

    @Test("token fired collapse pins stretch and sibling recede")
    func tokenFiredCollapsePinsStretchAndSiblingRecede() {
        let destructive = firedCollapseContext(isOutermost: true, role: .destructive)
        let sibling = firedCollapseContext(isOutermost: false, role: .normal)

        // Hold: the capsule keeps filling the (shrinking) live slot and receded siblings stay faded.
        #expect(SwipeActionTokenChromeFace.stretchProgress(context: destructive, holdsFireFace: true) == 1)
        #expect(SwipeActionTokenChromeFace.recedeProgress(context: sibling, holdsFireFace: true) == 1)
        // The destructive token itself never recedes, held or not.
        #expect(SwipeActionTokenChromeFace.recedeProgress(context: destructive, holdsFireFace: true) == 0)
        // Without the hold the same relaxed contexts fold back — the non-fired close vocabulary.
        #expect(SwipeActionTokenChromeFace.stretchProgress(context: destructive, holdsFireFace: false) == 0)
        #expect(SwipeActionTokenChromeFace.recedeProgress(context: sibling, holdsFireFace: false) == 0)
    }

    @Test("token fired collapse pins action-level reveal transform")
    func tokenFiredCollapsePinsActionLevelRevealTransform() {
        let collapsingDestructive = slotPresentation(
            .trailing,
            revealStyle: .token,
            slotIndex: 0,
            slotCount: 2,
            role: .destructive,
            groupAllowsDestructive: true,
            normalOpenProgress: 0.25,
            contentOffset: -32,
            actionWidth: 64,
            normalOpenExtent: 128,
            isTakeoverSettling: true
        )
        let collapsingSibling = slotPresentation(
            .trailing,
            revealStyle: .token,
            slotIndex: 1,
            slotCount: 2,
            role: .normal,
            groupAllowsDestructive: true,
            normalOpenProgress: 0.25,
            contentOffset: -32,
            actionWidth: 64,
            normalOpenExtent: 128,
            isTakeoverSettling: true
        )

        #expect(collapsingDestructive.revealProgress == 1)
        #expect(collapsingSibling.revealProgress == 1)

        let ordinaryDestructive = slotPresentation(
            .trailing,
            revealStyle: .token,
            slotIndex: 0,
            slotCount: 2,
            role: .destructive,
            groupAllowsDestructive: true,
            normalOpenProgress: 0.25,
            contentOffset: -32,
            actionWidth: 64,
            normalOpenExtent: 128
        )
        let ordinarySibling = slotPresentation(
            .trailing,
            revealStyle: .token,
            slotIndex: 1,
            slotCount: 2,
            role: .normal,
            groupAllowsDestructive: true,
            normalOpenProgress: 0.25,
            contentOffset: -32,
            actionWidth: 64,
            normalOpenExtent: 128
        )

        #expect(ordinaryDestructive.revealProgress == 0.5)
        #expect(ordinarySibling.revealProgress == 0)
    }

    @Test("token disarm paths keep deformation-driven stretch and recede")
    func tokenDisarmPathsKeepDeformationDrivenStretchAndRecede() {
        // Drag-back below the fire boundary: no hold, stretch and recede follow the live deformation.
        let dragBackDestructive = SwipeActionContext(
            side: .trailing,
            index: 0,
            count: 2,
            isOutermost: true,
            role: .destructive,
            normalOpenProgress: 1,
            deformationProgress: 0.5,
            isArmed: false,
            armChangeID: 2,
            armChangeKind: .exitFire
        )
        let dragBackSibling = SwipeActionContext(
            side: .trailing,
            index: 1,
            count: 2,
            isOutermost: false,
            role: .normal,
            normalOpenProgress: 1,
            deformationProgress: 0.5,
            isArmed: false,
            armChangeID: 2,
            armChangeKind: .exitFire
        )

        #expect(
            SwipeActionTokenChromeFace.stretchProgress(
                context: dragBackDestructive,
                holdsFireFace: false
            ) == 0.5
        )
        #expect(
            SwipeActionTokenChromeFace.recedeProgress(
                context: dragBackSibling,
                holdsFireFace: false
            ) == 0.5
        )
        // Non-destructive / non-outermost tokens never stretch.
        #expect(
            SwipeActionTokenChromeFace.stretchProgress(
                context: dragBackSibling,
                holdsFireFace: false
            ) == 0
        )
    }

    /// Context as the default chromes see it once a fired collapse begins: the forced reset has already
    /// relaxed `isArmed` and the deformation band, with no explicit disarm marker.
    private func firedCollapseContext(
        isOutermost: Bool,
        role: SwipeActionRoleKind
    ) -> SwipeActionContext {
        SwipeActionContext(
            side: .trailing,
            index: isOutermost ? 0 : 1,
            count: 2,
            isOutermost: isOutermost,
            role: role,
            normalOpenProgress: 0.6,
            deformationProgress: 0,
            isArmed: false,
            armChangeID: 1,
            armChangeKind: .enterFire
        )
    }

    @Test("token non-destructive over-open moves default tokens as a coherent group")
    func tokenNonDestructiveOverOpenMovesDefaultTokensAsCoherentGroup() {
        let normalOpenExtent: CGFloat = 184
        let extra: CGFloat = 30
        let leadingContentOffset = normalOpenExtent + extra
        let trailingContentOffset = -leadingContentOffset

        let leadingOuter = tokenOverOpenOffset(
            .leading,
            slotIndex: 0,
            contentOffset: leadingContentOffset,
            normalOpenExtent: normalOpenExtent
        )
        let leadingInner = tokenOverOpenOffset(
            .leading,
            slotIndex: 1,
            contentOffset: leadingContentOffset,
            normalOpenExtent: normalOpenExtent
        )
        let trailingOuter = tokenOverOpenOffset(
            .trailing,
            slotIndex: 0,
            contentOffset: trailingContentOffset,
            normalOpenExtent: normalOpenExtent
        )
        let trailingInner = tokenOverOpenOffset(
            .trailing,
            slotIndex: 1,
            contentOffset: trailingContentOffset,
            normalOpenExtent: normalOpenExtent
        )

        // Each token's final visual position (slot-origin drift + local offset) lands on the same signed
        // group displacement, so the group stays pinned to the content edge with stable relative gaps.
        #expect(leadingSlotDisplacement(slotIndex: 0, extra: extra) + leadingOuter == extra)
        #expect(leadingSlotDisplacement(slotIndex: 1, extra: extra) + leadingInner == extra)
        #expect(trailingSlotDisplacement(extra: extra) + trailingOuter == -extra)
        #expect(trailingSlotDisplacement(extra: extra) + trailingInner == -extra)

        // Disabled paths produce no offset.
        #expect(
            tokenOverOpenOffset(
                .leading,
                slotIndex: 0,
                contentOffset: normalOpenExtent,
                normalOpenExtent: normalOpenExtent
            ) == 0
        )
        #expect(
            tokenOverOpenOffset(
                .leading,
                slotIndex: 1,
                revealStyle: .slot,
                contentOffset: leadingContentOffset,
                normalOpenExtent: normalOpenExtent
            ) == 0
        )
        #expect(
            tokenOverOpenOffset(
                .leading,
                slotIndex: 1,
                allowsDestructive: true,
                contentOffset: leadingContentOffset,
                normalOpenExtent: normalOpenExtent
            ) == 0
        )
    }

    @Test("token over-open keeps tokens pinned to the content edge without re-clamping")
    func tokenOverOpenKeepsTokensPinnedToContentEdgeWithoutReclamping() {
        let normalOpenExtent: CGFloat = 184

        // Sweep the over-open extra, including past the legacy rubber-band cap (36). The content rubber
        // band (`SwipeCellInteractionModel.rubberBandedMovement`) owns all damping and capping, so token
        // motion must track `contentOffset` one-to-one here and never re-clamp; otherwise the group would
        // detach from the content edge once content motion changes.
        for extra in stride(from: CGFloat(0), through: 80, by: 8) {
            let leadingContentOffset = normalOpenExtent + extra
            let trailingContentOffset = -leadingContentOffset

            for slotIndex in 0...2 {
                let leadingVisual =
                    leadingSlotDisplacement(slotIndex: slotIndex, extra: extra)
                    + tokenOverOpenOffset(
                        .leading,
                        slotIndex: slotIndex,
                        contentOffset: leadingContentOffset,
                        normalOpenExtent: normalOpenExtent
                    )
                let trailingVisual =
                    trailingSlotDisplacement(extra: extra)
                    + tokenOverOpenOffset(
                        .trailing,
                        slotIndex: slotIndex,
                        contentOffset: trailingContentOffset,
                        normalOpenExtent: normalOpenExtent
                    )

                // The token group's visual displacement equals the content edge's over-open displacement.
                #expect(leadingVisual == extra)
                #expect(trailingVisual == -extra)
            }
        }
    }

    private func revealProgress(
        _ revealStyle: SwipeActionsRevealStyle,
        normalOpenProgress: CGFloat = 0.5,
        contentOffset: CGFloat,
        actionWidth: CGFloat = 64,
        normalOpenExtent: CGFloat = 192,
        slotIndex: Int,
        slotCount: Int = 3
    ) -> CGFloat {
        SwipeActionSlotRevealProgress.progress(
            for: revealStyle,
            normalOpenProgress: normalOpenProgress,
            contentOffset: contentOffset,
            actionWidth: actionWidth,
            normalOpenExtent: normalOpenExtent,
            slotIndex: slotIndex,
            slotCount: slotCount
        )
    }

    private func slotPresentation(
        _ side: SwipeCellSide,
        revealStyle: SwipeActionsRevealStyle = .slot,
        slotIndex: Int,
        slotCount: Int = 3,
        role: SwipeActionRoleKind = .normal,
        groupAllowsDestructive: Bool = false,
        normalOpenProgress: CGFloat = 0.5,
        contentOffset: CGFloat = 96,
        actionWidth: CGFloat = 64,
        normalOpenExtent: CGFloat = 192,
        deformationProgress: CGFloat = 0,
        isArmed: Bool = false,
        isTriggering: Bool = false,
        isTakeoverSettling: Bool = false
    ) -> SwipeActionSlotPresentation {
        SwipeActionSlotPresentation.resolve(
            revealStyle: revealStyle,
            side: side,
            slotIndex: slotIndex,
            slotCount: slotCount,
            role: role,
            groupAllowsDestructive: groupAllowsDestructive,
            normalOpenProgress: normalOpenProgress,
            contentOffset: contentOffset,
            actionWidth: actionWidth,
            normalOpenExtent: normalOpenExtent,
            deformationProgress: deformationProgress,
            isArmed: isArmed,
            isTriggering: isTriggering,
            isTakeoverSettling: isTakeoverSettling
        )
    }

    private func tokenOverOpenOffset(
        _ side: SwipeCellSide,
        slotIndex: Int,
        revealStyle: SwipeActionsRevealStyle = .token,
        allowsDestructive: Bool = false,
        contentOffset: CGFloat,
        normalOpenExtent: CGFloat
    ) -> CGFloat {
        SwipeCellTokenOrdinaryOverOpenOffset.offset(
            side: side,
            slotIndex: slotIndex,
            revealStyle: revealStyle,
            allowsDestructive: allowsDestructive,
            contentOffset: contentOffset,
            normalOpenExtent: normalOpenExtent
        )
    }

    private func leadingSlotDisplacement(slotIndex: Int, extra: CGFloat) -> CGFloat {
        slotIndex == 0 ? 0 : extra
    }

    private func trailingSlotDisplacement(extra: CGFloat) -> CGFloat {
        -extra
    }

    @Test("swipe action context environment defaults to nil and stores context")
    func swipeActionContextEnvironmentDefaultsToNilAndStoresContext() {
        var values = EnvironmentValues()
        let context = SwipeActionContext(
            side: .trailing,
            index: 0,
            count: 2,
            isOutermost: true,
            role: .destructive,
            normalOpenProgress: 1.4,
            deformationProgress: 0.45,
            isArmed: false,
            armChangeID: 3,
            armChangeKind: .exitFire
        )

        #expect(values.swipeActionContext == nil)

        values.swipeActionContext = context
        #expect(values.swipeActionContext?.side == .trailing)
        #expect(values.swipeActionContext?.index == 0)
        #expect(values.swipeActionContext?.count == 2)
        #expect(values.swipeActionContext?.isOutermost == true)
        #expect(values.swipeActionContext?.role == .destructive)
        #expect(values.swipeActionContext?.normalOpenProgress == 1)
        #expect(values.swipeActionContext?.deformationProgress == 0.45)
        #expect(values.swipeActionContext?.isArmed == false)
        #expect(values.swipeActionContext?.armChangeID == 3)
        #expect(values.swipeActionContext?.armChangeKind == .exitFire)
    }

    @Test("custom settling animation modifier type-checks")
    func customSettlingAnimationModifierTypeChecks() {
        _ = Text("Custom")
            .swipeCellIdentity(
                "custom-animation",
                openThreshold: 64,
                settlingAnimation: .linear(duration: 0.1)
            )
    }

    @Test("default label style environment stores overrides and sanitizes metrics")
    func defaultLabelStyleEnvironmentStoresOverridesAndSanitizesMetrics() {
        var values = EnvironmentValues()
        #expect(values.swipeActionDefaultLabelStyle == .default)

        let customStyle = SwipeActionDefaultLabelStyle(
            iconFont: .title.weight(.bold),
            titleFont: .footnote,
            iconSlotSize: 30,
            textSlotHeight: 18
        )
        values.swipeActionDefaultLabelStyle = customStyle
        #expect(values.swipeActionDefaultLabelStyle == customStyle)

        let invalidStyle = SwipeActionDefaultLabelStyle(
            iconSlotSize: .infinity,
            textSlotHeight: 0
        )
        #expect(invalidStyle.iconSlotSize == SwipeActionDefaultLabelMetrics.iconSlotSize)
        #expect(invalidStyle.textSlotHeight == SwipeActionDefaultLabelMetrics.textSlotHeight)

        var mutatedStyle = customStyle
        mutatedStyle.iconSlotSize = .nan
        mutatedStyle.textSlotHeight = -4
        #expect(mutatedStyle.iconSlotSize == SwipeActionDefaultLabelMetrics.iconSlotSize)
        #expect(mutatedStyle.textSlotHeight == SwipeActionDefaultLabelMetrics.textSlotHeight)
    }

    @Test("default label style system convenience sanitizes size inputs")
    func defaultLabelStyleSystemConvenienceSanitizesSizeInputs() {
        let numericStyle = SwipeActionDefaultLabelStyle.system(
            iconSize: 22,
            titleSize: 10,
            iconSlotSize: 32,
            textSlotHeight: 16
        )

        #expect(numericStyle.iconFont == Font.system(size: 22, weight: .semibold))
        #expect(numericStyle.titleFont == Font.system(size: 10, weight: .semibold))
        #expect(numericStyle.iconSlotSize == 32)
        #expect(numericStyle.textSlotHeight == 16)

        let invalidStyle = SwipeActionDefaultLabelStyle.system(
            iconSize: .nan,
            titleSize: -.infinity,
            iconSlotSize: -1,
            textSlotHeight: 0
        )

        #expect(invalidStyle.iconFont == Font.system(size: 17, weight: .semibold))
        #expect(invalidStyle.titleFont == Font.system(size: 11, weight: .semibold))
        #expect(invalidStyle.iconSlotSize == SwipeActionDefaultLabelMetrics.iconSlotSize)
        #expect(invalidStyle.textSlotHeight == SwipeActionDefaultLabelMetrics.textSlotHeight)
    }

    @Test("default label style modifier type-checks")
    func defaultLabelStyleModifierTypeChecks() {
        _ = Text("Styled")
            .swipeActionDefaultLabelStyle(
                SwipeActionDefaultLabelStyle(
                    iconFont: .title3.weight(.semibold),
                    titleFont: .caption.weight(.semibold),
                    iconSlotSize: 30,
                    textSlotHeight: 16
                )
            )
    }

    @Test("content remains the size source while the panel moves over background actions")
    func contentRemainsSizeSourceWhilePanelMovesOverBackgroundActions() {
        let leadingGeometry = SwipeCellPanelGeometry(
            containerSize: CGSize(width: 320, height: 72),
            contentOffset: 96
        )

        #expect(leadingGeometry.contentProposalSize == CGSize(width: 320, height: 72))
        #expect(leadingGeometry.contentFrame == CGRect(x: 96, y: 0, width: 320, height: 72))
        #expect(leadingGeometry.actionBackgroundFrame == CGRect(x: 0, y: 0, width: 320, height: 72))
        #expect(leadingGeometry.exposedSide(at: CGPoint(x: 24, y: 36)) == .leading)
        #expect(leadingGeometry.exposedSide(at: CGPoint(x: 128, y: 36)) == nil)

        let trailingGeometry = SwipeCellPanelGeometry(
            containerSize: CGSize(width: 320, height: 72),
            contentOffset: -96
        )

        #expect(trailingGeometry.contentProposalSize == CGSize(width: 320, height: 72))
        #expect(trailingGeometry.contentFrame == CGRect(x: -96, y: 0, width: 320, height: 72))
        #expect(trailingGeometry.actionBackgroundFrame == CGRect(x: 0, y: 0, width: 320, height: 72))
        #expect(trailingGeometry.exposedSide(at: CGPoint(x: 296, y: 36)) == .trailing)
        #expect(trailingGeometry.exposedSide(at: CGPoint(x: 192, y: 36)) == nil)
    }

    #if canImport(AppKit)
        @Test("action shell body keeps only active actions in content background bounds")
        func actionShellBodyKeepsOnlyActiveActionsInContentBackgroundBounds() {
            let leadingManager = SwipeCellManager()
            let leadingStore = FrameProbeStore()
            leadingManager.beginInteraction(for: "action-shell", side: .leading)

            let leadingHost = NSHostingView(
                rootView: Issue2ActionShellFrameProbe(
                    manager: leadingManager,
                    store: leadingStore,
                    contentOffset: 140
                )
            )
            leadingHost.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            leadingHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            leadingHost.layoutSubtreeIfNeeded()

            #expect(leadingStore.frames["content"] == CGRect(x: 140, y: 0, width: 320, height: 72))
            #expect(leadingStore.frames["leading-0"] == CGRect(x: -22, y: 0, width: 92, height: 72))
            #expect(leadingStore.frames["leading-1"] == CGRect(x: 48, y: 0, width: 92, height: 72))
            #expect(leadingStore.frames["trailing-0"] == nil)

            let trailingManager = SwipeCellManager()
            let trailingStore = FrameProbeStore()
            trailingManager.beginInteraction(for: "action-shell", side: .trailing)
            trailingManager.markTriggering(.trailing, for: "action-shell")

            let trailingHost = NSHostingView(
                rootView: Issue2ActionShellFrameProbe(
                    manager: trailingManager,
                    store: trailingStore,
                    contentOffset: -140
                )
            )
            trailingHost.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            trailingHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            trailingHost.layoutSubtreeIfNeeded()

            #expect(trailingStore.frames["content"] == CGRect(x: -140, y: 0, width: 320, height: 72))
            #expect(trailingStore.frames["leading-0"] == nil)
            #expect(trailingStore.frames["trailing-1"] == CGRect(x: 180, y: 0, width: 92, height: 72))
            #expect(trailingStore.frames["trailing-0"] == CGRect(x: 250, y: 0, width: 92, height: 72))
        }

        @Test("action shell keeps settling actions visible after manager reset")
        func actionShellKeepsSettlingActionsVisibleAfterManagerReset() {
            let manager = SwipeCellManager()
            let store = FrameProbeStore()

            let host = NSHostingView(
                rootView: Issue2ActionShellFrameProbe(
                    manager: manager,
                    store: store,
                    contentOffset: -92
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            #expect(store.frames["content"] == CGRect(x: -92, y: 0, width: 320, height: 72))
            #expect(store.frames["leading-0"] == nil)
            #expect(store.frames["trailing-1"]?.minX == 228)
            #expect(store.frames["trailing-1"]?.width == 92)
            #expect(store.frames["trailing-0"]?.minX == 274)
            #expect(store.frames["trailing-0"]?.width == 92)
        }

        @Test("stacked slot reveal exposes sibling before the front slot is fully open")
        func stackedSlotRevealExposesSiblingBeforeFrontSlotIsFullyOpen() throws {
            let manager = SwipeCellManager()
            let store = FrameProbeStore()
            manager.beginInteraction(for: "action-shell", side: .trailing)

            let host = NSHostingView(
                rootView: Issue2ActionShellFrameProbe(
                    manager: manager,
                    store: store,
                    contentOffset: -60
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let sibling = try #require(store.frames["trailing-1"])
            let front = try #require(store.frames["trailing-0"])
            let contentEdge: CGFloat = 260

            #expect(front.minX > contentEdge)
            #expect(sibling.maxX > contentEdge)
            #expect(sibling.minX < front.minX)
            #expect(front.minX == 290)
            #expect(sibling.minX == contentEdge)
        }

        @Test("normal geometry expands to cover overdrag on both sides")
        func normalGeometryExpandsToCoverOverdragOnBothSides() {
            let leadingManager = SwipeCellManager()
            let leadingStore = FrameProbeStore()
            leadingManager.beginInteraction(for: "action-shell", side: .leading)

            let leadingHost = NSHostingView(
                rootView: Issue2ActionShellFrameProbe(
                    manager: leadingManager,
                    store: leadingStore,
                    contentOffset: 220
                )
            )
            leadingHost.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            leadingHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            leadingHost.layoutSubtreeIfNeeded()

            #expect(leadingStore.frames["content"] == CGRect(x: 220, y: 0, width: 320, height: 72))
            #expect(leadingStore.frames["leading-0"] == CGRect(x: 0, y: 0, width: 128, height: 72))
            #expect(leadingStore.frames["leading-1"] == CGRect(x: 128, y: 0, width: 92, height: 72))
            #expect(leadingStore.frames["trailing-0"] == nil)

            let trailingManager = SwipeCellManager()
            let trailingStore = FrameProbeStore()
            trailingManager.beginInteraction(for: "action-shell", side: .trailing)

            let trailingHost = NSHostingView(
                rootView: Issue2ActionShellFrameProbe(
                    manager: trailingManager,
                    store: trailingStore,
                    contentOffset: -220
                )
            )
            trailingHost.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            trailingHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            trailingHost.layoutSubtreeIfNeeded()

            #expect(trailingStore.frames["content"] == CGRect(x: -220, y: 0, width: 320, height: 72))
            #expect(trailingStore.frames["leading-0"] == nil)
            #expect(trailingStore.frames["trailing-1"] == CGRect(x: 100, y: 0, width: 92, height: 72))
            #expect(trailingStore.frames["trailing-0"] == CGRect(x: 192, y: 0, width: 128, height: 72))
        }

        @Test("destructive geometry expands to cover the exposed trailing band")
        func destructiveGeometryExpandsToCoverTheExposedTrailingBand() {
            let manager = SwipeCellManager()
            let store = FrameProbeStore()
            manager.beginInteraction(for: "action-shell", side: .trailing)

            let host = NSHostingView(
                rootView: Issue11DestructiveGeometryFrameProbe(
                    manager: manager,
                    store: store,
                    contentOffset: -220,
                    deformationProgress: 0
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            #expect(store.frames["content"] == CGRect(x: -220, y: 0, width: 320, height: 72))
            #expect(store.frames["trailing-1"] == CGRect(x: 100, y: 0, width: 110, height: 72))
            #expect(store.frames["trailing-0"] == CGRect(x: 210, y: 0, width: 110, height: 72))
        }

        @Test("destructive deformation waits until fire boundary before front coverage")
        func destructiveDeformationWaitsUntilFireBoundaryBeforeFrontCoverage() {
            let manager = SwipeCellManager()
            let store = FrameProbeStore()
            manager.beginInteraction(for: "action-shell", side: .trailing)

            let host = NSHostingView(
                rootView: Issue11DestructiveGeometryFrameProbe(
                    manager: manager,
                    store: store,
                    contentOffset: -220,
                    deformationProgress: 0.5
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            #expect(store.frames["content"] == CGRect(x: -220, y: 0, width: 320, height: 72))
            #expect(store.frames["trailing-1"] == CGRect(x: 100, y: 0, width: 110, height: 72))
            #expect(store.frames["trailing-0"] == CGRect(x: 210, y: 0, width: 110, height: 72))
        }

        @Test("destructive takeover overlays siblings from the front")
        func destructiveTakeoverOverlaysSiblingsFromTheFront() {
            let manager = SwipeCellManager()
            let store = FrameProbeStore()
            manager.beginInteraction(for: "action-shell", side: .trailing)

            let host = NSHostingView(
                rootView: Issue11DestructiveGeometryFrameProbe(
                    manager: manager,
                    store: store,
                    contentOffset: -220,
                    deformationProgress: 1
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            #expect(store.frames["content"] == CGRect(x: -220, y: 0, width: 320, height: 72))
            #expect(store.frames["trailing-1"] == CGRect(x: 100, y: 0, width: 110, height: 72))
            #expect(store.frames["trailing-0"] == CGRect(x: 100, y: 0, width: 220, height: 72))
        }

        @Test("destructive takeover settling keeps front coverage at closed target")
        func destructiveTakeoverSettlingKeepsFrontCoverageAtClosedTarget() {
            let manager = SwipeCellManager()
            let store = FrameProbeStore()

            let host = NSHostingView(
                rootView: Issue11DestructiveGeometryFrameProbe(
                    manager: manager,
                    store: store,
                    contentOffset: 0,
                    deformationProgress: 0,
                    settlingSide: .trailing,
                    takeoverSettlingSide: .trailing
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            #expect(store.frames["content"] == CGRect(x: 0, y: 0, width: 320, height: 72))
            #expect(store.frames["trailing-1"]?.minX == 320)
            #expect(store.frames["trailing-1"]?.width == 92)
            #expect(store.frames["trailing-0"] == CGRect(x: 320, y: 0, width: 0, height: 72))
        }

        @Test("action shell keeps explicit settling side visible at closed offset")
        func actionShellKeepsExplicitSettlingSideVisibleAtClosedOffset() {
            let manager = SwipeCellManager()
            let store = FrameProbeStore()

            let host = NSHostingView(
                rootView: Issue2ActionShellFrameProbe(
                    manager: manager,
                    store: store,
                    contentOffset: 0,
                    settlingSide: .trailing
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            #expect(store.frames["content"] == CGRect(x: 0, y: 0, width: 320, height: 72))
            #expect(store.frames["leading-0"] == nil)
            #expect(store.frames["trailing-1"]?.minX == 320)
            #expect(store.frames["trailing-1"]?.width == 92)
            #expect(store.frames["trailing-0"]?.minX == 320)
            #expect(store.frames["trailing-0"]?.width == 92)
        }

        @Test("action shell injects normal open progress into content")
        func actionShellInjectsNormalOpenProgressIntoContent() {
            let manager = SwipeCellManager()
            let store = ProgressProbeStore()

            let host = NSHostingView(
                rootView: Issue4ProgressEnvironmentProbe(manager: manager, store: store)
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            #expect(abs((store.progress ?? -1) - 0.625) < 0.0001)
        }

        @Test("action shell injects per-button context into custom labels")
        func actionShellInjectsPerButtonContextIntoCustomLabels() {
            let manager = SwipeCellManager()
            let store = ActionContextProbeStore()
            manager.beginInteraction(for: "context-probe", side: .trailing)

            let host = NSHostingView(
                rootView: Issue8ActionContextProbe(manager: manager, store: store)
            )
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            #expect(store.contexts["trailing-0"]?.side == .trailing)
            #expect(store.contexts["trailing-0"]?.index == 0)
            #expect(store.contexts["trailing-0"]?.count == 2)
            #expect(store.contexts["trailing-0"]?.isOutermost == true)
            #expect(store.contexts["trailing-0"]?.role == .destructive)
            #expect(store.contexts["trailing-0"]?.normalOpenProgress == 1)
            #expect(store.contexts["trailing-0"]?.deformationProgress == 0.5)
            #expect(store.contexts["trailing-0"]?.isArmed == false)
            #expect(store.contexts["trailing-0"]?.armChangeID == 2)
            #expect(store.contexts["trailing-0"]?.armChangeKind == .exitFire)
            #expect(store.contexts["trailing-1"]?.index == 1)
            #expect(store.contexts["trailing-1"]?.role == .normal)
        }

        @Test("default slot label keeps fixed icon and text rows")
        func defaultSlotLabelKeepsFixedIconAndTextRows() throws {
            let store = FrameProbeStore()
            let host = NSHostingView(rootView: DefaultLabelChromeAlignmentProbe(store: store))
            host.frame = CGRect(x: 0, y: 0, width: 216, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let bothIcon = try #require(store.frames["both-icon"])
            let imageOnlyIcon = try #require(store.frames["image-only-icon"])
            let bothTitle = try #require(store.frames["both-title"])
            let titleOnlyTitle = try #require(store.frames["title-only-title"])

            #expect(abs(bothIcon.midY - imageOnlyIcon.midY) < 0.5)
            #expect(abs(bothTitle.midY - titleOnlyTitle.midY) < 0.5)
            #expect(abs(bothIcon.height - SwipeActionDefaultLabelMetrics.iconSlotSize) < 0.5)
            #expect(abs(bothTitle.height - SwipeActionDefaultLabelMetrics.textSlotHeight) < 0.5)
        }

        @Test("default slot label consumes override slot metrics")
        func defaultSlotLabelConsumesOverrideSlotMetrics() throws {
            let style = SwipeActionDefaultLabelStyle(
                iconFont: .title.weight(.bold),
                titleFont: .footnote.weight(.medium),
                iconSlotSize: 32,
                textSlotHeight: 18
            )
            let store = FrameProbeStore()
            let host = NSHostingView(rootView: DefaultLabelChromeAlignmentProbe(store: store, style: style))
            host.frame = CGRect(x: 0, y: 0, width: 216, height: 88)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let bothIcon = try #require(store.frames["both-icon"])
            let bothTitle = try #require(store.frames["both-title"])

            let expectedCenterDelta =
                (style.iconSlotSize / 2)
                + SwipeActionDefaultLabelMetrics.slotSpacing
                + (style.textSlotHeight / 2)

            #expect(abs(bothIcon.height - style.iconSlotSize) < 0.5)
            #expect(abs(bothTitle.height - style.textSlotHeight) < 0.5)
            #expect(abs((bothTitle.midY - bothIcon.midY) - expectedCenterDelta) < 0.5)
        }

        @Test("default token label keeps token and title slots")
        func defaultTokenLabelKeepsTokenAndTitleSlots() throws {
            let store = FrameProbeStore()
            let host = NSHostingView(rootView: DefaultLabelChromeAlignmentProbe(store: store, revealStyle: .token))
            host.frame = CGRect(x: 0, y: 0, width: 216, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let bothIcon = try #require(store.frames["both-icon"])
            let imageOnlyIcon = try #require(store.frames["image-only-icon"])
            let bothTitle = try #require(store.frames["both-title"])
            let titleOnlyTitle = try #require(store.frames["title-only-title"])

            // The probe chrome is 72pt wide, so the rendered token uses the iOS profile fitted to that slot.
            let layout = SwipeActionTokenLayout(metrics: SwipeActionDefaultLabelMetrics())
            let tokenSize = layout.restingSize(slotWidth: 72)
            let expectedCenterDelta =
                (tokenSize.height / 2)
                + layout.titleSpacing
                + (SwipeActionDefaultLabelMetrics.textSlotHeight / 2)

            // The probed icon frame is the glyph slot; the token behind it is verified in the layout
            // unit test. Glyph keeps the icon slot, title sits below in its own slot, and a lone token and a
            // title-only pill share the same vertical center.
            #expect(abs(bothIcon.width - SwipeActionDefaultLabelMetrics.iconSlotSize) < 0.5)
            #expect(abs(bothIcon.height - SwipeActionDefaultLabelMetrics.iconSlotSize) < 0.5)
            #expect(abs(bothTitle.height - SwipeActionDefaultLabelMetrics.textSlotHeight) < 0.5)
            #expect(abs((bothTitle.midY - bothIcon.midY) - expectedCenterDelta) < 0.5)
            #expect(abs(imageOnlyIcon.midY - titleOnlyTitle.midY) < 0.5)
            #expect(abs(titleOnlyTitle.height - tokenSize.height) < 0.5)
        }

        @Test("default token label keeps profile geometry independent from slot metrics")
        func defaultTokenLabelConsumesOverrideSlotMetrics() throws {
            let style = SwipeActionDefaultLabelStyle(
                iconFont: .title.weight(.bold),
                titleFont: .footnote.weight(.medium),
                iconSlotSize: 32,
                textSlotHeight: 18
            )
            let store = FrameProbeStore()
            let host = NSHostingView(
                rootView: DefaultLabelChromeAlignmentProbe(
                    store: store,
                    style: style,
                    revealStyle: .token
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 216, height: 88)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let bothIcon = try #require(store.frames["both-icon"])
            let bothTitle = try #require(store.frames["both-title"])
            let titleOnlyTitle = try #require(store.frames["title-only-title"])

            // Token geometry now comes from the token profile, not from icon slot metrics. The style
            // still owns the glyph slot and title row.
            let layout = SwipeActionTokenLayout(metrics: SwipeActionDefaultLabelMetrics(style: style))
            let tokenSize = layout.restingSize(slotWidth: 72)
            let expectedCenterDelta =
                (tokenSize.height / 2)
                + layout.titleSpacing
                + (style.textSlotHeight / 2)

            #expect(abs(bothIcon.width - style.iconSlotSize) < 0.5)
            #expect(abs(bothIcon.height - style.iconSlotSize) < 0.5)
            #expect(abs(bothTitle.height - style.textSlotHeight) < 0.5)
            #expect(abs((bothTitle.midY - bothIcon.midY) - expectedCenterDelta) < 0.5)
            #expect(abs(titleOnlyTitle.height - tokenSize.height) < 0.5)
        }

        @Test("default token label consumes token profile geometry")
        func defaultTokenLabelConsumesTokenProfileGeometry() throws {
            let profile = SwipeActionTokenProfile(
                restingWidth: 60,
                restingHeight: 36,
                titleSpacing: 9,
                stretchHorizontalInset: 6
            )
            var configuration = SwipeCellConfiguration.iOSDefault
            configuration.style.tokenProfile = profile

            let store = FrameProbeStore()
            let host = NSHostingView(
                rootView: DefaultLabelChromeAlignmentProbe(
                    store: store,
                    configuration: configuration,
                    revealStyle: .token
                )
            )
            host.frame = CGRect(x: 0, y: 0, width: 216, height: 88)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let bothIcon = try #require(store.frames["both-icon"])
            let bothTitle = try #require(store.frames["both-title"])
            let titleOnlyTitle = try #require(store.frames["title-only-title"])

            let layout = SwipeActionTokenLayout(
                metrics: SwipeActionDefaultLabelMetrics(),
                profile: profile
            )
            let tokenSize = layout.restingSize(slotWidth: 72)
            let expectedCenterDelta =
                (tokenSize.height / 2)
                + profile.titleSpacing
                + (SwipeActionDefaultLabelMetrics.textSlotHeight / 2)

            #expect(tokenSize == CGSize(width: 60, height: 36))
            #expect(abs((bothTitle.midY - bothIcon.midY) - expectedCenterDelta) < 0.5)
            #expect(abs(titleOnlyTitle.width - tokenSize.width) < 0.5)
            #expect(abs(titleOnlyTitle.height - tokenSize.height) < 0.5)
        }

        @Test("default slot destructive armed label moves icon and restores title")
        func defaultSlotDestructiveArmedLabelMovesIconAndRestoresTitle() throws {
            let store = FrameProbeStore()
            let host = NSHostingView(rootView: DefaultLabelChromeArmedProbe(store: store))
            host.frame = CGRect(x: 0, y: 0, width: 512, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let trailingArmedIcon = try #require(store.frames["trailing-armed-icon"])
            let leadingArmedIcon = try #require(store.frames["leading-armed-icon"])
            let trailingUnarmedIcon = try #require(store.frames["trailing-unarmed-icon"])
            let trailingArmedTitle = try #require(store.frames["trailing-armed-title"])
            let trailingUnarmedTitle = try #require(store.frames["trailing-unarmed-title"])
            _ = try #require(store.frames["title-only-armed-title"])

            let armedFrontCenter =
                SwipeActionDefaultLabelMetrics.armedFrontInset
                + (SwipeActionDefaultLabelMetrics.iconSlotSize / 2)
            let labelCenterY: CGFloat = 72 / 2

            #expect(abs(trailingArmedIcon.midX - armedFrontCenter) < 0.5)
            #expect(abs((leadingArmedIcon.midX - 128) - (128 - armedFrontCenter)) < 0.5)
            #expect(abs((trailingUnarmedIcon.midX - 256) - 64) < 0.5)
            // Arming fades the title but must not shift the icon vertically: its resting Y stays put so the
            // Destructive arm motion reads as a horizontal slide only, keeping the unarmed icon's height.
            #expect(abs(trailingArmedIcon.midY - trailingUnarmedIcon.midY) < 0.5)
            #expect(abs(leadingArmedIcon.midY - trailingUnarmedIcon.midY) < 0.5)
            #expect(trailingArmedIcon.midY < labelCenterY)
            #expect(abs(trailingArmedTitle.height - SwipeActionDefaultLabelMetrics.textSlotHeight) < 0.5)
            #expect(abs(trailingArmedTitle.height - trailingUnarmedTitle.height) < 0.5)
        }

        @Test("default slot destructive armed label uses override icon slot for front edge")
        func defaultSlotDestructiveArmedLabelUsesOverrideIconSlotForFrontEdge() throws {
            let style = SwipeActionDefaultLabelStyle(
                iconSlotSize: 32,
                textSlotHeight: 18
            )
            let store = FrameProbeStore()
            let host = NSHostingView(rootView: DefaultLabelChromeArmedProbe(store: store, style: style))
            host.frame = CGRect(x: 0, y: 0, width: 512, height: 88)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let trailingArmedIcon = try #require(store.frames["trailing-armed-icon"])
            let leadingArmedIcon = try #require(store.frames["leading-armed-icon"])
            let trailingUnarmedIcon = try #require(store.frames["trailing-unarmed-icon"])
            let trailingArmedTitle = try #require(store.frames["trailing-armed-title"])

            let armedFrontCenter =
                SwipeActionDefaultLabelMetrics.armedFrontInset
                + (style.iconSlotSize / 2)
            let labelCenterY: CGFloat = 88 / 2

            #expect(abs(trailingArmedIcon.midX - armedFrontCenter) < 0.5)
            #expect(abs((leadingArmedIcon.midX - 128) - (128 - armedFrontCenter)) < 0.5)
            #expect(abs((trailingUnarmedIcon.midX - 256) - 64) < 0.5)
            #expect(abs(trailingArmedIcon.midY - trailingUnarmedIcon.midY) < 0.5)
            #expect(trailingArmedIcon.midY < labelCenterY)
            #expect(abs(trailingArmedTitle.height - style.textSlotHeight) < 0.5)
        }

        @Test("default token destructive armed label slides glyph to fire edge and keeps title-only fallback")
        func defaultTokenDestructiveArmedLabelSlidesGlyphToFireEdge() throws {
            let store = FrameProbeStore()
            let host = NSHostingView(rootView: DefaultLabelChromeArmedProbe(store: store, revealStyle: .token))
            host.frame = CGRect(x: 0, y: 0, width: 512, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let trailingArmedIcon = try #require(store.frames["trailing-armed-icon"])
            let leadingArmedIcon = try #require(store.frames["leading-armed-icon"])
            let trailingUnarmedIcon = try #require(store.frames["trailing-unarmed-icon"])
            let trailingArmedTitle = try #require(store.frames["trailing-armed-title"])
            let titleOnlyArmedTitle = try #require(store.frames["title-only-armed-title"])

            let armedFrontCenter =
                SwipeActionDefaultLabelMetrics.armedFrontInset
                + (SwipeActionDefaultLabelMetrics.iconSlotSize / 2)
            let layout = SwipeActionTokenLayout(metrics: SwipeActionDefaultLabelMetrics())
            let tokenSize = layout.restingSize(slotWidth: DefaultLabelChromeArmedProbe.armedProbeRestSlotWidth)
            // The unarmed token probe is mid over-swipe (rest slot 64, live slot 128): the glyph stays
            // centered on the stretching capsule, not pinned to the compact resting center, so it never
            // drifts toward an edge. The capsule fill tracks the live slot, so deformation magnitude is moot.
            let tokenStretchedCenterX = layout.capsuleFrame(
                restSlotWidth: DefaultLabelChromeArmedProbe.armedProbeRestSlotWidth,
                liveSlotWidth: 128,
                position: 1,
                count: 2,
                stretchProgress: 0.5
            ).midX

            // Only on arm does the glyph slide to the content-facing fire edge — the same inset as the slot
            // chrome. The slide is driven by armed state, not deformation progress: an unarmed mid-stretch
            // glyph holds the capsule center instead of sliding.
            #expect(abs(trailingArmedIcon.midX - armedFrontCenter) < 0.5)
            #expect(abs((leadingArmedIcon.midX - 128) - (128 - armedFrontCenter)) < 0.5)
            #expect(abs((trailingUnarmedIcon.midX - 256) - tokenStretchedCenterX) < 0.5)
            // The glyph keeps its icon slot; only the token deforms horizontally.
            #expect(abs(trailingArmedIcon.width - SwipeActionDefaultLabelMetrics.iconSlotSize) < 0.5)
            #expect(abs(trailingArmedIcon.height - SwipeActionDefaultLabelMetrics.iconSlotSize) < 0.5)
            // Title slot stays mounted; the title-only fallback keeps its tint pill, never blanking.
            #expect(abs(trailingArmedTitle.height - SwipeActionDefaultLabelMetrics.textSlotHeight) < 0.5)
            #expect(abs(titleOnlyArmedTitle.height - tokenSize.height) < 0.5)
        }

        @Test("default label display mode keeps hidden title slots mounted")
        func defaultLabelDisplayModeKeepsHiddenTitleSlotsMounted() throws {
            let values = EnvironmentValues()
            #expect(values.swipeActionLabelDisplayMode == .iconAndTitle)

            let store = FrameProbeStore()
            let host = NSHostingView(rootView: DefaultLabelDisplayModeProbe(store: store))
            host.frame = CGRect(x: 0, y: 0, width: 216, height: 72)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()

            let iconTitleIcon = try #require(store.frames["icon-title-icon"])
            let iconTitleTitle = try #require(store.frames["icon-title-title"])
            #expect(store.frames["title-only-title"] != nil)
            #expect(store.frames["image-only-icon"] != nil)
            #expect(abs(iconTitleIcon.midY - (72 / 2)) < 0.5)
            #expect(abs(iconTitleTitle.height - SwipeActionDefaultLabelMetrics.textSlotHeight) < 0.5)
        }
    #endif

    @Test("token layout fits profile to the slot and stretches into a capsule")
    func tokenLayoutFitsProfileAndStretchesCapsule() {
        let metrics = SwipeActionDefaultLabelMetrics()
        let layout = SwipeActionTokenLayout(metrics: metrics)
        let wideSlot: CGFloat = 128

        // The iOS default is a 50pt circle. A narrow slot clamps the token so it never overflows, floored
        // at the icon slot so the glyph remains visible.
        #expect(layout.restingSize(slotWidth: wideSlot) == CGSize(width: 50, height: 50))
        let narrowSlot = metrics.iconSlotSize + 6
        let narrowSize = layout.restingSize(slotWidth: narrowSlot)
        #expect(narrowSize.width < 50)
        #expect(narrowSize.width >= metrics.iconSlotSize)
        #expect(narrowSize.height == narrowSize.width)

        // Destructive stretch keeps BOTH resting gaps fixed — the gap to the physical row edge and the gap
        // to the sibling / content — and only the slot's expansion lengthens the capsule in between (system
        // Mail). The math is side-agnostic; the resting frame's even-gap offset carries the side.
        let restSlot: CGFloat = 92
        let liveSlot: CGFloat = 128
        let leadingRest = layout.capsuleFrame(
            restSlotWidth: restSlot,
            liveSlotWidth: restSlot,
            position: 0,
            count: 2,
            stretchProgress: 0
        )
        let leadingStretched = layout.capsuleFrame(
            restSlotWidth: restSlot,
            liveSlotWidth: liveSlot,
            position: 0,
            count: 2,
            stretchProgress: 1
        )
        let trailingRest = layout.capsuleFrame(
            restSlotWidth: restSlot,
            liveSlotWidth: restSlot,
            position: 1,
            count: 2,
            stretchProgress: 0
        )
        let trailingStretched = layout.capsuleFrame(
            restSlotWidth: restSlot,
            liveSlotWidth: liveSlot,
            position: 1,
            count: 2,
            stretchProgress: 1
        )
        let siblingRest = layout.restingFrame(slotWidth: restSlot, position: 1, count: 2)
        let leadingRestGap = restSlot + siblingRest.minX - leadingRest.maxX
        let leadingLiveGap = liveSlot + siblingRest.minX - leadingStretched.maxX
        let trailingSiblingRest = layout.restingFrame(slotWidth: restSlot, position: 0, count: 2)
        let trailingRestGap = restSlot + trailingRest.minX - trailingSiblingRest.maxX
        let trailingLiveGap = restSlot + trailingStretched.minX - trailingSiblingRest.maxX

        // Inner gap (to sibling / content) preserved on both sides.
        #expect(abs(leadingLiveGap - leadingRestGap) < 0.001)
        #expect(abs(trailingLiveGap - trailingRestGap) < 0.001)
        // Outer gap (to the physical row edge) preserved on both sides: leading anchors `minX`, trailing
        // anchors the `maxX`-to-slot-edge distance — so the outer edge never drifts during over-swipe.
        #expect(abs(leadingStretched.minX - leadingRest.minX) < 0.001)
        #expect(abs((liveSlot - trailingStretched.maxX) - (restSlot - trailingRest.maxX)) < 0.001)
        // The capsule still lengthens to fill the expanded slot; height is unchanged.
        #expect(leadingStretched.width > leadingRest.width)
        #expect(trailingStretched.width > trailingRest.width)
        #expect(abs(leadingStretched.height - leadingRest.height) < 0.001)
        #expect(abs(trailingStretched.height - trailingRest.height) < 0.001)

        // `stretchProgress` only gates stretching; its magnitude does not interpolate the fill, so the fill
        // tracks the live slot directly (a partial or over-clamped progress matches full stretch).
        let partialTrailing = layout.capsuleFrame(
            restSlotWidth: restSlot,
            liveSlotWidth: liveSlot,
            position: 1,
            count: 2,
            stretchProgress: 0.3
        )
        let clampedTrailing = layout.capsuleFrame(
            restSlotWidth: restSlot,
            liveSlotWidth: liveSlot,
            position: 1,
            count: 2,
            stretchProgress: 2
        )
        #expect(abs(partialTrailing.maxX - trailingStretched.maxX) < 0.001)
        #expect(abs(clampedTrailing.maxX - trailingStretched.maxX) < 0.001)

        let macOSLayout = SwipeActionTokenLayout(
            metrics: metrics,
            profile: .macOSDefault
        )
        #expect(macOSLayout.restingSize(slotWidth: wideSlot) == CGSize(width: 60, height: 36))

        // Regression (#40/#41): a profile wider than its rest slot stays clamped to the rest slot — the
        // value the chrome uses for height — independent of how wide the live slot expands.
        let wideProfile = SwipeActionTokenProfile(
            restingWidth: 80,
            restingHeight: 44,
            titleSpacing: 4,
            stretchHorizontalInset: 4
        )
        let fittedLayout = SwipeActionTokenLayout(metrics: metrics, profile: wideProfile)
        let fittedSize = fittedLayout.restingSize(slotWidth: 64)
        #expect(fittedSize.width == 56)
        #expect(fittedSize.height == 44)
    }

    @Test("token layout distributes tokens with equal gaps")
    func tokenLayoutDistributesTokensWithEqualGaps() {
        let metrics = SwipeActionDefaultLabelMetrics()
        let layout = SwipeActionTokenLayout(metrics: metrics)
        let slot: CGFloat = 64

        // A single token stays centered (no distribution).
        #expect(layout.evenGapOffset(slotWidth: slot, position: 0, count: 1) == 0)

        // For N tokens in N equal slots, the token centers (slot center + even-gap offset) must yield equal
        // gaps everywhere: region edge -> first token, token -> token, last token -> region edge.
        let tokenWidth: CGFloat = layout.restingSize(slotWidth: slot).width
        let radius: CGFloat = tokenWidth / 2
        for count in 2...4 {
            let region: CGFloat = CGFloat(count) * slot
            var centers: [CGFloat] = []
            for p in 0..<count {
                let slotCenter: CGFloat = CGFloat(p) * slot + (slot / 2)
                let shift: CGFloat = layout.evenGapOffset(slotWidth: slot, position: p, count: count)
                centers.append(slotCenter + shift)
            }

            var gaps: [CGFloat] = [centers[0] - radius]
            for p in 1..<count {
                let between: CGFloat = (centers[p] - radius) - (centers[p - 1] + radius)
                gaps.append(between)
            }
            gaps.append(region - (centers[count - 1] + radius))

            let expected: CGFloat = (region - CGFloat(count) * tokenWidth) / CGFloat(count + 1)
            for gap in gaps {
                #expect(abs(gap - expected) < 0.001)
            }
        }
    }

    @Test("action shell presentation exposes only the active side")
    func actionShellPresentationExposesOnlyTheActiveSide() {
        let manager = SwipeCellManager()

        let closedPresentation = SwipeCellActionPresentation(
            side: .leading,
            cellID: "row",
            manager: manager
        )
        #expect(closedPresentation.isVisible == false)
        #expect(closedPresentation.allowsHitTesting == false)

        manager.beginInteraction(for: "row", side: .leading)

        let revealingLeadingPresentation = SwipeCellActionPresentation(
            side: .leading,
            cellID: "row",
            manager: manager
        )
        let hiddenTrailingPresentation = SwipeCellActionPresentation(
            side: .trailing,
            cellID: "row",
            manager: manager
        )

        #expect(revealingLeadingPresentation.isVisible == true)
        #expect(revealingLeadingPresentation.allowsHitTesting == false)
        #expect(hiddenTrailingPresentation.isVisible == false)
        #expect(hiddenTrailingPresentation.allowsHitTesting == false)

        manager.beginInteraction(for: "row", side: .trailing)
        manager.open(.trailing, for: "row")

        let leadingPresentation = SwipeCellActionPresentation(
            side: .leading,
            cellID: "row",
            manager: manager
        )
        let trailingPresentation = SwipeCellActionPresentation(
            side: .trailing,
            cellID: "row",
            manager: manager
        )

        #expect(leadingPresentation.isVisible == false)
        #expect(leadingPresentation.allowsHitTesting == false)
        #expect(trailingPresentation.isVisible == true)
        #expect(trailingPresentation.allowsHitTesting == true)

        manager.markTriggering(.trailing, for: "row")

        let triggeringLeadingPresentation = SwipeCellActionPresentation(
            side: .leading,
            cellID: "row",
            manager: manager
        )
        let triggeringTrailingPresentation = SwipeCellActionPresentation(
            side: .trailing,
            cellID: "row",
            manager: manager
        )

        #expect(triggeringLeadingPresentation.isVisible == false)
        #expect(triggeringLeadingPresentation.allowsHitTesting == false)
        #expect(triggeringTrailingPresentation.isVisible == true)
        #expect(triggeringTrailingPresentation.allowsHitTesting == true)
    }

    @Test("leading and trailing open actions trigger and reset")
    func leadingAndTrailingOpenActionsTriggerAndReset() {
        let leadingManager = SwipeCellManager()
        let leadingCoordinator = SwipeCellInteractionCoordinator()
        let leadingInputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: leadingManager,
            settlingAnimation: .linear(duration: 0)
        )
        var triggeredActions: [String] = []

        leadingManager.beginInteraction(for: "row", side: .leading)
        leadingManager.open(.leading, for: "row")

        let leadingResolution = SwipeCellActionTapGate.resolve(
            .leading,
            for: "row",
            manager: leadingManager
        )

        if case .immediate = leadingResolution {
            triggeredActions.append("leading")
            leadingCoordinator.beginActionTapClose(leadingInputs)
        }

        #expect(leadingResolution.didTrigger == true)
        #expect(triggeredActions == ["leading"])
        #expect(leadingManager.activeCellID == nil)
        #expect(leadingManager.phase == .resetting(.actionTrigger))
        #expect(leadingManager.lastResetReason == .actionTrigger)

        let trailingManager = SwipeCellManager()
        let trailingCoordinator = SwipeCellInteractionCoordinator()
        let trailingInputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: trailingManager,
            settlingAnimation: .linear(duration: 0)
        )
        trailingManager.beginInteraction(for: "row", side: .trailing)
        trailingManager.open(.trailing, for: "row")

        let trailingResolution = SwipeCellActionTapGate.resolve(
            .trailing,
            for: "row",
            manager: trailingManager
        )

        if case .immediate = trailingResolution {
            triggeredActions.append("trailing")
            trailingCoordinator.beginActionTapClose(trailingInputs)
        }

        #expect(trailingResolution.didTrigger == true)
        #expect(triggeredActions == ["leading", "trailing"])
        #expect(trailingManager.activeCellID == nil)
        #expect(trailingManager.phase == .resetting(.actionTrigger))
        #expect(trailingManager.lastResetReason == .actionTrigger)
    }

    @Test("action tap resets without running content tap-to-close")
    func actionTapResetsWithoutRunningContentTapToClose() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        var actionCount = 0
        var contentCloseCount = 0

        manager.beginInteraction(for: "row", side: .leading)
        manager.open(.leading, for: "row")

        let actionResolution = SwipeCellActionTapGate.resolve(
            .leading,
            for: "row",
            manager: manager
        )

        if case .immediate = actionResolution {
            actionCount += 1
            coordinator.beginActionTapClose(inputs)
        }

        #expect(actionResolution.didTrigger == true)
        #expect(actionCount == 1)
        #expect(contentCloseCount == 0)
        #expect(manager.activeCellID == nil)
        #expect(manager.phase == .resetting(.actionTrigger))
        #expect(manager.lastResetReason == .actionTrigger)

        let closedByContent = SwipeCellContentTapGate.close(
            for: "row",
            manager: manager
        ) {
            contentCloseCount += 1
        }

        #expect(closedByContent == .ignored)
        #expect(closedByContent.didConsumeTap == false)
        #expect(contentCloseCount == 0)
        #expect(manager.phase == .resetting(.actionTrigger))
    }

    @Test("action tap gate resolves fire timing")
    func actionTapGateResolvesFireTiming() {
        let immediateManager = SwipeCellManager()
        var phaseDuringImmediateAction: SwipeCellPhase?

        immediateManager.beginInteraction(for: "row", side: .leading)
        immediateManager.open(.leading, for: "row")

        let immediateResolution = SwipeCellActionTapGate.resolve(
            .leading,
            for: "row",
            manager: immediateManager,
            fireTiming: .immediate
        )
        phaseDuringImmediateAction = immediateManager.phase

        #expect(immediateResolution == .immediate)
        #expect(phaseDuringImmediateAction == .triggering(.leading))

        let afterCollapseManager = SwipeCellManager()
        var phaseDuringAfterCollapseAction: SwipeCellPhase?

        afterCollapseManager.beginInteraction(for: "row", side: .leading)
        afterCollapseManager.open(.leading, for: "row")

        let afterCollapseResolution = SwipeCellActionTapGate.resolve(
            .leading,
            for: "row",
            manager: afterCollapseManager,
            fireTiming: .afterCollapse
        )
        phaseDuringAfterCollapseAction = afterCollapseManager.phase

        #expect(afterCollapseResolution == .afterCollapse)
        #expect(phaseDuringAfterCollapseAction == .triggering(.leading))

        let holdOpenManager = SwipeCellManager()
        var phaseDuringHoldOpenAction: SwipeCellPhase?

        holdOpenManager.beginInteraction(for: "row", side: .leading)
        holdOpenManager.open(.leading, for: "row")

        let holdOpenResolution = SwipeCellActionTapGate.resolve(
            .leading,
            for: "row",
            manager: holdOpenManager,
            fireTiming: .triggerAndHoldOpen
        )
        phaseDuringHoldOpenAction = holdOpenManager.phase

        #expect(holdOpenResolution == .triggerAndHoldOpen)
        #expect(phaseDuringHoldOpenAction == .triggering(.leading))
        #expect(holdOpenManager.activeCellID == AnyHashable("row"))
        #expect(holdOpenManager.phase == .triggering(.leading))
        #expect(holdOpenManager.lastResetReason == nil)
        #expect(holdOpenManager.close() == true)
        #expect(holdOpenManager.phase == .resetting(.explicitClose))
    }

    @Test("content tap close lets row capture visible side before reset")
    func contentTapCloseLetsRowCaptureVisibleSideBeforeReset() {
        let manager = SwipeCellManager()
        var capturedSide: SwipeCellSide?

        manager.beginInteraction(for: "row", side: .trailing)
        manager.open(.trailing, for: "row")

        let closedByContent = SwipeCellContentTapGate.close(
            for: "row",
            manager: manager
        ) {
            capturedSide = SwipeCellActionPresentation.visibleSide(
                for: "row",
                manager: manager
            )
        }

        #expect(closedByContent == .closedOwner)
        #expect(capturedSide == .trailing)
        #expect(manager.phase == .resetting(.tapContent))
    }

    @Test("closed content tap does not consume caller click")
    func closedContentTapDoesNotConsumeCallerClick() {
        let manager = SwipeCellManager()
        var ownerClosePrepared = false

        let result = SwipeCellContentTapGate.close(for: "row", manager: manager) {
            ownerClosePrepared = true
        }

        #expect(result == .ignored)
        #expect(result.didConsumeTap == false)
        #expect(ownerClosePrepared == false)
        #expect(manager.shouldConsumeContentTap(for: "row") == false)
        #expect(manager.phase == .closed)
        #expect(manager.resetGeneration == 0)
    }

    @Test("foreign content tap closes visible owner without running target owner close")
    func foreignContentTapClosesVisibleOwnerWithoutRunningTargetOwnerClose() {
        let manager = SwipeCellManager()
        var targetOwnerCloseCount = 0

        manager.beginInteraction(for: "owner", side: .leading)
        manager.open(.leading, for: "owner")

        let closedByForeignTap = SwipeCellContentTapGate.close(
            for: "target",
            manager: manager
        ) {
            targetOwnerCloseCount += 1
        }

        #expect(closedByForeignTap == .closedForeignOwner)
        #expect(closedByForeignTap.didConsumeTap == true)
        #expect(targetOwnerCloseCount == 0)
        #expect(manager.activeCellID == nil)
        #expect(manager.resettingCellID == AnyHashable("owner"))
        #expect(manager.lastResetReason == .tapContent)
    }

    @Test("foreign content tap during visible reset is consumed without another reset")
    func foreignContentTapDuringVisibleResetIsConsumedWithoutAnotherReset() {
        let manager = SwipeCellManager()
        var targetOwnerCloseCount = 0

        manager.beginInteraction(for: "owner", side: .trailing)
        manager.open(.trailing, for: "owner")
        manager.reset(reason: .scroll)

        let generation = manager.resetGeneration
        let result = SwipeCellContentTapGate.close(
            for: "target",
            manager: manager
        ) {
            targetOwnerCloseCount += 1
        }

        #expect(result == .closedForeignOwner)
        #expect(targetOwnerCloseCount == 0)
        #expect(manager.resetGeneration == generation)
        #expect(manager.lastResetReason == .scroll)
    }

    @Test("closed or mismatched actions are ignored")
    func closedOrMismatchedActionsAreIgnored() {
        let manager = SwipeCellManager()

        #expect(
            SwipeCellActionTapGate.resolve(.leading, for: "row", manager: manager) == .ignored
        )

        manager.beginInteraction(for: "row", side: .leading)
        manager.open(.leading, for: "row")

        #expect(
            SwipeCellActionTapGate.resolve(.trailing, for: "row", manager: manager) == .ignored
        )

        #expect(manager.activeCellID == AnyHashable("row"))
        #expect(manager.phase == .open(.leading))
    }

    @Test("cell pan intent only begins for horizontal movement")
    func cellPanIntentOnlyBeginsForHorizontalMovement() {
        #expect(SwipeCellPanIntent.isHorizontal(velocity: CGPoint(x: 20, y: 8)) == true)
        #expect(SwipeCellPanIntent.isHorizontal(velocity: CGPoint(x: 8, y: 20)) == false)
        #expect(SwipeCellPanIntent.isHorizontal(velocity: CGPoint(x: 12, y: 12)) == false)
    }

    @Test("cell pan prediction projects velocity into end translation")
    func cellPanPredictionProjectsVelocityIntoEndTranslation() {
        let prediction = SwipeCellPanIntent.predictedEndTranslation(
            translation: CGSize(width: 20, height: 3),
            velocity: CGPoint(x: 200, y: -40)
        )

        #expect(prediction.width == 70)
        #expect(prediction.height == -7)
    }

    @Test("restoring an open side closes past threshold instead of crossing to the opposite side")
    func restoringOpenSideClosesInsteadOfCrossingToOppositeSide() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 92,
                normalOpenThreshold: 48
            )
        )

        #expect(
            model.snapshot(
                startSide: .trailing,
                translationWidth: 120,
                pointerActive: false
            ).releaseTarget == .closed
        )
        #expect(
            model.snapshot(
                startSide: .leading,
                translationWidth: -120,
                pointerActive: false
            ).releaseTarget == .closed
        )
        #expect(
            model.snapshot(
                startSide: .trailing,
                translationWidth: 1,
                pointerActive: false
            ).releaseTarget == .open(.trailing)
        )
        #expect(
            model.snapshot(
                startSide: .leading,
                translationWidth: -1,
                pointerActive: false
            ).releaseTarget == .open(.leading)
        )
    }

    @Test("same-side drag from an open side keeps that side open")
    func sameSideDragFromOpenSideKeepsThatSideOpen() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 92,
                normalOpenThreshold: 48
            )
        )

        #expect(
            model.snapshot(
                startSide: .trailing,
                translationWidth: -20,
                pointerActive: false
            ).releaseTarget == .open(.trailing)
        )
        #expect(
            model.snapshot(
                startSide: .leading,
                translationWidth: 20,
                pointerActive: false
            ).releaseTarget == .open(.leading)
        )
    }

    @Test("restoring drag keeps semantic side on the originally open side")
    func restoringDragKeepsSemanticSideOnOriginallyOpenSide() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 92,
                normalOpenThreshold: 48
            )
        )

        #expect(
            model.snapshot(
                startSide: .trailing,
                translationWidth: 120,
                pointerActive: true
            ).interactionSide == .trailing
        )
        #expect(
            model.snapshot(
                startSide: .leading,
                translationWidth: -120,
                pointerActive: true
            ).interactionSide == .leading
        )
    }
}

private struct Issue1ListScopeSample: View {
    var body: some View {
        List(0..<5, id: \.self) { row in
            Text("Row \(row)")
                .swipeCellIdentity(row)
        }
        .swipeCellScope()
    }
}

private struct IssueTapAndButtonSample: View {
    var body: some View {
        List {
            Text("Tap")
                .swipeCellIdentity("tap")
                .onTapGesture {}

            Button {
            } label: {
                Text("Button")
                    .swipeCellIdentity("button")
            }
            .buttonStyle(.plain)
        }
        .swipeCellScope()
    }
}

private struct Issue2ActionShellSample: View {
    private let manager = SwipeCellManager()

    var body: some View {
        SwipeCellActionShell(
            cellID: "action-shell",
            manager: manager,
            contentOffset: 92,
            containerWidth: 320,
            leadingGroup: SwipeActionGroup(
                side: .leading,
                actions: [SwipeAction("Leading", systemImage: "arrow.right") {}],
                actionWidth: 92
            ),
            trailingGroup: SwipeActionGroup(
                side: .trailing,
                actions: [SwipeAction("Trailing", systemImage: "arrow.left") {}],
                actionWidth: 92
            ),
            onContentTap: {},
            content: {
                Text("Long content should keep its original width while the panel moves.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 72)
                    .background(.background)
            }
        )
    }
}

private struct Issue8SwipeCellActionsSample: View {
    var body: some View {
        Text("Declarative")
            .frame(height: 72)
            .swipeCellActions(
                "row",
                leading: [
                    SwipeAction("Pin", systemImage: "pin", tint: .green) {},
                    SwipeAction("Mute", systemImage: "bell.slash", tint: .orange) {},
                ],
                trailing: [
                    SwipeAction("Delete", systemImage: "trash", role: .destructive(.init()), tint: .red) {},
                    SwipeAction(role: .normal(), tint: .purple) {
                    } label: { context in
                        Text(context.isArmed ? "Armed" : "More")
                    },
                ],
                revealStyle: .token
            )
            .swipeActionStyle(TestSwipeActionStyle())
            .swipeCellScope()
    }
}

private struct Issue17ActionTemplateSample: View {
    private enum SlotID: Hashable {
        case pin
        case delete
    }

    private static let template = SwipeCellActionTemplate(
        leading: [
            SwipeActionTemplate<String>(id: SlotID.pin, "Pin", systemImage: "pin") { _ in }
        ],
        trailing: [
            SwipeActionTemplate<String>(id: SlotID.delete, "Delete", systemImage: "trash", tint: .red) { _ in }
        ]
    )

    var body: some View {
        Text("Template")
            .frame(height: 72)
            .swipeCellActions("row")
            .swipeCellScope(actionTemplate: Self.template)
    }
}

private struct Issue69OwnedContainerScopeSample: View {
    var body: some View {
        ScrollView {
            Text("Owned")
                .swipeCellIdentity("owned")
        }
        .swipeCellScope(container: .scrollView)
    }
}

private struct Issue69CallerOwnedContainerScopeSample: View {
    private let manager = SwipeCellManager()

    var body: some View {
        ScrollView {
            Text("Caller")
                .swipeCellIdentity("caller")
        }
        .swipeCellScope(manager: manager, container: .scrollView)
    }
}

private struct TestSwipeActionStyle: SwipeActionStyle {
    func makeBody(configuration: SwipeActionStyleConfiguration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(configuration.tint)
    }
}

#if canImport(AppKit)
    @MainActor
    private final class FrameProbeStore {
        var frames: [String: CGRect] = [:]
    }

    @MainActor
    private final class ProgressProbeStore {
        var progress: CGFloat?
    }

    @MainActor
    private final class ActionContextProbeStore {
        var contexts: [String: SwipeActionContext] = [:]
    }

    private struct FrameProbePreferenceKey: PreferenceKey {
        static let defaultValue: [String: CGRect] = [:]

        static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
            value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
        }
    }

    private struct FrameProbe: View {
        let id: String

        var body: some View {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FrameProbePreferenceKey.self,
                    value: [id: proxy.frame(in: .named("action-shell-probe"))]
                )
            }
        }
    }

    private struct Issue2ActionShellFrameProbe: View {
        let manager: SwipeCellManager
        let store: FrameProbeStore
        let contentOffset: CGFloat
        var settlingSide: SwipeCellSide? = nil

        var body: some View {
            SwipeCellActionShell(
                cellID: "action-shell",
                manager: manager,
                contentOffset: contentOffset,
                normalOpenProgress: 1,
                containerWidth: 320,
                leadingGroup: Self.leadingGroup,
                trailingGroup: Self.trailingGroup,
                settlingSide: settlingSide,
                onContentTap: {},
                content: {
                    Color.white
                        .frame(width: 320, height: 72)
                        .background(FrameProbe(id: "content"))
                }
            )
            .coordinateSpace(name: "action-shell-probe")
            .frame(width: 320, height: 72)
            .onPreferenceChange(FrameProbePreferenceKey.self) { frames in
                store.frames = frames
            }
        }

        private static var leadingGroup: SwipeActionGroup {
            SwipeActionGroup(
                side: .leading,
                actions: [
                    frameProbeAction(id: "leading-0", tint: .green),
                    frameProbeAction(id: "leading-1", tint: .mint),
                ],
                actionWidth: 92
            )
        }

        private static var trailingGroup: SwipeActionGroup {
            SwipeActionGroup(
                side: .trailing,
                actions: [
                    frameProbeAction(id: "trailing-0", tint: .blue),
                    frameProbeAction(id: "trailing-1", tint: .cyan),
                ],
                actionWidth: 92
            )
        }

        private static func frameProbeAction(id: String, tint: Color) -> SwipeAction {
            SwipeAction(tint: tint) {
            } label: { _ in
                Color.clear
                    .background(FrameProbe(id: id))
            }
        }
    }

    private struct Issue11DestructiveGeometryFrameProbe: View {
        let manager: SwipeCellManager
        let store: FrameProbeStore
        let contentOffset: CGFloat
        var deformationProgress: CGFloat = 0.5
        var settlingSide: SwipeCellSide? = nil
        var takeoverSettlingSide: SwipeCellSide? = nil

        var body: some View {
            SwipeCellActionShell(
                cellID: "action-shell",
                manager: manager,
                contentOffset: contentOffset,
                normalOpenProgress: 1,
                deformationProgress: deformationProgress,
                containerWidth: 320,
                leadingGroup: SwipeActionGroup(side: .leading, actions: []),
                trailingGroup: trailingGroup,
                settlingSide: settlingSide,
                takeoverSettlingSide: takeoverSettlingSide,
                onContentTap: {},
                content: {
                    Color.white
                        .frame(width: 320, height: 72)
                        .background(FrameProbe(id: "content"))
                }
            )
            .coordinateSpace(name: "action-shell-probe")
            .frame(width: 320, height: 72)
            .onPreferenceChange(FrameProbePreferenceKey.self) { frames in
                store.frames = frames
            }
        }

        private var trailingGroup: SwipeActionGroup {
            SwipeActionGroup(
                side: .trailing,
                actions: [
                    frameProbeAction(id: "trailing-0", role: .destructive(.init()), tint: .red),
                    frameProbeAction(id: "trailing-1", role: .normal(), tint: .cyan),
                ],
                actionWidth: 92
            )
        }

        private func frameProbeAction(
            id: String,
            role: SwipeActionRole,
            tint: Color
        ) -> SwipeAction {
            SwipeAction(role: role, tint: tint) {
            } label: { _ in
                Color.clear
                    .background(FrameProbe(id: id))
            }
        }
    }

    private struct ProgressProbe: View {
        let store: ProgressProbeStore
        @Environment(\.swipeCellNormalOpenProgress) private var progress

        var body: some View {
            Color.clear
                .frame(width: 320, height: 72)
                .onAppear {
                    store.progress = progress
                }
                .onChange(of: progress) { _, newValue in
                    store.progress = newValue
                }
        }
    }

    private struct Issue4ProgressEnvironmentProbe: View {
        let manager: SwipeCellManager
        let store: ProgressProbeStore

        var body: some View {
            SwipeCellActionShell(
                cellID: "progress-probe",
                manager: manager,
                contentOffset: 0,
                normalOpenProgress: 0.625,
                containerWidth: 320,
                leadingGroup: SwipeActionGroup(
                    side: .leading,
                    actions: [SwipeAction("Leading") {}],
                    actionWidth: 92
                ),
                trailingGroup: SwipeActionGroup(
                    side: .trailing,
                    actions: [SwipeAction("Trailing") {}],
                    actionWidth: 92
                ),
                onContentTap: {},
                content: {
                    ProgressProbe(store: store)
                }
            )
            .frame(width: 320, height: 72)
        }
    }

    private struct ActionContextProbe: View {
        let id: String
        let context: SwipeActionContext
        let store: ActionContextProbeStore

        var body: some View {
            Color.clear
                .onAppear {
                    store.contexts[id] = context
                }
                .onChange(of: context) { _, newValue in
                    store.contexts[id] = newValue
                }
        }
    }

    private struct Issue8ActionContextProbe: View {
        let manager: SwipeCellManager
        let store: ActionContextProbeStore

        var body: some View {
            SwipeCellActionShell(
                cellID: "context-probe",
                manager: manager,
                contentOffset: -180,
                normalOpenProgress: 1,
                deformationProgress: 0.5,
                isArmed: false,
                armChangeID: 2,
                armChangeKind: .exitFire,
                containerWidth: 320,
                leadingGroup: SwipeActionGroup(side: .leading, actions: []),
                trailingGroup: trailingGroup,
                onContentTap: {},
                content: {
                    Color.white
                        .frame(width: 320, height: 72)
                }
            )
            .frame(width: 320, height: 72)
        }

        private var trailingGroup: SwipeActionGroup {
            SwipeActionGroup(
                side: .trailing,
                actions: [
                    contextProbeAction(id: "trailing-0", role: .destructive(.init()), tint: .red),
                    contextProbeAction(id: "trailing-1", role: .normal(), tint: .blue),
                ],
                actionWidth: 92
            )
        }

        private func contextProbeAction(
            id: String,
            role: SwipeActionRole,
            tint: Color
        ) -> SwipeAction {
            SwipeAction(role: role, tint: tint) {
            } label: { context in
                ActionContextProbe(
                    id: id,
                    context: context,
                    store: store
                )
            }
        }
    }

    private struct DefaultLabelChromeProbe: View {
        let idPrefix: String
        let hasIcon: Bool
        let hasTitle: Bool
        let context: SwipeActionContext
        var revealStyle: SwipeActionsRevealStyle = .slot

        @Environment(\.swipeActionLabelDisplayMode) private var displayMode
        @Environment(\.swipeActionDefaultLabelStyle) private var style

        var body: some View {
            SwipeActionDefaultLabelChrome(
                hasIcon: hasIcon,
                hasTitle: hasTitle,
                context: context,
                revealStyle: revealStyle,
                displayMode: displayMode,
                style: style
            ) {
                Color.clear
                    .background(FrameProbe(id: "\(idPrefix)-icon"))
            } title: {
                Color.clear
                    .background(FrameProbe(id: "\(idPrefix)-title"))
            }
        }
    }

    private struct DefaultLabelDisplayModeProbe: View {
        let store: FrameProbeStore

        var body: some View {
            HStack(spacing: 0) {
                DefaultLabelChromeProbe(
                    idPrefix: "icon-title",
                    hasIcon: true,
                    hasTitle: true,
                    context: Self.normalContext
                )
                .frame(width: 72, height: 72)

                DefaultLabelChromeProbe(
                    idPrefix: "title-only",
                    hasIcon: false,
                    hasTitle: true,
                    context: Self.normalContext
                )
                .frame(width: 72, height: 72)

                DefaultLabelChromeProbe(
                    idPrefix: "image-only",
                    hasIcon: true,
                    hasTitle: false,
                    context: Self.normalContext
                )
                .frame(width: 72, height: 72)
            }
            .swipeCellConfiguration(.iOSDefault)
            .swipeActionLabelDisplayMode(.iconOnly)
            .coordinateSpace(name: "action-shell-probe")
            .onPreferenceChange(FrameProbePreferenceKey.self) { frames in
                store.frames = frames
            }
        }

        private static var normalContext: SwipeActionContext {
            SwipeActionContext(
                side: .trailing,
                index: 0,
                count: 3,
                isOutermost: true,
                role: .normal,
                normalOpenProgress: 1,
                deformationProgress: 0,
                isArmed: false,
                armChangeID: 0
            )
        }
    }

    private struct DefaultLabelChromeAlignmentProbe: View {
        let store: FrameProbeStore
        var configuration: SwipeCellConfiguration = .iOSDefault
        var style: SwipeActionDefaultLabelStyle = .default
        var revealStyle: SwipeActionsRevealStyle = .slot

        var body: some View {
            HStack(spacing: 0) {
                DefaultLabelChromeProbe(
                    idPrefix: "both",
                    hasIcon: true,
                    hasTitle: true,
                    context: Self.normalContext,
                    revealStyle: revealStyle
                )
                .frame(width: 72, height: 72)

                DefaultLabelChromeProbe(
                    idPrefix: "image-only",
                    hasIcon: true,
                    hasTitle: false,
                    context: Self.normalContext,
                    revealStyle: revealStyle
                )
                .frame(width: 72, height: 72)

                DefaultLabelChromeProbe(
                    idPrefix: "title-only",
                    hasIcon: false,
                    hasTitle: true,
                    context: Self.normalContext,
                    revealStyle: revealStyle
                )
                .frame(width: 72, height: 72)
            }
            .swipeCellConfiguration(configuration)
            .swipeActionDefaultLabelStyle(style)
            .coordinateSpace(name: "action-shell-probe")
            .onPreferenceChange(FrameProbePreferenceKey.self) { frames in
                store.frames = frames
            }
        }

        private static var normalContext: SwipeActionContext {
            SwipeActionContext(
                side: .trailing,
                index: 0,
                count: 3,
                isOutermost: true,
                role: .normal,
                normalOpenProgress: 1,
                deformationProgress: 0,
                isArmed: false,
                armChangeID: 0
            )
        }
    }

    private struct DefaultLabelChromeArmedProbe: View {
        let store: FrameProbeStore
        var configuration: SwipeCellConfiguration = .iOSDefault
        var style: SwipeActionDefaultLabelStyle = .default
        var revealStyle: SwipeActionsRevealStyle = .slot

        var body: some View {
            HStack(spacing: 0) {
                DefaultLabelChromeProbe(
                    idPrefix: "trailing-armed",
                    hasIcon: true,
                    hasTitle: true,
                    context: Self.armedContext(side: .trailing),
                    revealStyle: revealStyle
                )
                .frame(width: 128, height: 72)

                DefaultLabelChromeProbe(
                    idPrefix: "leading-armed",
                    hasIcon: true,
                    hasTitle: true,
                    context: Self.armedContext(side: .leading),
                    revealStyle: revealStyle
                )
                .frame(width: 128, height: 72)

                DefaultLabelChromeProbe(
                    idPrefix: "trailing-unarmed",
                    hasIcon: true,
                    hasTitle: true,
                    context: Self.unarmedContext(side: .trailing),
                    revealStyle: revealStyle
                )
                .frame(width: 128, height: 72)

                DefaultLabelChromeProbe(
                    idPrefix: "title-only-armed",
                    hasIcon: false,
                    hasTitle: true,
                    context: Self.armedContext(side: .trailing),
                    revealStyle: revealStyle
                )
                .frame(width: 128, height: 72)
            }
            .swipeCellConfiguration(configuration)
            .swipeActionDefaultLabelStyle(style)
            // Resting slot narrower than the 128pt live frame, so the token capsule actually over-swipe
            // stretches and the glyph must track the stretched capsule center (ignored by the slot chrome).
            .environment(\.swipeActionRestSlotWidth, Self.armedProbeRestSlotWidth)
            .coordinateSpace(name: "action-shell-probe")
            .onPreferenceChange(FrameProbePreferenceKey.self) { frames in
                store.frames = frames
            }
        }

        static let armedProbeRestSlotWidth: CGFloat = 64

        private static func armedContext(side: SwipeCellSide) -> SwipeActionContext {
            SwipeActionContext(
                side: side,
                index: 0,
                count: 2,
                isOutermost: true,
                role: .destructive,
                normalOpenProgress: 1,
                deformationProgress: 1,
                isArmed: true,
                armChangeID: 1,
                armChangeKind: .enterFire
            )
        }

        // Mid over-swipe but not yet armed: the token is partly stretched, yet the glyph must hold center —
        // both chromes move the glyph only on arm (driven by armed state), never tracking deformation.
        private static func unarmedContext(side: SwipeCellSide) -> SwipeActionContext {
            SwipeActionContext(
                side: side,
                index: 0,
                count: 2,
                isOutermost: true,
                role: .destructive,
                normalOpenProgress: 1,
                deformationProgress: 0.5,
                isArmed: false,
                armChangeID: 2,
                armChangeKind: .exitFire
            )
        }
    }
#endif
