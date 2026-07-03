import CoreGraphics
import SwiftUI

/// Direction of the latest active-drag crossing over the destructive fire boundary.
nonisolated public enum SwipeActionArmChangeKind: Equatable, Sendable {
    case enterFire
    case exitFire
}

/// Published interaction state for one rendered swipe action.
///
/// `index == 0` is the outermost slot on its side. Layout-only facts such as allocated width stay
/// outside this public context; custom labels and styles consume normalized progress instead.
nonisolated public struct SwipeActionContext: Equatable, Sendable {
    public let side: SwipeCellSide
    public let index: Int
    public let count: Int
    public let isOutermost: Bool
    public let role: SwipeActionRoleKind
    public let normalOpenProgress: CGFloat
    public let deformationProgress: CGFloat
    /// Continuous destructive fire state for visual styling.
    public let isArmed: Bool
    /// Monotonic token for active-drag fire-boundary crossings.
    public let armChangeID: Int
    /// Direction for `armChangeID`; silent release/reset cleanup leaves this marker unchanged.
    public let armChangeKind: SwipeActionArmChangeKind?

    public init(
        side: SwipeCellSide,
        index: Int,
        count: Int,
        isOutermost: Bool,
        role: SwipeActionRoleKind,
        normalOpenProgress: CGFloat,
        deformationProgress: CGFloat,
        isArmed: Bool,
        armChangeID: Int,
        armChangeKind: SwipeActionArmChangeKind? = nil
    ) {
        self.side = side
        self.index = index
        self.count = count
        self.isOutermost = isOutermost
        self.role = role
        self.normalOpenProgress = Self.clampedProgress(normalOpenProgress)
        self.deformationProgress = Self.clampedProgress(deformationProgress)
        self.isArmed = isArmed
        self.armChangeID = max(0, armChangeID)
        self.armChangeKind = armChangeKind
    }

    @available(*, deprecated, renamed: "deformationProgress")
    public var destructiveProgress: CGFloat { deformationProgress }

    @available(*, deprecated, renamed: "isArmed")
    public var isDestructiveArmed: Bool { isArmed }

    private static func clampedProgress(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

private struct SwipeActionContextEnvironmentKey: EnvironmentKey {
    static let defaultValue: SwipeActionContext? = nil
}

extension EnvironmentValues {
    public var swipeActionContext: SwipeActionContext? {
        get { self[SwipeActionContextEnvironmentKey.self] }
        set { self[SwipeActionContextEnvironmentKey.self] = newValue }
    }
}
