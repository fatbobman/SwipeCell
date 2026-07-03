import CoreGraphics
import Foundation
import Testing

@testable import SwipeCell

#if DEBUG
    @MainActor
    @Suite("SwipeCell diagnostics")
    struct SwipeCellDiagnosticsTests {
        @Test("private diagnostics environment gates channels")
        func environmentGatesChannels() {
            #if DEBUG
                #expect(!SwipeCellDiagnostics.isEnabled(.warnings, environment: [:]))
                #expect(
                    SwipeCellDiagnostics.isEnabled(
                        .warnings,
                        environment: [SwipeCellDiagnostics.environmentKey: "warnings"]
                    )
                )
                #expect(
                    SwipeCellDiagnostics.isEnabled(
                        .layout,
                        environment: [SwipeCellDiagnostics.environmentKey: "warnings, layout"]
                    )
                )
                #expect(
                    SwipeCellDiagnostics.isEnabled(
                        .scrollFast,
                        environment: [SwipeCellDiagnostics.environmentKey: "scroll-fast"]
                    )
                )
                #expect(
                    SwipeCellDiagnostics.isEnabled(
                        .directTouch,
                        environment: [SwipeCellDiagnostics.environmentKey: "direct-touch"]
                    )
                )
                #expect(
                    SwipeCellDiagnostics.isEnabled(
                        .validation,
                        environment: [SwipeCellDiagnostics.environmentKey: "validation,direct-touch"]
                    )
                )
                #expect(
                    SwipeCellDiagnostics.isEnabled(
                        .layout,
                        environment: [SwipeCellDiagnostics.environmentKey: SwipeCellDiagnostics.allSelector]
                    )
                )
                #expect(
                    SwipeCellDiagnostics.isEnabled(
                        .validation,
                        environment: [SwipeCellDiagnostics.environmentKey: SwipeCellDiagnostics.allSelector]
                    )
                )
            #else
                #expect(
                    !SwipeCellDiagnostics.isEnabled(
                        .warnings,
                        environment: [SwipeCellDiagnostics.environmentKey: SwipeCellDiagnostics.allSelector]
                    )
                )
            #endif
        }

        @Test("unknown diagnostics environment keys do not enable channels")
        func unknownDiagnosticsEnvironmentKeysDoNotEnableChannels() {
            #if DEBUG
                let environment = ["UNRELATED_DEBUG_SWITCH": "true"]

                for channel in SwipeCellDiagnostics.Channel.allCases {
                    #expect(!SwipeCellDiagnostics.isEnabled(channel, environment: environment))
                }
            #else
                #expect(!SwipeCellDiagnostics.isEnabled(.directTouch, environment: ["UNRELATED_DEBUG_SWITCH": "true"]))
            #endif
        }

        @Test("diagnostics event formatter keeps stable key-value fields")
        func diagnosticsEventFormatterKeepsStableKeyValueFields() {
            let message = SwipeCellDiagnostics.message(
                event: "MEASURE SETTLE",
                fields: [
                    .init("row id", "row A"),
                    .init("active", true),
                    .init("dx", CGFloat(1.235), precision: 2),
                    .init("ts", TimeInterval?.none),
                ]
            )

            #expect(message == "event=MEASURE_SETTLE row_id=row_A active=1 dx=1.24 ts=nil")
        }

        @Test("scroll measure snapshot formats through diagnostics fields")
        func scrollMeasureSnapshotFormatsThroughDiagnosticsFields() {
            #if DEBUG
                let snapshot = SwipeCellScrollWheelMeasureDiagnosticsSnapshot(
                    isActive: true,
                    mode: "reveal",
                    side: "leading",
                    referenceRevealDistance: 48,
                    slowReferenceRevealDistance: 24,
                    adaptiveLowerDelta: 20,
                    adaptiveUpperDelta: 40,
                    maxProgressStep: 0.2,
                    minStartDelta: 1,
                    fastIntentRequiredDistance: 12,
                    fastReleaseOpenCommitRatio: 0.85,
                    fastIntentWindowDistance: 18,
                    fastIntentSampleCount: 2,
                    isSingleFastIntentSample: false,
                    hasFastIntent: true,
                    fastIntentStartAge: 0.12,
                    fastIntentTriggerAge: nil,
                    fastIntentCommitDistance: 41,
                    fastIntentCommitThreshold: 48,
                    visualProgress: 0.8,
                    uncappedVisualProgress: 1.1,
                    fastReferenceProgress: 0.9,
                    uncappedFastReferenceProgress: 1.2,
                    releaseBypassesNormalReleaseThreshold: true,
                    hasObservedIndirectTouchPresence: true,
                    isIndirectTouchPresenceActive: false,
                    hasLatchedDestructiveArm: true
                )

                let message = SwipeCellDiagnostics.message(
                    event: "MEASURE",
                    fields: SwipeCellDiagnostics.fields(for: snapshot)
                )

                #expect(message.contains("active=1"))
                #expect(message.contains("side=leading"))
                #expect(message.contains("dFast=48.000"))
                #expect(message.contains("releaseBypass=1"))
                #expect(message.contains("touchActive=0"))
            #else
                #expect(!SwipeCellDiagnostics.isEnabled(.measure, environment: [:]))
            #endif
        }

        @Test("warning diagnostics emit once per stable key")
        func warningDiagnosticsEmitOncePerStableKey() {
            var registry = SwipeCellDiagnosticsRegistry()
            let firstOverflow = registry.shouldEmitOnce(key: "action-overflow")
            let repeatedOverflow = registry.shouldEmitOnce(key: "action-overflow")
            let rowIDMismatch = registry.shouldEmitOnce(key: "row-id-mismatch")

            #expect(firstOverflow)
            #expect(!repeatedOverflow)
            #expect(rowIDMismatch)
        }

        @Test("layout diagnostics throttle independently by key")
        func layoutDiagnosticsThrottleIndependentlyByKey() {
            var registry = SwipeCellDiagnosticsRegistry()
            let firstWidth = registry.shouldEmitThrottled(key: "width", timestamp: 10, interval: 1)
            let repeatedWidth = registry.shouldEmitThrottled(key: "width", timestamp: 10.5, interval: 1)
            let nextWidthWindow = registry.shouldEmitThrottled(key: "width", timestamp: 11, interval: 1)
            let separateKey = registry.shouldEmitThrottled(key: "fit", timestamp: 10.5, interval: 1)

            #expect(firstWidth)
            #expect(!repeatedWidth)
            #expect(nextWidthWindow)
            #expect(separateKey)
        }

        @Test("validation messages keep sortable key-value fields")
        func validationMessagesKeepSortableKeyValueFields() {
            let message = SwipeCellValidationDiagnostics.message(
                seq: 104,
                time: 12.3456,
                cell: "row A",
                cycle: 12,
                event: "settle.complete",
                verdict: .ok("animated-close"),
                fields: [
                    .init("source", "reset-token"),
                    .init("role", SwipeCellOffsetAnimationRole.forcedReset),
                    .init("fromOffset", CGFloat(-72)),
                    .init("targetOffset", CGFloat(0)),
                    .init("visibleSideAfter", SwipeCellSide?.none),
                ]
            )

            #expect(
                message
                    == "seq=104 time=12.346 cell=row_A cycle=12 verdict=ok:animated-close event=settle.complete source=reset-token role=forcedReset fromOffset=-72.000 targetOffset=0.000 visibleSideAfter=nil"
            )
        }

        @Test("validation verdicts classify animated and immediate closes")
        func validationVerdictsClassifyAnimatedAndImmediateCloses() {
            let animatedClose = SwipeCellValidationDiagnostics.settleCompletionVerdict(
                animatedRequest: true,
                fromOffset: -72,
                targetOffset: 0,
                role: .forcedReset,
                ownsClosingSettle: true
            )
            let immediateClose = SwipeCellValidationDiagnostics.settleCompletionVerdict(
                animatedRequest: false,
                fromOffset: 72,
                targetOffset: 0,
                role: .forcedReset,
                ownsClosingSettle: false
            )
            let jumpedClose = SwipeCellValidationDiagnostics.settleApplyVerdict(
                animatedRequest: true,
                fromOffset: -72,
                targetOffset: 0,
                role: .forcedReset,
                ownsClosingSettle: false
            )

            #expect(animatedClose == .ok("animated-close"))
            #expect(immediateClose == .ok("immediate-close-requested"))
            #expect(jumpedClose == .suspect("animated-reset-jumped-to-zero"))
        }

        @Test("validation verdicts flag animated closes completing within one frame")
        func validationVerdictsFlagAnimatedClosesCompletingWithinOneFrame() {
            let immediateAnimatedClose = SwipeCellValidationDiagnostics.immediateAnimatedSettleVerdict(
                animatedRequest: true,
                fromOffset: 72,
                targetOffset: 0,
                role: .forcedReset,
                ownsClosingSettle: true,
                settleElapsed: 0.002
            )
            let visibleAnimatedClose = SwipeCellValidationDiagnostics.immediateAnimatedSettleVerdict(
                animatedRequest: true,
                fromOffset: 72,
                targetOffset: 0,
                role: .forcedReset,
                ownsClosingSettle: true,
                settleElapsed: 0.2
            )
            let nonOwnerClose = SwipeCellValidationDiagnostics.immediateAnimatedSettleVerdict(
                animatedRequest: true,
                fromOffset: 72,
                targetOffset: 0,
                role: .forcedReset,
                ownsClosingSettle: false,
                settleElapsed: 0.002
            )

            #expect(immediateAnimatedClose == .suspect("unexpected-immediate-reset"))
            #expect(visibleAnimatedClose == nil)
            #expect(nonOwnerClose == nil)
        }

        @Test("validation detects a shared manager mutation during an animated settle window")
        func validationDetectsManagerMutationDuringSettleWindow() {
            // The captured suspect: the old owner's close applies while its row is still `revealing` and a new
            // owner reaches `open(leading)` before completion — the cross-cell mutation that collapses the
            // in-flight offset animation into a sub-frame completion.
            let ownerOpenedMidClose = SwipeCellValidationDiagnostics.managerMutatedDuringSettle(
                phaseAtApply: .revealing,
                activeAtApply: AnyHashable(114),
                resetGenerationAtApply: 2,
                phaseAtCompletion: .open(.leading),
                activeAtCompletion: AnyHashable(114),
                resetGenerationAtCompletion: 2
            )
            // An uninterrupted close ends the window with the same manager identity it started with.
            let quietWindow = SwipeCellValidationDiagnostics.managerMutatedDuringSettle(
                phaseAtApply: .resetting(.replacedByAnotherCell),
                activeAtApply: AnyHashable(114),
                resetGenerationAtApply: 2,
                phaseAtCompletion: .resetting(.replacedByAnotherCell),
                activeAtCompletion: AnyHashable(114),
                resetGenerationAtCompletion: 2
            )
            // A foreign reset landing mid-window flips the active owner and bumps the reset generation.
            let foreignResetMidClose = SwipeCellValidationDiagnostics.managerMutatedDuringSettle(
                phaseAtApply: .revealing,
                activeAtApply: AnyHashable(114),
                resetGenerationAtApply: 2,
                phaseAtCompletion: .revealing,
                activeAtCompletion: AnyHashable(116),
                resetGenerationAtCompletion: 3
            )

            #expect(ownerOpenedMidClose)
            #expect(!quietWindow)
            #expect(foreignResetMidClose)
        }

        @Test("validation verdicts flag visible side loss while closing")
        func validationVerdictsFlagVisibleSideLossWhileClosing() {
            let verdict = SwipeCellValidationDiagnostics.visibleSideVerdict(
                fromOffset: -48,
                targetOffset: 0,
                visibleSideBefore: .trailing,
                visibleSideAfter: nil,
                settlingSideAfter: nil
            )
            let stable = SwipeCellValidationDiagnostics.visibleSideVerdict(
                fromOffset: -48,
                targetOffset: 0,
                visibleSideBefore: .trailing,
                visibleSideAfter: .trailing,
                settlingSideAfter: .trailing
            )

            #expect(verdict == .suspect("visible-side-lost-while-closing"))
            #expect(stable == nil)
        }

        @Test("validation verdicts flag release settle completion after owner replacement")
        func validationVerdictsFlagReleaseSettleCompletionAfterOwnerReplacement() {
            let staleRelease = SwipeCellValidationDiagnostics.staleReleaseVerdict(
                source: "release",
                role: .releaseSettling,
                targetOffset: 72,
                cellID: 115,
                activeCellID: AnyHashable(114)
            )
            let currentOwnerRelease = SwipeCellValidationDiagnostics.staleReleaseVerdict(
                source: "release",
                role: .releaseSettling,
                targetOffset: 72,
                cellID: 115,
                activeCellID: AnyHashable(115)
            )
            let closingResetToken = SwipeCellValidationDiagnostics.staleReleaseVerdict(
                source: "reset-token",
                role: .forcedReset,
                targetOffset: 0,
                cellID: 115,
                activeCellID: AnyHashable(114)
            )

            #expect(staleRelease == .suspect("stale-release-after-owner-replacement"))
            #expect(currentOwnerRelease == nil)
            #expect(closingResetToken == nil)
        }

        @Test("validation verdicts flag resetting owner cleared outside visible reset completion")
        func validationVerdictsFlagResettingOwnerClearedOutsideVisibleResetCompletion() {
            let clearedByNewBegin = SwipeCellValidationDiagnostics.resettingOwnerClearedVerdict(
                event: "manager.beginInteraction",
                resettingBefore: AnyHashable(114),
                resettingAfter: nil
            )
            let completedVisibleReset = SwipeCellValidationDiagnostics.resettingOwnerClearedVerdict(
                event: "manager.completeVisibleReset",
                resettingBefore: AnyHashable(114),
                resettingAfter: nil
            )
            let stillResetting = SwipeCellValidationDiagnostics.resettingOwnerClearedVerdict(
                event: "manager.beginInteraction",
                resettingBefore: AnyHashable(114),
                resettingAfter: AnyHashable(114)
            )

            #expect(clearedByNewBegin == .suspect("resetting-owner-cleared-before-local-complete"))
            #expect(completedVisibleReset == nil)
            #expect(stillResetting == nil)
        }

        @Test("validation verdicts flag reset-token settle after resetting owner context is gone")
        func validationVerdictsFlagResetTokenSettleAfterResettingOwnerContextIsGone() {
            let lostResettingOwner = SwipeCellValidationDiagnostics.resetTokenSettleVerdict(
                source: "reset-token",
                role: .forcedReset,
                fromOffset: -144,
                targetOffset: 0,
                cellID: 115,
                activeCellID: AnyHashable(114),
                resettingCellID: nil
            )
            let retainedResettingOwner = SwipeCellValidationDiagnostics.resetTokenSettleVerdict(
                source: "reset-token",
                role: .forcedReset,
                fromOffset: -144,
                targetOffset: 0,
                cellID: 115,
                activeCellID: AnyHashable(114),
                resettingCellID: AnyHashable(115)
            )
            let sameActiveOwner = SwipeCellValidationDiagnostics.resetTokenSettleVerdict(
                source: "reset-token",
                role: .forcedReset,
                fromOffset: -144,
                targetOffset: 0,
                cellID: 115,
                activeCellID: AnyHashable(115),
                resettingCellID: nil
            )

            #expect(lostResettingOwner == .suspect("resetting-owner-cleared-before-local-complete"))
            #expect(retainedResettingOwner == nil)
            #expect(sameActiveOwner == nil)
        }
    }
#else
    @MainActor
    @Suite("SwipeCell release diagnostics")
    struct SwipeCellDiagnosticsReleaseTests {
        @Test("release diagnostics gates remain disabled")
        func releaseDiagnosticsGatesRemainDisabled() {
            #expect(!SwipeCellDiagnostics.isEnabled(.warnings))
            #expect(!SwipeCellDiagnostics.isEnabled(.directTouch, environment: ["UNRELATED_DEBUG_SWITCH": "true"]))
        }
    }
#endif
