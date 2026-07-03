import CoreGraphics
import Foundation
import SwiftUI

enum SwipeCellStaleReleaseDecision: Equatable {
    case none
    case ignoreIndirectScroll
    case collapseDirectTouch
}

nonisolated struct SwipeCellReleaseSettleMetrics: Equatable, Sendable {
    let releaseTarget: SwipeCellReleaseTarget
    let releaseClassification: SwipeCellReleaseClassification
    let actualRemainingDistance: CGFloat
    let pacedRemainingDistance: CGFloat
    let releaseSpeed: CGFloat
    let referenceDistance: CGFloat
    let settleDuration: TimeInterval
}

/// Pure release-settle output: call sites keep owning state writes, scheduling, and diagnostics emission.
nonisolated struct SwipeCellReleaseSettlePlan: Equatable, Sendable {
    let metrics: SwipeCellReleaseSettleMetrics
    let animation: Animation
}

/// Resolves gesture-release retargeting and settle motion without owning observable coordinator state.
enum SwipeCellGestureReleaseResolver {
    static func staleReleaseDecision(_ inputs: SwipeCellInteractionInputs) -> SwipeCellStaleReleaseDecision {
        guard let manager = inputs.manager,
            manager.ownsActiveCell(inputs.cellID) == false
        else {
            return .none
        }

        switch inputs.configuration.motion.trackingStyle {
        case .indirectScroll:
            return .ignoreIndirectScroll
        case .directTouch:
            return .collapseDirectTouch
        }
    }

    static func shouldDeferClosedTarget(_ inputs: SwipeCellInteractionInputs) -> Bool {
        switch inputs.configuration.motion.trackingStyle {
        case .directTouch, .indirectScroll:
            return true
        }
    }

    static func resolvedSnapshot(
        _ snapshot: SwipeCellInteractionSnapshot,
        value: SwipeCellPanValue,
        model: SwipeCellInteractionModel,
        startSide: SwipeCellSide?
    ) -> SwipeCellInteractionSnapshot {
        // macOS scroll-wheel can visually reach the destructive distance from a fast physical burst.
        // Fire only after the input layer marks that destructive release as confirmed; otherwise
        // retarget to a normal open using the same locked model geometry.
        guard !value.allowsDestructiveRelease,
            case .destructive = snapshot.releaseTarget
        else {
            return snapshot
        }

        let sideConfiguration = model.configuration.sideConfiguration(for: snapshot.interactionSide)
        let openTranslationWidth: CGFloat =
            if startSide == nil {
                switch snapshot.interactionSide {
                case .leading:
                    sideConfiguration.normalOpenExtent
                case .trailing:
                    -sideConfiguration.normalOpenExtent
                }
            } else {
                0
            }

        return model.snapshot(
            startSide: startSide,
            lockedSide: snapshot.interactionSide,
            translationWidth: openTranslationWidth,
            predictedEndTranslationWidth: openTranslationWidth,
            openOriginMovement: value.openOriginMovement,
            pointerActive: false
        )
    }

    /// Curve for a `panEnded` gesture-release settle: a continuation from release offset
    /// (`contentOffset`) to `targetOffset`. Once the target is resolved, release speed is diagnostic
    /// only; remaining distance and reference geometry own visible settle duration (issues #77/#79).
    nonisolated static func animation(
        releaseVelocity: CGPoint,
        releaseTarget: SwipeCellReleaseTarget,
        releaseClassification: SwipeCellReleaseClassification = .standard,
        contentOffset: CGFloat,
        targetOffset: CGFloat,
        referenceDistance: CGFloat,
        motion: SwipeCellConfiguration.Motion
    ) -> Animation {
        releaseSettlePlan(
            releaseVelocity: releaseVelocity,
            releaseTarget: releaseTarget,
            releaseClassification: releaseClassification,
            contentOffset: contentOffset,
            targetOffset: targetOffset,
            referenceDistance: referenceDistance,
            motion: motion
        ).animation
    }

    nonisolated static func releaseSettlePlan(
        releaseVelocity: CGPoint,
        releaseTarget: SwipeCellReleaseTarget,
        releaseClassification: SwipeCellReleaseClassification = .standard,
        contentOffset: CGFloat,
        targetOffset: CGFloat,
        referenceDistance: CGFloat,
        motion: SwipeCellConfiguration.Motion
    ) -> SwipeCellReleaseSettlePlan {
        let metrics = releaseSettleMetrics(
            releaseVelocity: releaseVelocity,
            releaseTarget: releaseTarget,
            releaseClassification: releaseClassification,
            contentOffset: contentOffset,
            targetOffset: targetOffset,
            referenceDistance: referenceDistance,
            motion: motion
        )
        return SwipeCellReleaseSettlePlan(
            metrics: metrics,
            animation: animation(metrics: metrics, motion: motion)
        )
    }

    nonisolated static func releaseSettleMetrics(
        releaseVelocity: CGPoint,
        releaseTarget: SwipeCellReleaseTarget,
        releaseClassification: SwipeCellReleaseClassification = .standard,
        contentOffset: CGFloat,
        targetOffset: CGFloat,
        referenceDistance: CGFloat,
        motion: SwipeCellConfiguration.Motion
    ) -> SwipeCellReleaseSettleMetrics {
        let actualRemainingDistance = abs(targetOffset - contentOffset)
        let pacedRemainingDistance = SwipeCellReleaseSettleMotion.pacedRemainingDistance(
            actualRemainingDistance: actualRemainingDistance,
            releaseClassification: releaseClassification,
            targetOffset: targetOffset
        )
        let releaseSpeed = SwipeCellReleaseSettleMotion.settleSpeed(
            releaseVelocityX: releaseVelocity.x,
            releaseTarget: releaseTarget,
            releaseClassification: releaseClassification,
            contentOffset: contentOffset,
            targetOffset: targetOffset
        )
        let settleDuration = SwipeCellReleaseSettleMotion.gestureSettleDuration(
            remainingDistance: pacedRemainingDistance,
            releaseSpeed: releaseSpeed,
            releaseTarget: releaseTarget,
            referenceDistance: referenceDistance,
            motion: motion
        )
        return SwipeCellReleaseSettleMetrics(
            releaseTarget: releaseTarget,
            releaseClassification: releaseClassification,
            actualRemainingDistance: actualRemainingDistance,
            pacedRemainingDistance: pacedRemainingDistance,
            releaseSpeed: releaseSpeed,
            referenceDistance: referenceDistance,
            settleDuration: settleDuration
        )
    }

    nonisolated static func referenceDistance(
        releaseTarget: SwipeCellReleaseTarget,
        sideConfiguration: SwipeCellInteractionSideConfiguration,
        contentOffset: CGFloat,
        targetOffset: CGFloat
    ) -> CGFloat {
        switch releaseTarget {
        case .closed, .open:
            return sideConfiguration.normalOpenExtent
        case .destructive:
            return max(
                sideConfiguration.destructiveHoldExtent,
                abs(targetOffset),
                abs(contentOffset)
            )
        }
    }

    nonisolated static func animation(
        metrics: SwipeCellReleaseSettleMetrics,
        motion: SwipeCellConfiguration.Motion
    ) -> Animation {
        return SwipeCellReleaseSettleMotion.animation(
            remainingDistance: metrics.pacedRemainingDistance,
            releaseSpeed: metrics.releaseSpeed,
            releaseTarget: metrics.releaseTarget,
            referenceDistance: metrics.referenceDistance,
            motion: motion
        )
    }
}
