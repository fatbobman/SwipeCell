import CoreGraphics
import SwiftUI

/// Narrow write-back surface for D extraction; the handler sequences timing but does not own render state.
protocol SwipeCellDestructiveTriggerHost: AnyObject {
    func shouldClaimImmediateDestructiveAutoCollapseBeforeClosure(_ inputs: SwipeCellInteractionInputs) -> Bool

    func destructiveTriggerExpandAnimation(
        releaseVelocity: CGPoint,
        releaseTarget: SwipeCellReleaseTarget,
        releaseClassification: SwipeCellReleaseClassification,
        targetOffset: CGFloat,
        inputs: SwipeCellInteractionInputs
    ) -> Animation

    func applyDestructiveTriggerOffsetUpdate(
        _ update: SwipeCellOffsetUpdate,
        inputs: SwipeCellInteractionInputs,
        source: String,
        settleAnimation: Animation?,
        claimsForcedResetBeforeDeferring: Bool,
        completion: (() -> Void)?
    )

    func expectDestructiveTriggerLocalResetGeneration(_ inputs: SwipeCellInteractionInputs)
}

/// Stateless destructive-release timing helper; observable render writes stay on the coordinator host.
enum SwipeCellDestructiveTriggerHandler {
    static func applyRelease(
        _ side: SwipeCellSide,
        snapshot: SwipeCellInteractionSnapshot,
        releaseVelocity: CGPoint,
        inputs: SwipeCellInteractionInputs,
        host: SwipeCellDestructiveTriggerHost
    ) {
        // A destructive release crossed the activation edge under the finger, so its expand-in-place
        // settle stays in the gesture-release family instead of using the reset curve. The resolver then
        // applies the resolved-target pacing contract: distance/reference owns duration, while the
        // platform tracking style still chooses the animation family.
        let expandAnimation = host.destructiveTriggerExpandAnimation(
            releaseVelocity: releaseVelocity,
            releaseTarget: snapshot.releaseTarget ?? .destructive(side),
            releaseClassification: snapshot.releaseClassification,
            targetOffset: snapshot.settlingTarget?.contentOffset ?? 0,
            inputs: inputs
        )

        guard let trigger = inputs.destructiveTrigger(side) else {
            host.applyDestructiveTriggerOffsetUpdate(
                .releaseSettling(from: snapshot),
                inputs: inputs,
                source: "release",
                settleAnimation: expandAnimation,
                claimsForcedResetBeforeDeferring: false,
                completion: nil
            )
            inputs.manager?.applyReleaseTarget(.destructive(side), for: inputs.cellID)
            return
        }

        inputs.manager?.applyReleaseTarget(.destructive(side), for: inputs.cellID)

        switch trigger.completion {
        case .directTrigger:
            if trigger.action.controlledAction == nil,
                host.shouldClaimImmediateDestructiveAutoCollapseBeforeClosure(inputs)
            {
                collapseAfterDestructiveTrigger(
                    inputs: inputs,
                    host: host,
                    claimsCloseBeforeDeferring: true
                )
                #if DEBUG
                    SwipeCellUserClosureDiagnostics.emit(
                        .invoked,
                        inputs: inputs,
                        triggerSource: "destructive-trigger",
                        resolvedTiming: "directTrigger"
                    )
                #endif
                trigger.action.action()
            } else {
                let controller = triggerController(snapshot: snapshot, inputs: inputs, host: host)
                #if DEBUG
                    SwipeCellUserClosureDiagnostics.emit(
                        .invoked,
                        inputs: inputs,
                        triggerSource: "destructive-trigger",
                        resolvedTiming: "directTrigger",
                        closureKind: trigger.action.controlledAction == nil ? .simple : .controller
                    )
                #endif
                let usesController = trigger.action.trigger(with: controller)
                if !usesController, !controller.isResolved {
                    controller.collapse()
                }
            }
        case .triggerAfterReset:
            let controller = triggerController(snapshot: snapshot, inputs: inputs, host: host)
            #if DEBUG
                SwipeCellUserClosureDiagnostics.emit(
                    .queued,
                    inputs: inputs,
                    triggerSource: "destructive-trigger",
                    resolvedTiming: "triggerAfterReset"
                )
            #endif
            collapseAfterDestructiveTrigger(inputs: inputs, host: host) {
                #if DEBUG
                    SwipeCellUserClosureDiagnostics.emitCollapseTerminal(
                        inputs: inputs,
                        triggerSource: "destructive-trigger",
                        resolvedTiming: "triggerAfterReset",
                        closureKind: trigger.action.controlledAction == nil ? .simple : .controller
                    )
                    SwipeCellUserClosureDiagnostics.emit(
                        .invoked,
                        inputs: inputs,
                        triggerSource: "destructive-trigger",
                        resolvedTiming: "triggerAfterReset",
                        closureKind: trigger.action.controlledAction == nil ? .simple : .controller
                    )
                #endif
                _ = trigger.action.trigger(with: controller)
            }
        case .triggerHoldExpanded:
            host.applyDestructiveTriggerOffsetUpdate(
                .releaseSettling(from: snapshot),
                inputs: inputs,
                source: "release",
                settleAnimation: expandAnimation,
                claimsForcedResetBeforeDeferring: false,
                completion: nil
            )
            let controller = triggerController(snapshot: snapshot, inputs: inputs, host: host)
            #if DEBUG
                SwipeCellUserClosureDiagnostics.emit(
                    .invoked,
                    inputs: inputs,
                    triggerSource: "destructive-trigger",
                    resolvedTiming: "triggerHoldExpanded",
                    closureKind: trigger.action.controlledAction == nil ? .simple : .controller
                )
            #endif
            let usesController = trigger.action.trigger(with: controller)
            if !usesController, !controller.isResolved {
                controller.holdExpanded()
            }
        }
    }

