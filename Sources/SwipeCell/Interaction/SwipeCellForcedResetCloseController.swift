import CoreGraphics
import Foundation

enum SwipeCellForcedResetCloseDriver: Equatable, Sendable {
    case pinnedValueToken
    case macOSResetTokenClose
    case macOSContentTapClose
    case macOSActionCollapse

    #if DEBUG
        var diagnosticString: String {
            switch self {
            case .pinnedValueToken:
                "pinnedValueToken"
            case .macOSResetTokenClose:
                "macOSResetTokenClose"
            case .macOSContentTapClose:
                "macOSContentTapClose"
            case .macOSActionCollapse:
                "macOSActionCollapse"
            }
        }
    #endif
}

enum SwipeCellForcedResetCloseRendering: Equatable, Sendable {
    case pinnedValueToken
    case indirectScroll
}

protocol ForcedResetCloseDriving: Sendable {
    var identity: SwipeCellForcedResetCloseDriver { get }
    var rendering: SwipeCellForcedResetCloseRendering { get }
}

struct PinnedValueTokenForcedResetCloseDriver: ForcedResetCloseDriving {
    let identity: SwipeCellForcedResetCloseDriver = .pinnedValueToken
    let rendering: SwipeCellForcedResetCloseRendering = .pinnedValueToken
}

struct IndirectScrollForcedResetCloseDriver: ForcedResetCloseDriving {
    let identity: SwipeCellForcedResetCloseDriver
    let rendering: SwipeCellForcedResetCloseRendering = .indirectScroll
}

enum SwipeCellForcedResetCloseTerminalState: Equatable, Sendable {
    case visibleComplete
    case detachedCleanup
    case cancelledByNewLocalOwner

    #if DEBUG
        var diagnosticString: String {
            switch self {
            case .visibleComplete:
                "visible-complete"
            case .detachedCleanup:
                "detached-cleanup"
            case .cancelledByNewLocalOwner:
                "cancelled-by-new-local-owner"
            }
        }
    #endif

    var completesVisibleReset: Bool {
        switch self {
        case .visibleComplete, .detachedCleanup:
            true
        case .cancelledByNewLocalOwner:
            false
        }
    }
}

struct SwipeCellForcedResetCloseCompletion {
    let epoch: Int
    let closeDriver: SwipeCellForcedResetCloseDriver
    let update: SwipeCellOffsetUpdate
    let inputs: SwipeCellInteractionInputs
    let completion: (() -> Void)?
    let ownsSettlingSide: Bool
    let inputSuppressionEpoch: Int?
    #if DEBUG
        let source: String
        let animatedRequest: Bool
        let deferred: Bool
        let fromOffset: CGFloat
        let sideBeforeClose: SwipeCellSide?
        let settlingSideBeforeClose: SwipeCellSide?
        let applyTimestamp: TimeInterval
        let phaseAtSettleApply: SwipeCellPhase?
        let activeAtSettleApply: AnyHashable?
        let resetGenerationAtSettleApply: Int
    #endif
}

struct SwipeCellClaimedForcedResetClose {
    let epoch: Int
    let driver: SwipeCellForcedResetCloseDriver
}

/// Owns forced-reset close mechanism state while the observable render outputs stay on the coordinator.
final class SwipeCellForcedResetCloseController {
    private(set) var pendingCloseToken: Int?
    private(set) var pendingCloseDriver: SwipeCellForcedResetCloseDriver?
    private(set) var pendingMacOSResetTokenCloseEpoch: Int?
    private(set) var lastForcedResetCloseDriver: SwipeCellForcedResetCloseDriver?
    #if DEBUG
        private(set) var lastMacOSResetTokenCloseTerminalState: String?
        private(set) var macOSResetTokenCloseTerminalCount = 0
    #endif
    var pausesMacOSResetTokenCloseCompletionForTesting = false

    private var macOSResetTokenCloseEpoch = 0
    private var pendingClose: SwipeCellForcedResetCloseCompletion?

