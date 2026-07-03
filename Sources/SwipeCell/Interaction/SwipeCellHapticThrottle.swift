import Foundation

/// Owns haptic sequence and suppression timing while the observable event stays on the coordinator.
final class SwipeCellHapticThrottle {
    private var sequence = 0
    private var nextAllowedAt = Date.distantPast

    func nextEvent(
        kind: SwipeCellHapticEventKind,
        respectsSuppression: Bool,
        suppression: TimeInterval
    ) -> SwipeCellHapticEvent? {
        let now = Date()
        if respectsSuppression, now < nextAllowedAt {
            return nil
        }

        sequence += 1
        nextAllowedAt = now.addingTimeInterval(suppression)
        return SwipeCellHapticEvent(id: sequence, kind: kind)
    }
}
