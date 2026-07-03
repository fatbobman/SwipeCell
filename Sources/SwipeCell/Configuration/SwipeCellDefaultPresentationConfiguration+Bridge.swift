import CoreGraphics
import Foundation
import SwiftUI

extension SwipeCellDefaultPresentationConfiguration {
    @usableFromInline
    static func slotChrome(for configuration: SwipeCellConfiguration) -> SlotChromeSeed {
        if configuration.style.tokenProfile == macOSToken.chrome.tokenProfile {
            return macOSSlot.chrome
        }

        return iOSSlot.chrome
    }

    @usableFromInline
    static func slotRevealTransform(for configuration: SwipeCellConfiguration) -> SlotRevealTransformSeed {
        if configuration.style.tokenProfile == macOSToken.chrome.tokenProfile {
            return macOSSlot.revealTransform
        }

        return iOSSlot.revealTransform
    }

    @usableFromInline
    static func tokenChrome(for profile: SwipeActionTokenProfile) -> TokenChromeSeed {
        if profile == macOSToken.chrome.tokenProfile {
            return macOSToken.chrome
        }

        return iOSToken.chrome
    }

    nonisolated struct ConfigurationBridgeSeed: Equatable, Sendable {
        /// Geometry defaults for action width, thresholds, and destructive activation.
        let geometry: SwipeCellConfiguration.Geometry
        /// Active tracking and release-settle motion defaults.
        let motion: MotionSeed
        /// Platform input scaling and scroll-wheel synthesis defaults.
        let input: SwipeCellConfiguration.PlatformInput
        /// Reset, haptic, and tap-suppression timing defaults.
        let timing: SwipeCellConfiguration.Timing
        /// Reveal style inherited by cells that do not provide an override.
        let defaultRevealStyle: SwipeActionsRevealStyle
        /// Lower scale bound for `.token` reveal.
        let tokenRevealMinScale: CGFloat
        /// Lower opacity bound for `.token` reveal.
        let tokenRevealMinOpacity: Double
        /// Default token geometry profile passed through public configuration.
        let tokenProfile: SwipeActionTokenProfile
        /// Non-destructive action fade rate during destructive deformation.
        let deformationOpacityFalloff: Double
        /// Animation used when a resolved cell settles visual state.
        let settlingAnimation: Animation

        init(
            geometry: SwipeCellConfiguration.Geometry,
            motion: MotionSeed,
            input: SwipeCellConfiguration.PlatformInput,
            timing: SwipeCellConfiguration.Timing,
            defaultRevealStyle: SwipeActionsRevealStyle,
            tokenRevealMinScale: CGFloat,
            tokenRevealMinOpacity: Double,
            tokenProfile: SwipeActionTokenProfile,
            deformationOpacityFalloff: Double,
            settlingAnimation: Animation
        ) {
            self.geometry = geometry
            self.motion = motion
            self.input = input
            self.timing = timing
            self.defaultRevealStyle = defaultRevealStyle
            self.tokenRevealMinScale = tokenRevealMinScale
            self.tokenRevealMinOpacity = tokenRevealMinOpacity
            self.tokenProfile = tokenProfile
            self.deformationOpacityFalloff = deformationOpacityFalloff
            self.settlingAnimation = settlingAnimation
        }

        var style: SwipeCellConfiguration.Style {
            SwipeCellConfiguration.Style(
                defaultRevealStyle: defaultRevealStyle,
                tokenRevealMinScale: tokenRevealMinScale,
                tokenRevealMinOpacity: tokenRevealMinOpacity,
                tokenProfile: tokenProfile,
                deformationOpacityFalloff: deformationOpacityFalloff,
                settlingAnimation: settlingAnimation
            )
        }

        var configuration: SwipeCellConfiguration {
            SwipeCellConfiguration(
                geometry: geometry,
                motion: motion.configurationMotion,
                input: input,
                timing: timing,
                style: style
            )
        }
    }

    nonisolated struct MotionSeed: Equatable, Sendable {
        /// Rubber-band compression coefficient after normal reveal.
        let rubberBandCoefficient: CGFloat
        /// Maximum visual rubber-band distance after normal reveal.
        let maxRubberBandDistance: CGFloat
        /// Lower bound for release-settle duration.
        let settleMinDuration: TimeInterval
        /// Upper bound for release-settle duration.
        let settleMaxDuration: TimeInterval
        /// Base release-settle timing curve.
        let settleCurve: SwipeCellConfiguration.TimingCurve
        /// Prediction horizon used by direct-touch release.
        let releasePredictionDuration: CGFloat
        /// Horizontal intent bias used by gesture ownership.
        let horizontalOwnershipBias: CGFloat
        /// Active-drag tracking model for the platform input modality.
        let trackingStyle: SwipeCellTrackingStyle

        init(
            rubberBandCoefficient: CGFloat,
            maxRubberBandDistance: CGFloat,
            settleMinDuration: TimeInterval,
            settleMaxDuration: TimeInterval,
            settleCurve: SwipeCellConfiguration.TimingCurve,
            releasePredictionDuration: CGFloat,
            horizontalOwnershipBias: CGFloat,
            trackingStyle: SwipeCellTrackingStyle
        ) {
            self.rubberBandCoefficient = rubberBandCoefficient
            self.maxRubberBandDistance = maxRubberBandDistance
            self.settleMinDuration = settleMinDuration
            self.settleMaxDuration = settleMaxDuration
            self.settleCurve = settleCurve
            self.releasePredictionDuration = releasePredictionDuration
            self.horizontalOwnershipBias = horizontalOwnershipBias
            self.trackingStyle = trackingStyle
        }

        var configurationMotion: SwipeCellConfiguration.Motion {
            var motion = SwipeCellConfiguration.Motion(
                rubberBandCoefficient: rubberBandCoefficient,
                maxRubberBandDistance: maxRubberBandDistance,
                settleMinDuration: settleMinDuration,
                settleMaxDuration: settleMaxDuration,
                settleCurve: settleCurve,
                releasePredictionDuration: releasePredictionDuration,
                horizontalOwnershipBias: horizontalOwnershipBias
            )
            motion.trackingStyle = trackingStyle
            return motion
        }
    }
}
