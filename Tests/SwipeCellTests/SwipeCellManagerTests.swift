import Foundation
import Testing

@testable import SwipeCell

@MainActor
@Suite("SwipeCellManager")
struct SwipeCellManagerTests {
    @Test("initial state has no active cell")
    func initialState() {
        let manager = SwipeCellManager()

        #expect(manager.activeCellID == nil)
        #expect(manager.activeSide == nil)
        #expect(manager.phase == .closed)
        #expect(manager.container == .list)
        #expect(manager.resetGeneration == 0)
        #expect(manager.resetRequest == nil)
    }

    @Test("scope container is stored without mutating interaction state")
    func scopeContainerIsStoredWithoutMutatingInteractionState() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .trailing)
        let generation = manager.resetGeneration

        manager.applyScope(
            container: .scrollView,
            configuration: SwipeCellConfiguration.platformDefault.resolved(for: .scrollView)
        )

        #expect(manager.container == .scrollView)
        #expect(manager.activeCellID == AnyHashable("A"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .revealing)
        #expect(manager.resetGeneration == generation)
    }

    @Test("activating a cell enters revealing ownership")
    func activateCell() {
        let manager = SwipeCellManager()

        let replaced = manager.beginInteraction(for: "A", side: .leading)

        #expect(replaced == false)
        #expect(manager.activeCellID == AnyHashable("A"))
        #expect(manager.activeSide == .leading)
        #expect(manager.phase == .revealing)
        #expect(manager.resetGeneration == 0)
    }

    @Test("active swipe drag flag excludes release settling")
    func activeSwipeDragExcludesReleaseSettling() {
        let manager = SwipeCellManager()
        #expect(manager.hasActiveSwipeDrag == false)

        // A drag in progress reveals: the macOS scope reads this to `.scrollDisabled` the parent.
        manager.beginInteraction(for: "A", side: .trailing)
        #expect(manager.hasActiveSwipeDrag)

        // Release settling keeps ownership for visible completion without keeping the parent locked.
        #expect(manager.beginGestureReleaseSettle(for: "A") == true)
        #expect(manager.phase == .revealing)
        #expect(manager.hasActiveSwipeDrag == false)

        // Settled open: the list regains vertical scrolling (and scroll-to-close).
        manager.open(.trailing, for: "A")
        #expect(manager.hasActiveSwipeDrag == false)

        // Re-dragging an already-open row re-enters revealing.
        manager.beginInteraction(for: "A", side: .trailing)
        #expect(manager.hasActiveSwipeDrag)

        manager.markTriggering(.trailing, for: "A")
        #expect(manager.hasActiveSwipeDrag == false)

        // Reset settles closed: not dragging.
        manager.reset(reason: .scroll)
        #expect(manager.hasActiveSwipeDrag == false)

        manager.completeReset()
    }

    @Test("activating another cell advances reset generation")
    func activateAnotherCellResetsPreviousOwnership() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .leading)
        manager.open(.leading, for: "A")

        let replaced = manager.beginInteraction(for: "B", side: .trailing)

        #expect(replaced == true)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .revealing)
        #expect(manager.resetGeneration == 1)
        #expect(manager.lastResetReason == .replacedByAnotherCell)
        #expect(manager.resettingCellID == AnyHashable("A"))
    }

    @Test("same active interaction preserves foreign visible reset owner")
    func sameActiveInteractionPreservesForeignVisibleResetOwner() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .leading)
        manager.open(.leading, for: "A")
        manager.beginInteraction(for: "B", side: .trailing)

        let generation = manager.resetGeneration
        let replaced = manager.beginInteraction(for: "B", side: .trailing)

        #expect(replaced == false)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(manager.resetGeneration == generation)
    }

    @Test("owner can open leading and trailing")
    func ownerCanOpenSides() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: 1)

        #expect(manager.open(.leading, for: 1) == true)
        #expect(manager.phase == .open(.leading))
        #expect(manager.activeSide == .leading)

        manager.beginInteraction(for: 1)
        #expect(manager.open(.trailing, for: 1) == true)
        #expect(manager.phase == .open(.trailing))
        #expect(manager.activeSide == .trailing)
    }

    @Test("programmatic open rejects unmounted row without mutating owner state")
    func programmaticOpenRejectsUnmountedRow() {
        let manager = SwipeCellManager()

        #expect(manager.open("missing", side: .trailing) == false)
        #expect(manager.activeCellID == nil)
        #expect(manager.activeSide == nil)
        #expect(manager.phase == .closed)
        #expect(manager.resetGeneration == 0)
        #expect(manager.programmaticOpenRequest == nil)
    }

    @Test("programmatic open rejects unavailable side without mutating owner state")
    func programmaticOpenRejectsUnavailableSide() {
        let manager = SwipeCellManager()
        manager.registerProgrammaticOpenTarget(
            for: "row",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: false
            )
        ) { _ in }

        #expect(manager.open("row", side: .trailing) == false)
        #expect(manager.activeCellID == nil)
        #expect(manager.phase == .closed)
        #expect(manager.resetGeneration == 0)
        #expect(manager.programmaticOpenRequest == nil)
    }

    @Test("programmatic open publishes accepted request with default non-animated flag")
    func programmaticOpenPublishesAcceptedRequest() {
        let manager = SwipeCellManager()
        var receivedRequest: SwipeCellProgrammaticOpenRequest?
        manager.registerProgrammaticOpenTarget(
            for: "row",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { request in
            receivedRequest = request
        }

        #expect(manager.open("row", side: .trailing) == true)
        #expect(manager.activeCellID == AnyHashable("row"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .open(.trailing))
        #expect(manager.resetGeneration == 0)
        #expect(manager.programmaticOpenGeneration == 1)
        #expect(manager.programmaticOpenRequest?.animated == false)
        #expect(receivedRequest == manager.programmaticOpenRequest)
    }

    @Test("programmatic open preserves explicit animated flag")
    func programmaticOpenPreservesAnimatedFlag() {
        let manager = SwipeCellManager()
        manager.registerProgrammaticOpenTarget(
            for: "row",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { _ in }

        #expect(manager.open("row", side: .leading, animated: true) == true)
        #expect(manager.programmaticOpenRequest?.animated == true)
        #expect(manager.programmaticOpenRequest?.side == .leading)
    }

    @Test("programmatic open replaces existing owner through reset generation")
    func programmaticOpenReplacesExistingOwnerThroughResetGeneration() {
        let manager = SwipeCellManager()
        manager.registerProgrammaticOpenTarget(
            for: "B",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { _ in }
        manager.beginInteraction(for: "A", side: .leading)
        manager.open(.leading, for: "A")

        #expect(manager.open("B", side: .trailing) == true)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .open(.trailing))
        #expect(manager.resetGeneration == 1)
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(manager.lastResetReason == .replacedByAnotherCell)
    }

    @Test("same target programmatic open preserves foreign visible reset owner")
    func sameTargetProgrammaticOpenPreservesForeignVisibleResetOwner() {
        let manager = SwipeCellManager()
        manager.registerProgrammaticOpenTarget(
            for: "B",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { _ in }
        manager.beginInteraction(for: "A", side: .leading)
        manager.open(.leading, for: "A")
        #expect(manager.open("B", side: .trailing) == true)

        let generation = manager.resetGeneration
        #expect(manager.open("B", side: .leading) == true)

        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.activeSide == .leading)
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(manager.resetGeneration == generation)
    }

    @Test("scroll reset clears active owner")
    func scrollResetClearsActiveOwner() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A")

        let reset = manager.reset(reason: .scroll)

        #expect(reset == true)
        #expect(manager.activeCellID == nil)
        #expect(manager.activeSide == nil)
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(manager.phase == .resetting(.scroll))
        #expect(manager.resetGeneration == 1)
        #expect(manager.resetRequest?.generation == 1)
        #expect(manager.resetRequest?.reason == .scroll)
        #expect(manager.resetRequest?.animated == true)

        manager.completeReset()
        #expect(manager.resettingCellID == nil)
        #expect(manager.phase == .closed)
    }

    @Test("scroll reset without active owner is no-op")
    func scrollResetWithoutActiveOwnerIsNoOp() {
        let manager = SwipeCellManager()

        let reset = manager.reset(reason: .scroll)

        #expect(reset == false)
        #expect(manager.activeCellID == nil)
        #expect(manager.phase == .closed)
        #expect(manager.resetGeneration == 0)
        #expect(manager.resetRequest == nil)
    }

    @Test("public close defaults to animated explicit close")
    func publicCloseDefaultsToAnimatedExplicitClose() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .trailing)
        manager.open(.trailing, for: "A")

        #expect(manager.close() == true)
        #expect(manager.activeCellID == nil)
        #expect(manager.activeSide == nil)
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(manager.phase == .resetting(.explicitClose))
        #expect(manager.resetGeneration == 1)
        #expect(manager.resetRequest?.generation == 1)
        #expect(manager.resetRequest?.reason == .explicitClose)
        #expect(manager.resetRequest?.animated == true)
    }

    @Test("public close can request immediate explicit close")
    func publicCloseCanRequestImmediateExplicitClose() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .leading)
        manager.open(.leading, for: "A")

        #expect(manager.close(animated: false) == true)
        #expect(manager.phase == .resetting(.explicitClose))
        #expect(manager.resetRequest?.reason == .explicitClose)
        #expect(manager.resetRequest?.animated == false)
    }

    @Test("public close without active owner is no-op")
    func publicCloseWithoutActiveOwnerIsNoOp() {
        let manager = SwipeCellManager()

        #expect(manager.close() == false)
        #expect(manager.activeCellID == nil)
        #expect(manager.activeSide == nil)
        #expect(manager.phase == .closed)
        #expect(manager.resetGeneration == 0)
        #expect(manager.resetRequest == nil)
    }

    @Test("horizontal interaction briefly suppresses scroll reset")
    func horizontalInteractionBrieflySuppressesScrollReset() {
        let manager = SwipeCellManager()

        #expect(manager.canResetForScroll() == true)

        manager.beginInteraction(for: "A", side: .trailing)

        #expect(manager.canResetForScroll() == false)
        #expect(manager.canResetForScroll(now: Date().addingTimeInterval(1)) == true)

        manager.open(.trailing, for: "A")

        #expect(manager.canResetForScroll() == false)
        #expect(manager.canResetForScroll(now: Date().addingTimeInterval(1)) == true)
    }

    @Test("owner close paths clear active owner")
    func ownerClosePathsClearActiveOwner() {
        for reason in [
            SwipeCellResetReason.explicitClose,
            .tapContent,
            .actionTrigger,
            .gestureCancelled,
            .editMode,
        ] {
            let manager = SwipeCellManager()
            manager.beginInteraction(for: "A")

            #expect(manager.close("A", reason: reason) == true)
            #expect(manager.activeCellID == nil)
            #expect(manager.phase == .resetting(reason))
        }
    }

    @Test("non-owner cannot close or mutate active state")
    func nonOwnerCannotCloseOrMutateActiveState() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .leading)

        #expect(manager.open(.trailing, for: "B") == false)
        #expect(manager.close("B", reason: .explicitClose) == false)
        #expect(manager.activeCellID == AnyHashable("A"))
        #expect(manager.activeSide == .leading)
        #expect(manager.phase == .revealing)
        #expect(manager.resetGeneration == 0)
    }

    @Test("foreign tap closes current owner without taking target ownership")
    func foreignTapClosesCurrentOwnerWithoutTakingTargetOwnership() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .trailing)
        manager.open(.trailing, for: "A")

        let closed = manager.closeForeignVisibleOwner(from: "B", reason: .tapContent)

        #expect(closed == true)
        #expect(manager.activeCellID == nil)
        #expect(manager.activeSide == nil)
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(manager.phase == .resetting(.tapContent))
        #expect(manager.lastResetReason == .tapContent)
        #expect(manager.shouldConsumeContentTap(for: "B") == true)
    }

    @Test("resetting owner blocks foreign tap until visible reset completes")
    func resettingOwnerBlocksForeignTapUntilVisibleResetCompletes() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "A", side: .leading)
        manager.open(.leading, for: "A")
        manager.reset(reason: .scroll)

        let generation = manager.resetGeneration
        let closedAgain = manager.closeForeignVisibleOwner(from: "B", reason: .tapContent)

        #expect(closedAgain == true)
        #expect(manager.resetGeneration == generation)
        #expect(manager.lastResetReason == .scroll)
        #expect(manager.shouldConsumeContentTap(for: "B") == true)

        manager.completeVisibleReset(for: "A")

        #expect(manager.resettingCellID == nil)
        #expect(manager.shouldConsumeContentTap(for: "B") == false)
    }

    @Test("manager instances isolate list scopes")
    func managerInstancesIsolateScopes() {
        let outer = SwipeCellManager()
        let inner = SwipeCellManager()

        outer.beginInteraction(for: "outer")
        inner.beginInteraction(for: "inner")
        inner.reset(reason: .scroll)

        #expect(outer.activeCellID == AnyHashable("outer"))
        #expect(outer.phase == .revealing)
        #expect(outer.resetGeneration == 0)
        #expect(inner.activeCellID == nil)
        #expect(inner.phase == .resetting(.scroll))
        #expect(inner.resetGeneration == 1)
    }
}