    func driver(
        for update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String,
        animatedRequest: Bool,
        ownsSettlingSide: Bool
    ) -> (any ForcedResetCloseDriving)? {
        guard update.animationRole == .forcedReset,
            animatedRequest,
            ownsSettlingSide
        else {
            return nil
        }

        if inputs.configuration.motion.trackingStyle == .indirectScroll {
            switch source {
            case "reset-token":
                return IndirectScrollForcedResetCloseDriver(identity: .macOSResetTokenClose)
            case "tap-content":
                return IndirectScrollForcedResetCloseDriver(identity: .macOSContentTapClose)
            case "tap-action", "destructive-trigger":
                return IndirectScrollForcedResetCloseDriver(identity: .macOSActionCollapse)
            default:
                break
            }
        }

        return PinnedValueTokenForcedResetCloseDriver()
    }

    func closeEpoch(for driver: SwipeCellForcedResetCloseDriver) -> Int? {
        switch driver {
        case .pinnedValueToken:
            pendingCloseToken
        case .macOSResetTokenClose, .macOSContentTapClose, .macOSActionCollapse:
            pendingMacOSResetTokenCloseEpoch
        }
    }

    func pendingDetachedCleanup(for cellID: AnyHashable) -> SwipeCellForcedResetCloseCompletion? {
        guard let pending = pendingClose,
            pending.inputs.cellID == cellID,
            pending.closeDriver != .pinnedValueToken
        else {
            return nil
        }
        return pending
    }

    func pendingCancellable(for cellID: AnyHashable) -> SwipeCellForcedResetCloseCompletion? {
        guard let pending = pendingClose,
            pending.inputs.cellID == cellID
        else {
            return nil
        }
        return pending
    }

    func pendingClaimedClose(
        _ claimedClose: SwipeCellClaimedForcedResetClose
    ) -> SwipeCellForcedResetCloseCompletion? {
        guard let pending = pendingClose,
            pending.epoch == claimedClose.epoch,
            pending.closeDriver == claimedClose.driver
        else {
            return nil
        }
        return pending
    }

    #if DEBUG
        func beginPinnedClose(
            closeToken: Int,
            update: SwipeCellOffsetUpdate,
            inputs: SwipeCellInteractionInputs,
            source: String,
            animatedRequest: Bool,
            deferred: Bool,
            completion: (() -> Void)?,
            fromOffset: CGFloat,
            sideBeforeClose: SwipeCellSide?,
            settlingSideBeforeClose: SwipeCellSide?,
            ownsSettlingSide: Bool,
            inputSuppressionEpoch: Int?,
            settleAppliedAt: TimeInterval,
            phaseAtSettleApply: SwipeCellPhase?,
            activeAtSettleApply: AnyHashable?,
            resetGenerationAtSettleApply: Int
        ) {
            pendingCloseToken = closeToken
            pendingMacOSResetTokenCloseEpoch = nil
            pendingCloseDriver = .pinnedValueToken
            lastForcedResetCloseDriver = .pinnedValueToken
            pendingClose = SwipeCellForcedResetCloseCompletion(
                epoch: closeToken,
                closeDriver: .pinnedValueToken,
                update: update,
                inputs: inputs,
                completion: completion,
                ownsSettlingSide: ownsSettlingSide,
                inputSuppressionEpoch: inputSuppressionEpoch,
                source: source,
                animatedRequest: animatedRequest,
                deferred: deferred,
                fromOffset: fromOffset,
                sideBeforeClose: sideBeforeClose,
                settlingSideBeforeClose: settlingSideBeforeClose,
                applyTimestamp: settleAppliedAt,
                phaseAtSettleApply: phaseAtSettleApply,
                activeAtSettleApply: activeAtSettleApply,
                resetGenerationAtSettleApply: resetGenerationAtSettleApply
            )
        }
    #else
        func beginPinnedClose(
            closeToken: Int,
            update: SwipeCellOffsetUpdate,
            inputs: SwipeCellInteractionInputs,
            completion: (() -> Void)?,
            ownsSettlingSide: Bool,
            inputSuppressionEpoch: Int?
        ) {
            pendingCloseToken = closeToken
            pendingMacOSResetTokenCloseEpoch = nil
            pendingCloseDriver = .pinnedValueToken
            lastForcedResetCloseDriver = .pinnedValueToken
            pendingClose = SwipeCellForcedResetCloseCompletion(
                epoch: closeToken,
                closeDriver: .pinnedValueToken,
                update: update,
                inputs: inputs,
                completion: completion,
                ownsSettlingSide: ownsSettlingSide,
                inputSuppressionEpoch: inputSuppressionEpoch
            )
        }
    #endif

