import CoreGraphics
import Foundation
import SwiftUI

@usableFromInline
nonisolated enum SwipeCellDefaultPresentationConfiguration {
    /// Structured default label metrics shared by the current platform seeds.
    @usableFromInline static let defaultLabelMetrics = DefaultLabelMetricsSeed(
        iconFont: .body.weight(.semibold),
        titleFont: .caption2.weight(.semibold),
        iconSlotSize: 24,
        textSlotHeight: 14,
        slotSpacing: 4,
        textHorizontalInset: 4,
        armedFrontInset: 18
    )

    /// iOS default data for `.slot` presentation.
    @usableFromInline static let iOSSlot = SlotSeed(
        labelMetrics: defaultLabelMetrics,
        chrome: SlotChromeSeed(
            drawsFullSlotTint: true,
            armedTitleOpacity: 0,
            armedGlyphSlideDuration: 0.3
        ),
        revealTransform: SlotRevealTransformSeed(hiddenOffsetFraction: 1),
        deformationVisual: DeformationVisualSeed(nonDestructiveOpacityFalloff: 0.35)
    )

    /// iOS default data for `.token` presentation.
    @usableFromInline static let iOSToken = TokenSeed(
        labelMetrics: defaultLabelMetrics,
        chrome: TokenChromeSeed(
            tokenProfile: SwipeActionTokenProfile(
                restingWidth: 50,
                restingHeight: 50,
                titleSpacing: 4,
                stretchHorizontalInset: 4
            ),
            drawsTokenTint: true,
            nonDestructiveRecedeMaxFade: 0.8,
            armedTitleOpacity: 0,
            armedGlyphSlideDuration: 0.3
        ),
        revealTransform: TokenRevealTransformSeed(
            minimumScale: 0.5,
            minimumOpacity: 0
        ),
        deformationVisual: DeformationVisualSeed(nonDestructiveOpacityFalloff: 0.35)
    )

    /// macOS default data for `.slot` presentation.
    @usableFromInline static let macOSSlot = SlotSeed(
        labelMetrics: defaultLabelMetrics,
        chrome: SlotChromeSeed(
            drawsFullSlotTint: true,
            armedTitleOpacity: 0,
            armedGlyphSlideDuration: 0.3
        ),
        revealTransform: SlotRevealTransformSeed(hiddenOffsetFraction: 1),
        deformationVisual: DeformationVisualSeed(nonDestructiveOpacityFalloff: 0.35)
    )

    /// macOS default data for `.token` presentation.
    @usableFromInline static let macOSToken = TokenSeed(
        labelMetrics: defaultLabelMetrics,
        chrome: TokenChromeSeed(
            tokenProfile: SwipeActionTokenProfile(
                restingWidth: 60,
                restingHeight: 36,
                titleSpacing: 5,
                stretchHorizontalInset: 6
            ),
            drawsTokenTint: true,
            nonDestructiveRecedeMaxFade: 0.8,
            armedTitleOpacity: 0,
            armedGlyphSlideDuration: 0.3
        ),
        revealTransform: TokenRevealTransformSeed(
            minimumScale: 0.5,
            minimumOpacity: 0
        ),
        deformationVisual: DeformationVisualSeed(nonDestructiveOpacityFalloff: 0.35)
    )

    /// iOS bridge data for `SwipeCellConfiguration.iOSDefault`.
    static let iOSConfiguration = ConfigurationBridgeSeed(
        geometry: .init(
            defaultActionWidth: 72,
            normalOpenCommitThreshold: .ratio(0.5),
            maxFullSwipeActivationFraction: 0.9,
            destructiveActivationDefaults: .init(.openExtentPlusActionWidths(1.5)),
            defaultOpenThreshold: 48
        ),
        motion: MotionSeed(
            rubberBandCoefficient: 0.12,
            maxRubberBandDistance: 36,
            settleMinDuration: 0.28,
            settleMaxDuration: 0.70,
            settleCurve: .init(c0x: 0.215, c0y: 0.61, c1x: 0.43, c1y: 1.0),
            releasePredictionDuration: 0.25,
            horizontalOwnershipBias: 0,
            trackingStyle: .directTouch
        ),
        input: .init(
            scrollWheelTrackpadScale: 1,
            scrollWheelLineScale: 10,
            scrollWheelMinStartDelta: 1,
            scrollWheelEndSynthesisDelay: 0.12,
            scrollWheelReferenceRevealDistance: 48,
            scrollWheelMaxProgressStep: 0.2
        ),
        timing: .init(
            minimumScrollResetDelta: 1,
            hapticSuppression: 0.14,
            scrollResetSuppression: 0.35,
            tapCloseSuppression: 0.25
        ),
        defaultRevealStyle: .slot,
        tokenRevealMinScale: iOSToken.revealTransform.minimumScale,
        tokenRevealMinOpacity: iOSToken.revealTransform.minimumOpacity,
        tokenProfile: iOSToken.chrome.tokenProfile,
        deformationOpacityFalloff: iOSSlot.deformationVisual.nonDestructiveOpacityFalloff,
        settlingAnimation: .easeInOut(duration: 0.3)
    )

    /// macOS bridge data for `SwipeCellConfiguration.macOSDefault`.
    static let macOSConfiguration = ConfigurationBridgeSeed(
        geometry: .init(
            defaultActionWidth: 72,
            normalOpenCommitThreshold: .ratio(0.5),
            maxFullSwipeActivationFraction: 0.9,
            destructiveActivationDefaults: .init(.rowWidthFraction(0.6)),
            defaultOpenThreshold: 48
        ),
        motion: MotionSeed(
            rubberBandCoefficient: 0.12,
            maxRubberBandDistance: 36,
            settleMinDuration: 0.28,
            settleMaxDuration: 0.70,
            settleCurve: .init(c0x: 0.215, c0y: 0.61, c1x: 0.43, c1y: 1.0),
            releasePredictionDuration: 0.25,
            horizontalOwnershipBias: 0,
            trackingStyle: .indirectScroll
        ),
        input: .init(
            scrollWheelTrackpadScale: 1,
            scrollWheelLineScale: 10,
            scrollWheelMinStartDelta: 1,
            scrollWheelEndSynthesisDelay: 0.12,
            scrollWheelReferenceRevealDistance: 48,
            scrollWheelMaxProgressStep: 0.2
        ),
        timing: .init(
            minimumScrollResetDelta: 1,
            hapticSuppression: 0.14,
            scrollResetSuppression: 0.35,
            tapCloseSuppression: 0.25
        ),
        defaultRevealStyle: .slot,
        tokenRevealMinScale: macOSToken.revealTransform.minimumScale,
        tokenRevealMinOpacity: macOSToken.revealTransform.minimumOpacity,
        tokenProfile: macOSToken.chrome.tokenProfile,
        deformationOpacityFalloff: macOSSlot.deformationVisual.nonDestructiveOpacityFalloff,
        settlingAnimation: .easeInOut(duration: 0.3)
    )

}
