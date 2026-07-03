import CoreGraphics
import Foundation

#if DEBUG
    nonisolated private final class SwipeCellValidationDiagnosticsStore: @unchecked Sendable {
        private let lock = NSLock()
        private var sequence = 0
        private var cyclesByCell: [String: Int] = [:]

        func nextSequence() -> Int {
            lock.lock()
            defer { lock.unlock() }

            sequence += 1
            return sequence
        }

        func beginCycle(for cell: String) -> Int {
            lock.lock()
            defer { lock.unlock() }

            let cycle = (cyclesByCell[cell] ?? 0) + 1
            cyclesByCell[cell] = cycle
            return cycle
        }

        func currentCycle(for cell: String) -> Int {
            lock.lock()
            defer { lock.unlock() }

            return cyclesByCell[cell] ?? 0
        }
    }

    /// DEBUG-only validation trace helpers. Callers may report state here, but runtime decisions must not
    /// depend on emitted diagnostics or verdicts.
    nonisolated enum SwipeCellValidationDiagnostics {
        struct Field: Equatable, Sendable {
            let key: String
            let value: String

            init(_ key: String, _ value: String) {
                self.key = key
                self.value = Self.normalized(value)
            }

            init(_ key: String, _ value: Bool) {
                self.init(key, value ? "true" : "false")
            }

            init(_ key: String, _ value: Int) {
                self.init(key, String(value))
            }

            init(_ key: String, _ value: TimeInterval) {
                self.init(key, SwipeCellValidationDiagnostics.string(value))
            }

            init(_ key: String, _ value: TimeInterval?) {
                self.init(key, value.map(SwipeCellValidationDiagnostics.string) ?? "nil")
            }

            init(_ key: String, _ value: CGFloat) {
                self.init(key, SwipeCellValidationDiagnostics.string(value))
            }

            init(_ key: String, _ value: CGFloat?) {
                self.init(key, value.map(SwipeCellValidationDiagnostics.string) ?? "nil")
            }

            init(_ key: String, _ value: SwipeCellSide?) {
                self.init(key, SwipeCellValidationDiagnostics.string(value))
            }

            init(_ key: String, _ value: SwipeCellResetReason?) {
                self.init(key, SwipeCellValidationDiagnostics.string(value))
            }

            init(_ key: String, _ value: SwipeCellPhase?) {
                self.init(key, SwipeCellValidationDiagnostics.string(value))
            }

            init(_ key: String, _ value: SwipeCellOffsetAnimationRole) {
                self.init(key, SwipeCellValidationDiagnostics.string(value))
            }

            init(_ key: String, _ value: SwipeCellTrackingStyle) {
                self.init(key, SwipeCellValidationDiagnostics.string(value))
            }

            init(_ key: String, _ value: AnyHashable?) {
                self.init(key, value.map(SwipeCellValidationDiagnostics.cellString) ?? "nil")
            }

            static func normalized(_ value: String) -> String {
                value.replacingOccurrences(
                    of: #"\s+"#,
                    with: "_",
                    options: .regularExpression
                )
            }
        }

        enum Verdict: Equatable, Sendable {
            case ok(String)
            case suspect(String)

            var diagnosticString: String {
                switch self {
                case .ok(let reason):
                    "ok:\(Field.normalized(reason))"
                case .suspect(let reason):
                    "suspect reason=\(Field.normalized(reason))"
                }
            }
        }

        private static let revealedOffsetThreshold: CGFloat = 0.5
        // A visible animated close should survive at least one display frame; a sub-frame completion means
        // SwiftUI accepted the animated request but skipped observable motion.
        private static let immediateAnimatedSettleThreshold: TimeInterval = 1.0 / 60.0

        #if DEBUG
            private static let store = SwipeCellValidationDiagnosticsStore()
        #endif

        @discardableResult
        static func beginCycle<CellID: Hashable>(for cellID: CellID) -> Int {
            #if DEBUG
                store.beginCycle(for: cellString(cellID))
            #else
                0
            #endif
        }

        static func currentCycle<CellID: Hashable>(for cellID: CellID) -> Int {
            #if DEBUG
                store.currentCycle(for: cellString(cellID))
            #else
                0
            #endif
        }

        static func emit<CellID: Hashable>(
            event: String,
            cellID: CellID,
            cycle: Int? = nil,
            verdict: Verdict? = nil,
            fields: [Field] = []
        ) {
            #if DEBUG
                guard SwipeCellDiagnostics.isEnabled(.validation) else { return }

                let cell = cellString(cellID)
                let resolvedCycle = cycle ?? store.currentCycle(for: cell)
                SwipeCellDiagnostics.trace(
                    .validation,
                    message: message(
                        seq: store.nextSequence(),
                        time: ProcessInfo.processInfo.systemUptime,
                        cell: cell,
                        cycle: resolvedCycle,
                        event: event,
                        verdict: verdict,
                        fields: fields
                    )
                )
            #endif
        }

        static func message(
            seq: Int,
            time: TimeInterval,
            cell: String,
            cycle: Int,
            event: String,
            verdict: Verdict? = nil,
            fields: [Field] = []
        ) -> String {
            var parts = [
                "seq=\(seq)",
                "time=\(string(time))",
                "cell=\(Field.normalized(cell))",
                "cycle=\(cycle)",
            ]

            if let verdict {
                switch verdict {
                case .ok(let reason):
                    parts.append("verdict=ok:\(Field.normalized(reason))")
                case .suspect(let reason):
                    parts.append("verdict=suspect")
                    parts.append("reason=\(Field.normalized(reason))")
                }
            }

            parts.append("event=\(Field.normalized(event))")
            parts.append(contentsOf: fields.map { "\($0.key)=\($0.value)" })

            return parts.joined(separator: " ")
        }

        static func settleApplyVerdict(
            animatedRequest: Bool,
            fromOffset: CGFloat,
            targetOffset: CGFloat,
            role: SwipeCellOffsetAnimationRole,
            ownsClosingSettle: Bool
        ) -> Verdict? {
            guard isClosingToZero(fromOffset: fromOffset, targetOffset: targetOffset) else {
                return nil
            }

            if animatedRequest == false {
                return .ok("immediate-close-requested")
            }

            guard role != .none, ownsClosingSettle else {
                return .suspect("animated-reset-jumped-to-zero")
            }

            return nil
        }

        static func settleCompletionVerdict(
            animatedRequest: Bool,
            fromOffset: CGFloat,
            targetOffset: CGFloat,
            role: SwipeCellOffsetAnimationRole,
            ownsClosingSettle: Bool
        ) -> Verdict? {
            guard isClosingToZero(fromOffset: fromOffset, targetOffset: targetOffset) else {
                return nil
            }

            if animatedRequest == false {
                return .ok("immediate-close-requested")
            }

            if role != .none, ownsClosingSettle {
                return .ok("animated-close")
            }

            return .suspect("animated-reset-jumped-to-zero")
        }

        static func immediateAnimatedSettleVerdict(
            animatedRequest: Bool,
            fromOffset: CGFloat,
            targetOffset: CGFloat,
            role: SwipeCellOffsetAnimationRole,
            ownsClosingSettle: Bool,
            settleElapsed: TimeInterval?
        ) -> Verdict? {
            guard animatedRequest,
                role != .none,
                ownsClosingSettle,
                isClosingToZero(fromOffset: fromOffset, targetOffset: targetOffset),
                let settleElapsed,
                settleElapsed >= 0,
                settleElapsed < immediateAnimatedSettleThreshold
            else {
                return nil
            }

            return .suspect("unexpected-immediate-reset")
        }

        /// Whether the shared manager changed identity between an animated settle's apply and its completion.
        /// A close that finishes within a frame is only explained by something re-rendering the row mid-flight;
        /// `true` alongside `unexpected-immediate-reset` points at a cross-cell manager mutation (e.g. a new
        /// owner reaching `open`) collapsing the in-flight offset animation, rather than a local transaction
        /// problem. Observational only — it never gates a verdict, it just lets the on-device capture read the
        /// cause directly off one line.
        static func managerMutatedDuringSettle(
            phaseAtApply: SwipeCellPhase?,
            activeAtApply: AnyHashable?,
            resetGenerationAtApply: Int,
            phaseAtCompletion: SwipeCellPhase?,
            activeAtCompletion: AnyHashable?,
            resetGenerationAtCompletion: Int
        ) -> Bool {
            phaseAtApply != phaseAtCompletion
                || activeAtApply != activeAtCompletion
                || resetGenerationAtApply != resetGenerationAtCompletion
        }

        static func staleReleaseVerdict<CellID: Hashable>(
            source: String,
            role: SwipeCellOffsetAnimationRole,
            targetOffset: CGFloat,
            cellID: CellID,
            activeCellID: AnyHashable?
        ) -> Verdict? {
            guard source == "release",
                role == .releaseSettling,
                abs(targetOffset) > revealedOffsetThreshold,
                let activeCellID,
                activeCellID != AnyHashable(cellID)
            else {
                return nil
            }

            return .suspect("stale-release-after-owner-replacement")
        }

        static func resettingOwnerClearedVerdict(
            event: String,
            resettingBefore: AnyHashable?,
            resettingAfter: AnyHashable?
        ) -> Verdict? {
            guard event != "manager.completeVisibleReset",
                resettingBefore != nil,
                resettingAfter == nil
            else {
                return nil
            }

            return .suspect("resetting-owner-cleared-before-local-complete")
        }

        static func resetTokenSettleVerdict<CellID: Hashable>(
            source: String,
            role: SwipeCellOffsetAnimationRole,
            fromOffset: CGFloat,
            targetOffset: CGFloat,
            cellID: CellID,
            activeCellID: AnyHashable?,
            resettingCellID: AnyHashable?
        ) -> Verdict? {
            let erasedCellID = AnyHashable(cellID)
            guard source == "reset-token",
                role == .forcedReset,
                isClosingToZero(fromOffset: fromOffset, targetOffset: targetOffset),
                activeCellID != nil,
                activeCellID != erasedCellID,
                resettingCellID != erasedCellID
            else {
                return nil
            }

            return .suspect("resetting-owner-cleared-before-local-complete")
        }

        static func visibleSideVerdict(
            fromOffset: CGFloat,
            targetOffset: CGFloat,
            visibleSideBefore: SwipeCellSide?,
            visibleSideAfter: SwipeCellSide?,
            settlingSideAfter: SwipeCellSide?
        ) -> Verdict? {
            guard isClosingToZero(fromOffset: fromOffset, targetOffset: targetOffset),
                visibleSideBefore != nil,
                visibleSideAfter == nil,
                settlingSideAfter == nil
            else {
                return nil
            }

            return .suspect("visible-side-lost-while-closing")
        }

        static func hostLifecycleVerdict(
            event: String,
            contentOffset: CGFloat,
            visibleSide: SwipeCellSide?
        ) -> Verdict? {
            guard event == "host.appear" || event == "host.disappear" else { return nil }
            guard abs(contentOffset) > revealedOffsetThreshold || visibleSide != nil else { return nil }

            return .suspect("coordinator-recreated-while-visible")
        }

        static func string(_ value: CGFloat) -> String {
            guard value.isFinite else { return "\(value)" }
            return String(format: "%.3f", Double(value))
        }

        static func string(_ value: TimeInterval) -> String {
            guard value.isFinite else { return "\(value)" }
            return String(format: "%.3f", value)
        }

        static func string(_ value: SwipeCellSide?) -> String {
            switch value {
            case .leading:
                "leading"
            case .trailing:
                "trailing"
            case nil:
                "nil"
            }
        }

        static func string(_ value: SwipeCellResetReason?) -> String {
            switch value {
            case .replacedByAnotherCell:
                "replacedByAnotherCell"
            case .scroll:
                "scroll"
            case .tapContent:
                "tapContent"
            case .actionTrigger:
                "actionTrigger"
            case .explicitClose:
                "explicitClose"
            case .gestureCancelled:
                "gestureCancelled"
            case .editMode:
                "editMode"
            case nil:
                "nil"
            }
        }

        static func string(_ value: SwipeCellPhase?) -> String {
            switch value {
            case .closed:
                "closed"
            case .revealing:
                "revealing"
            case .open(let side):
                "open(\(string(side)))"
            case .triggering(let side):
                "triggering(\(string(side)))"
            case .resetting(let reason):
                "resetting(\(string(reason)))"
            case nil:
                "nil"
            }
        }

        static func string(_ value: SwipeCellReleaseTarget?) -> String {
            switch value {
            case .closed:
                "closed"
            case .open(let side):
                "open(\(string(side)))"
            case .destructive(let side):
                "destructive(\(string(side)))"
            case nil:
                "nil"
            }
        }

        static func string(_ value: SwipeCellOffsetAnimationRole) -> String {
            switch value {
            case .none:
                "none"
            case .releaseSettling:
                "releaseSettling"
            case .forcedReset:
                "forcedReset"
            }
        }

        static func string(_ value: SwipeCellTrackingStyle) -> String {
            switch value {
            case .directTouch:
                "directTouch"
            case .indirectScroll:
                "indirectScroll"
            }
        }

        static func cellString<CellID: Hashable>(_ cellID: CellID) -> String {
            Field.normalized(String(describing: cellID))
        }

        private static func isClosingToZero(fromOffset: CGFloat, targetOffset: CGFloat) -> Bool {
            abs(fromOffset) > revealedOffsetThreshold && abs(targetOffset) <= revealedOffsetThreshold
        }
    }
#endif
