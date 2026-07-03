import CoreGraphics
import SwiftUI
import Testing

@_spi(ManualDebug) @testable import SwipeCell

@MainActor
@Suite("SwipeCell configuration")
struct SwipeCellConfigurationTests {
    @Test("platform default selects the active platform seed")
    func platformDefaultSelectsActivePlatformSeed() {
        #if os(macOS)
            #expect(SwipeCellConfiguration.platformDefault == .macOSDefault)
        #else
            #expect(SwipeCellConfiguration.platformDefault == .iOSDefault)
        #endif
    }

    @Test("scroll wheel gain profiles use tuned fast intent bars")
    func scrollWheelGainProfilesUseTunedFastIntentBars() {
        #expect(SwipeCellScrollWheelGainProfile.listDefault.fastReleaseIntentDistance == 1)
        #expect(SwipeCellScrollWheelGainProfile.scrollViewDefault.fastReleaseIntentDistance == 1)
        #expect(SwipeCellScrollWheelGainProfile.scrollViewDefault.fastReleaseOpenCommitRatio == 0.44)
    }

    @Test("internal bridge seeds assemble the public defaults")
    func internalBridgeSeedsAssemblePublicDefaults() {
        #expect(SwipeCellDefaultPresentationConfiguration.iOSConfiguration.configuration == .iOSDefault)
        #expect(SwipeCellDefaultPresentationConfiguration.macOSConfiguration.configuration == .macOSDefault)
        #expect(SwipeCellConfiguration() == .iOSDefault)
        #expect(SwipeCellConfiguration.Geometry() == SwipeCellConfiguration.iOSDefault.geometry)
        #expect(SwipeCellConfiguration.Motion() == SwipeCellConfiguration.iOSDefault.motion)
        #expect(SwipeCellConfiguration.PlatformInput() == SwipeCellConfiguration.iOSDefault.input)
        #expect(SwipeCellConfiguration.Timing() == SwipeCellConfiguration.iOSDefault.timing)
        #expect(SwipeCellConfiguration.Style() == SwipeCellConfiguration.iOSDefault.style)
        #expect(SwipeCellConfiguration.Feedback() == SwipeCellConfiguration.iOSDefault.feedback)
        #expect(SwipeCellConfiguration.Rendering() == SwipeCellConfiguration.iOSDefault.rendering)
    }

    @Test("internal presentation seeds keep platform and reveal-style axes separate")
    func internalPresentationSeedsKeepPlatformAndRevealStyleAxesSeparate() {
        let iOSSlot = SwipeCellDefaultPresentationConfiguration.iOSSlot
        let iOSToken = SwipeCellDefaultPresentationConfiguration.iOSToken
        let macOSSlot = SwipeCellDefaultPresentationConfiguration.macOSSlot
        let macOSToken = SwipeCellDefaultPresentationConfiguration.macOSToken

        #expect(iOSSlot.chrome.drawsFullSlotTint)
        #expect(macOSSlot.chrome.drawsFullSlotTint)
        #expect(iOSToken.chrome.drawsTokenTint)
        #expect(macOSToken.chrome.drawsTokenTint)
        #expect(iOSSlot.labelMetrics == iOSToken.labelMetrics)
        #expect(macOSSlot.labelMetrics == macOSToken.labelMetrics)
        #expect(iOSToken.chrome.tokenProfile.restingWidth == iOSToken.chrome.tokenProfile.restingHeight)
        #expect(macOSToken.chrome.tokenProfile.restingWidth > macOSToken.chrome.tokenProfile.restingHeight)
        #expect(SwipeActionTokenProfile.iOSDefault == iOSToken.chrome.tokenProfile)
        #expect(SwipeActionTokenProfile.macOSDefault == macOSToken.chrome.tokenProfile)
    }

