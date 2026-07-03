import Foundation
import Observation

nonisolated public enum SwipeCellSide: Equatable, Sendable {
    case leading
    case trailing
}

nonisolated public enum SwipeCellResetReason: Equatable, Sendable {
    case replacedByAnotherCell
    case scroll
    case tapContent
    case actionTrigger
    case explicitClose
    case gestureCancelled
    case editMode
}

nonisolated public enum SwipeCellPhase: Equatable, Sendable {
    case closed
    case revealing
    case open(SwipeCellSide)
    case triggering(SwipeCellSide)
    case resetting(SwipeCellResetReason)
}

struct SwipeCellProgrammaticOpenRequest: Equatable {
    let generation: Int
    let cellID: AnyHashable
    let side: SwipeCellSide
    let animated: Bool
}

struct SwipeCellResetRequest: Equatable {
    let generation: Int
    let reason: SwipeCellResetReason
    let animated: Bool
}

struct SwipeCellProgrammaticOpenCapabilities: Equatable {
    let canOpenLeading: Bool
    let canOpenTrailing: Bool

    func canOpen(_ side: SwipeCellSide) -> Bool {
        switch side {
        case .leading:
            canOpenLeading
        case .trailing:
            canOpenTrailing
        }
    }
}

private struct SwipeCellProgrammaticOpenTarget {
    let registrationID: Int
    let capabilities: SwipeCellProgrammaticOpenCapabilities
    let open: (SwipeCellProgrammaticOpenRequest) -> Void

    func canOpen(_ side: SwipeCellSide) -> Bool {
        capabilities.canOpen(side)
    }
}

#if DEBUG
    private struct SwipeCellManagerValidationSnapshot {
        let activeCellID: AnyHashable?
        let activeSide: SwipeCellSide?
        let phase: SwipeCellPhase
        let isGestureReleaseSettling: Bool
        let resetGeneration: Int
        let lastResetReason: SwipeCellResetReason?
        let resettingCellID: AnyHashable?

        init(_ manager: SwipeCellManager) {
            activeCellID = manager.activeCellID
            activeSide = manager.activeSide
            phase = manager.phase
            isGestureReleaseSettling = manager.isGestureReleaseSettling
            resetGeneration = manager.resetGeneration
            lastResetReason = manager.lastResetReason
            resettingCellID = manager.resettingCellID
        }
    }
#endif

@Observable
public final class SwipeCellManager {
    public private(set) var activeCellID: AnyHashable?
    public private(set) var activeSide: SwipeCellSide?
    public private(set) var phase: SwipeCellPhase
    private(set) var container: SwipeCellContainer
    /// Scope-local token that tells stale owner cells to collapse their local UI.
    private(set) var resetGeneration: Int
    public private(set) var lastResetReason: SwipeCellResetReason?
    private(set) var resetRequest: SwipeCellResetRequest?
    private(set) var programmaticOpenGeneration: Int = 0
    private(set) var programmaticOpenRequest: SwipeCellProgrammaticOpenRequest?
    /// The previous owner remains tap-blocking only while its local close animation is still visible.
    private(set) var resettingCellID: AnyHashable?
    /// Release settles keep the owner until visible completion, but they are no longer active drags.
    fileprivate var isGestureReleaseSettling = false
    @ObservationIgnored private var timing = SwipeCellConfiguration.platformDefault.timing
    @ObservationIgnored private var scrollResetSuppressedUntil: Date?
    @ObservationIgnored private var programmaticOpenTargets: [AnyHashable: SwipeCellProgrammaticOpenTarget] = [:]
    @ObservationIgnored private var nextProgrammaticOpenRegistrationID = 0

    public init() {
        self.activeCellID = nil
        self.activeSide = nil
        self.phase = .closed
        self.container = .list
        self.resetGeneration = 0
        self.lastResetReason = nil
    }

    func applyConfiguration(_ configuration: SwipeCellConfiguration) {
        timing = configuration.timing
    }