    private static func triggerController(
        snapshot: SwipeCellInteractionSnapshot,
        inputs: SwipeCellInteractionInputs,
        host: SwipeCellDestructiveTriggerHost
    ) -> SwipeActionTriggerController {
        SwipeActionTriggerController(
            collapse: {
                collapseAfterDestructiveTrigger(inputs: inputs, host: host)
            },
            holdExpanded: {
                holdDestructiveExpanded(snapshot: snapshot, inputs: inputs, host: host)
            }
        )
    }

    private static func holdDestructiveExpanded(
        snapshot: SwipeCellInteractionSnapshot,
        inputs: SwipeCellInteractionInputs,
        host: SwipeCellDestructiveTriggerHost
    ) {
        guard case .destructive(let side) = snapshot.releaseTarget else { return }

        if inputs.manager?.ownsActiveCell(inputs.cellID) != true {
            inputs.manager?.beginInteraction(for: inputs.cellID, side: side)
        }
        inputs.manager?.applyReleaseTarget(.destructive(side), for: inputs.cellID)
        host.applyDestructiveTriggerOffsetUpdate(
            .releaseSettling(from: snapshot),
            inputs: inputs,
            source: "destructive-hold",
            settleAnimation: nil,
            claimsForcedResetBeforeDeferring: false,
            completion: nil
        )
    }

    private static func collapseAfterDestructiveTrigger(
        inputs: SwipeCellInteractionInputs,
        host: SwipeCellDestructiveTriggerHost,
        claimsCloseBeforeDeferring: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        host.applyDestructiveTriggerOffsetUpdate(
            .forcedReset,
            inputs: inputs,
            source: "destructive-trigger",
            settleAnimation: nil,
            claimsForcedResetBeforeDeferring: claimsCloseBeforeDeferring,
            completion: {
                inputs.manager?.completeVisibleReset(for: inputs.cellID)
                completion?()
            }
        )
        host.expectDestructiveTriggerLocalResetGeneration(inputs)
        inputs.manager?.close(inputs.cellID, reason: .explicitClose)
    }
}
