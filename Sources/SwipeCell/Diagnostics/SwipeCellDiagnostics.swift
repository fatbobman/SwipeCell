import CoreGraphics
import Foundation

#if DEBUG
    nonisolated struct SwipeCellDiagnosticsRegistry: Equatable {
        private var emittedOnceKeys: Set<String> = []
        private var throttledEmissionTimes: [String: TimeInterval] = [:]

        mutating func shouldEmitOnce(key: String) -> Bool {
            emittedOnceKeys.insert(key).inserted
        }

        mutating func shouldEmitThrottled(
            key: String,
            timestamp: TimeInterval,
            interval: TimeInterval
        ) -> Bool {
            guard interval > 0 else { return true }

            if let previous = throttledEmissionTimes[key], timestamp - previous < interval {
                return false
            }

            throttledEmissionTimes[key] = timestamp
            return true
        }
    }

    nonisolated private final class SwipeCellDiagnosticsEmissionStore: @unchecked Sendable {
        private let lock = NSLock()
        private var registry = SwipeCellDiagnosticsRegistry()

        func shouldEmitOnce(key: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return registry.shouldEmitOnce(key: key)
        }

        func shouldEmitThrottled(
            key: String,
            timestamp: TimeInterval,
            interval: TimeInterval
        ) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return registry.shouldEmitThrottled(
                key: key,
                timestamp: timestamp,
                interval: interval
            )
        }
    }

    nonisolated struct SwipeCellScrollWheelMeasureDiagnosticsSnapshot: Equatable, Sendable {
        let isActive: Bool
        let mode: String
        let side: String
        let referenceRevealDistance: CGFloat
        let slowReferenceRevealDistance: CGFloat
        let adaptiveLowerDelta: CGFloat
        let adaptiveUpperDelta: CGFloat
        let maxProgressStep: CGFloat
        let minStartDelta: CGFloat
        let fastIntentRequiredDistance: CGFloat
        let fastReleaseOpenCommitRatio: CGFloat
        let fastIntentWindowDistance: CGFloat
        let fastIntentSampleCount: Int
        let isSingleFastIntentSample: Bool
        let hasFastIntent: Bool
        let fastIntentStartAge: TimeInterval?
        let fastIntentTriggerAge: TimeInterval?
        let fastIntentCommitDistance: CGFloat?
        let fastIntentCommitThreshold: CGFloat?
        let visualProgress: CGFloat
        let uncappedVisualProgress: CGFloat
        let fastReferenceProgress: CGFloat
        let uncappedFastReferenceProgress: CGFloat
        let releaseBypassesNormalReleaseThreshold: Bool?
        let hasObservedIndirectTouchPresence: Bool
        let isIndirectTouchPresenceActive: Bool
        let hasLatchedDestructiveArm: Bool

        static let inactive = Self(
            isActive: false,
            mode: "reveal",
            side: "nil",
            referenceRevealDistance: .nan,
            slowReferenceRevealDistance: .nan,
            adaptiveLowerDelta: .nan,
            adaptiveUpperDelta: .nan,
            maxProgressStep: .nan,
            minStartDelta: .nan,
            fastIntentRequiredDistance: .nan,
            fastReleaseOpenCommitRatio: .nan,
            fastIntentWindowDistance: 0,
            fastIntentSampleCount: 0,
            isSingleFastIntentSample: false,
            hasFastIntent: false,
            fastIntentStartAge: nil,
            fastIntentTriggerAge: nil,
            fastIntentCommitDistance: nil,
            fastIntentCommitThreshold: nil,
            visualProgress: 0,
            uncappedVisualProgress: 0,
            fastReferenceProgress: 0,
            uncappedFastReferenceProgress: 0,
            releaseBypassesNormalReleaseThreshold: nil,
            hasObservedIndirectTouchPresence: false,
            isIndirectTouchPresenceActive: false,
            hasLatchedDestructiveArm: false
        )
    }

    nonisolated enum SwipeCellDiagnostics {
        static let environmentKey = "SWIPECELL_DIAGNOSTICS"
        static let allSelector = "all"

        enum Channel: String, CaseIterable, Sendable {
            /// Recoverable caller misconfiguration; emitted once per stable key.
            case warnings
            /// High-frequency layout fallback; emitted through throttled stable keys.
            case layout
            /// macOS indirect-scroll and fast-intent event traces.
            case scrollFast = "scroll-fast"
            /// iOS direct-touch release planning traces.
            case directTouch = "direct-touch"
            /// Manager/coordinator lifecycle and reset/settle invariant traces.
            case validation
            /// Quantitative sampling for curve/device calibration; never used for behavior decisions.
            case measure
        }

        struct Field: Equatable, Sendable {
            enum BooleanStyle: Sendable {
                case numeric
                case word
            }

            let key: String
            let value: String

            init(_ key: String, _ value: String) {
                self.key = Self.normalized(key)
                self.value = Self.normalized(value)
            }

            init(_ key: String, _ value: Bool, style: BooleanStyle = .numeric) {
                switch style {
                case .numeric:
                    self.init(key, value ? "1" : "0")
                case .word:
                    self.init(key, value ? "true" : "false")
                }
            }

            init(_ key: String, _ value: Int) {
                self.init(key, String(value))
            }

            init(_ key: String, _ value: UInt) {
                self.init(key, String(value))
            }

            init(_ key: String, _ value: CGFloat, precision: Int = 3) {
                self.init(key, Self.string(value, precision: precision))
            }

            init(_ key: String, _ value: CGFloat?, precision: Int = 3) {
                self.init(key, value.map { Self.string($0, precision: precision) } ?? "nil")
            }

            init(_ key: String, _ value: TimeInterval, precision: Int = 3) {
                self.init(key, Self.string(value, precision: precision))
            }

            init(_ key: String, _ value: TimeInterval?, precision: Int = 3) {
                self.init(key, value.map { Self.string($0, precision: precision) } ?? "nil")
            }

            init(_ key: String, _ value: SwipeCellReleaseTarget?) {
                self.init(key, Self.string(value))
            }

            static func normalized(_ value: String) -> String {
                value.replacingOccurrences(
                    of: #"\s+"#,
                    with: "_",
                    options: .regularExpression
                )
            }

            static func string(_ value: CGFloat, precision: Int = 3) -> String {
                guard value.isFinite else { return "\(value)" }
                return String(format: "%.\(precision)f", Double(value))
            }

            static func string(_ value: TimeInterval, precision: Int = 3) -> String {
                guard value.isFinite else { return "\(value)" }
                return String(format: "%.\(precision)f", value)
            }

            static func string(_ value: SwipeCellReleaseTarget?) -> String {
                switch value {
                case .closed:
                    "closed"
                case .open(let side):
                    "open(\(side))"
                case .destructive(let side):
                    "destructive(\(side))"
                case nil:
                    "nil"
                }
            }
        }

        private static let layoutThrottleInterval: TimeInterval = 1

        #if DEBUG
            private static let emissionStore = SwipeCellDiagnosticsEmissionStore()
        #endif

        static func isEnabled(
            _ channel: Channel,
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) -> Bool {
            #if DEBUG
                let tokens = diagnosticTokens(environment: environment)
                return tokens.contains(allSelector) || tokens.contains(channel.rawValue)
            #else
                return false
            #endif
        }

        static func warning(
            _ key: String,
            enabled: Bool = true,
            message: @autoclosure () -> String
        ) {
            #if DEBUG
                guard enabled, isEnabled(.warnings), emissionStore.shouldEmitOnce(key: key) else {
                    return
                }
                emit("warning", message())
            #endif
        }

        static func layoutFallback(
            _ key: String,
            enabled: Bool = true,
            message: @autoclosure () -> String
        ) {
            #if DEBUG
                guard
                    enabled,
                    isEnabled(.layout),
                    emissionStore.shouldEmitThrottled(
                        key: key,
                        timestamp: ProcessInfo.processInfo.systemUptime,
                        interval: layoutThrottleInterval
                    )
                else {
                    return
                }
                emit("layout", message())
            #endif
        }

        static func trace(
            _ channel: Channel,
            message: @autoclosure () -> String
        ) {
            #if DEBUG
                guard isEnabled(channel) else { return }
                emit(channel.rawValue, message())
            #endif
        }

        static func trace(
            _ channel: Channel,
            event: String,
            fields: @autoclosure () -> [Field] = []
        ) {
            #if DEBUG
                guard isEnabled(channel) else { return }
                emit(channel.rawValue, message(event: event, fields: fields()))
            #endif
        }

        static func message(event: String, fields: [Field] = []) -> String {
            (["event=\(Field.normalized(event))"] + fields.map { "\($0.key)=\($0.value)" })
                .joined(separator: " ")
        }

        private static func diagnosticTokens(environment: [String: String]) -> Set<String> {
            guard let rawValue = environment[environmentKey] else {
                return []
            }

            let separators = CharacterSet(charactersIn: ",; ")
                .union(.whitespacesAndNewlines)
            return Set(
                rawValue
                    .lowercased()
                    .components(separatedBy: separators)
                    .filter { !$0.isEmpty }
            )
        }

        private static func emit(_ category: String, _ message: String) {
            #if DEBUG
                Swift.print("[SwipeCell][\(category)] \(message)")
            #endif
        }
    }

    #if DEBUG
        extension SwipeCellDiagnostics {
            static func fields(
                for snapshot: SwipeCellScrollWheelMeasureDiagnosticsSnapshot
            ) -> [Field] {
                [
                    .init("active", snapshot.isActive),
                    .init("mode", snapshot.mode),
                    .init("side", snapshot.side),
                    .init("dFast", snapshot.referenceRevealDistance),
                    .init("dSlow", snapshot.slowReferenceRevealDistance),
                    .init("lo", snapshot.adaptiveLowerDelta),
                    .init("hi", snapshot.adaptiveUpperDelta),
                    .init("step", snapshot.maxProgressStep),
                    .init("minStart", snapshot.minStartDelta),
                    .init("required", snapshot.fastIntentRequiredDistance),
                    .init("commitRatio", snapshot.fastReleaseOpenCommitRatio),
                    .init("win", snapshot.fastIntentWindowDistance),
                    .init("samples", snapshot.fastIntentSampleCount),
                    .init("single", snapshot.isSingleFastIntentSample),
                    .init("fast", snapshot.hasFastIntent),
                    .init("startAge", snapshot.fastIntentStartAge),
                    .init("trigAge", snapshot.fastIntentTriggerAge),
                    .init("commit", snapshot.fastIntentCommitDistance),
                    .init("threshold", snapshot.fastIntentCommitThreshold),
                    .init("vProg", snapshot.visualProgress),
                    .init("uvProg", snapshot.uncappedVisualProgress),
                    .init("fProg", snapshot.fastReferenceProgress),
                    .init("ufProg", snapshot.uncappedFastReferenceProgress),
                    .init(
                        "releaseBypass",
                        snapshot.releaseBypassesNormalReleaseThreshold.map { $0 ? "1" : "0" } ?? "-"
                    ),
                    .init("touchSeen", snapshot.hasObservedIndirectTouchPresence),
                    .init("touchActive", snapshot.isIndirectTouchPresenceActive),
                    .init("latched", snapshot.hasLatchedDestructiveArm),
                ]
            }
        }
    #endif

#else
    nonisolated enum SwipeCellDiagnostics {
        struct Channel: Sendable {
            static let warnings = Self()
            static let layout = Self()
            static let scrollFast = Self()
            static let directTouch = Self()
            static let validation = Self()
            static let measure = Self()
        }

        static func isEnabled(
            _ channel: Channel,
            environment: [String: String] = [:]
        ) -> Bool {
            _ = channel
            _ = environment
            return false
        }
    }
#endif