    func applyScope(
        container: SwipeCellContainer,
        configuration: SwipeCellConfiguration
    ) {
        self.container = container
        applyConfiguration(configuration)
    }

    @discardableResult
    func beginInteraction<CellID: Hashable>(
        for cellID: CellID,
        side: SwipeCellSide? = nil
    ) -> Bool {
        #if DEBUG
            let before = validationSnapshot
        #endif
        suppressScrollReset()

        let erasedID = AnyHashable(cellID)
        let replacesActiveCell = activeCellID.map { $0 != erasedID } ?? false

        if replacesActiveCell {
            resettingCellID = activeCellID
            publishResetRequest(reason: .replacedByAnotherCell, animated: true)
        } else {
            clearOwnResettingCell(erasedID)
            lastResetReason = nil
        }

        activeCellID = erasedID
        activeSide = side
        phase = .revealing
        isGestureReleaseSettling = false

        #if DEBUG
            let cycle = SwipeCellValidationDiagnostics.beginCycle(for: erasedID)
            let after = validationSnapshot
            if replacesActiveCell, let replacedCellID = before.activeCellID {
                emitValidationEvent(
                    "manager.reset",
                    cellID: replacedCellID,
                    before: before,
                    after: after,
                    fields: [
                        .init("reason", SwipeCellResetReason.replacedByAnotherCell),
                        .init("animatedRequest", true),
                        .init("source", "foreign-owner"),
                    ]
                )
            }
            emitValidationEvent(
                "manager.beginInteraction",
                cellID: erasedID,
                cycle: cycle,
                before: before,
                after: after,
                verdict: SwipeCellValidationDiagnostics.resettingOwnerClearedVerdict(
                    event: "manager.beginInteraction",
                    resettingBefore: before.resettingCellID,
                    resettingAfter: after.resettingCellID
                ),
                fields: [
                    .init("side", side),
                    .init("replacedActiveCell", replacesActiveCell),
                ]
            )
        #endif

        return replacesActiveCell
    }

    @discardableResult
    func open<CellID: Hashable>(_ side: SwipeCellSide, for cellID: CellID) -> Bool {
        #if DEBUG
            let before = validationSnapshot
        #endif
        guard ownsActiveCell(cellID) else { return false }

        suppressScrollReset()
        activeSide = side
        phase = .open(side)
        isGestureReleaseSettling = false
        lastResetReason = nil

        #if DEBUG
            emitValidationEvent(
                "manager.open",
                cellID: AnyHashable(cellID),
                before: before,
                after: validationSnapshot,
                fields: [.init("side", side)]
            )
        #endif

        return true
    }

    @discardableResult
    public func open<CellID: Hashable>(
        _ cellID: CellID,
        side: SwipeCellSide,
        animated: Bool = false
    ) -> Bool {
        let erasedID = AnyHashable(cellID)
        guard let target = programmaticOpenTargets[erasedID],
            target.canOpen(side)
        else {
            return false
        }

        let request = acceptProgrammaticOpen(for: erasedID, side: side, animated: animated)
        target.open(request)

        return true
    }

    @discardableResult
    public func close(animated: Bool = true) -> Bool {
        reset(reason: .explicitClose, animated: animated)
    }

    @discardableResult
    func markTriggering<CellID: Hashable>(
        _ side: SwipeCellSide,
        for cellID: CellID
    ) -> Bool {
        #if DEBUG
            let before = validationSnapshot
        #endif
        guard ownsActiveCell(cellID) else { return false }

        activeSide = side
        phase = .triggering(side)
        isGestureReleaseSettling = false
        lastResetReason = nil

        #if DEBUG
            emitValidationEvent(
                "manager.markTriggering",
                cellID: AnyHashable(cellID),
                before: before,
                after: validationSnapshot,
                fields: [.init("side", side)]
            )
        #endif

        return true
    }

