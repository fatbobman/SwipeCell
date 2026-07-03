import CoreGraphics

nonisolated enum SwipeCellOffsetAnimationRole: Equatable, Sendable {
    case none
    case releaseSettling
    case forcedReset
}

nonisolated struct SwipeCellOffsetUpdate: Equatable, Sendable {
    let contentOffset: CGFloat
    let normalOpenProgress: CGFloat
    let deformationProgress: CGFloat
    let isArmed: Bool
    let animationRole: SwipeCellOffsetAnimationRole

    @available(*, deprecated, renamed: "deformationProgress")
    var destructiveProgress: CGFloat { deformationProgress }

    @available(*, deprecated, renamed: "isArmed")
    var isDestructiveArmed: Bool { isArmed }

    static func activeDrag(from snapshot: SwipeCellInteractionSnapshot) -> SwipeCellOffsetUpdate {
        SwipeCellOffsetUpdate(
            contentOffset: snapshot.activeOffset,
            normalOpenProgress: snapshot.normalOpenProgress,
            deformationProgress: snapshot.deformationProgress,
            isArmed: snapshot.isArmed,
            animationRole: .none
        )
    }

    static func releaseSettling(from snapshot: SwipeCellInteractionSnapshot) -> SwipeCellOffsetUpdate {
        SwipeCellOffsetUpdate(
            contentOffset: snapshot.settlingTarget?.contentOffset ?? 0,
            normalOpenProgress: settledProgress(for: snapshot.releaseTarget),
            deformationProgress: settledDeformationProgress(for: snapshot.releaseTarget),
            isArmed: snapshot.releaseTarget?.isDestructive == true,
            animationRole: .releaseSettling
        )
    }

    static var forcedReset: SwipeCellOffsetUpdate {
        SwipeCellOffsetUpdate(
            contentOffset: 0,
            normalOpenProgress: 0,
            deformationProgress: 0,
            isArmed: false,
            animationRole: .forcedReset
        )
    }

    /// Whether applying this update should own the action layer's settling-side lifecycle: keep the
    /// closing side mounted while content animates back, then clear it once the animation completes.
    ///
    /// A close drives two settle updates that race — the deferred release/tap settle and the
    /// reset-token settle. Whichever runs first moves content to zero; the other arrives with content
    /// already at rest. Only the one that still has a revealed offset to animate may own. If the late
    /// update owned, its `withAnimation` would finish immediately (no offset change) and clear the
    /// side before the real settle animation ends, making the action buttons vanish mid-close.
    func ownsVisibleCloseSettle(fromContentOffset currentOffset: CGFloat) -> Bool {
        guard animationRole != .none, contentOffset == 0 else { return false }
        // Matches the action shell's reveal threshold: a real revealed offset must remain to settle.
        return abs(currentOffset) > 0.5
    }

    private static func settledProgress(for target: SwipeCellReleaseTarget?) -> CGFloat {
        switch target {
        case .open, .destructive:
            1
        case .closed, nil:
            0
        }
    }

    private static func settledDeformationProgress(for target: SwipeCellReleaseTarget?) -> CGFloat {
        target?.isDestructive == true ? 1 : 0
    }
}

extension SwipeCellReleaseTarget {
    fileprivate nonisolated var isDestructive: Bool {
        switch self {
        case .destructive:
            true
        case .closed, .open:
            false
        }
    }
}