    @Test("default label metrics and chrome are read from internal seeds")
    func defaultLabelMetricsAndChromeAreReadFromInternalSeeds() {
        let labelSeed = SwipeCellDefaultPresentationConfiguration.defaultLabelMetrics
        let style = SwipeActionDefaultLabelStyle.default
        let metrics = SwipeActionDefaultLabelMetrics()

        #expect(style.iconFont == labelSeed.iconFont)
        #expect(style.titleFont == labelSeed.titleFont)
        #expect(style.iconSlotSize == labelSeed.iconSlotSize)
        #expect(style.textSlotHeight == labelSeed.textSlotHeight)
        #expect(metrics.slotSpacing == labelSeed.slotSpacing)
        #expect(metrics.textHorizontalInset == labelSeed.textHorizontalInset)
        #expect(metrics.armedFrontInset == labelSeed.armedFrontInset)
        #expect(
            SwipeCellDefaultPresentationConfiguration.slotChrome(for: .iOSDefault)
                == SwipeCellDefaultPresentationConfiguration.iOSSlot.chrome
        )
        #expect(
            SwipeCellDefaultPresentationConfiguration.slotChrome(for: .macOSDefault)
                == SwipeCellDefaultPresentationConfiguration.macOSSlot.chrome
        )
        #expect(
            SwipeCellDefaultPresentationConfiguration.slotRevealTransform(for: .iOSDefault)
                == SwipeCellDefaultPresentationConfiguration.iOSSlot.revealTransform
        )
        #expect(
            SwipeCellDefaultPresentationConfiguration.slotRevealTransform(for: .macOSDefault)
                == SwipeCellDefaultPresentationConfiguration.macOSSlot.revealTransform
        )
        #expect(
            SwipeCellDefaultPresentationConfiguration.tokenChrome(for: .iOSDefault)
                == SwipeCellDefaultPresentationConfiguration.iOSToken.chrome
        )
        #expect(
            SwipeCellDefaultPresentationConfiguration.tokenChrome(for: .macOSDefault)
                == SwipeCellDefaultPresentationConfiguration.macOSToken.chrome
        )
    }

    @Test("iOS default profile follows the list gain profile")
    func iOSDefaultFollowsListGainProfile() {
        let configuration = SwipeCellConfiguration.iOSDefault
        let listProfile = SwipeCellScrollWheelGainProfile.listDefault
        let scrollViewProfile = SwipeCellScrollWheelGainProfile.scrollViewDefault

        #expect(configuration.geometry.defaultActionWidth == 72)
        #expect(configuration.geometry.normalOpenCommitThreshold == .ratio(0.5))
        #expect(configuration.geometry.maxFullSwipeActivationFraction == 0.9)
        #expect(
            configuration.geometry.destructiveActivationDefaults
                == .init(.openExtentPlusActionWidths(1.5))
        )
        #expect(configuration.geometry.defaultOpenThreshold == 48)

        #expect(configuration.motion.rubberBandCoefficient == 0.12)
        #expect(configuration.motion.maxRubberBandDistance == 36)
        #expect(configuration.motion.settleMinDuration == 0.28)
        #expect(configuration.motion.settleMaxDuration == 0.70)
        #expect(configuration.motion.settleCurve == .init(c0x: 0.215, c0y: 0.61, c1x: 0.43, c1y: 1.0))
        #expect(configuration.motion.releasePredictionDuration == 0.25)
        #expect(configuration.motion.horizontalOwnershipBias == 0)

        #expect(configuration.input.scrollWheelTrackpadScale == 1)
        #expect(configuration.input.scrollWheelLineScale == 10)
        #expect(configuration.input.scrollWheelMinStartDelta == 1)
        #expect(configuration.input.scrollWheelEndSynthesisDelay == 0.12)
        #expect(configuration.input.scrollWheelReferenceRevealDistance == listProfile.fastReferenceRevealDistance)
        #expect(configuration.input.scrollWheelSlowReferenceRevealDistance == listProfile.slowReferenceRevealDistance)
        #expect(configuration.input.scrollWheelAdaptiveLowerDelta == listProfile.adaptiveLowerDelta)
        #expect(configuration.input.scrollWheelAdaptiveUpperDelta == listProfile.adaptiveUpperDelta)
        #expect(configuration.input.scrollWheelFastReleaseIntentDistance == listProfile.fastReleaseIntentDistance)
        #expect(configuration.input.scrollWheelFastReleaseOpenCommitRatio == listProfile.fastReleaseOpenCommitRatio)
        #expect(configuration.input.scrollViewScrollWheelGainProfile == scrollViewProfile)
        #expect(configuration.input.scrollWheelMaxProgressStep == 0.2)

        #expect(configuration.timing.minimumScrollResetDelta == 1)
        #expect(configuration.timing.hapticSuppression == 0.14)
        #expect(configuration.timing.scrollResetSuppression == 0.35)
        #expect(configuration.timing.tapCloseSuppression == 0.25)

        #expect(configuration.style.defaultRevealStyle == .slot)
        #expect(configuration.style.tokenRevealMinScale == 0.5)
        #expect(configuration.style.tokenRevealMinOpacity == 0)
        #expect(configuration.style.tokenProfile == .iOSDefault)
        #expect(configuration.style.deformationOpacityFalloff == 0.35)
        #expect(configuration.style.settlingAnimation == .easeInOut(duration: 0.3))

        #expect(configuration.feedback.hapticPolicy == .standard)
        #expect(configuration.rendering.actionShellDrawingGroup == .disabled)
    }

    @Test("macOS default profile uses half commit gate and row-width destructive activation")
    func macOSDefaultUsesHalfCommitGateAndRowWidthDestructiveActivation() {
        let configuration = SwipeCellConfiguration.macOSDefault

        #expect(configuration.geometry.normalOpenCommitThreshold == .ratio(0.5))
        #expect(configuration.geometry.maxFullSwipeActivationFraction == 0.9)
        #expect(
            configuration.geometry.destructiveActivationDefaults
                == .init(.rowWidthFraction(0.6))
        )
        #expect(configuration.style.tokenProfile == .macOSDefault)
        #expect(configuration.style.tokenProfile.restingWidth > configuration.style.tokenProfile.restingHeight)
        #expect(configuration.feedback.hapticPolicy == .standard)
        #expect(configuration.rendering.actionShellDrawingGroup == .disabled)
    }

    @Test("haptic policy maps destructive boundary events to feedback requests")
    func hapticPolicyMapsDestructiveBoundaryEventsToFeedbackRequests() {
        #expect(SwipeCellHapticPolicy.disabled.feedbackRequest(for: .arm) == nil)
        #expect(SwipeCellHapticPolicy.disabled.feedbackRequest(for: .disarm) == nil)
        #expect(
            SwipeCellHapticPolicy.subtle.feedbackRequest(for: .arm)
                == .impact(weight: .light, intensity: 0.7)
        )
        #expect(
            SwipeCellHapticPolicy.standard.feedbackRequest(for: .arm)
                == .impact(weight: .medium, intensity: 1)
        )
        #expect(
            SwipeCellHapticPolicy.prominent.feedbackRequest(for: .arm)
                == .impact(weight: .heavy, intensity: 1)
        )
        #expect(SwipeCellHapticPolicy.subtle.feedbackRequest(for: .disarm) == .selection)
        #expect(SwipeCellHapticPolicy.standard.feedbackRequest(for: .disarm) == .selection)
        #expect(SwipeCellHapticPolicy.prominent.feedbackRequest(for: .disarm) == .selection)
    }

    @Test("drawing group mode exposes disabled and enabled helper parameters")
    func drawingGroupModeExposesDisabledAndEnabledHelperParameters() throws {
        #expect(SwipeCellDrawingGroupMode.disabled.actionShellDrawingGroupParameters == nil)

        let parameters = try #require(
            SwipeCellDrawingGroupMode.enabled(
                opaque: true,
                colorMode: .linear
            )
            .actionShellDrawingGroupParameters
        )

        #expect(parameters.opaque)
        #expect(parameters.colorMode == .linear)
        #expect(
            SwipeCellActionShellDrawingGroupModifier(mode: .enabled(opaque: true, colorMode: .linear))
                == SwipeCellActionShellDrawingGroupModifier(mode: .enabled(opaque: true, colorMode: .linear))
        )
    }

    @Test("token profile sanitizes invalid values against fallback")
    func tokenProfileSanitizesInvalidValuesAgainstFallback() {
        let fallback = SwipeActionTokenProfile(
            restingWidth: 60,
            restingHeight: 36,
            titleSpacing: 5,
            stretchHorizontalInset: 6
        )
        let invalid = SwipeActionTokenProfile(
            restingWidth: .nan,
            restingHeight: -.infinity,
            titleSpacing: 0,
            stretchHorizontalInset: 0
        )

        #expect(invalid.sanitized(fallback: fallback) == fallback)

        let mixed = SwipeActionTokenProfile(
            restingWidth: 72,
            restingHeight: 40,
            titleSpacing: 8,
            stretchHorizontalInset: 2
        )
        #expect(mixed.sanitized(fallback: fallback) == mixed)
    }

    @Test("normal open commit threshold resolves and normalizes to a reachable distance")
    func normalOpenCommitThresholdResolvesToReachableDistance() {
        #expect(SwipeCellNormalOpenCommitThreshold.ratio(0.5).resolvedDistance(for: 200) == 100)
        #expect(SwipeCellNormalOpenCommitThreshold.ratio(2).resolvedDistance(for: 200) == 200)
        #expect(SwipeCellNormalOpenCommitThreshold.ratio(.nan).resolvedDistance(for: 200) == 100)

        #expect(SwipeCellNormalOpenCommitThreshold.distance(48).resolvedDistance(for: 200) == 48)
        #expect(SwipeCellNormalOpenCommitThreshold.distance(48).resolvedDistance(for: 44) == 44)
        #expect(SwipeCellNormalOpenCommitThreshold.distance(.infinity).resolvedDistance(for: 200) == 1)
        #expect(SwipeCellNormalOpenCommitThreshold.distance(-12).resolvedDistance(for: 200) == 1)
    }

    @Test("closure overrides inherit sibling fields")
    func closureOverridesInheritSiblingFields() {
        let outer = SwipeCellConfiguration.iOSDefault.copy { configuration in
            configuration.geometry.defaultActionWidth = 80
            configuration.timing.minimumScrollResetDelta = 3
            configuration.feedback.hapticPolicy = .prominent
            configuration.rendering.actionShellDrawingGroup = .enabled(opaque: true, colorMode: .linear)
        }
        let nested = outer.copy { configuration in
            configuration.motion.maxRubberBandDistance = 44
        }

        #expect(nested.geometry.defaultActionWidth == 80)
        #expect(nested.timing.minimumScrollResetDelta == 3)
        #expect(nested.motion.maxRubberBandDistance == 44)
        #expect(nested.style.defaultRevealStyle == .slot)
        #expect(nested.feedback.hapticPolicy == .prominent)
        #expect(nested.rendering.actionShellDrawingGroup == .enabled(opaque: true, colorMode: .linear))
    }

    @Test("row-local configuration override can enable drawing group without changing siblings")
    func rowLocalConfigurationOverrideCanEnableDrawingGroupWithoutChangingSiblings() {
        let inherited = SwipeCellConfiguration.iOSDefault
        let rowOverride = inherited.copy { configuration in
            configuration.rendering.actionShellDrawingGroup = .enabled(
                opaque: false,
                colorMode: .extendedLinear
            )
        }

        #expect(inherited.rendering.actionShellDrawingGroup == .disabled)
        #expect(rowOverride.rendering.actionShellDrawingGroup == .enabled(opaque: false, colorMode: .extendedLinear))
        #expect(rowOverride.geometry == inherited.geometry)
        #expect(rowOverride.motion == inherited.motion)
        #expect(rowOverride.input == inherited.input)
        #expect(rowOverride.timing == inherited.timing)
        #expect(rowOverride.style == inherited.style)
        #expect(rowOverride.feedback == inherited.feedback)
    }

    @Test("container scenario resolves scope input without changing sibling domains")
    func containerScenarioResolvesScopeInput() {
        var base = SwipeCellConfiguration.platformDefault
        base.input.scrollWheelReferenceRevealDistance = 321
        base.input.scrollWheelSlowReferenceRevealDistance = 111
        base.input.scrollWheelAdaptiveLowerDelta = 9
        base.input.scrollWheelAdaptiveUpperDelta = 12
        base.input.scrollWheelFastReleaseIntentDistance = 14
        base.input.scrollWheelFastReleaseOpenCommitRatio = 0.95
        base.input.scrollViewScrollWheelGainProfile = SwipeCellScrollWheelGainProfile(
            fastReferenceRevealDistance: 700,
            slowReferenceRevealDistance: 70,
            adaptiveLowerDelta: 12,
            adaptiveUpperDelta: 34,
            fastReleaseIntentDistance: 36,
            fastReleaseOpenCommitRatio: 0.8
        )
        base.input.scrollWheelMaxProgressStep = 0.4
        base.timing.minimumScrollResetDelta = 5

        let list = base.resolved(for: .list)
        let scrollView = base.resolved(for: .scrollView)

        #expect(list == base)
        #if os(macOS)
            #expect(scrollView.input.scrollWheelReferenceRevealDistance == 700)
            #expect(scrollView.input.scrollWheelSlowReferenceRevealDistance == 70)
            #expect(scrollView.input.scrollWheelAdaptiveLowerDelta == 12)
            #expect(scrollView.input.scrollWheelAdaptiveUpperDelta == 34)
            #expect(scrollView.input.scrollWheelFastReleaseIntentDistance == 36)
            #expect(scrollView.input.scrollWheelFastReleaseOpenCommitRatio == 0.8)
            #expect(scrollView.input.scrollWheelMaxProgressStep == 0.4)
            #expect(scrollView.timing.minimumScrollResetDelta == 5)
            #expect(scrollView.geometry == base.geometry)
            #expect(scrollView.motion == base.motion)
            #expect(scrollView.style == base.style)
            #expect(scrollView.feedback == base.feedback)
            #expect(scrollView.rendering == base.rendering)
        #else
            #expect(scrollView == base)
        #endif
    }

    @Test("closer row configuration can override scroll view scenario input")
    func closerRowConfigurationCanOverrideScrollViewScenarioInput() {
        let scoped = SwipeCellConfiguration.platformDefault.resolved(for: .scrollView)
        let rowOverride = scoped.copy {
            $0.input.scrollWheelReferenceRevealDistance = 720
            $0.input.scrollWheelSlowReferenceRevealDistance = 72
            $0.input.scrollWheelFastReleaseIntentDistance = 42
            $0.input.scrollWheelFastReleaseOpenCommitRatio = 0.85
        }

        #expect(rowOverride.input.scrollWheelReferenceRevealDistance == 720)
        #expect(rowOverride.input.scrollWheelSlowReferenceRevealDistance == 72)
        #expect(rowOverride.input.scrollWheelFastReleaseIntentDistance == 42)
        #expect(rowOverride.input.scrollWheelFastReleaseOpenCommitRatio == 0.85)
    }

    @Test("copy can replace one domain from a template")
    func copyCanReplaceOneDomainFromTemplate() {
        let base = SwipeCellConfiguration.iOSDefault
        let copied = base.copy(
            geometry: .init(defaultActionWidth: 88, defaultOpenThreshold: 52)
        )

        #expect(copied.geometry.defaultActionWidth == 88)
        #expect(copied.geometry.defaultOpenThreshold == 52)
        #expect(copied.motion == base.motion)
        #expect(copied.input == base.input)
        #expect(base.geometry.defaultActionWidth == 72)
    }

    @Test("copy can replace feedback from a template")
    func copyCanReplaceFeedbackFromTemplate() {
        let base = SwipeCellConfiguration.iOSDefault
        let copied = base.copy(
            feedback: .init(hapticPolicy: .disabled)
        )

        #expect(copied.feedback.hapticPolicy == .disabled)
        #expect(copied.geometry == base.geometry)
        #expect(copied.motion == base.motion)
        #expect(copied.input == base.input)
        #expect(copied.timing == base.timing)
        #expect(copied.style == base.style)
        #expect(copied.rendering == base.rendering)
    }

    @Test("copy can replace rendering from a template")
    func copyCanReplaceRenderingFromTemplate() {
        let base = SwipeCellConfiguration.iOSDefault
        let copied = base.copy(
            rendering: .init(actionShellDrawingGroup: .enabled(opaque: true, colorMode: .linear))
        )

        #expect(copied.rendering.actionShellDrawingGroup == .enabled(opaque: true, colorMode: .linear))
        #expect(copied.geometry == base.geometry)
        #expect(copied.motion == base.motion)
        #expect(copied.input == base.input)
        #expect(copied.timing == base.timing)
        #expect(copied.style == base.style)
        #expect(copied.feedback == base.feedback)
    }

    @Test("copy can adjust one nested field by key path")
    func copyCanAdjustOneNestedFieldByKeyPath() {
        let copied = SwipeCellConfiguration.iOSDefault.copy(
            setting: \.input.scrollWheelLineScale,
            to: CGFloat(14)
        )

        #expect(copied.input.scrollWheelLineScale == 14)
        #expect(copied.input.scrollWheelTrackpadScale == 1)
        #expect(copied.geometry == SwipeCellConfiguration.iOSDefault.geometry)
        #expect(copied.feedback == SwipeCellConfiguration.iOSDefault.feedback)
        #expect(copied.rendering == SwipeCellConfiguration.iOSDefault.rendering)
    }

    @Test("cell typed overrides only replace their target fields")
    func cellTypedOverridesOnlyReplaceTargetFields() {
        var inherited = SwipeCellConfiguration.iOSDefault
        inherited.geometry.defaultActionWidth = 82
        inherited.geometry.defaultOpenThreshold = 56
        inherited.style.defaultRevealStyle = .token
        inherited.style.settlingAnimation = .linear(duration: 0.2)
        inherited.timing.minimumScrollResetDelta = 4

        let resolvedInherited = SwipeCellResolvedCellConfiguration(configuration: inherited)
        #expect(resolvedInherited.actionWidth == 82)
        #expect(resolvedInherited.openThreshold == 56)
        #expect(resolvedInherited.revealStyle == .token)
        #expect(resolvedInherited.settlingAnimation == .linear(duration: 0.2))
        #expect(resolvedInherited.configuration.timing.minimumScrollResetDelta == 4)

        let resolvedCell = SwipeCellResolvedCellConfiguration(
            configuration: inherited,
            actionWidth: 96,
            revealStyle: .slot,
            settlingAnimation: .linear(duration: 0.1),
            openThreshold: 72
        )

        #expect(resolvedCell.actionWidth == 96)
        #expect(resolvedCell.openThreshold == 72)
        #expect(resolvedCell.revealStyle == .slot)
        #expect(resolvedCell.settlingAnimation == .linear(duration: 0.1))
        #expect(resolvedCell.configuration.timing.minimumScrollResetDelta == 4)
    }

    @Test("action role activation overrides configuration geometry")
    func actionRoleActivationOverridesConfigurationGeometry() {
        var configuration = SwipeCellConfiguration.iOSDefault
        configuration.geometry.defaultActionWidth = 70
        configuration.geometry.normalOpenCommitThreshold = .ratio(0.25)
        configuration.geometry.maxFullSwipeActivationFraction = 0.8
        configuration.geometry.destructiveActivationDefaults = .init(.openExtentPlusActionWidths(1))

        let automatic = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction("Delete", role: .destructive(.init())) {},
                SwipeAction("More") {},
            ],
            configuration: configuration,
            emitsDiagnostics: false
        )
        let explicit = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction(
                    "Delete",
                    role: .destructive(.init(activation: .actionWidthMultiplier(5)))
                ) {},
                SwipeAction("More") {},
            ],
            configuration: configuration,
            emitsDiagnostics: false
        )

        #expect(automatic.actionWidth == 70)
        #expect(automatic.normalOpenThreshold == 35)
        #expect(automatic.interactionSideConfiguration(containerWidth: 400).destructiveActivationExtent == 210)
        #expect(explicit.interactionSideConfiguration(containerWidth: 400).destructiveActivationExtent == 320)
    }

    @Test("motion and input fields are consumed by model helpers")
    func motionAndInputFieldsAreConsumed() {
        let motion = SwipeCellConfiguration.Motion(
            rubberBandCoefficient: 1,
            maxRubberBandDistance: 10,
            settleMinDuration: 0.1,
            settleMaxDuration: 0.2
        )
        let model = SwipeCellInteractionModel(
            configuration: .symmetric(normalOpenExtent: 100),
            motion: motion
        )
        let snapshot = model.snapshot(
            startSide: nil,
            translationWidth: 150,
            pointerActive: true
        )

        #expect(snapshot.effectiveMovement == 110)
        #expect(
            SwipeCellReleaseSettleMotion.settleDuration(
                remainingDistance: 60,
                releaseSpeed: 200,
                motion: motion
            ) == 0.2
        )

        // Reference distance == extent makes the synthetic translation equal the accumulated distance,
        // so this isolates that `scrollWheelMinStartDelta` still gates `began`.
        var accumulator = SwipeCellScrollWheelPanAccumulator(
            input: .init(
                scrollWheelMinStartDelta: 20,
                scrollWheelReferenceRevealDistance: 100,
                scrollWheelSlowReferenceRevealDistance: 100,
                scrollWheelMaxProgressStep: 1
            ),
            interactionConfiguration: .symmetric(normalOpenExtent: 100),
            containerWidth: 100
        )

        #expect(
            accumulator.handle(
                SwipeCellScrollWheelSample(delta: CGSize(width: 12, height: 0), phase: .began)
            ) == .ignored
        )
        #expect(
            accumulator.handle(
                SwipeCellScrollWheelSample(delta: CGSize(width: 21, height: 0), phase: .began)
            )
                == .began(
                    SwipeCellPanValue(
                        translation: CGSize(width: 21, height: 0),
                        predictedEndTranslation: CGSize(width: 21, height: 0)
                    )
                )
        )
    }
}
