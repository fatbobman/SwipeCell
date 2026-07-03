import Foundation
import SwiftUI

#if os(macOS)
    import AppKit

    struct SwipeCellScrollWheelPanBridge: NSViewRepresentable {
        var isEnabled: Bool
        var input: SwipeCellConfiguration.PlatformInput
        var interactionConfiguration: SwipeCellInteractionConfiguration
        var container: SwipeCellContainer
        var containerWidth: CGFloat
        var contentOffset: CGFloat
        var onBegan: () -> Void
        var onChanged: (SwipeCellPanValue) -> Void
        var onEnded: (SwipeCellPanValue) -> Void
        var onCancelled: () -> Void

        func makeNSView(context: Context) -> SwipeCellScrollWheelEventView {
            let view = SwipeCellScrollWheelEventView()
            updateNSView(view, context: context)
            return view
        }

        func updateNSView(_ view: SwipeCellScrollWheelEventView, context: Context) {
            view.configure(
                isEnabled: isEnabled,
                input: input,
                interactionConfiguration: interactionConfiguration,
                container: container,
                containerWidth: containerWidth,
                contentOffset: contentOffset,
                onBegan: onBegan,
                onChanged: onChanged,
                onEnded: onEnded,
                onCancelled: onCancelled
            )
        }
    }

    // A single app-level `scrollWheel` monitor shared by every bridge view. It samples Magic Mouse /
    // Trackpad deltas as a *bypass*: it never consumes the event (always returns it), so the enclosing
    // `NSScrollView` keeps ownership of every stream and vertical scrolling is never swallowed. Blocking
    // the parent during an active horizontal swipe is delegated to SwiftUI `.scrollDisabled` at the
    // scope, driven by the shared swipe state — trying to win the stream inside the event dispatch lost
    // a structural race against responsive-scroll latch in every prior approach (issue #31). Rows
    // register while in a window and are held weakly, so the monitor tears down once no row remains.
    @MainActor
    final class SwipeCellScrollWheelMonitor {
        static let shared = SwipeCellScrollWheelMonitor()

        private final class WeakView {
            weak var value: SwipeCellScrollWheelEventView?
            init(_ value: SwipeCellScrollWheelEventView) { self.value = value }
        }

        private var clients: [WeakView] = []
        private var monitor: Any?

        func register(_ view: SwipeCellScrollWheelEventView) {
            prune()
            guard !clients.contains(where: { $0.value === view }) else { return }
            clients.append(WeakView(view))
            startIfNeeded()
        }

        func unregister(_ view: SwipeCellScrollWheelEventView) {
            clients.removeAll { $0.value == nil || $0.value === view }
            stopIfIdle()
        }

        private func startIfNeeded() {
            guard monitor == nil else { return }
            // `scrollWheel` is an NSResponder event, not an NSGestureRecognizer event. A local monitor
            // observes the deltas without any bridge view becoming the hit-tested view for clicks.
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.dispatch(event) ?? event
            }
        }

        private func stopIfIdle() {
            guard clients.isEmpty, let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        private func prune() {
            clients.removeAll { $0.value == nil }
        }

        // Sampling only: every registered row inspects the event, but it is always returned so the
        // enclosing `NSScrollView` still receives it. Rows do not overlap, so at most one samples a swipe.
        private func dispatch(_ event: NSEvent) -> NSEvent? {
            prune()
            for client in clients {
                client.value?.handleScrollWheel(event)
            }
            stopIfIdle()
            return event
        }
    }

    // Passive Trackpad touch sampler for issue #71. It uses a local monitor and always returns the
    // original event, so the bridge can observe indirect touch lifecycle without becoming hit-testable.
    @MainActor
    final class SwipeCellIndirectTouchMonitor {
        static let shared = SwipeCellIndirectTouchMonitor()

        private final class WeakView {
            weak var value: SwipeCellScrollWheelEventView?
            init(_ value: SwipeCellScrollWheelEventView) { self.value = value }
        }

        private var clients: [WeakView] = []
        private var monitor: Any?

        func register(_ view: SwipeCellScrollWheelEventView) {
            prune()
            guard !clients.contains(where: { $0.value === view }) else { return }
            clients.append(WeakView(view))
            startIfNeeded()
        }

        func unregister(_ view: SwipeCellScrollWheelEventView) {
            clients.removeAll { $0.value == nil || $0.value === view }
            stopIfIdle()
        }

        private func startIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.gesture, .directTouch]) { [weak self] event in
                self?.dispatch(event) ?? event
            }
        }

        private func stopIfIdle() {
            guard clients.isEmpty, let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        private func prune() {
            clients.removeAll { $0.value == nil }
        }

        private func dispatch(_ event: NSEvent) -> NSEvent? {
            prune()
            for client in clients {
                client.value?.handleIndirectTouchEvent(event)
            }
            stopIfIdle()
            return event
        }
    }

    // A per-row bypass sampler for macOS `scrollWheel` input. It never owns the event stream: `hitTest`
    // stays transparent and the shared monitor returns every event, so vertical scrolling always reaches
    // the enclosing `NSScrollView`. The view only synthesizes a row swipe from horizontal samples and
    // publishes the active swipe state; the parent is held still during an active swipe by `.scrollDisabled`
    // at the scope (issue #31).
    final class SwipeCellScrollWheelEventView: NSView {
        private struct PostReleaseCooldown {
            let input: SwipeCellConfiguration.PlatformInput
            let expiresAt: TimeInterval
        }

        private var isBridgeEnabled = true
        private var input = SwipeCellConfiguration.platformDefault.input
        private var onBegan: () -> Void = {}
        private var onChanged: (SwipeCellPanValue) -> Void = { _ in }
        private var onEnded: (SwipeCellPanValue) -> Void = { _ in }
        private var onCancelled: () -> Void = {}
        private var container: SwipeCellContainer = .list

        private var accumulator = SwipeCellScrollWheelPanAccumulator()
        // Raw scroll delta is normalized before it reaches the accumulator, so the bridge must lock the
        // active input too. Otherwise a view update could change scale mid-gesture even though the
        // accumulator has locked `D_ref`, step cap, and geometry for the same active scroll.
        private var activeScrollInput: SwipeCellConfiguration.PlatformInput?
        private var syntheticEndTimer: Timer?
        // Lives in the bridge because it suppresses only post-release residual samples; the accumulator
        // must stay free to lock a fresh gesture once the window expires.
        private var postReleaseCooldown: PostReleaseCooldown?
        private var isIndirectTouchMonitorRegistered = false

        // The bridge view never participates in hit-testing: the shared monitor samples `scrollWheel`
        // out of band, so clicks and every other event fall straight through to the SwiftUI row content,
        // Buttons, and NavigationLinks underneath.
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        // Invoked by `SwipeCellScrollWheelMonitor` for every `scrollWheel` event in this row's window.
        // Sampling only — the monitor always returns the event, so the parent scroll view is never
        // blocked here; an active swipe is held still by `.scrollDisabled` at the scope. Window / bounds
        // filtering keeps a row from sampling a scroll that lands over another row.
        func handleScrollWheel(_ event: NSEvent) {
            let inWindow = isBridgeEnabled && window != nil && event.window === window
            let accepted =
                inWindow && bounds.contains(convert(event.locationInWindow, from: nil))
            #if DEBUG
                SwipeCellDiagnostics.trace(
                    .scrollFast,
                    event: "raw-scroll",
                    fields: [
                        .init("phase", String(describing: SwipeCellScrollWheelPhase(event.phase))),
                        .init("momentum", String(describing: SwipeCellScrollWheelPhase(event.momentumPhase))),
                        .init("dx", event.scrollingDeltaX, precision: 2),
                        .init("dy", event.scrollingDeltaY, precision: 2),
                        .init("ts", event.timestamp),
                        .init("accepted", accepted),
                        .init("inWindow", inWindow),
                        .init("active", accumulator.isActive),
                    ]
                )
            #endif
            guard accepted else { return }

            handleScrollWheelSample(
                rawDelta: CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY),
                phase: SwipeCellScrollWheelPhase(event.phase),
                momentumPhase: SwipeCellScrollWheelPhase(event.momentumPhase),
                hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas,
                timestamp: event.timestamp
            )
        }

        // Invoked by `SwipeCellIndirectTouchMonitor`. The event is never consumed; this only samples
        // non-resting indirect touches for active `.scrollView` gestures.
        func handleIndirectTouchEvent(_ event: NSEvent) {
            let inWindow = isBridgeEnabled && window != nil && event.window === window
            let location = convert(event.locationInWindow, from: nil)
            let accepted = inWindow && bounds.contains(location)
            let phase = accepted ? indirectTouchPresencePhase(from: event) : nil
            #if DEBUG
                if SwipeCellDiagnostics.isEnabled(.scrollFast) {
                    SwipeCellDiagnostics.trace(
                        .scrollFast,
                        event: "indirect-touch",
                        fields: [
                            .init("type", event.type.rawValue),
                            .init("inWindow", inWindow),
                            .init("accepted", accepted),
                            .init("active", accumulator.isActive),
                            .init("selfTouching", event.touches(matching: .touching, in: self).count),
                            .init("nilTouching", event.touches(matching: .touching, in: nil).count),
                            .init("nilStationary", event.touches(matching: .stationary, in: nil).count),
                            .init("nilEnded", event.touches(matching: .ended, in: nil).count),
                            .init("nilCancelled", event.touches(matching: .cancelled, in: nil).count),
                            .init("phase", touchPhaseLabel(phase)),
                        ]
                    )
                }
                SwipeCellDiagnostics.trace(
                    .measure,
                    event: "MEASURE_TOUCH_RAW",
                    fields: [
                        .init("c", String(describing: container)),
                        .init("type", event.type.rawValue),
                        .init("inWindow", inWindow),
                        .init("accepted", accepted),
                        .init("active", accumulator.isActive),
                        .init("selfTouching", event.touches(matching: .touching, in: self).count),
                        .init("nilTouching", event.touches(matching: .touching, in: nil).count),
                        .init("nilStationary", event.touches(matching: .stationary, in: nil).count),
                        .init("nilEnded", event.touches(matching: .ended, in: nil).count),
                        .init("nilCancelled", event.touches(matching: .cancelled, in: nil).count),
                        .init("phase", touchPhaseLabel(phase)),
                        .init("ts", event.timestamp, precision: 4),
                    ]
                )
            #endif
            guard accepted, let phase else { return }

            handleIndirectTouchPresence(phase, timestamp: event.timestamp)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                teardownActiveScroll()
            } else {
                SwipeCellScrollWheelMonitor.shared.register(self)
                updateIndirectTouchMonitorRegistration()
            }
        }

        override func removeFromSuperview() {
            teardownActiveScroll()
            super.removeFromSuperview()
        }

        func configure(
            isEnabled: Bool,
            input: SwipeCellConfiguration.PlatformInput,
            interactionConfiguration: SwipeCellInteractionConfiguration,
            container: SwipeCellContainer = .list,
            containerWidth: CGFloat,
            contentOffset: CGFloat = 0,
            onBegan: @escaping () -> Void,
            onChanged: @escaping (SwipeCellPanValue) -> Void,
            onEnded: @escaping (SwipeCellPanValue) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            isBridgeEnabled = isEnabled
            self.input = input
            self.container = container
            accumulator.update(
                input: input,
                interactionConfiguration: interactionConfiguration,
                container: container,
                containerWidth: containerWidth,
                contentOffset: contentOffset
            )
            self.onBegan = onBegan
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled

            if !isEnabled {
                cancelActiveScroll()
            }
            updateIndirectTouchMonitorRegistration()
        }

        // Cleanup on window loss / removal. Cancel any in-flight gesture so a detached row cannot leave
        // the shared swipe state stuck `.revealing` (which would keep the parent `.scrollDisabled`),
        // then detach from the monitor. The monitor holds only weak references, so a missed call still
        // self-heals on the next dispatch.
        private func teardownActiveScroll() {
            invalidateSyntheticEndTimer()
            postReleaseCooldown = nil
            cancelActiveScroll()
            unregisterIndirectTouchMonitor()
            SwipeCellScrollWheelMonitor.shared.unregister(self)
        }

        @discardableResult
        func handleScrollWheelSample(
            rawDelta: CGSize,
            phase: SwipeCellScrollWheelPhase = .none,
            momentumPhase: SwipeCellScrollWheelPhase = .none,
            hasPreciseScrollingDeltas: Bool,
            timestamp: TimeInterval? = nil
        ) -> Bool {
            let normalizationInput = activeScrollInput ?? input
            let delta = scrollDelta(
                rawDelta: rawDelta,
                hasPreciseScrollingDeltas: hasPreciseScrollingDeltas,
                input: normalizationInput
            )
            if consumesPostReleaseCooldownSample(
                delta: delta,
                timestamp: timestamp
            ) {
                return true
            }

            if consumesActiveVerticalNoOp(
                delta: delta,
                phase: phase,
                momentumPhase: momentumPhase
            ) {
                // Still live activity: re-arm the synthetic-end fallback so the row does not settle in the
                // middle of an ongoing physical scroll.
                scheduleSyntheticEndTimer()
                return true
            }

            let sample = SwipeCellScrollWheelSample(
                delta: delta,
                phase: phase,
                momentumPhase: momentumPhase,
                timestamp: timestamp
            )
            #if DEBUG
                let measureActiveBefore = accumulator.isActive
            #endif
            let decision = accumulator.handle(sample)
            #if DEBUG
                let measureActiveAfter = accumulator.isActive
                SwipeCellDiagnostics.trace(
                    .scrollFast,
                    event: "decision",
                    fields: [
                        .init("decision", decisionLabel(decision)),
                        .init("phase", String(describing: phase)),
                        .init("momentum", String(describing: momentumPhase)),
                    ]
                )
                SwipeCellDiagnostics.trace(
                    .measure,
                    event: "MEASURE",
                    fields: [
                        .init("c", String(describing: container)),
                        .init("ph", String(describing: phase)),
                        .init("mom", String(describing: momentumPhase)),
                        .init("precise", hasPreciseScrollingDeltas),
                        .init("preActive", measureActiveBefore),
                        .init("postActive", measureActiveAfter),
                        .init("rawdx", rawDelta.width, precision: 2),
                        .init("ndx", delta.width, precision: 2),
                    ]
                        + measureEventFields(decision)
                        + SwipeCellDiagnostics.fields(for: accumulator.measureDiagnosticsSnapshot)
                        + [.init("ts", timestamp, precision: 4)]
                )
            #endif
            startPostReleaseCooldownIfNeeded(
                after: decision,
                input: normalizationInput,
                timestamp: timestamp
            )
            updateActiveScrollInput(after: decision, normalizationInput: normalizationInput)
            // Arm a synthetic-end fallback for *any* active scroll, not only phase-less line wheels.
            // Phased devices (Trackpad / Magic Mouse) terminate via a delivered `.ended` or momentum,
            // but when that signal is dropped or the user simply stops scrolling past full open, nothing
            // would settle the row and it sticks at the rubber-band overshoot (#27 problem 1). With the
            // timer always armed, a quiet gap settles the row; a real `.ended` / momentum / cancel still
            // terminates immediately and invalidates it, so termination is guaranteed and idempotent.
            let shouldScheduleSyntheticEnd =
                switch decision {
                case .began, .changed: true
                case .ignored, .latched, .ended, .cancelled: false
                }
            guard apply(decision) else {
                return false
            }

            if shouldScheduleSyntheticEnd {
                scheduleSyntheticEndTimer()
            } else {
                invalidateSyntheticEndTimer()
            }
            return true
        }

        @discardableResult
        func handleIndirectTouchPresence(
            _ phase: SwipeCellIndirectTouchPresencePhase,
            timestamp: TimeInterval? = nil
        ) -> Bool {
            let normalizationInput = activeScrollInput ?? input
            #if DEBUG
                let measureActiveBefore = accumulator.isActive
            #endif
            let event = accumulator.handleTouchPresence(
                SwipeCellIndirectTouchPresenceSample(
                    phase: phase,
                    timestamp: timestamp
                )
            )
            #if DEBUG
                SwipeCellDiagnostics.trace(
                    .measure,
                    event: "MEASURE_TOUCH",
                    fields: [
                        .init("c", String(describing: container)),
                        .init("touch", touchPhaseLabel(phase)),
                        .init("preActive", measureActiveBefore),
                        .init("postActive", accumulator.isActive),
                    ]
                        + measureEventFields(event)
                        + SwipeCellDiagnostics.fields(for: accumulator.measureDiagnosticsSnapshot)
                        + [.init("ts", timestamp, precision: 4)]
                )
            #endif
            startPostReleaseCooldownIfNeeded(
                after: event,
                input: normalizationInput,
                timestamp: timestamp
            )
            updateActiveScrollInput(after: event, normalizationInput: normalizationInput)
            if case .ignored = event {
                return false
            }
            if case .latched = event {
                invalidateSyntheticEndTimer()
            }
            return apply(event)
        }

        private func scrollDelta(
            rawDelta: CGSize,
            hasPreciseScrollingDeltas: Bool,
            input: SwipeCellConfiguration.PlatformInput
        ) -> CGSize {
            let scale =
                hasPreciseScrollingDeltas
                ? input.scrollWheelTrackpadScale
                : input.scrollWheelLineScale
            return CGSize(
                width: rawDelta.width * scale,
                height: rawDelta.height * scale
            )
        }

        private func updateActiveScrollInput(
            after event: SwipeCellScrollWheelPanEvent,
            normalizationInput: SwipeCellConfiguration.PlatformInput
        ) {
            switch event {
            case .began:
                activeScrollInput = normalizationInput
                postReleaseCooldown = nil
            case .changed, .latched:
                activeScrollInput = activeScrollInput ?? normalizationInput
            case .ended, .cancelled:
                activeScrollInput = nil
            case .ignored:
                break
            }
        }

        private func updateIndirectTouchMonitorRegistration() {
            guard shouldObserveIndirectTouches else {
                unregisterIndirectTouchMonitor()
                return
            }

            allowedTouchTypes = [.indirect]
            wantsRestingTouches = true
            guard !isIndirectTouchMonitorRegistered else { return }

            SwipeCellIndirectTouchMonitor.shared.register(self)
            isIndirectTouchMonitorRegistered = true
            #if DEBUG
                SwipeCellDiagnostics.trace(
                    .scrollFast,
                    event: "indirect-touch-monitor",
                    fields: [
                        .init("registered", true),
                        .init("container", String(describing: container)),
                    ]
                )
            #endif
        }

        private func unregisterIndirectTouchMonitor() {
            guard isIndirectTouchMonitorRegistered else { return }

            SwipeCellIndirectTouchMonitor.shared.unregister(self)
            isIndirectTouchMonitorRegistered = false
        }

        private var shouldObserveIndirectTouches: Bool {
            isBridgeEnabled && container == .scrollView && window != nil
        }

        private func indirectTouchPresencePhase(from event: NSEvent) -> SwipeCellIndirectTouchPresencePhase? {
            let touching = nonRestingIndirectTouches(matching: .touching, in: event)
            let stationary = nonRestingIndirectTouches(matching: .stationary, in: event)
            let ended = nonRestingIndirectTouches(matching: .ended, in: event)
            let cancelled = nonRestingIndirectTouches(matching: .cancelled, in: event)

            if !stationary.isEmpty {
                return .stationary
            }
            if !touching.isEmpty {
                return .active
            }
            if !cancelled.isEmpty {
                return .cancelled
            }
            if !ended.isEmpty {
                return .ended
            }
            return nil
        }

        private func nonRestingIndirectTouches(
            matching phase: NSTouch.Phase,
            in event: NSEvent
        ) -> [NSTouch] {
            // Must query `in: nil`, not `in: self`. AppKit associates indirect (Trackpad) touches with the
            // view hit-tested under the pointer, but this bridge is deliberately hit-test transparent
            // (`hitTest` returns nil) so row clicks / Buttons / NavigationLinks pass through. A transparent
            // view is therefore never the touch-associated view, and `touches(matching:in: self)` returns an
            // empty set for every phase — which silently dropped the whole Trackpad lifecycle and left the
            // gesture on the #70 keep-alive fallback, indistinguishable from Magic Mouse. Reading all touches
            // on the event and scoping to this row via the window / bounds gate in `handleIndirectTouchEvent`
            // plus the accumulator's active-gesture guard keeps the passive observer correct without making
            // the view hit-testable.
            event.touches(matching: phase, in: nil).filter {
                $0.type == .indirect && !$0.isResting
            }
        }

        @discardableResult
        private func apply(_ event: SwipeCellScrollWheelPanEvent) -> Bool {
            switch event {
            case .ignored:
                return false
            case .latched:
                return true
            case .began(let value):
                onBegan()
                onChanged(value)
                return true
            case .changed(let value):
                onChanged(value)
                return true
            case .ended(let value):
                invalidateSyntheticEndTimer()
                onEnded(value)
                return true
            case .cancelled:
                invalidateSyntheticEndTimer()
                onCancelled()
                return true
            }
        }

        private func scheduleSyntheticEndTimer() {
            invalidateSyntheticEndTimer()
            let delay = (activeScrollInput ?? input).scrollWheelEndSynthesisDelay
            syntheticEndTimer = Timer.scheduledTimer(
                withTimeInterval: delay,
                repeats: false
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.finishActiveScroll()
                }
            }
        }

        private func invalidateSyntheticEndTimer() {
            syntheticEndTimer?.invalidate()
            syntheticEndTimer = nil
        }

        private func finishActiveScroll() {
            #if DEBUG
                SwipeCellDiagnostics.trace(
                    .scrollFast,
                    event: "finish",
                    fields: [.init("cause", "synthetic-timer")]
                )
            #endif
            let normalizationInput = activeScrollInput ?? input
            #if DEBUG
                let measureActiveBefore = accumulator.isActive
            #endif
            let event = accumulator.finishActiveGesture()
            #if DEBUG
                SwipeCellDiagnostics.trace(
                    .measure,
                    event: "MEASURE_TIMER",
                    fields: [
                        .init("c", String(describing: container)),
                        .init("timer", "synthetic"),
                        .init("preActive", measureActiveBefore),
                        .init("postActive", accumulator.isActive),
                    ]
                        + measureEventFields(event)
                        + SwipeCellDiagnostics.fields(for: accumulator.measureDiagnosticsSnapshot)
                        + [.init("ts", "nil")]
                )
            #endif
            startPostReleaseCooldownIfNeeded(
                after: event,
                input: normalizationInput,
                timestamp: nil
            )
            updateActiveScrollInput(after: event, normalizationInput: normalizationInput)
            if case .ignored = event {
                activeScrollInput = nil
            }
            if case .latched = event {
                invalidateSyntheticEndTimer()
            }
            apply(event)
        }

        private func cancelActiveScroll() {
            postReleaseCooldown = nil
            let event = accumulator.cancelActiveGesture()
            updateActiveScrollInput(after: event, normalizationInput: activeScrollInput ?? input)
            if case .ignored = event {
                activeScrollInput = nil
            }
            apply(event)
        }

        private func startPostReleaseCooldownIfNeeded(
            after event: SwipeCellScrollWheelPanEvent,
            input: SwipeCellConfiguration.PlatformInput,
            timestamp: TimeInterval?
        ) {
            guard case .ended = event else { return }
            let start = eventTimestamp(timestamp)
            postReleaseCooldown = PostReleaseCooldown(
                input: input,
                expiresAt: start + postReleaseCooldownDuration(for: input)
            )
        }

        // During an active swipe drag only horizontal-dominant samples drive the accumulator. A vertical-
        // dominant or exact-tie sample is consumed as a pure no-op — skipped before the accumulator so it
        // cannot move the row or touch fast intent / destructive continuation / close-release velocity.
        // The monitor still returns the event to the parent, which the scope holds via `.scrollDisabled`
        // for the drag's duration (issue #31). Terminal phases are never no-op'd, so `.ended` /
        // `.cancelled` / momentum still settle the gesture.
        private func consumesActiveVerticalNoOp(
            delta: CGSize,
            phase: SwipeCellScrollWheelPhase,
            momentumPhase: SwipeCellScrollWheelPhase
        ) -> Bool {
            guard accumulator.isActive,
                momentumPhase == .none,
                phase != .ended,
                phase != .cancelled,
                !SwipeCellPanIntent.isHorizontal(delta: delta)
            else { return false }
            return true
        }

        private func consumesPostReleaseCooldownSample(
            delta: CGSize,
            timestamp: TimeInterval?
        ) -> Bool {
            guard !accumulator.isActive,
                let cooldown = postReleaseCooldown
            else { return false }

            let now = eventTimestamp(timestamp)
            guard now < cooldown.expiresAt else {
                postReleaseCooldown = nil
                return false
            }

            guard abs(delta.width) >= cooldown.input.scrollWheelMinStartDelta,
                SwipeCellPanIntent.isHorizontal(delta: delta)
            else {
                return false
            }

            return true
        }

        private func postReleaseCooldownDuration(
            for input: SwipeCellConfiguration.PlatformInput
        ) -> TimeInterval {
            let synthesisDelay = input.scrollWheelEndSynthesisDelay
            let scaledDelay: TimeInterval
            if synthesisDelay.isFinite && synthesisDelay > 0 {
                scaledDelay = synthesisDelay * 1.5
            } else {
                scaledDelay = 0
            }
            return max(0.18, scaledDelay)
        }

        private func eventTimestamp(_ timestamp: TimeInterval?) -> TimeInterval {
            guard let timestamp, timestamp.isFinite else {
                return ProcessInfo.processInfo.systemUptime
            }
            return timestamp
        }

        #if DEBUG
            private func measureEventFields(
                _ decision: SwipeCellScrollWheelPanEvent
            ) -> [SwipeCellDiagnostics.Field] {
                let movement: CGFloat
                let bypass: String
                let allowsDestructive: String
                let velocityX: CGFloat
                switch decision {
                case .began(let value), .changed(let value), .ended(let value):
                    movement = value.translation.width
                    bypass = value.bypassesNormalReleaseThreshold ? "1" : "0"
                    allowsDestructive = value.allowsDestructiveRelease ? "1" : "0"
                    velocityX = value.velocity.x
                default:
                    movement = .nan
                    bypass = "-"
                    allowsDestructive = "-"
                    velocityX = .nan
                }
                return [
                    .init("decision", decisionKind(decision)),
                    .init("move", movement, precision: 2),
                    .init("bypass", bypass),
                    .init("allowDestructive", allowsDestructive),
                    .init("vx", velocityX, precision: 2),
                ]
            }

            private func decisionLabel(_ decision: SwipeCellScrollWheelPanEvent) -> String {
                switch decision {
                case .ignored: "ignored"
                case .began: "began"
                case .changed: "changed"
                case .latched: "latched"
                case .ended(let value):
                    "ended(allowsDestructive=\(value.allowsDestructiveRelease))"
                case .cancelled: "cancelled"
                }
            }

            private func decisionKind(_ decision: SwipeCellScrollWheelPanEvent) -> String {
                switch decision {
                case .ignored:
                    return "ignored"
                case .began:
                    return "began"
                case .changed:
                    return "changed"
                case .latched:
                    return "latched"
                case .ended:
                    return "ended"
                case .cancelled:
                    return "cancelled"
                }
            }

            private func touchPhaseLabel(_ phase: SwipeCellIndirectTouchPresencePhase?) -> String {
                guard let phase else { return "nil" }
                return touchPhaseLabel(phase)
            }

            private func touchPhaseLabel(_ phase: SwipeCellIndirectTouchPresencePhase) -> String {
                switch phase {
                case .active:
                    return "active"
                case .stationary:
                    return "stationary"
                case .ended:
                    return "ended"
                case .cancelled:
                    return "cancelled"
                }
            }
        #endif
    }

    extension SwipeCellScrollWheelPhase {
        init(_ phase: NSEvent.Phase) {
            if phase.contains(.cancelled) {
                self = .cancelled
            } else if phase.contains(.ended) {
                self = .ended
            } else if phase.contains(.began) {
                self = .began
            } else if phase.contains(.changed) {
                self = .changed
            } else if phase.contains(.mayBegin) {
                self = .mayBegin
            } else {
                self = .none
            }
        }
    }
#endif
