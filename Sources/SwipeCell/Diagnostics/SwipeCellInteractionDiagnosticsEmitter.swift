import CoreGraphics
import Foundation

#if DEBUG
    enum SwipeCellUserClosurePhase: String {
        case queued
        case invoked
        case skipped
        case cancelled

        var event: String {
            switch self {
            case .queued:
                "userClosure.queued"
            case .invoked:
                "userClosure.invoke"
            case .skipped:
                "userClosure.skipped"
            case .cancelled:
                "userClosure.cancelled"
            }
        }
    }

    enum SwipeCellUserClosureKind: String {
        case simple
        case controller
    }

    enum SwipeCellUserClosureDiagnostics {
        static func emitCollapseTerminal(
            inputs: SwipeCellInteractionInputs,
            triggerSource: String,
            resolvedTiming: String,
            closureKind: SwipeCellUserClosureKind = .simple
        ) {
            SwipeCellValidationDiagnostics.emit(
                event: "actionCollapse.terminal",
                cellID: inputs.cellID,
                fields: baseFields(
                    inputs: inputs,
                    triggerSource: triggerSource,
                    resolvedTiming: resolvedTiming,
                    closureKind: closureKind
                )
            )
        }

        static func emit(
            _ phase: SwipeCellUserClosurePhase,
            inputs: SwipeCellInteractionInputs,
            triggerSource: String,
            resolvedTiming: String,
            closureKind: SwipeCellUserClosureKind = .simple
        ) {
            SwipeCellValidationDiagnostics.emit(
                event: phase.event,
                cellID: inputs.cellID,
                fields: [.init("closurePhase", phase.rawValue)]
                    + baseFields(
                        inputs: inputs,
                        triggerSource: triggerSource,
                        resolvedTiming: resolvedTiming,
                        closureKind: closureKind
                    )
            )
        }

        private static func baseFields(
            inputs: SwipeCellInteractionInputs,
            triggerSource: String,
            resolvedTiming: String,
            closureKind: SwipeCellUserClosureKind
        ) -> [SwipeCellValidationDiagnostics.Field] {
            let manager = inputs.manager
            return [
                .init("triggerSource", triggerSource),
                .init("resolvedTiming", resolvedTiming),
                .init("closureKind", closureKind.rawValue),
                .init("trackingStyle", inputs.configuration.motion.trackingStyle),
                .init("phase", manager?.phase),
                .init("active", manager?.activeCellID),
                .init("activeSide", manager?.activeSide),
                .init("resetting", manager?.resettingCellID),
                .init("resetGen", manager?.resetGeneration ?? 0),
                .init("resetReason", manager?.lastResetReason),
            ]
        }
    }

    struct SwipeCellInteractionDiagnosticsSnapshot {
        let cellID: AnyHashable
        let trackingStyle: SwipeCellTrackingStyle
        let phase: SwipeCellPhase?
        let activeCellID: AnyHashable?
        let activeSide: SwipeCellSide?
        let resettingCellID: AnyHashable?
        let resetGeneration: Int
        let resetReason: SwipeCellResetReason?
        let visibleSide: SwipeCellSide?
        let settlingSide: SwipeCellSide?
        let contentOffset: CGFloat

        init(
            inputs: SwipeCellInteractionInputs,
            visibleSide: SwipeCellSide?,
            settlingSide: SwipeCellSide?,
            contentOffset: CGFloat
        ) {
            let manager = inputs.manager
            self.cellID = inputs.cellID
            trackingStyle = inputs.configuration.motion.trackingStyle
            phase = manager?.phase
            activeCellID = manager?.activeCellID
            activeSide = manager?.activeSide
            resettingCellID = manager?.resettingCellID
            resetGeneration = manager?.resetGeneration ?? 0
            resetReason = manager?.lastResetReason
            self.visibleSide = visibleSide
            self.settlingSide = settlingSide
            self.contentOffset = contentOffset
        }

        var baseFields: [SwipeCellValidationDiagnostics.Field] {
            [
                .init("phase", phase),
                .init("active", activeCellID),
                .init("activeSide", activeSide),
                .init("resetting", resettingCellID),
                .init("resetGen", resetGeneration),
                .init("resetReason", resetReason),
                .init("visibleSide", visibleSide),
                .init("settlingSide", settlingSide),
            ]
        }
    }

    enum SwipeCellInteractionDiagnosticsEmitter {
        static func emitValidationEvent(
            _ event: String,
            snapshot: SwipeCellInteractionDiagnosticsSnapshot,
            verdict: SwipeCellValidationDiagnostics.Verdict? = nil,
            fields: [SwipeCellValidationDiagnostics.Field] = []
        ) {
            SwipeCellValidationDiagnostics.emit(
                event: event,
                cellID: snapshot.cellID,
                verdict: verdict,
                fields: snapshot.baseFields + fields
            )
        }

        static func emitHostLifecycle(
            event: String,
            snapshot: SwipeCellInteractionDiagnosticsSnapshot
        ) {
            emitValidationEvent(
                event,
                snapshot: snapshot,
                verdict: SwipeCellValidationDiagnostics.hostLifecycleVerdict(
                    event: event,
                    contentOffset: snapshot.contentOffset,
                    visibleSide: snapshot.visibleSide
                ),
                fields: [
                    .init("fromOffset", snapshot.contentOffset),
                    .init("visibleSide", snapshot.visibleSide),
                    .init("settlingSide", snapshot.settlingSide),
                ]
            )
        }

        static func emitInertStaleRelease(
            snapshot: SwipeCellInteractionDiagnosticsSnapshot
        ) {
            emitValidationEvent(
                "pan.ended",
                snapshot: snapshot,
                verdict: .suspect("stale-release-after-owner-replacement"),
                fields: [
                    .init("source", "release"),
                    .init("role", SwipeCellOffsetAnimationRole.releaseSettling),
                    .init("trackingStyle", snapshot.trackingStyle),
                    .init("fromOffset", snapshot.contentOffset),
                    .init("result", "inert"),
                ]
            )
        }

        static func emitSettleEvent(
            _ event: String,
            update: SwipeCellOffsetUpdate,
            snapshot: SwipeCellInteractionDiagnosticsSnapshot,
            source: String,
            animatedRequest: Bool,
            deferred: Bool,
            completion: Bool,
            fromOffset: CGFloat,
            visibleSideBefore: SwipeCellSide?,
            visibleSideAfter: SwipeCellSide?,
            settlingSideBefore: SwipeCellSide?,
            settlingSideAfter: SwipeCellSide?,
            ownsClosingSettle: Bool,
            settleElapsed: TimeInterval? = nil,
            resettingBeforeCompletion: AnyHashable? = nil,
            phaseAtApply: SwipeCellPhase? = nil,
            activeAtApply: AnyHashable? = nil,
            resetGenerationAtApply: Int? = nil,
            managerMutatedDuringSettle: Bool? = nil,
            closeDriver: SwipeCellForcedResetCloseDriver? = nil,
            closeEpoch: Int? = nil,
            terminalState: SwipeCellForcedResetCloseTerminalState? = nil,
            verdict: SwipeCellValidationDiagnostics.Verdict? = nil
        ) {
            var fields: [SwipeCellValidationDiagnostics.Field] = [
                .init("source", source),
                .init("role", update.animationRole),
                .init("fromOffset", fromOffset),
                .init("targetOffset", update.contentOffset),
                .init("visibleSideBefore", visibleSideBefore),
                .init("visibleSideAfter", visibleSideAfter),
                .init("settlingSideBefore", settlingSideBefore),
                .init("settlingSideAfter", settlingSideAfter),
                .init("ownsClosingSettle", ownsClosingSettle),
                .init("animatedRequest", animatedRequest),
                .init("deferred", deferred),
                .init("completion", completion),
                .init("trackingStyle", snapshot.trackingStyle),
            ]
            if let closeDriver {
                fields.append(.init("closeDriver", closeDriver.diagnosticString))
            }
            if let closeEpoch {
                fields.append(.init("closeEpoch", closeEpoch))
            }
            if let terminalState {
                fields.append(.init("terminalState", terminalState.diagnosticString))
            }
            if let settleElapsed {
                fields.append(.init("settleElapsed", settleElapsed))
            }
            if let resettingBeforeCompletion {
                fields.append(.init("resettingBeforeCompletion", resettingBeforeCompletion))
            }
            // Emitted together only when the apply-to-completion window was measured, so a sub-frame close
            // can be read against the manager state it started and ended the animation with.
            if let managerMutatedDuringSettle {
                fields.append(.init("phaseAtApply", phaseAtApply))
                fields.append(.init("activeAtApply", activeAtApply))
                fields.append(.init("resetGenAtApply", resetGenerationAtApply ?? 0))
                fields.append(.init("managerMutatedDuringSettle", managerMutatedDuringSettle))
            }

            emitValidationEvent(event, snapshot: snapshot, verdict: verdict, fields: fields)
        }

        static func emitDirectTouchRelease(
            snapshot: SwipeCellInteractionSnapshot,
            value: SwipeCellPanValue,
            model: SwipeCellInteractionModel,
            startSide: SwipeCellSide?,
            gestureStartTimestamp: TimeInterval?,
            contentOffset: CGFloat
        ) {
            guard model.motion.trackingStyle == .directTouch else { return }

            let sideConfiguration = model.configuration.sideConfiguration(for: snapshot.interactionSide)
            let actualTowardSide = SwipeCellInteractionGeometry.movement(
                value.translation.width,
                toward: snapshot.interactionSide
            )
            let predictedTowardSide = SwipeCellInteractionGeometry.movement(
                value.predictedEndTranslation.width,
                toward: snapshot.interactionSide
            )
            let predictionGain = predictedTowardSide - actualTowardSide
            let gestureElapsed = SwipeCellDirectTouchFastIntent.initialCompressionElapsed(
                gestureStartTimestamp: gestureStartTimestamp,
                sampleTimestamp: value.timestamp
            )
            let releaseTarget = snapshot.releaseTarget ?? .closed
            let targetOffset = snapshot.settlingTarget?.contentOffset ?? 0
            let referenceDistance = SwipeCellGestureReleaseResolver.referenceDistance(
                releaseTarget: releaseTarget,
                sideConfiguration: sideConfiguration,
                contentOffset: contentOffset,
                targetOffset: targetOffset
            )
            let settlePlan = SwipeCellGestureReleaseResolver.releaseSettlePlan(
                releaseVelocity: value.velocity,
                releaseTarget: releaseTarget,
                releaseClassification: snapshot.releaseClassification,
                contentOffset: contentOffset,
                targetOffset: targetOffset,
                referenceDistance: referenceDistance,
                motion: model.motion
            )
            let metrics = settlePlan.metrics

            SwipeCellDiagnostics.trace(
                .directTouch,
                event: "release",
                fields: [
                    .init("origin", startSide == nil ? "closed" : "open"),
                    .init("side", String(describing: snapshot.interactionSide)),
                    .init("translation", value.translation.width),
                    .init("predicted", value.predictedEndTranslation.width),
                    .init("actualMovement", snapshot.effectiveMovement),
                    .init("normalThreshold", sideConfiguration.normalOpenThreshold),
                    .init("openExtent", sideConfiguration.normalOpenExtent),
                    .init("actualTowardSide", actualTowardSide),
                    .init("predictedTowardSide", predictedTowardSide),
                    .init("predictionGain", predictionGain),
                    .init("velocityX", value.velocity.x),
                    .init("gestureElapsed", gestureElapsed),
                    .init("target", targetOffset),
                    .init("remaining", metrics.actualRemainingDistance),
                    .init("pacedRemaining", metrics.pacedRemainingDistance),
                    .init("reference", metrics.referenceDistance),
                    .init("releaseSpeed", metrics.releaseSpeed),
                    .init("settleDuration", metrics.settleDuration),
                    .init("thresholdLevel", String(describing: snapshot.thresholdLevel)),
                    .init("releaseTarget", snapshot.releaseTarget),
                    .init("classification", String(describing: snapshot.releaseClassification)),
                ]
            )
        }

        static func emitDirectTouchFastIntent(
            snapshot: SwipeCellInteractionSnapshot,
            value: SwipeCellPanValue,
            model: SwipeCellInteractionModel,
            startSide: SwipeCellSide?,
            gestureStartTimestamp: TimeInterval?,
            visibleMovement: CGFloat?,
            fastState: SwipeCellDirectTouchFastIntentDebugState
        ) {
            guard model.motion.trackingStyle == .directTouch else { return }

            let sideConfiguration = model.configuration.sideConfiguration(for: snapshot.interactionSide)
            let actualTowardSide = SwipeCellInteractionGeometry.movement(
                value.translation.width,
                toward: snapshot.interactionSide
            )
            let predictedTowardSide = SwipeCellInteractionGeometry.movement(
                value.predictedEndTranslation.width,
                toward: snapshot.interactionSide
            )
            let predictionGain = predictedTowardSide - actualTowardSide
            let gestureElapsed = SwipeCellDirectTouchFastIntent.initialCompressionElapsed(
                gestureStartTimestamp: gestureStartTimestamp,
                sampleTimestamp: value.timestamp
            )

            SwipeCellDiagnostics.trace(
                .directTouch,
                event: "fastIntent",
                fields: [
                    .init("origin", startSide == nil ? "closed" : "open"),
                    .init("phase", fastState.phase),
                    .init("isFastIntent", fastState.isFastIntent),
                    .init("isFastCandidate", fastState.isFastCandidate),
                    .init("side", String(describing: fastState.side ?? snapshot.interactionSide)),
                    .init("translation", value.translation.width),
                    .init("predicted", value.predictedEndTranslation.width),
                    .init("actualMovement", snapshot.effectiveMovement),
                    .init("visibleMovement", visibleMovement),
                    .init("visibleDebt", fastState.visibleDebt),
                    .init("lastVisibleMovement", fastState.lastVisibleMovement),
                    .init("lastRawMovement", fastState.lastRawMovement),
                    .init("normalThreshold", sideConfiguration.normalOpenThreshold),
                    .init("openExtent", sideConfiguration.normalOpenExtent),
                    .init("actualTowardSide", actualTowardSide),
                    .init("predictedTowardSide", predictedTowardSide),
                    .init("predictionGain", predictionGain),
                    .init("velocityX", value.velocity.x),
                    .init("gestureElapsed", gestureElapsed),
                    .init("sampleCount", fastState.sampleCount ?? 0),
                    .init("firstTimestamp", fastState.firstTimestamp),
                    .init("commitTimestamp", fastState.commitTimestamp),
                    .init("startVisibleMovement", fastState.startVisibleMovement),
                ]
            )
        }
    }
#endif