    #if DEBUG
        @discardableResult
        func beginIndirectScrollClose(
            closeDriver: SwipeCellForcedResetCloseDriver,
            update: SwipeCellOffsetUpdate,
            inputs: SwipeCellInteractionInputs,
            source: String,
            animatedRequest: Bool,
            deferred: Bool,
            completion: (() -> Void)?,
            fromOffset: CGFloat,
            sideBeforeClose: SwipeCellSide?,
            settlingSideBeforeClose: SwipeCellSide?,
            ownsSettlingSide: Bool,
            inputSuppressionEpoch: Int?,
            settleAppliedAt: TimeInterval,
            phaseAtSettleApply: SwipeCellPhase?,
            activeAtSettleApply: AnyHashable?,
            resetGenerationAtSettleApply: Int
        ) -> Int {
            macOSResetTokenCloseEpoch += 1
            let epoch = macOSResetTokenCloseEpoch
            pendingCloseToken = nil
            pendingMacOSResetTokenCloseEpoch = epoch
            pendingCloseDriver = closeDriver
            lastForcedResetCloseDriver = closeDriver
            pendingClose = SwipeCellForcedResetCloseCompletion(
                epoch: epoch,
                closeDriver: closeDriver,
                update: update,
                inputs: inputs,
                completion: completion,
                ownsSettlingSide: ownsSettlingSide,
                inputSuppressionEpoch: inputSuppressionEpoch,
                source: source,
                animatedRequest: animatedRequest,
                deferred: deferred,
                fromOffset: fromOffset,
                sideBeforeClose: sideBeforeClose,
                settlingSideBeforeClose: settlingSideBeforeClose,
                applyTimestamp: settleAppliedAt,
                phaseAtSettleApply: phaseAtSettleApply,
                activeAtSettleApply: activeAtSettleApply,
                resetGenerationAtSettleApply: resetGenerationAtSettleApply
            )
            return epoch
        }
    #else
        @discardableResult
        func beginIndirectScrollClose(
            closeDriver: SwipeCellForcedResetCloseDriver,
            update: SwipeCellOffsetUpdate,
            inputs: SwipeCellInteractionInputs,
            completion: (() -> Void)?,
            ownsSettlingSide: Bool,
            inputSuppressionEpoch: Int?
        ) -> Int {
            macOSResetTokenCloseEpoch += 1
            let epoch = macOSResetTokenCloseEpoch
            pendingCloseToken = nil
            pendingMacOSResetTokenCloseEpoch = epoch
            pendingCloseDriver = closeDriver
            lastForcedResetCloseDriver = closeDriver
            pendingClose = SwipeCellForcedResetCloseCompletion(
                epoch: epoch,
                closeDriver: closeDriver,
                update: update,
                inputs: inputs,
                completion: completion,
                ownsSettlingSide: ownsSettlingSide,
                inputSuppressionEpoch: inputSuppressionEpoch
            )
            return epoch
        }
    #endif

    func complete(
        epoch: Int,
        driver: SwipeCellForcedResetCloseDriver,
        terminalState: SwipeCellForcedResetCloseTerminalState
    ) -> SwipeCellForcedResetCloseCompletion? {
        guard let pending = pendingClose,
            pending.epoch == epoch,
            pending.closeDriver == driver
        else {
            return nil
        }

        pendingClose = nil
        pendingCloseToken = nil
        pendingMacOSResetTokenCloseEpoch = nil
        pendingCloseDriver = nil
        #if DEBUG
            if pending.closeDriver != .pinnedValueToken {
                lastMacOSResetTokenCloseTerminalState = terminalState.diagnosticString
                macOSResetTokenCloseTerminalCount += 1
            }
        #endif
        return pending
    }
}
