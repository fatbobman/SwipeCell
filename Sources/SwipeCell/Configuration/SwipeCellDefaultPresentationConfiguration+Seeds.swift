import CoreGraphics
import Foundation
import SwiftUI

extension SwipeCellDefaultPresentationConfiguration {
    @usableFromInline
    nonisolated struct SlotSeed: Equatable, Sendable {
        /// Font and fixed label-region metrics for structured default labels.
        @usableFromInline let labelMetrics: DefaultLabelMetricsSeed
        /// Full-slot tint and armed-state visual parameters for `.slot`.
        @usableFromInline let chrome: SlotChromeSeed
        /// Offset policy used while slot actions reveal.
        @usableFromInline let revealTransform: SlotRevealTransformSeed
        /// Opacity policy for non-destructive actions during destructive deformation.
        @usableFromInline let deformationVisual: DeformationVisualSeed

        @usableFromInline
        init(
            labelMetrics: DefaultLabelMetricsSeed,
            chrome: SlotChromeSeed,
            revealTransform: SlotRevealTransformSeed,
            deformationVisual: DeformationVisualSeed
        ) {
            self.labelMetrics = labelMetrics
            self.chrome = chrome
            self.revealTransform = revealTransform
            self.deformationVisual = deformationVisual
        }
    }

    @usableFromInline
    nonisolated struct TokenSeed: Equatable, Sendable {
        /// Font and fixed label-region metrics for structured default labels.
        @usableFromInline let labelMetrics: DefaultLabelMetricsSeed
        /// Token tint, geometry, and armed-state visual parameters for `.token`.
        @usableFromInline let chrome: TokenChromeSeed
        /// Scale and opacity policy used while token actions reveal.
        @usableFromInline let revealTransform: TokenRevealTransformSeed
        /// Opacity policy for non-destructive actions during destructive deformation.
        @usableFromInline let deformationVisual: DeformationVisualSeed

        @usableFromInline
        init(
            labelMetrics: DefaultLabelMetricsSeed,
            chrome: TokenChromeSeed,
            revealTransform: TokenRevealTransformSeed,
            deformationVisual: DeformationVisualSeed
        ) {
            self.labelMetrics = labelMetrics
            self.chrome = chrome
            self.revealTransform = revealTransform
            self.deformationVisual = deformationVisual
        }
    }

    @usableFromInline
    nonisolated struct DefaultLabelMetricsSeed: Equatable, Sendable {
        /// Icon font used by the structured default label.
        @usableFromInline let iconFont: Font
        /// Title font used by the structured default label.
        @usableFromInline let titleFont: Font
        /// Fixed icon layout region used before token fitting.
        @usableFromInline let iconSlotSize: CGFloat
        /// Fixed title layout region used below icon/token chrome.
        @usableFromInline let textSlotHeight: CGFloat
        /// Vertical gap between icon/token chrome and title text.
        @usableFromInline let slotSpacing: CGFloat
        /// Horizontal text inset inside the action label region.
        @usableFromInline let textHorizontalInset: CGFloat
        /// Content-facing inset used by the armed destructive glyph slide.
        @usableFromInline let armedFrontInset: CGFloat

        @usableFromInline
        init(
            iconFont: Font,
            titleFont: Font,
            iconSlotSize: CGFloat,
            textSlotHeight: CGFloat,
            slotSpacing: CGFloat,
            textHorizontalInset: CGFloat,
            armedFrontInset: CGFloat
        ) {
            self.iconFont = iconFont
            self.titleFont = titleFont
            self.iconSlotSize = iconSlotSize
            self.textSlotHeight = textSlotHeight
            self.slotSpacing = slotSpacing
            self.textHorizontalInset = textHorizontalInset
            self.armedFrontInset = armedFrontInset
        }
    }

    @usableFromInline
    nonisolated struct SlotChromeSeed: Equatable, Sendable {
        /// Whether the default style paints the whole action slot tint.
        @usableFromInline let drawsFullSlotTint: Bool
        /// Title opacity while a destructive slot is armed.
        @usableFromInline let armedTitleOpacity: Double
        /// Duration for the destructive armed glyph slide.
        @usableFromInline let armedGlyphSlideDuration: TimeInterval

        @usableFromInline
        init(
            drawsFullSlotTint: Bool,
            armedTitleOpacity: Double,
            armedGlyphSlideDuration: TimeInterval
        ) {
            self.drawsFullSlotTint = drawsFullSlotTint
            self.armedTitleOpacity = armedTitleOpacity
            self.armedGlyphSlideDuration = armedGlyphSlideDuration
        }
    }

    @usableFromInline
    nonisolated struct TokenChromeSeed: Equatable, Sendable {
        /// Resting and stretch geometry for visible token chrome.
        @usableFromInline let tokenProfile: SwipeActionTokenProfile
        /// Whether the structured default label paints token-local tint.
        @usableFromInline let drawsTokenTint: Bool
        /// Maximum opacity fade for non-destructive tokens during destructive arm.
        @usableFromInline let nonDestructiveRecedeMaxFade: Double
        /// Title opacity while a destructive token is armed.
        @usableFromInline let armedTitleOpacity: Double
        /// Duration for the destructive armed glyph slide.
        @usableFromInline let armedGlyphSlideDuration: TimeInterval

        @usableFromInline
        init(
            tokenProfile: SwipeActionTokenProfile,
            drawsTokenTint: Bool,
            nonDestructiveRecedeMaxFade: Double,
            armedTitleOpacity: Double,
            armedGlyphSlideDuration: TimeInterval
        ) {
            self.tokenProfile = tokenProfile
            self.drawsTokenTint = drawsTokenTint
            self.nonDestructiveRecedeMaxFade = nonDestructiveRecedeMaxFade
            self.armedTitleOpacity = armedTitleOpacity
            self.armedGlyphSlideDuration = armedGlyphSlideDuration
        }
    }

    @usableFromInline
    nonisolated struct SlotRevealTransformSeed: Equatable, Sendable {
        /// Hidden-distance fraction used before a slot is fully revealed.
        @usableFromInline let hiddenOffsetFraction: CGFloat

        @usableFromInline
        init(hiddenOffsetFraction: CGFloat) {
            self.hiddenOffsetFraction = hiddenOffsetFraction
        }
    }

    @usableFromInline
    nonisolated struct TokenRevealTransformSeed: Equatable, Sendable {
        /// Lower scale bound used before a token is fully revealed.
        @usableFromInline let minimumScale: CGFloat
        /// Lower opacity bound used before a token is fully revealed.
        @usableFromInline let minimumOpacity: Double

        @usableFromInline
        init(minimumScale: CGFloat, minimumOpacity: Double) {
            self.minimumScale = minimumScale
            self.minimumOpacity = minimumOpacity
        }
    }

    @usableFromInline
    nonisolated struct DeformationVisualSeed: Equatable, Sendable {
        /// Opacity falloff applied to non-destructive actions during destructive deformation.
        @usableFromInline let nonDestructiveOpacityFalloff: Double

        @usableFromInline
        init(nonDestructiveOpacityFalloff: Double) {
            self.nonDestructiveOpacityFalloff = nonDestructiveOpacityFalloff
        }
    }
}
