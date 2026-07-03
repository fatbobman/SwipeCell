import CoreGraphics
import Foundation
import Testing

@_spi(ManualDebug) @testable import SwipeCell

@MainActor
@Suite("SwipeCell interaction model")
struct SwipeCellInteractionModelTests {
    @Test("dragging below normal threshold carries side and progress")
    func draggingBelowNormalThreshold() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 30,
            pointerActive: true
        )

        #expect(snapshot.pointerActive == true)
        #expect(snapshot.interactionSide == .leading)
        #expect(snapshot.translationWidth == 30)
        #expect(snapshot.activeOffset == 30)
        #expect(snapshot.effectiveMovement == 30)
        #expect(abs(snapshot.normalOpenProgress - 0.3) < 0.0001)
        #expect(snapshot.deformationProgress == 0)
        #expect(snapshot.isArmed == false)
        #expect(snapshot.thresholdLevel == .belowNormal)
        #expect(snapshot.releaseTarget == nil)
        #expect(snapshot.settlingTarget == nil)
    }

    @Test("dragging at normal threshold becomes open-ready")
    func draggingAtNormalThreshold() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 50,
            pointerActive: true
        )

        #expect(snapshot.thresholdLevel == .normalOpen)
        #expect(abs(snapshot.normalOpenProgress - 0.5) < 0.0001)
        #expect(snapshot.deformationProgress == 0)
        #expect(snapshot.isArmed == false)
    }

    @Test("dragging beyond normal threshold before destructive threshold is distinct")
    func draggingBeyondNormalBeforeDestructive() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 125,
            pointerActive: true
        )

        #expect(snapshot.thresholdLevel == .betweenNormalAndDestructive)
        #expect(snapshot.normalOpenProgress == 1)
        #expect(snapshot.deformationProgress == 0.5)
        #expect(snapshot.isArmed == false)
    }

    @Test("dragging at destructive threshold becomes destructive-ready")
    func draggingAtDestructiveThreshold() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 150,
            pointerActive: true
        )

        #expect(snapshot.thresholdLevel == .destructive)
        #expect(snapshot.normalOpenProgress == 1)
        #expect(snapshot.deformationProgress == 1)
        #expect(snapshot.isArmed == true)
    }

    @Test("destructive progress clamps after destructive threshold")
    func destructiveProgressClampsAfterDestructiveThreshold() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 240,
            pointerActive: true
        )

        #expect(snapshot.thresholdLevel == .destructive)
        #expect(snapshot.deformationProgress == 1)
        #expect(snapshot.isArmed == true)
    }

    @Test("release below normal threshold settles closed")
    func releaseBelowNormalThresholdSettlesClosed() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 49,
            pointerActive: false
        )

        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.settlingTarget?.releaseTarget == .closed)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("indirect release ignores projected movement below normal threshold")
    func indirectReleaseIgnoresProjectedMovementBelowNormalThreshold() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            ),
            motion: SwipeCellConfiguration.macOSDefault.motion
        )

        let snapshot = model.snapshot(
            startSide: nil,
            translationWidth: 30,
            predictedEndTranslationWidth: 60,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 30)
        #expect(snapshot.thresholdLevel == .belowNormal)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("direct-touch fast flick uses same-side prediction to open")
    func directTouchFastFlickUsesSameSidePredictionToOpen() {
        // Case: IOS-OPEN-FAST
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 30,
            predictedEndTranslationWidth: 60,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 30)
        #expect(snapshot.thresholdLevel == .normalOpen)
        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.releaseClassification == .automaticOpen)
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("direct-touch slow drag below normal threshold ignores shallow prediction")
    func directTouchSlowDragBelowNormalThresholdIgnoresShallowPrediction() {
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 45,
            predictedEndTranslationWidth: 52,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 45)
        #expect(snapshot.thresholdLevel == .belowNormal)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.releaseClassification == .standard)
    }

    @Test("direct-touch minimal fast flick uses prediction to open")
    func directTouchMinimalFastFlickUsesPredictionToOpen() {
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 1,
            predictedEndTranslationWidth: 80,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 1)
        #expect(snapshot.thresholdLevel == .normalOpen)
        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.releaseClassification == .automaticOpen)
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("direct-touch zero movement prediction stays closed")
    func directTouchZeroMovementPredictionStaysClosed() {
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 0,
            predictedEndTranslationWidth: 80,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 0)
        #expect(snapshot.thresholdLevel == .belowNormal)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.releaseClassification == .standard)
    }

    @Test("active drag ignores projected threshold movement")
    func activeDragIgnoresProjectedThresholdMovement() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            )
        )

        let snapshot = model.snapshot(
            startSide: nil,
            translationWidth: 30,
            predictedEndTranslationWidth: 60,
            pointerActive: true
        )

        #expect(snapshot.activeOffset == 30)
        #expect(snapshot.thresholdLevel == .belowNormal)
        #expect(snapshot.releaseTarget == nil)
        #expect(abs(snapshot.normalOpenProgress - 0.3) < 0.0001)
    }

    @Test("release ignores opposite projected movement")
    func releaseIgnoresOppositeProjectedMovement() {
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 30,
            predictedEndTranslationWidth: -80,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .leading)
        #expect(snapshot.thresholdLevel == .belowNormal)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.releaseClassification == .standard)
    }

    @Test("release at normal threshold settles to open target")
    func releaseAtNormalThresholdSettlesOpen() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 50,
            pointerActive: false
        )

        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.releaseClassification == .standard)
        #expect(snapshot.settlingTarget?.releaseTarget == .open(.leading))
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("release uses actual movement over normal threshold")
    func releaseUsesActualMovementOverNormalThreshold() {
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 60,
            predictedEndTranslationWidth: 30,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 60)
        #expect(snapshot.thresholdLevel == .normalOpen)
        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.releaseClassification == .standard)
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("direct-touch heavy fast flick over normal threshold keeps automatic-open classification")
    func directTouchHeavyFastFlickOverNormalThresholdKeepsAutomaticOpenClassification() {
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 70,
            predictedEndTranslationWidth: 105,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 70)
        #expect(snapshot.thresholdLevel == .normalOpen)
        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.releaseClassification == .automaticOpen)
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("direct-touch rubber-banded fast flick past open extent keeps automatic-open classification")
    func directTouchRubberBandedFastFlickPastOpenExtentKeepsAutomaticOpenClassification() {
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 122,
            predictedEndTranslationWidth: 950,
            pointerActive: false
        )

        #expect(abs(snapshot.effectiveMovement - 102.64) < 0.0001)
        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.releaseClassification == .automaticOpen)
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("direct-touch slow drag over normal threshold stays a manual commit")
    func directTouchSlowDragOverNormalThresholdStaysManualCommit() {
        // Case: IOS-OPEN-SLOW
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 70,
            predictedEndTranslationWidth: 78,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 70)
        #expect(snapshot.thresholdLevel == .normalOpen)
        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.releaseClassification == .standard)
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("direct-touch fast release at open endpoint stays standard")
    func directTouchFastReleaseAtOpenEndpointStaysStandard() {
        let snapshot = directTouchModel.snapshot(
            startSide: nil,
            translationWidth: 100,
            predictedEndTranslationWidth: 108,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 100)
        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.releaseClassification == .standard)
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("direct-touch open-origin actual close threshold wins over open prediction")
    func directTouchOpenOriginActualCloseThresholdWinsOverOpenPrediction() {
        let snapshot = directTouchModel.snapshot(
            startSide: .trailing,
            translationWidth: 60,
            predictedEndTranslationWidth: -240,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -40)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("direct-touch open-origin partial close restores open")
    func directTouchOpenOriginPartialCloseRestoresOpen() {
        let snapshot = directTouchModel.snapshot(
            startSide: .trailing,
            translationWidth: 40,
            predictedEndTranslationWidth: 40,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -60)
        #expect(snapshot.releaseTarget == .open(.trailing))
        #expect(snapshot.settlingTarget?.contentOffset == -100)
    }

    @Test("direct-touch fast close uses reset prediction")
    func directTouchFastCloseUsesResetPrediction() {
        // Case: IOS-CLOSE-FAST
        let snapshot = directTouchModel.snapshot(
            startSide: .trailing,
            translationWidth: 30,
            predictedEndTranslationWidth: 70,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -70)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.releaseClassification == .automaticClose)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("direct-touch minimal fast close uses reset prediction")
    func directTouchMinimalFastCloseUsesResetPrediction() {
        let snapshot = directTouchModel.snapshot(
            startSide: .trailing,
            translationWidth: 1,
            predictedEndTranslationWidth: 80,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -99)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.releaseClassification == .automaticClose)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("direct-touch zero movement close prediction restores open")
    func directTouchZeroMovementClosePredictionRestoresOpen() {
        let snapshot = directTouchModel.snapshot(
            startSide: .trailing,
            translationWidth: 0,
            predictedEndTranslationWidth: 80,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -100)
        #expect(snapshot.releaseTarget == .open(.trailing))
        #expect(snapshot.settlingTarget?.contentOffset == -100)
    }

    @Test("indirect release hint opens below normal threshold")
    func indirectReleaseHintOpensBelowNormalThreshold() {
        let snapshot = indirectScrollModel.snapshot(
            startSide: nil,
            translationWidth: 20,
            bypassesNormalReleaseThreshold: true,
            pointerActive: false
        )

        #expect(snapshot.activeOffset == 20)
        #expect(snapshot.thresholdLevel == .normalOpen)
        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("indirect open-origin partial close restores open below threshold")
    func indirectOpenOriginPartialCloseRestoresOpenBelowThreshold() {
        let snapshot = indirectScrollModel.snapshot(
            startSide: .trailing,
            translationWidth: 40,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -60)
        #expect(snapshot.releaseTarget == .open(.trailing))
        #expect(snapshot.settlingTarget?.contentOffset == -100)
    }

    @Test("indirect open-origin actual close threshold closes")
    func indirectOpenOriginActualCloseThresholdCloses() {
        let snapshot = indirectScrollModel.snapshot(
            startSide: .trailing,
            translationWidth: 50,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -50)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("indirect open-origin release hint closes below threshold")
    func indirectOpenOriginReleaseHintClosesBelowThreshold() {
        let snapshot = indirectScrollModel.snapshot(
            startSide: .trailing,
            translationWidth: 20,
            bypassesNormalReleaseThreshold: true,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -80)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("direct-touch partial close ignores open-direction prediction")
    func directTouchPartialCloseIgnoresOpenDirectionPrediction() {
        let snapshot = directTouchModel.snapshot(
            startSide: .trailing,
            translationWidth: 30,
            predictedEndTranslationWidth: -80,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.activeOffset == -70)
        #expect(snapshot.releaseTarget == .open(.trailing))
        #expect(snapshot.settlingTarget?.contentOffset == -100)
    }

    @Test("direct-touch fast open-origin close is classified separately")
    func directTouchFastOpenOriginCloseIsClassifiedSeparately() {
        let snapshot = directTouchModel.snapshot(
            startSide: .trailing,
            translationWidth: 122,
            predictedEndTranslationWidth: 950,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.releaseClassification == .automaticClose)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("direct-touch manual open-origin close stays standard")
    func directTouchManualOpenOriginCloseStaysStandard() {
        // Case: IOS-CLOSE-MANUAL
        let snapshot = directTouchModel.snapshot(
            startSide: .trailing,
            translationWidth: 60,
            predictedEndTranslationWidth: 60,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.releaseTarget == .closed)
        #expect(snapshot.releaseClassification == .standard)
        #expect(snapshot.settlingTarget?.contentOffset == 0)
    }

    @Test("release ignores projected movement for destructive activation")
    func releaseIgnoresProjectedMovementForDestructiveActivation() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: -100,
            predictedEndTranslationWidth: -160,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.thresholdLevel == .betweenNormalAndDestructive)
        #expect(snapshot.releaseTarget == .open(.trailing))
        #expect(snapshot.releaseClassification == .standard)
        #expect(snapshot.settlingTarget?.contentOffset == -100)
    }

    @Test("release projection cannot enter destructive band")
    func releaseProjectionCannotEnterDestructiveBand() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: -80,
            predictedEndTranslationWidth: -180,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.thresholdLevel == .normalOpen)
        #expect(snapshot.deformationProgress == 0)
        #expect(snapshot.isArmed == false)
        #expect(snapshot.releaseTarget == .open(.trailing))
        #expect(snapshot.settlingTarget?.contentOffset == -100)
    }

    @Test("release at destructive threshold settles to destructive target")
    func releaseAtDestructiveThresholdSettlesDestructive() {
        // Case: IOS-DESTRUCT-RELEASE
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: -150,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .trailing)
        #expect(snapshot.releaseTarget == .destructive(.trailing))
        #expect(snapshot.releaseClassification == .standard)
        #expect(snapshot.settlingTarget?.releaseTarget == .destructive(.trailing))
        #expect(snapshot.settlingTarget?.contentOffset == -180)
    }

    @Test("open-side reverse drag can close but cannot cross-open opposite side")
    func openSideReverseDragCanCloseWithoutCrossOpen() {
        let trailingSnapshot = destructiveModel.snapshot(
            startSide: .trailing,
            translationWidth: 120,
            pointerActive: false
        )
        let leadingSnapshot = destructiveModel.snapshot(
            startSide: .leading,
            translationWidth: -120,
            pointerActive: false
        )

        #expect(trailingSnapshot.interactionSide == .trailing)
        #expect(trailingSnapshot.activeOffset == 0)
        #expect(trailingSnapshot.releaseTarget == .closed)
        #expect(leadingSnapshot.interactionSide == .leading)
        #expect(leadingSnapshot.activeOffset == 0)
        #expect(leadingSnapshot.releaseTarget == .closed)
    }

    @Test("open-origin close seed uses current movement and restores clean open below threshold")
    func openOriginCloseSeedUsesCurrentMovement() {
        let active = destructiveModel.snapshot(
            startSide: .trailing,
            translationWidth: 40,
            openOriginMovement: 180,
            pointerActive: true
        )
        let released = destructiveModel.snapshot(
            startSide: .trailing,
            translationWidth: 40,
            openOriginMovement: 180,
            pointerActive: false
        )

        #expect(active.activeOffset == -140)
        #expect(active.effectiveMovement == 140)
        #expect(active.normalOpenProgress == 1)
        #expect(abs(active.deformationProgress - 0.8) < 0.0001)
        #expect(active.isArmed == false)
        #expect(released.releaseTarget == .open(.trailing))
        #expect(released.settlingTarget?.contentOffset == -100)
    }

    @Test("partial open-origin close seed moves monotonically toward closed")
    func partialOpenOriginCloseSeedMovesTowardClosed() {
        let active = destructiveModel.snapshot(
            startSide: .trailing,
            translationWidth: 15,
            openOriginMovement: 40,
            pointerActive: true
        )
        let pastClosed = destructiveModel.snapshot(
            startSide: .trailing,
            translationWidth: 100,
            openOriginMovement: 40,
            pointerActive: false
        )

        #expect(active.activeOffset == -25)
        #expect(active.effectiveMovement == 25)
        #expect(abs(active.normalOpenProgress - 0.25) < 0.0001)
        #expect(pastClosed.activeOffset == 0)
        #expect(pastClosed.releaseTarget == .closed)
    }

    @Test("same-side drag from an open side remains open")
    func sameSideDragFromOpenSideRemainsOpen() {
        let trailingSnapshot = destructiveModel.snapshot(
            startSide: .trailing,
            translationWidth: -1,
            pointerActive: false
        )
        let leadingSnapshot = destructiveModel.snapshot(
            startSide: .leading,
            translationWidth: 1,
            pointerActive: false
        )

        #expect(trailingSnapshot.releaseTarget == .open(.trailing))
        #expect(trailingSnapshot.settlingTarget?.contentOffset == -100)
        #expect(leadingSnapshot.releaseTarget == .open(.leading))
        #expect(leadingSnapshot.settlingTarget?.contentOffset == 100)
    }

    @Test("locked fresh gesture stays on its committed side when reversing")
    func lockedFreshGestureStaysOnCommittedSideWhenReversing() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            )
        )

        // Committed to leading on the first frame, then the finger reverses past the origin.
        let reversing = model.snapshot(
            startSide: nil,
            lockedSide: .leading,
            translationWidth: -80,
            pointerActive: true
        )

        #expect(reversing.interactionSide == .leading)
        #expect(reversing.activeOffset == 0)
        #expect(reversing.effectiveMovement == 0)
        #expect(reversing.normalOpenProgress == 0)

        // The same gesture dragging back toward its own side reopens normally.
        let sameSide = model.snapshot(
            startSide: nil,
            lockedSide: .leading,
            translationWidth: 70,
            pointerActive: true
        )

        #expect(sameSide.interactionSide == .leading)
        #expect(sameSide.activeOffset == 70)
    }

    @Test("locked fresh gesture releases closed instead of opening the opposite side")
    func lockedFreshGestureReleasesClosedInsteadOfOpeningOppositeSide() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            )
        )

        let snapshot = model.snapshot(
            startSide: nil,
            lockedSide: .leading,
            translationWidth: -120,
            predictedEndTranslationWidth: -200,
            pointerActive: false
        )

        #expect(snapshot.interactionSide == .leading)
        #expect(snapshot.releaseTarget == .closed)
    }

    @Test("unlocked fresh gesture still tracks the drag direction")
    func unlockedFreshGestureStillTracksDragDirection() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            )
        )

        let leading = model.snapshot(startSide: nil, translationWidth: 60, pointerActive: true)
        let trailing = model.snapshot(startSide: nil, translationWidth: -60, pointerActive: true)

        #expect(leading.interactionSide == .leading)
        #expect(leading.activeOffset == 60)
        #expect(trailing.interactionSide == .trailing)
        #expect(trailing.activeOffset == -60)
    }

    @Test("non-destructive side never reports destructive states")
    func nonDestructiveSideNeverReportsDestructiveStates() {
        let model = SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: destructiveSide,
                trailing: SwipeCellInteractionSideConfiguration(
                    normalOpenExtent: 100,
                    normalOpenThreshold: 50,
                    allowsDestructive: false,
                    destructiveThreshold: 150,
                    destructiveSettlingExtent: 180
                )
            )
        )

        let activeSnapshot = model.snapshot(
            startSide: nil,
            translationWidth: -180,
            pointerActive: true
        )
        let releasedSnapshot = model.snapshot(
            startSide: nil,
            translationWidth: -180,
            pointerActive: false
        )

        #expect(activeSnapshot.thresholdLevel == .normalOpen)
        #expect(activeSnapshot.normalOpenProgress == 1)
        #expect(activeSnapshot.deformationProgress == 0)
        #expect(activeSnapshot.isArmed == false)
        #expect(releasedSnapshot.releaseTarget == .open(.trailing))
        #expect(releasedSnapshot.deformationProgress == 0)
        #expect(releasedSnapshot.isArmed == false)
        #expect(releasedSnapshot.settlingTarget?.contentOffset == -100)
    }

    @Test("normal open progress clamps to normal extent")
    func normalOpenProgressClampsToNormalExtent() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            )
        )

        let partial = model.snapshot(startSide: nil, translationWidth: 30, pointerActive: true)
        let exact = model.snapshot(startSide: nil, translationWidth: 100, pointerActive: true)
        let beyond = model.snapshot(startSide: nil, translationWidth: 110, pointerActive: true)

        #expect(abs(partial.normalOpenProgress - 0.3) < 0.0001)
        #expect(exact.normalOpenProgress == 1)
        #expect(beyond.normalOpenProgress == 1)
    }

    @Test("active drag soft clamps independently by side extent")
    func activeDragSoftClampsIndependentlyBySideExtent() {
        let model = SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: SwipeCellInteractionSideConfiguration(
                    normalOpenExtent: 100,
                    normalOpenThreshold: 50
                ),
                trailing: SwipeCellInteractionSideConfiguration(
                    normalOpenExtent: 180,
                    normalOpenThreshold: 90
                )
            )
        )

        let leading = model.snapshot(startSide: nil, translationWidth: 500, pointerActive: true)
        let trailing = model.snapshot(startSide: nil, translationWidth: -500, pointerActive: true)

        #expect(leading.effectiveMovement == 136)
        #expect(leading.activeOffset == 136)
        #expect(trailing.effectiveMovement == 216)
        #expect(trailing.activeOffset == -216)
    }

    @Test("destructive active drag soft clamps to destructive settling extent")
    func destructiveActiveDragSoftClampsToDestructiveSettlingExtent() {
        let destructiveSide = SwipeCellInteractionSideConfiguration(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            allowsDestructive: true,
            destructiveThreshold: 180,
            destructiveSettlingExtent: 300
        )
        let model = SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: destructiveSide,
                trailing: destructiveSide
            )
        )

        let snapshot = model.snapshot(startSide: nil, translationWidth: 500, pointerActive: true)

        #expect(snapshot.effectiveMovement == 324)
        #expect(snapshot.activeOffset == 324)
        #expect(snapshot.thresholdLevel == .destructive)
        #expect(snapshot.deformationProgress == 1)
    }

    @Test("open-side same direction drag also soft clamps")
    func openSideSameDirectionDragAlsoSoftClamps() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            )
        )

        let snapshot = model.snapshot(
            startSide: .leading,
            translationWidth: 500,
            pointerActive: true
        )

        #expect(snapshot.effectiveMovement == 136)
        #expect(snapshot.activeOffset == 136)
    }

    @Test("disabled or zero-extent side reports no progress or open target")
    func disabledOrZeroExtentSideReportsNoProgressOrOpenTarget() {
        // Case: EMPTY-DISABLED-SIDE
        let model = SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: .disabled,
                trailing: SwipeCellInteractionSideConfiguration(normalOpenExtent: 0)
            )
        )

        let leadingSnapshot = model.snapshot(
            startSide: nil,
            translationWidth: 80,
            pointerActive: false
        )
        let trailingSnapshot = model.snapshot(
            startSide: nil,
            translationWidth: -80,
            pointerActive: false
        )

        #expect(leadingSnapshot.normalOpenProgress == 0)
        #expect(leadingSnapshot.thresholdLevel == .belowNormal)
        #expect(leadingSnapshot.releaseTarget == .closed)
        #expect(trailingSnapshot.normalOpenProgress == 0)
        #expect(trailingSnapshot.thresholdLevel == .belowNormal)
        #expect(trailingSnapshot.releaseTarget == .closed)
    }

    @Test("threshold normalization keeps destructive boundary after normal boundary")
    func thresholdNormalizationKeepsDestructiveBoundaryAfterNormalBoundary() {
        let side = SwipeCellInteractionSideConfiguration(
            normalOpenExtent: 100,
            normalOpenThreshold: -10,
            allowsDestructive: true,
            destructiveThreshold: 40
        )
        let model = SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: side,
                trailing: side
            )
        )

        let normalSnapshot = model.snapshot(
            startSide: nil,
            translationWidth: 100,
            pointerActive: true
        )
        let betweenSnapshot = model.snapshot(
            startSide: nil,
            translationWidth: 100.5,
            pointerActive: true
        )
        let destructiveSnapshot = model.snapshot(
            startSide: nil,
            translationWidth: 200,
            pointerActive: true
        )

        #expect(side.normalOpenThreshold == 100)
        #expect(side.destructiveActivationExtent == 101)
        #expect(normalSnapshot.thresholdLevel == .betweenNormalAndDestructive)
        #expect(betweenSnapshot.thresholdLevel == .betweenNormalAndDestructive)
        #expect(destructiveSnapshot.thresholdLevel == .destructive)
    }

    @Test("release targets apply through manager phase API")
    func releaseTargetsApplyThroughManagerPhaseAPI() {
        let manager = SwipeCellManager()

        manager.beginInteraction(for: "row", side: .leading)
        #expect(manager.applyReleaseTarget(.open(.leading), for: "row") == true)
        #expect(manager.phase == .open(.leading))

        manager.beginInteraction(for: "row", side: .leading)
        #expect(manager.applyReleaseTarget(.destructive(.leading), for: "row") == true)
        #expect(manager.phase == .triggering(.leading))

        manager.beginInteraction(for: "row", side: .leading)
        #expect(manager.applyReleaseTarget(.closed, for: "row") == true)
        #expect(manager.phase == .resetting(.gestureCancelled))
    }

    @Test("non-owner cannot apply release target")
    func nonOwnerCannotApplyReleaseTarget() {
        let manager = SwipeCellManager()
        manager.beginInteraction(for: "owner", side: .trailing)

        #expect(manager.applyReleaseTarget(.open(.leading), for: "other") == false)
        #expect(manager.applyReleaseTarget(.destructive(.trailing), for: "other") == false)
        #expect(manager.applyReleaseTarget(.closed, for: "other") == false)
        #expect(manager.activeCellID == AnyHashable("owner"))
        #expect(manager.activeSide == .trailing)
        #expect(manager.phase == .revealing)
    }

    @Test("active drag offset update carries snapshot progress without animation")
    func activeDragOffsetUpdateCarriesSnapshotProgressWithoutAnimation() {
        let snapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: -30,
            pointerActive: true
        )

        let update = SwipeCellOffsetUpdate.activeDrag(from: snapshot)

        #expect(update.contentOffset == -30)
        #expect(abs(update.normalOpenProgress - 0.3) < 0.0001)
        #expect(update.deformationProgress == 0)
        #expect(update.isArmed == false)
        #expect(update.animationRole == .none)
    }

    @Test("release settling update uses stable target offset and progress")
    func releaseSettlingUpdateUsesStableTargetOffsetAndProgress() {
        let openSnapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 50,
            pointerActive: false
        )
        let destructiveSnapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: -150,
            pointerActive: false
        )
        let closedSnapshot = destructiveModel.snapshot(
            startSide: nil,
            translationWidth: 20,
            pointerActive: false
        )

        let openUpdate = SwipeCellOffsetUpdate.releaseSettling(from: openSnapshot)
        let destructiveUpdate = SwipeCellOffsetUpdate.releaseSettling(from: destructiveSnapshot)
        let closedUpdate = SwipeCellOffsetUpdate.releaseSettling(from: closedSnapshot)

        #expect(openUpdate.contentOffset == 100)
        #expect(openUpdate.normalOpenProgress == 1)
        #expect(openUpdate.deformationProgress == 0)
        #expect(openUpdate.isArmed == false)
        #expect(openUpdate.animationRole == .releaseSettling)

        #expect(destructiveUpdate.contentOffset == -180)
        #expect(destructiveUpdate.normalOpenProgress == 1)
        #expect(destructiveUpdate.deformationProgress == 1)
        #expect(destructiveUpdate.isArmed == true)
        #expect(destructiveUpdate.animationRole == .releaseSettling)

        #expect(closedUpdate.contentOffset == 0)
        #expect(closedUpdate.normalOpenProgress == 0)
        #expect(closedUpdate.deformationProgress == 0)
        #expect(closedUpdate.isArmed == false)
        #expect(closedUpdate.animationRole == .releaseSettling)
    }

    @Test("forced reset offset update animates back to closed progress")
    func forcedResetOffsetUpdateAnimatesBackToClosedProgress() {
        let update = SwipeCellOffsetUpdate.forcedReset

        #expect(update.contentOffset == 0)
        #expect(update.normalOpenProgress == 0)
        #expect(update.deformationProgress == 0)
        #expect(update.isArmed == false)
        #expect(update.animationRole == .forcedReset)
    }

    @Test("a manual reverse-swipe close keeps the gesture-release role, not a reset")
    func manualReverseSwipeCloseKeepsGestureReleaseRole() {
        // Opening from a side, then reversing past the origin resolves to `.closed` — but it is still a
        // finger release, so it stays the gesture-release role and must not be reclassified as a
        // programmatic reset. Tap / scroll / cross-cell / cancel collapses are the reset role instead.
        let manualClose = SwipeCellOffsetUpdate.releaseSettling(
            from: destructiveModel.snapshot(
                startSide: .leading,
                translationWidth: -120,
                pointerActive: false
            )
        )

        #expect(manualClose.contentOffset == 0)
        #expect(manualClose.animationRole == .releaseSettling)
        #expect(SwipeCellOffsetUpdate.forcedReset.animationRole == .forcedReset)
    }

    @Test("closing settle owns the settling side only when a revealed offset remains")
    func closingSettleOwnsSettlingSideOnlyWhenRevealedOffsetRemains() {
        let forcedReset = SwipeCellOffsetUpdate.forcedReset

        // The settle that still has a revealed offset to animate owns the action side.
        #expect(forcedReset.ownsVisibleCloseSettle(fromContentOffset: -92) == true)
        #expect(forcedReset.ownsVisibleCloseSettle(fromContentOffset: 92) == true)

        // The redundant racing settle arrives once content already rests at zero and must not own,
        // so it cannot clear the action side before the real settle animation finishes.
        #expect(forcedReset.ownsVisibleCloseSettle(fromContentOffset: 0) == false)
        #expect(forcedReset.ownsVisibleCloseSettle(fromContentOffset: 0.4) == false)
    }

    @Test("only a closing settle can own the settling side")
    func onlyClosingSettleCanOwnTheSettlingSide() {
        let openSettle = SwipeCellOffsetUpdate.releaseSettling(
            from: destructiveModel.snapshot(
                startSide: nil,
                translationWidth: 50,
                pointerActive: false
            )
        )
        let closingSettle = SwipeCellOffsetUpdate.releaseSettling(
            from: destructiveModel.snapshot(
                startSide: nil,
                translationWidth: 20,
                pointerActive: false
            )
        )
        let activeDrag = SwipeCellOffsetUpdate.activeDrag(
            from: destructiveModel.snapshot(
                startSide: nil,
                translationWidth: 120,
                pointerActive: true
            )
        )

        // Opening keeps the cell active; the manager phase drives visibility, not the settling side.
        #expect(openSettle.contentOffset == 100)
        #expect(openSettle.ownsVisibleCloseSettle(fromContentOffset: 120) == false)
        // A below-threshold release settles closed and owns the side while content slides back.
        #expect(closingSettle.contentOffset == 0)
        #expect(closingSettle.ownsVisibleCloseSettle(fromContentOffset: 20) == true)
        // Active drag never settles.
        #expect(activeDrag.ownsVisibleCloseSettle(fromContentOffset: 120) == false)
    }

    @Test("coordinator publishes directed arm feed markers during active drag")
    func coordinatorPublishesDirectedArmFeedMarkersDuringActiveDrag() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: zeroHapticSuppressionConfiguration,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 125),
            model: destructiveModel,
            inputs: inputs
        )

        #expect(coordinator.isArmed == false)
        #expect(coordinator.armChangeID == 0)
        #expect(coordinator.armChangeKind == nil)
        #expect(coordinator.hapticEvent == nil)

        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        let armHaptic = coordinator.hapticEvent
        #expect(coordinator.isArmed == true)
        #expect(coordinator.armChangeID == 1)
        #expect(coordinator.armChangeKind == .enterFire)
        #expect(armHaptic?.kind == .arm)

        coordinator.panChanged(
            panValue(width: 125),
            model: destructiveModel,
            inputs: inputs
        )

        #expect(coordinator.isArmed == false)
        #expect(coordinator.armChangeID == 2)
        #expect(coordinator.armChangeKind == .exitFire)
        #expect(coordinator.hapticEvent?.kind == .disarm)
        #expect(coordinator.hapticEvent != armHaptic)
    }

    @Test("disabled haptic policy keeps arm markers without consuming suppression")
    func disabledHapticPolicyKeepsArmMarkersWithoutConsumingSuppression() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        var disabledConfiguration = SwipeCellConfiguration.platformDefault
        disabledConfiguration.feedback.hapticPolicy = .disabled
        disabledConfiguration.timing.hapticSuppression = 60
        var enabledConfiguration = disabledConfiguration
        enabledConfiguration.feedback.hapticPolicy = .standard
        let disabledInputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: disabledConfiguration,
            settlingAnimation: .linear(duration: 0)
        )
        let enabledInputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: enabledConfiguration,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(disabledInputs)
        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: disabledInputs
        )

        #expect(coordinator.isArmed == true)
        #expect(coordinator.armChangeID == 1)
        #expect(coordinator.armChangeKind == .enterFire)
        #expect(coordinator.hapticEvent == nil)

        coordinator.panChanged(
            panValue(width: 125),
            model: destructiveModel,
            inputs: disabledInputs
        )

        #expect(coordinator.isArmed == false)
        #expect(coordinator.armChangeID == 2)
        #expect(coordinator.armChangeKind == .exitFire)
        #expect(coordinator.hapticEvent == nil)

        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: enabledInputs
        )

        let enabledArmHaptic = coordinator.hapticEvent
        #expect(coordinator.isArmed == true)
        #expect(coordinator.armChangeID == 3)
        #expect(coordinator.armChangeKind == .enterFire)
        #expect(enabledArmHaptic?.id == 1)
        #expect(enabledArmHaptic?.kind == .arm)

        coordinator.panChanged(
            panValue(width: 125),
            model: destructiveModel,
            inputs: enabledInputs
        )

        #expect(coordinator.isArmed == false)
        #expect(coordinator.armChangeID == 4)
        #expect(coordinator.armChangeKind == .exitFire)
        #expect(coordinator.hapticEvent == enabledArmHaptic)
    }

    @Test("coordinator ignores projected destructive release")
    func coordinatorIgnoresProjectedDestructiveRelease() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        var fireCount = 0
        let action = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .directTrigger))
        ) {
            fireCount += 1
        }
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            destructiveTrigger: { side in
                guard side == .trailing else { return nil }
                return SwipeCellDestructiveTrigger(
                    action: action,
                    completion: .directTrigger
                )
            }
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: -100),
            model: destructiveModel,
            inputs: inputs
        )
        coordinator.panEnded(
            panValue(width: -100, predictedWidth: -220),
            model: destructiveModel,
            inputs: inputs
        )

        try? await Task.sleep(for: .milliseconds(50))

        #expect(fireCount == 0)
        #expect(manager.phase == .open(.trailing))
        #expect(coordinator.isArmed == false)
        #expect(coordinator.hapticEvent == nil)
        #expect(coordinator.contentOffset == -100)
    }

    @Test("coordinator downgrades unconfirmed scroll destructive release to open")
    func coordinatorDowngradesUnconfirmedScrollDestructiveReleaseToOpen() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        var fireCount = 0
        let action = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .directTrigger))
        ) {
            fireCount += 1
        }
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            destructiveTrigger: { side in
                guard side == .trailing else { return nil }
                return SwipeCellDestructiveTrigger(
                    action: action,
                    completion: .directTrigger
                )
            }
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: -160, allowsDestructiveRelease: false),
            model: destructiveModel,
            inputs: inputs
        )

        let enterHaptic = coordinator.hapticEvent

        coordinator.panEnded(
            panValue(width: -160, allowsDestructiveRelease: false),
            model: destructiveModel,
            inputs: inputs
        )

        try? await Task.sleep(for: .milliseconds(50))

        #expect(fireCount == 0)
        #expect(manager.phase == .open(.trailing))
        #expect(enterHaptic?.kind == .arm)
        #expect(coordinator.hapticEvent == enterHaptic)
        #expect(coordinator.contentOffset == -100)
    }

    @Test("release velocity does not change the resolved target")
    func releaseVelocityDoesNotChangeResolvedTarget() async {
        func landedOffset(releaseVelocity: CGFloat) async -> CGFloat {
            let manager = SwipeCellManager()
            let coordinator = SwipeCellInteractionCoordinator()
            let inputs = SwipeCellInteractionInputs(
                cellID: "row",
                manager: manager,
                settlingAnimation: .linear(duration: 0)
            )

            coordinator.panBegan(inputs)
            coordinator.panChanged(panValue(width: 60), model: destructiveModel, inputs: inputs)
            coordinator.panEnded(
                panValue(width: 60, velocity: releaseVelocity),
                model: destructiveModel,
                inputs: inputs
            )

            try? await Task.sleep(for: .milliseconds(50))

            #expect(manager.phase == .open(.leading))
            return coordinator.contentOffset
        }

        // A hard flick and a still release both land on the model's velocity-free open target; velocity
        // may still feed prediction and diagnostics, but it never re-targets the row.
        let flung = await landedOffset(releaseVelocity: 6000)
        let still = await landedOffset(releaseVelocity: 0)

        #expect(flung == 100)
        #expect(still == 100)
    }

    @Test("direct-touch fast active drag near endpoint ramps visible offset")
    func directTouchFastActiveDragNearEndpointRampsVisibleOffset() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 122, predictedWidth: 950, velocity: 3_400, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 25) < 0.0001)
        #expect(coordinator.normalOpenProgress == 0.25)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch first fast active sample stays in preflight")
    func directTouchFirstFastActiveSampleStaysInPreflight() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 40, predictedWidth: 950, velocity: 3_400, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == 14)
        #expect(coordinator.normalOpenProgress == 0.14)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch trailing first fast active sample stays in preflight")
    func directTouchTrailingFirstFastActiveSampleStaysInPreflight() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: -40, predictedWidth: -950, velocity: -3_400, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == -14)
        #expect(coordinator.normalOpenProgress == 0.14)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch fast active close bypasses closed-origin fast preflight")
    func directTouchFastActiveCloseBypassesClosedOriginFastPreflight() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        manager.beginInteraction(for: "row", side: .trailing)
        manager.open(.trailing, for: "row")
        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 40, predictedWidth: 950, velocity: 3_400, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == -60)
        #expect(coordinator.normalOpenProgress == 0.6)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch leading fast active close bypasses closed-origin fast preflight")
    func directTouchLeadingFastActiveCloseBypassesClosedOriginFastPreflight() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        manager.beginInteraction(for: "row", side: .leading)
        manager.open(.leading, for: "row")
        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: -40, predictedWidth: -950, velocity: -3_400, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == 60)
        #expect(coordinator.normalOpenProgress == 0.6)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch fast active close near closed preserves release reserve")
    func directTouchFastActiveCloseNearClosedPreservesReleaseReserve() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        manager.beginInteraction(for: "row", side: .trailing)
        manager.open(.trailing, for: "row")
        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 122, predictedWidth: 950, velocity: 3_400, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 15) < 0.0001)
        #expect(abs(coordinator.normalOpenProgress - 0.15) < 0.0001)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch fast active close reserve settles closed on release")
    func directTouchFastActiveCloseReserveSettlesClosedOnRelease() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: instantDirectTouchConfiguration,
            settlingAnimation: .linear(duration: 0)
        )

        manager.beginInteraction(for: "row", side: .trailing)
        manager.open(.trailing, for: "row")
        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 122, predictedWidth: 950, velocity: 3_400, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 15) < 0.0001)

        coordinator.panEnded(
            panValue(width: 122, predictedWidth: 950, velocity: 3_400, timestamp: 1.09),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset + 15) < 0.0001)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .closed)
    }

    @Test("direct-touch slow active drag near endpoint keeps finger offset")
    func directTouchSlowActiveDragNearEndpointKeepsFingerOffset() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 122, predictedWidth: 128, velocity: 80, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 102.64) < 0.0001)
        #expect(coordinator.normalOpenProgress == 1)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch slow active close keeps finger offset")
    func directTouchSlowActiveCloseKeepsFingerOffset() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        manager.beginInteraction(for: "row", side: .trailing)
        manager.open(.trailing, for: "row")
        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 40, predictedWidth: 45, velocity: 80, timestamp: 1.08),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == -60)
        #expect(coordinator.normalOpenProgress == 0.6)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch late active drag near endpoint keeps finger offset")
    func directTouchLateActiveDragNearEndpointKeepsFingerOffset() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 122, predictedWidth: 950, velocity: 3_400, timestamp: 1.30),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(abs(coordinator.contentOffset - 102.64) < 0.0001)
        #expect(coordinator.normalOpenProgress == 1)
        #expect(coordinator.isArmed == false)
    }

    @Test("direct-touch late active close keeps finger offset")
    func directTouchLateActiveCloseKeepsFingerOffset() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: SwipeCellConfiguration.iOSDefault,
            settlingAnimation: .linear(duration: 0)
        )

        manager.beginInteraction(for: "row", side: .trailing)
        manager.open(.trailing, for: "row")
        coordinator.panBegan(inputs, timestamp: 1.0)
        coordinator.panChanged(
            panValue(width: 40, predictedWidth: 950, velocity: 3_400, timestamp: 1.31),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(coordinator.contentOffset == -60)
        #expect(coordinator.normalOpenProgress == 0.6)
        #expect(coordinator.isArmed == false)
    }

    @Test("controller hold expanded settles to destructive hold extent")
    func controllerHoldExpandedSettlesToDestructiveHoldExtent() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        var receivedController: SwipeActionTriggerController?
        let action = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .directTrigger))
        ) { controller in
            receivedController = controller
            controller.holdExpanded()
        }
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            destructiveTrigger: { side in
                guard side == .leading else { return nil }
                return SwipeCellDestructiveTrigger(
                    action: action,
                    completion: .directTrigger
                )
            }
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 240),
            model: destructiveModel,
            inputs: inputs
        )

        let enterMarkerID = coordinator.armChangeID
        let enterHaptic = coordinator.hapticEvent

        coordinator.panEnded(
            panValue(width: 240),
            model: destructiveModel,
            inputs: inputs
        )

        try? await Task.sleep(for: .milliseconds(50))

        #expect(receivedController?.isResolved == true)
        #expect(manager.phase == .triggering(.leading))
        #expect(coordinator.contentOffset == 180)
        #expect(coordinator.isArmed == true)
        #expect(coordinator.armChangeID == enterMarkerID)
        #expect(coordinator.armChangeKind == .enterFire)
        #expect(coordinator.hapticEvent == enterHaptic)
    }

    @Test("direct destructive release fires simple action immediately after macOS close claim")
    func directDestructiveReleaseFiresSimpleActionImmediatelyAfterMacOSCloseClaim() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        #if os(macOS)
            coordinator.pausesMacOSResetTokenCloseCompletionForTesting = true
        #endif
        var fireCount = 0
        var pendingDriverDuringAction: SwipeCellForcedResetCloseDriver?
        var resettingCellDuringAction: AnyHashable?
        let action = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .directTrigger))
        ) {
            pendingDriverDuringAction = coordinator.pendingCloseDriver
            resettingCellDuringAction = manager.resettingCellID
            fireCount += 1
        }
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            destructiveTrigger: { side in
                guard side == .leading else { return nil }
                return SwipeCellDestructiveTrigger(
                    action: action,
                    completion: .directTrigger
                )
            }
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        let enterMarkerID = coordinator.armChangeID
        let enterHaptic = coordinator.hapticEvent

        coordinator.panEnded(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        let releaseHaptic = coordinator.hapticEvent

        #if os(macOS)
            #expect(fireCount == 1)
            #expect(pendingDriverDuringAction == .macOSActionCollapse)
            #expect(resettingCellDuringAction == AnyHashable("row"))
            #expect(coordinator.lastForcedResetCloseDriver == .macOSActionCollapse)
            #expect(coordinator.pendingCloseDriver == .macOSActionCollapse)
            #expect(coordinator.pendingMacOSResetTokenCloseEpoch == 1)
            #expect(coordinator.pendingCloseToken == nil)
            try? await Task.sleep(for: .milliseconds(50))
            coordinator.hostDisappeared(inputs)
            #if DEBUG
                #expect(coordinator.lastMacOSResetTokenCloseTerminalState == "detached-cleanup")
                #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
            #endif
        #else
            try? await Task.sleep(for: .milliseconds(50))
            #expect(fireCount == 1)
        #endif

        #expect(manager.phase == .closed)
        #expect(coordinator.isArmed == false)
        #expect(coordinator.armChangeID == enterMarkerID)
        #expect(coordinator.armChangeKind == .enterFire)
        #expect(releaseHaptic == enterHaptic)
        #expect(coordinator.hapticEvent == enterHaptic)
    }

    @Test("destructive controller collapse clears armed state without feed marker")
    func destructiveControllerCollapseClearsArmedStateWithoutFeedMarker() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        var receivedController: SwipeActionTriggerController?
        let action = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .directTrigger))
        ) { controller in
            receivedController = controller
        }
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            destructiveTrigger: { side in
                guard side == .leading else { return nil }
                return SwipeCellDestructiveTrigger(
                    action: action,
                    completion: .directTrigger
                )
            }
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        let enterMarkerID = coordinator.armChangeID
        let enterHaptic = coordinator.hapticEvent

        coordinator.panEnded(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        #expect(manager.phase == .triggering(.leading))
        #expect(coordinator.isArmed == true)

        receivedController?.collapse()

        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.isArmed == false)
        #expect(coordinator.armChangeID == enterMarkerID)
        #expect(coordinator.armChangeKind == .enterFire)
        #expect(coordinator.hapticEvent == enterHaptic)
    }

    @Test("destructive auto release holds takeover before deferred close renders")
    func destructiveAutoReleaseHoldsTakeoverBeforeDeferredCloseRenders() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let action = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .directTrigger))
        ) {}
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            destructiveTrigger: { side in
                guard side == .leading else { return nil }
                return SwipeCellDestructiveTrigger(
                    action: action,
                    completion: .directTrigger
                )
            }
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        coordinator.panEnded(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        #expect(coordinator.takeoverSettlingSide == .leading)
        #expect(manager.phase == .resetting(.explicitClose))
    }

    @Test("destructive fired collapse holds fire face silently until visible settle completes")
    func destructiveFiredCollapseHoldsFireFaceSilentlyUntilVisibleSettleCompletes() async {
        // Case: RESET-DESTRUCT-FIRED-HOLD (issue #116)
        // The fired collapse relaxes `isArmed` without a disarm marker or haptic while
        // `takeoverSettlingSide` stays up, so the default chromes hold the fire face for exactly the
        // visible settle; completion releases the hold together with the settling side.
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let action = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .directTrigger))
        ) {}
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            destructiveTrigger: { side in
                guard side == .leading else { return nil }
                return SwipeCellDestructiveTrigger(
                    action: action,
                    completion: .directTrigger
                )
            }
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        let enterMarkerID = coordinator.armChangeID
        let enterHaptic = coordinator.hapticEvent
        #expect(coordinator.isArmed)
        #expect(coordinator.armChangeKind == .enterFire)

        coordinator.panEnded(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        // The hold rises before the deferred forced reset renders, so the armed face never sees a frame
        // without either signal.
        #expect(coordinator.takeoverSettlingSide == .leading)
        #expect(coordinator.isArmed)

        try? await Task.sleep(for: .milliseconds(50))
        completePinnedCloseIfNeeded(coordinator)
        try? await Task.sleep(for: .milliseconds(50))

        // `isArmed` relaxed during the collapse without ever publishing a disarm marker or haptic, and
        // completion released the hold together with the settling side.
        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.isArmed == false)
        #expect(coordinator.armChangeID == enterMarkerID)
        #expect(coordinator.armChangeKind == .enterFire)
        #expect(coordinator.hapticEvent == enterHaptic)
        #expect(coordinator.takeoverSettlingSide == nil)
        #expect(coordinator.settlingSide == nil)
        #expect(manager.phase == .closed)
    }

    @Test("action-trigger close clears armed state without feed marker")
    func actionTriggerCloseClearsArmedStateWithoutFeedMarker() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        let enterMarkerID = coordinator.armChangeID
        let enterHaptic = coordinator.hapticEvent

        coordinator.beginActionTapClose(inputs)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.isArmed == false)
        #expect(coordinator.armChangeID == enterMarkerID)
        #expect(coordinator.armChangeKind == .enterFire)
        #expect(coordinator.hapticEvent == enterHaptic)
    }

    @Test("action tap after collapse fires after visible reset completion")
    func actionTapAfterCollapseFiresAfterVisibleResetCompletion() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        var events: [String] = []

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 100),
            model: destructiveModel,
            inputs: inputs
        )
        manager.open(.leading, for: "row")

        let resolution = SwipeCellActionTapGate.resolve(
            .leading,
            for: "row",
            manager: manager,
            fireTiming: .afterCollapse
        )

        #expect(resolution == .afterCollapse)

        coordinator.beginActionTapClose(inputs) {
            events.append("action")
        }

        #expect(events.isEmpty)
        #expect(manager.phase == .resetting(.actionTrigger))
        #expect(manager.resettingCellID == AnyHashable("row"))

        try? await Task.sleep(for: .milliseconds(50))
        completePinnedCloseIfNeeded(coordinator)

        #expect(events == ["action"])
        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .closed)
        #expect(manager.resettingCellID == nil)
    }

    @Test("macOS immediate action tap claims close before invoking closure")
    func macOSImmediateActionTapClaimsCloseBeforeInvokingClosure() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        #if os(macOS)
            coordinator.pausesMacOSResetTokenCloseCompletionForTesting = true
        #endif
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: .macOSDefault,
            settlingAnimation: .linear(duration: 0)
        )
        var events: [String] = []
        var pendingDriverDuringAction: SwipeCellForcedResetCloseDriver?
        var resettingCellDuringAction: AnyHashable?

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 100),
            model: destructiveModel,
            inputs: inputs
        )
        manager.open(.leading, for: "row")

        let resolution = SwipeCellActionTapGate.resolve(
            .leading,
            for: "row",
            manager: manager,
            fireTiming: .immediate
        )

        coordinator.performActionTap(
            resolution: resolution,
            inputs: inputs
        ) {
            pendingDriverDuringAction = coordinator.pendingCloseDriver
            resettingCellDuringAction = manager.resettingCellID
            events.append("action")
        }

        #expect(resolution == .immediate)

        #if os(macOS)
            #expect(events == ["action"])
            #expect(pendingDriverDuringAction == .macOSActionCollapse)
            #expect(resettingCellDuringAction == AnyHashable("row"))
            #expect(manager.phase == .resetting(.actionTrigger))
            #expect(manager.resettingCellID == AnyHashable("row"))

            #expect(coordinator.lastForcedResetCloseDriver == .macOSActionCollapse)
            #expect(coordinator.pendingCloseDriver == .macOSActionCollapse)
            #expect(coordinator.pendingMacOSResetTokenCloseEpoch == 1)
            #expect(coordinator.pendingCloseToken == nil)
            coordinator.hostDisappeared(inputs)

            #expect(events == ["action"])
            #if DEBUG
                #expect(coordinator.lastMacOSResetTokenCloseTerminalState == "detached-cleanup")
                #expect(coordinator.macOSResetTokenCloseTerminalCount == 1)
            #endif
            #expect(manager.resettingCellID == nil)
        #else
            #expect(events == ["action"])
        #endif
    }

    @Test("trigger after reset action stays collapsed without controller override")
    func triggerAfterResetActionStaysCollapsedWithoutControllerOverride() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        var fireCount = 0
        let action = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .triggerAfterReset))
        ) {
            fireCount += 1
        }
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0),
            destructiveTrigger: { side in
                guard side == .leading else { return nil }
                return SwipeCellDestructiveTrigger(
                    action: action,
                    completion: .triggerAfterReset
                )
            }
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )
        coordinator.panEnded(
            panValue(width: 160),
            model: destructiveModel,
            inputs: inputs
        )

        #expect(fireCount == 0)

        try? await Task.sleep(for: .milliseconds(50))
        completePinnedCloseIfNeeded(coordinator)

        #expect(fireCount == 1)
        #expect(manager.phase == .closed)
        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("closed release ignores its own reset token until deferred settle")
    func closedReleaseIgnoresItsOwnResetTokenUntilDeferredSettle() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 30),
            model: destructiveModel,
            inputs: inputs
        )
        coordinator.panEnded(
            panValue(width: 30),
            model: destructiveModel,
            inputs: inputs
        )

        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)
        #expect(coordinator.contentOffset == 30)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .closed)
    }

    @Test("direct-touch closed release defers manager reset until visible settle")
    func directTouchClosedReleaseDefersManagerResetUntilVisibleSettle() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: instantDirectTouchConfiguration,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs, model: directTouchModel)
        coordinator.panChanged(
            panValue(width: -100),
            model: directTouchModel,
            inputs: inputs
        )
        manager.open(.trailing, for: "row")

        let generation = manager.resetGeneration

        coordinator.panBegan(inputs, model: directTouchModel)
        coordinator.panChanged(
            panValue(width: 1, predictedWidth: 80),
            model: directTouchModel,
            inputs: inputs
        )
        coordinator.panEnded(
            panValue(width: 1, predictedWidth: 80),
            model: directTouchModel,
            inputs: inputs
        )

        #expect(manager.phase == .revealing)
        #expect(manager.resetGeneration == generation)
        #expect(manager.resettingCellID == nil)
        #expect(coordinator.contentOffset == -99)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .closed)
        #expect(manager.resetGeneration == generation + 1)
        #expect(manager.resettingCellID == nil)
    }

    @Test("indirect-scroll closed release defers manager reset until visible settle")
    func indirectScrollClosedReleaseDefersManagerResetUntilVisibleSettle() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            configuration: instantIndirectScrollConfiguration,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs, model: indirectScrollModel)
        coordinator.panChanged(
            panValue(width: -100),
            model: indirectScrollModel,
            inputs: inputs
        )
        manager.open(.trailing, for: "row")

        let generation = manager.resetGeneration

        coordinator.panBegan(inputs, model: indirectScrollModel)
        coordinator.panChanged(
            panValue(width: 20, bypassesNormalReleaseThreshold: true),
            model: indirectScrollModel,
            inputs: inputs
        )
        coordinator.panEnded(
            panValue(width: 20, bypassesNormalReleaseThreshold: true),
            model: indirectScrollModel,
            inputs: inputs
        )

        #expect(manager.phase == .revealing)
        #expect(manager.hasActiveSwipeDrag == false)
        #expect(manager.resetGeneration == generation)
        #expect(manager.resettingCellID == nil)
        #expect(coordinator.contentOffset == -80)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .closed)
        #expect(manager.resetGeneration == generation + 1)
        #expect(manager.resettingCellID == nil)
    }

    @Test("cancelled pan ignores its own reset token until deferred settle")
    func cancelledPanIgnoresItsOwnResetTokenUntilDeferredSettle() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )

        coordinator.panBegan(inputs)
        coordinator.panChanged(
            panValue(width: 80),
            model: destructiveModel,
            inputs: inputs
        )
        coordinator.panCancelled(inputs)

        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)
        #expect(coordinator.contentOffset == 80)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.contentOffset == 0)
        #expect(manager.phase == .resetting(.gestureCancelled))
    }

    @Test("foreign pan replacement defers old owner reset into animated settle")
    func foreignPanReplacementDefersOldOwnerResetIntoAnimatedSettle() async {
        let manager = SwipeCellManager()
        let oldOwner = SwipeCellInteractionCoordinator()
        let newOwner = SwipeCellInteractionCoordinator()
        let oldInputs = SwipeCellInteractionInputs(
            cellID: "A",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        let newInputs = SwipeCellInteractionInputs(
            cellID: "B",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )

        oldOwner.panBegan(oldInputs)
        oldOwner.panChanged(
            panValue(width: -100),
            model: destructiveModel,
            inputs: oldInputs
        )
        oldOwner.panEnded(
            panValue(width: -100),
            model: destructiveModel,
            inputs: oldInputs
        )

        try? await Task.sleep(for: .milliseconds(50))

        #expect(manager.phase == .open(.trailing))
        #expect(oldOwner.contentOffset == -100)

        newOwner.panBegan(newInputs)
        newOwner.panChanged(
            panValue(width: 80),
            model: destructiveModel,
            inputs: newInputs
        )

        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.lastResetReason == .replacedByAnotherCell)
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(newOwner.contentOffset == 80)

        oldOwner.handleResetGenerationChange(manager.resetGeneration, inputs: oldInputs)
        #expect(oldOwner.contentOffset == -100)

        try? await Task.sleep(for: .milliseconds(50))
        completePinnedCloseIfNeeded(oldOwner)

        #expect(oldOwner.contentOffset == 0)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.resettingCellID == nil)
    }

    @Test("indirect-scroll stale owner release after replacement stays inert until reset-token close")
    func indirectScrollStaleOwnerReleaseAfterReplacementStaysInertUntilResetTokenClose() async {
        let manager = SwipeCellManager()
        let oldOwner = SwipeCellInteractionCoordinator()
        let newOwner = SwipeCellInteractionCoordinator()
        let oldInputs = SwipeCellInteractionInputs(
            cellID: "A",
            manager: manager,
            configuration: .macOSDefault,
            settlingAnimation: .linear(duration: 10)
        )
        let newInputs = SwipeCellInteractionInputs(
            cellID: "B",
            manager: manager,
            configuration: .macOSDefault,
            settlingAnimation: .linear(duration: 10)
        )

        oldOwner.panBegan(oldInputs, model: indirectScrollModel)
        oldOwner.panChanged(
            panValue(width: -100),
            model: indirectScrollModel,
            inputs: oldInputs
        )
        oldOwner.panEnded(
            panValue(width: -100),
            model: indirectScrollModel,
            inputs: oldInputs
        )

        try? await Task.sleep(for: .milliseconds(50))

        #expect(manager.phase == .open(.trailing))
        #expect(oldOwner.contentOffset == -100)

        newOwner.panBegan(newInputs, model: indirectScrollModel)
        newOwner.panChanged(
            panValue(width: 80),
            model: indirectScrollModel,
            inputs: newInputs
        )

        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.resettingCellID == AnyHashable("A"))

        oldOwner.panEnded(
            panValue(width: -100),
            model: indirectScrollModel,
            inputs: oldInputs
        )

        #expect(oldOwner.contentOffset == -100)
        #expect(oldOwner.pendingCloseDriver == nil)
        #expect(manager.resettingCellID == AnyHashable("A"))

        oldOwner.handleResetGenerationChange(manager.resetGeneration, inputs: oldInputs)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(oldOwner.contentOffset == 0)
        #expect(oldOwner.closeToken == 0)
        #expect(oldOwner.pendingCloseToken == nil)
        #expect(oldOwner.lastForcedResetCloseDriver == .macOSResetTokenClose)
        #if DEBUG
            #expect(oldOwner.lastMacOSResetTokenCloseTerminalState == "visible-complete")
            #expect(oldOwner.macOSResetTokenCloseTerminalCount == 1)
        #endif
        #expect(oldOwner.pendingCloseDriver == nil)
        #expect(oldOwner.pendingMacOSResetTokenCloseEpoch == nil)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.resettingCellID == nil)

        oldOwner.hostDisappeared(oldInputs)
        #if DEBUG
            #expect(oldOwner.macOSResetTokenCloseTerminalCount == 1)
        #endif
        #expect(oldOwner.contentOffset == 0)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.resettingCellID == nil)
    }

    @Test("public close default animates visible reset")
    func publicCloseDefaultAnimatesVisibleReset() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        manager.registerProgrammaticOpenTarget(
            for: "row",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { request in
            coordinator.applyProgrammaticOpen(request, model: destructiveModel, inputs: inputs)
        }

        #expect(manager.open("row", side: .trailing) == true)
        #expect(coordinator.contentOffset == -100)

        #expect(manager.close() == true)
        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)

        #expect(coordinator.contentOffset == -100)
        #expect(manager.resettingCellID == AnyHashable("row"))

        try? await Task.sleep(for: .milliseconds(50))
        completePinnedCloseIfNeeded(coordinator)

        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.normalOpenProgress == 0)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
        #expect(manager.resettingCellID == nil)
    }

    @Test("public close can disable visible reset animation")
    func publicCloseCanDisableVisibleResetAnimation() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        manager.registerProgrammaticOpenTarget(
            for: "row",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { request in
            coordinator.applyProgrammaticOpen(request, model: destructiveModel, inputs: inputs)
        }

        #expect(manager.open("row", side: .leading) == true)
        #expect(coordinator.contentOffset == 100)

        #expect(manager.close(animated: false) == true)
        coordinator.handleResetGenerationChange(manager.resetGeneration, inputs: inputs)

        #expect(coordinator.contentOffset == 0)
        #expect(coordinator.normalOpenProgress == 0)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
        #expect(manager.resettingCellID == nil)
    }

    @Test("programmatic open applies visible normal-open offset")
    func programmaticOpenAppliesVisibleNormalOpenOffset() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        manager.registerProgrammaticOpenTarget(
            for: "row",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { request in
            coordinator.applyProgrammaticOpen(request, model: destructiveModel, inputs: inputs)
        }

        #expect(manager.open("row", side: .trailing) == true)
        #expect(manager.phase == .open(.trailing))
        #expect(coordinator.contentOffset == -100)
        #expect(coordinator.normalOpenProgress == 1)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("animated programmatic open defers visible offset into a clean transaction")
    func animatedProgrammaticOpenDefersVisibleOffset() async {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        manager.registerProgrammaticOpenTarget(
            for: "row",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { request in
            coordinator.applyProgrammaticOpen(request, model: destructiveModel, inputs: inputs)
        }

        #expect(manager.open("row", side: .leading, animated: true) == true)
        #expect(manager.phase == .open(.leading))
        #expect(coordinator.contentOffset == 0)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.contentOffset == 100)
        #expect(coordinator.normalOpenProgress == 1)
        #expect(coordinator.deformationProgress == 0)
        #expect(coordinator.isArmed == false)
    }

    @Test("programmatic open can switch side on the same row")
    func programmaticOpenCanSwitchSideOnSameRow() {
        let manager = SwipeCellManager()
        let coordinator = SwipeCellInteractionCoordinator()
        let inputs = SwipeCellInteractionInputs(
            cellID: "row",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        manager.registerProgrammaticOpenTarget(
            for: "row",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { request in
            coordinator.applyProgrammaticOpen(request, model: destructiveModel, inputs: inputs)
        }

        #expect(manager.open("row", side: .leading) == true)
        #expect(coordinator.contentOffset == 100)

        #expect(manager.open("row", side: .trailing) == true)
        #expect(manager.phase == .open(.trailing))
        #expect(manager.resetGeneration == 0)
        #expect(coordinator.contentOffset == -100)
    }

    @Test("programmatic open replacement resets old visible owner")
    func programmaticOpenReplacementResetsOldVisibleOwner() async {
        let manager = SwipeCellManager()
        let oldOwner = SwipeCellInteractionCoordinator()
        let newOwner = SwipeCellInteractionCoordinator()
        let oldInputs = SwipeCellInteractionInputs(
            cellID: "A",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        let newInputs = SwipeCellInteractionInputs(
            cellID: "B",
            manager: manager,
            settlingAnimation: .linear(duration: 0)
        )
        manager.registerProgrammaticOpenTarget(
            for: "A",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { request in
            oldOwner.applyProgrammaticOpen(request, model: destructiveModel, inputs: oldInputs)
        }
        manager.registerProgrammaticOpenTarget(
            for: "B",
            capabilities: SwipeCellProgrammaticOpenCapabilities(
                canOpenLeading: true,
                canOpenTrailing: true
            )
        ) { request in
            newOwner.applyProgrammaticOpen(request, model: destructiveModel, inputs: newInputs)
        }

        #expect(manager.open("A", side: .leading) == true)
        #expect(oldOwner.contentOffset == 100)

        #expect(manager.open("B", side: .trailing) == true)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.resettingCellID == AnyHashable("A"))
        #expect(manager.resetGeneration == 1)
        #expect(newOwner.contentOffset == -100)
        #expect(oldOwner.contentOffset == 100)

        oldOwner.handleResetGenerationChange(manager.resetGeneration, inputs: oldInputs)
        try? await Task.sleep(for: .milliseconds(50))
        completePinnedCloseIfNeeded(oldOwner)

        #expect(oldOwner.contentOffset == 0)
        #expect(newOwner.contentOffset == -100)
        #expect(manager.activeCellID == AnyHashable("B"))
        #expect(manager.resettingCellID == nil)
    }

    @Test("ratio commit threshold opens at the same progress fraction across extents")
    func ratioCommitThresholdIsExtentIndependentUnderGain() {
        // Under the #27 gain model the macOS path feeds the model `translationWidth == progress × extent`.
        // A `.ratio(0.5)` commit threshold then opens at progress ≥ 0.5 regardless of the side extent.
        func releaseTarget(extent: CGFloat, progress: CGFloat) -> SwipeCellReleaseTarget? {
            let model = SwipeCellInteractionModel(
                configuration: .symmetric(
                    normalOpenExtent: extent,
                    normalOpenThreshold: SwipeCellNormalOpenCommitThreshold.ratio(0.5)
                        .resolvedDistance(for: extent)
                )
            )
            return model.snapshot(
                startSide: nil,
                translationWidth: progress * extent,
                pointerActive: false
            ).releaseTarget
        }

        for extent in [CGFloat(72), CGFloat(216)] {
            #expect(releaseTarget(extent: extent, progress: 0.49) == .closed)
            #expect(releaseTarget(extent: extent, progress: 0.5) == .open(.leading))
        }
    }

    @Test("past-open non-armed release settles to the clean open extent, not an overshoot offset")
    func pastOpenNonArmedReleaseSettlesToCleanOpen() {
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(normalOpenExtent: 100, normalOpenThreshold: 50)
        )

        // Gain can push a non-destructive side past full open (progress > 1); the release must still
        // resolve to a clean open at `normalOpenExtent`, never settling on the rubber-band overshoot.
        let snapshot = model.snapshot(
            startSide: nil,
            translationWidth: 250,
            pointerActive: false
        )

        #expect(snapshot.releaseTarget == .open(.leading))
        #expect(snapshot.settlingTarget?.contentOffset == 100)
    }

    private var destructiveModel: SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: SwipeCellInteractionConfiguration(
                leading: destructiveSide,
                trailing: destructiveSide
            )
        )
    }

    private var directTouchModel: SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            ),
            motion: SwipeCellConfiguration.iOSDefault.motion
        )
    }

    private var indirectScrollModel: SwipeCellInteractionModel {
        SwipeCellInteractionModel(
            configuration: .symmetric(
                normalOpenExtent: 100,
                normalOpenThreshold: 50
            ),
            motion: SwipeCellConfiguration.macOSDefault.motion
        )
    }

    private var instantDirectTouchConfiguration: SwipeCellConfiguration {
        var configuration = SwipeCellConfiguration.iOSDefault
        configuration.motion = SwipeCellConfiguration.Motion(settleMinDuration: 0, settleMaxDuration: 0)
        return configuration
    }

    private var instantIndirectScrollConfiguration: SwipeCellConfiguration {
        var configuration = SwipeCellConfiguration.macOSDefault
        configuration.motion.settleMinDuration = 0
        configuration.motion.settleMaxDuration = 0
        return configuration
    }

    private var zeroHapticSuppressionConfiguration: SwipeCellConfiguration {
        var configuration = SwipeCellConfiguration.platformDefault
        configuration.timing.hapticSuppression = 0
        return configuration
    }

    private var destructiveSide: SwipeCellInteractionSideConfiguration {
        SwipeCellInteractionSideConfiguration(
            normalOpenExtent: 100,
            normalOpenThreshold: 50,
            allowsDestructive: true,
            destructiveThreshold: 150,
            destructiveSettlingExtent: 180
        )
    }

    private func panValue(
        width: CGFloat,
        predictedWidth: CGFloat? = nil,
        velocity: CGFloat = 0,
        allowsDestructiveRelease: Bool = true,
        bypassesNormalReleaseThreshold: Bool = false,
        timestamp: TimeInterval? = nil
    ) -> SwipeCellPanValue {
        SwipeCellPanValue(
            translation: CGSize(width: width, height: 0),
            predictedEndTranslation: CGSize(width: predictedWidth ?? width, height: 0),
            allowsDestructiveRelease: allowsDestructiveRelease,
            bypassesNormalReleaseThreshold: bypassesNormalReleaseThreshold,
            velocity: CGPoint(x: velocity, y: 0),
            timestamp: timestamp
        )
    }

    private func completePinnedCloseIfNeeded(_ coordinator: SwipeCellInteractionCoordinator) {
        guard let token = coordinator.pendingCloseToken else { return }
        coordinator.completePinnedClose(token: token)
    }
}
