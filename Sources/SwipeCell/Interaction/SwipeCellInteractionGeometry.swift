import CoreGraphics

nonisolated enum SwipeCellInteractionGeometry {
    static func movement(_ width: CGFloat, toward side: SwipeCellSide) -> CGFloat {
        switch side {
        case .leading:
            width
        case .trailing:
            -width
        }
    }

    static func resetDistance(_ width: CGFloat, from side: SwipeCellSide) -> CGFloat {
        max(0, -movement(width, toward: side))
    }

    static func signedOffset(_ movement: CGFloat, for side: SwipeCellSide) -> CGFloat {
        movement * directionMultiplier(for: side)
    }

    static func directionMultiplier(for side: SwipeCellSide) -> CGFloat {
        switch side {
        case .leading:
            1
        case .trailing:
            -1
        }
    }
}