    @discardableResult
    func applyReleaseTarget<CellID: Hashable>(
        _ target: SwipeCellReleaseTarget,
        for cellID: CellID,
        closeReason: SwipeCellResetReason = .gestureCancelled
    ) -> Bool {
        switch target {
        case .closed:
            close(cellID, reason: closeReason)
        case .open(let side):
            open(side, for: cellID)
        case .destructive(let side):
            markTriggering(side, for: cellID)
        }
    }

    @discardableResult
    func close<CellID: Hashable>(
        _ cellID: CellID,
        reason: SwipeCellResetReason = .explicitClose,
        animated: Bool = true
    ) -> Bool {
        guard ownsActiveCell(cellID) else { return false }

        return reset(reason: reason, animated: animated)
    }

    @discardableResult
    func reset(reason: SwipeCellResetReason, animated: Bool = true) -> Bool {
        #if DEBUG
            let before = validationSnapshot
        #endif
        guard let resettingOwnerID = activeCellID else { return false }

        activeCellID = nil
        activeSide = nil
        resettingCellID = resettingOwnerID
        phase = .resetting(reason)
        isGestureReleaseSettling = false
        publishResetRequest(reason: reason, animated: animated)

        #if DEBUG
            emitValidationEvent(
                "manager.reset",
                cellID: resettingOwnerID,
                before: before,
                after: validationSnapshot,
                fields: [
                    .init("reason", reason),
                    .init("animatedRequest", animated),
                    .init("source", reason.validationSource),
                ]
            )
        #endif

        return true
    }

    func completeReset() {
        #if DEBUG
            let before = validationSnapshot
        #endif
        guard case .resetting = phase else { return }
        resettingCellID = nil
        phase = .closed
        isGestureReleaseSettling = false
        #if DEBUG
            emitValidationEvent(
                "manager.completeReset",
                cellID: before.resettingCellID ?? before.activeCellID ?? AnyHashable("nil"),
                before: before,
                after: validationSnapshot
            )
        #endif
    }

    func ownsActiveCell<CellID: Hashable>(_ cellID: CellID) -> Bool {
        activeCellID == AnyHashable(cellID)
    }

    /// True only while a horizontal swipe drag is in progress. Release settles may keep the owner in
    /// `.revealing` until visible completion, but they must cancel the parent scroll lock immediately.
    var hasActiveSwipeDrag: Bool {
        phase == .revealing && !isGestureReleaseSettling
    }

    @discardableResult
    func beginGestureReleaseSettle<CellID: Hashable>(for cellID: CellID) -> Bool {
        #if DEBUG
            let before = validationSnapshot
        #endif
        guard ownsActiveCell(cellID) else { return false }

        isGestureReleaseSettling = true
        #if DEBUG
            emitValidationEvent(
                "manager.beginGestureReleaseSettle",
                cellID: AnyHashable(cellID),
                before: before,
                after: validationSnapshot
            )
        #endif
        return true
    }

    func shouldConsumeContentTap<CellID: Hashable>(for cellID: CellID) -> Bool {
        ownsActiveCell(cellID) || hasForeignVisibleOwner(for: cellID)
    }

    @discardableResult
    func closeForeignVisibleOwner<CellID: Hashable>(
        from cellID: CellID,
        reason: SwipeCellResetReason
    ) -> Bool {
        #if DEBUG
            let before = validationSnapshot
        #endif
        let erasedID = AnyHashable(cellID)

        if let activeCellID {
            guard activeCellID != erasedID else { return false }
            let didReset = reset(reason: reason)
            #if DEBUG
                if didReset {
                    emitValidationEvent(
                        "manager.closeForeignVisibleOwner",
                        cellID: activeCellID,
                        before: before,
                        after: validationSnapshot,
                        fields: [
                            .init("sourceCell", erasedID),
                            .init("reason", reason),
                            .init("result", "resetActiveOwner"),
                        ]
                    )
                }
            #endif
            return didReset
        }

        if let resettingCellID {
            let blocksForeignCell = resettingCellID != erasedID
            #if DEBUG
                if blocksForeignCell {
                    emitValidationEvent(
                        "manager.closeForeignVisibleOwner",
                        cellID: resettingCellID,
                        before: before,
                        after: validationSnapshot,
                        fields: [
                            .init("sourceCell", erasedID),
                            .init("reason", reason),
                            .init("result", "blockedByResettingOwner"),
                        ]
                    )
                }
            #endif
            return blocksForeignCell
        }

        return false
    }

