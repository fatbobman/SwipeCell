import Foundation

/// Holds coordinator-owned mechanism state that is not part of the SwiftUI observation surface.
final class SwipeCellResetGenerationTracker {
    private var observedGeneration = 0

    func syncBaseline(_ generation: Int) {
        observedGeneration = generation
    }

    func receive(_ generation: Int) -> Bool {
        guard generation != observedGeneration else { return false }

        observedGeneration = generation
        return true
    }

    func expectNext(after generation: Int) {
        observedGeneration = generation + 1
    }
}

/// Keeps tap-to-close suppression out of the observable coordinator while preserving its facade.
final class SwipeCellTapCloseSuppression {
    private var suppressedUntil = Date.distantPast

    var canTapClose: Bool {
        Date() >= suppressedUntil
    }

    func suppress(for duration: TimeInterval) {
        suppressedUntil = Date().addingTimeInterval(duration)
    }
}