    func ownsResettingCell<CellID: Hashable>(_ cellID: CellID) -> Bool {
        resettingCellID == AnyHashable(cellID)
    }

    func completeVisibleReset<CellID: Hashable>(for cellID: CellID) {
        #if DEBUG
            let before = validationSnapshot
        #endif
        guard ownsResettingCell(cellID) else { return }
        resettingCellID = nil
        // Foreign replacement keeps the new owner phase; reset-owned closes return the scope to idle.
        if case .resetting = phase {
            phase = .closed
            isGestureReleaseSettling = false
        }
        #if DEBUG
            emitValidationEvent(
                "manager.completeVisibleReset",
                cellID: AnyHashable(cellID),
                before: before,
                after: validationSnapshot
            )
        #endif
    }

    func resetRequest(for generation: Int) -> SwipeCellResetRequest? {
        guard resetRequest?.generation == generation else { return nil }
        return resetRequest
    }

    @discardableResult
    func registerProgrammaticOpenTarget<CellID: Hashable>(
        for cellID: CellID,
        capabilities: SwipeCellProgrammaticOpenCapabilities,
        open: @escaping (SwipeCellProgrammaticOpenRequest) -> Void
    ) -> Int {
        nextProgrammaticOpenRegistrationID += 1
        let registrationID = nextProgrammaticOpenRegistrationID
        programmaticOpenTargets[AnyHashable(cellID)] = SwipeCellProgrammaticOpenTarget(
            registrationID: registrationID,
            capabilities: capabilities,
            open: open
        )
        return registrationID
    }

    func unregisterProgrammaticOpenTarget<CellID: Hashable>(
        for cellID: CellID,
        registrationID: Int
    ) {
        let erasedID = AnyHashable(cellID)
        guard programmaticOpenTargets[erasedID]?.registrationID == registrationID else { return }
        programmaticOpenTargets[erasedID] = nil
    }

    func canResetForScroll(now: Date = Date()) -> Bool {
        guard let scrollResetSuppressedUntil else { return true }
        guard now >= scrollResetSuppressedUntil else { return false }

        self.scrollResetSuppressedUntil = nil
        return true
    }

    private func suppressScrollReset(now: Date = Date()) {
        scrollResetSuppressedUntil = now.addingTimeInterval(timing.scrollResetSuppression)
    }

    private func acceptProgrammaticOpen(
        for cellID: AnyHashable,
        side: SwipeCellSide,
        animated: Bool
    ) -> SwipeCellProgrammaticOpenRequest {
        #if DEBUG
            let before = validationSnapshot
        #endif
        suppressScrollReset()

        let replacesActiveCell = activeCellID.map { $0 != cellID } ?? false

        if replacesActiveCell {
            resettingCellID = activeCellID
            publishResetRequest(reason: .replacedByAnotherCell, animated: true)
        } else {
            clearOwnResettingCell(cellID)
            lastResetReason = nil
        }

        activeCellID = cellID
        activeSide = side
        phase = .open(side)
        isGestureReleaseSettling = false
        programmaticOpenGeneration += 1
        let request = SwipeCellProgrammaticOpenRequest(
            generation: programmaticOpenGeneration,
            cellID: cellID,
            side: side,
            animated: animated
        )
        programmaticOpenRequest = request

        #if DEBUG
            let cycle = SwipeCellValidationDiagnostics.beginCycle(for: cellID)
            let after = validationSnapshot
            if replacesActiveCell, let replacedCellID = before.activeCellID {
                emitValidationEvent(
                    "manager.reset",
                    cellID: replacedCellID,
                    before: before,
                    after: after,
                    fields: [
                        .init("reason", SwipeCellResetReason.replacedByAnotherCell),
                        .init("animatedRequest", true),
                        .init("source", "programmatic-open"),
                    ]
                )
            }
            emitValidationEvent(
                "manager.open",
                cellID: cellID,
                cycle: cycle,
                before: before,
                after: after,
                verdict: SwipeCellValidationDiagnostics.resettingOwnerClearedVerdict(
                    event: "manager.open",
                    resettingBefore: before.resettingCellID,
                    resettingAfter: after.resettingCellID
                ),
                fields: [
                    .init("side", side),
                    .init("animatedRequest", animated),
                    .init("source", "programmatic-open"),
                    .init("replacedActiveCell", replacesActiveCell),
                ]
            )
        #endif

        return request
    }

    private func publishResetRequest(reason: SwipeCellResetReason, animated: Bool) {
        resetGeneration += 1
        lastResetReason = reason
        resetRequest = SwipeCellResetRequest(
            generation: resetGeneration,
            reason: reason,
            animated: animated
        )
    }

    private func hasForeignVisibleOwner<CellID: Hashable>(for cellID: CellID) -> Bool {
        let erasedID = AnyHashable(cellID)

        if let activeCellID {
            return activeCellID != erasedID
        }

        if let resettingCellID {
            return resettingCellID != erasedID
        }

        return false
    }

    /// Same-row continuation may take over its own pending reset; a foreign reset owner must complete
    /// from that row's local close driver.
    private func clearOwnResettingCell(_ cellID: AnyHashable) {
        guard resettingCellID == cellID else { return }
        resettingCellID = nil
    }

    #if DEBUG
        private var validationSnapshot: SwipeCellManagerValidationSnapshot {
            SwipeCellManagerValidationSnapshot(self)
        }

        private func emitValidationEvent(
            _ event: String,
            cellID: AnyHashable,
            cycle: Int? = nil,
            before: SwipeCellManagerValidationSnapshot,
            after: SwipeCellManagerValidationSnapshot,
            verdict: SwipeCellValidationDiagnostics.Verdict? = nil,
            fields: [SwipeCellValidationDiagnostics.Field] = []
        ) {
            SwipeCellValidationDiagnostics.emit(
                event: event,
                cellID: cellID,
                cycle: cycle,
                verdict: verdict,
                fields: validationFields(before: before, after: after) + fields
            )
        }

        private func validationFields(
            before: SwipeCellManagerValidationSnapshot,
            after: SwipeCellManagerValidationSnapshot
        ) -> [SwipeCellValidationDiagnostics.Field] {
            [
                .init("phaseBefore", before.phase),
                .init("phaseAfter", after.phase),
                .init("activeBefore", before.activeCellID),
                .init("activeAfter", after.activeCellID),
                .init("activeSideBefore", before.activeSide),
                .init("activeSideAfter", after.activeSide),
                .init("releaseSettlingBefore", before.isGestureReleaseSettling),
                .init("releaseSettlingAfter", after.isGestureReleaseSettling),
                .init("resettingBefore", before.resettingCellID),
                .init("resettingAfter", after.resettingCellID),
                .init("resetGen", after.resetGeneration),
                .init("resetReason", after.lastResetReason),
            ]
        }
    #endif
}

extension SwipeCellResetReason {
    nonisolated var validationSource: String {
        switch self {
        case .replacedByAnotherCell:
            "foreign-owner"
        case .scroll:
            "scroll"
        case .tapContent:
            "tap-content"
        case .actionTrigger:
            "tap-action"
        case .explicitClose:
            "programmatic-close"
        case .gestureCancelled:
            "release"
        case .editMode:
            "edit-mode"
        }
    }
}
