import CoreGraphics
import Foundation
import SwiftUI

/// Normal-open release threshold. Ratio keeps the threshold tied to the revealed action extent;
/// distance expresses an absolute model-space gate, useful for a minimal post-begin commit intent.
nonisolated public enum SwipeCellNormalOpenCommitThreshold: Equatable, Sendable {
    case ratio(CGFloat)
    case distance(CGFloat)

    /// Resolves invalid or unreachable values back into a positive distance inside the reveal extent.
    public func resolvedDistance(for normalOpenExtent: CGFloat) -> CGFloat {
        let normalizedExtent = Self.positiveFiniteDistance(normalOpenExtent, fallback: 0)
        guard normalizedExtent > 0 else { return 0 }

        let candidate =
            switch self {
            case .ratio(let ratio):
                normalizedExtent * min(Self.positiveFiniteDistance(ratio, fallback: 0.5), 1)
            case .distance(let distance):
                Self.positiveFiniteDistance(distance, fallback: 1)
            }

        return min(max(candidate, 1), normalizedExtent)
    }

    private static func positiveFiniteDistance(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return max(0, fallback) }
        return value
    }
}

/// Destructive full-swipe activation geometry, resolved after action and row widths are known.
nonisolated public enum SwipeCellDestructiveActivationGeometry: Equatable, Sendable {
    case actionWidthMultiplier(CGFloat)
    case openExtentPlusDistance(CGFloat)
    case openExtentPlusActionWidths(CGFloat)
    case rowWidthFraction(CGFloat)
}

/// Side-aware automatic destructive activation defaults.
///
/// Stored values stay explicit per side so callers and tests can inspect the effective policy without
/// reconstructing a base-plus-override fallback chain.
nonisolated public struct SwipeCellDestructiveActivationDefaults: Equatable, Sendable {
    public var leading: SwipeCellDestructiveActivationGeometry
    public var trailing: SwipeCellDestructiveActivationGeometry

    public init(_ geometry: SwipeCellDestructiveActivationGeometry = .openExtentPlusActionWidths(1.5)) {
        self.leading = geometry
        self.trailing = geometry
    }

    public init(
        leading: SwipeCellDestructiveActivationGeometry,
        trailing: SwipeCellDestructiveActivationGeometry
    ) {
        self.leading = leading
        self.trailing = trailing
    }

    public func geometry(for side: SwipeCellSide) -> SwipeCellDestructiveActivationGeometry {
        switch side {
        case .leading:
            leading
        case .trailing:
            trailing
        }
    }
}

/// Active-drag and gesture-release motion model, selected by input modality (issue #28).
///
/// Direct touch and indirect scroll want different handling: a finger on the content demands 1:1
/// tracking, while indirect scroll benefits from a spring's smoothing and interruptibility. The
/// platform profiles set this so the difference stays configuration data rather than a `#if`.
@_spi(ManualDebug) nonisolated public enum SwipeCellTrackingStyle: Equatable, Sendable {
    /// Direct touch (iOS default): a `disablesAnimations` 1:1 active drag keeps the content glued to the
    /// finger, paired with a duration-owned `.timingCurve` settle after the release target resolves. A
    /// spring's tracking lag is too visible under direct manipulation.
    case directTouch
    /// Indirect scroll (macOS default): a stiff interactive-spring active drag and a same-family
    /// `bounce: 0` settle spring paced by remaining distance, so an in-flight settle is retargeted — not
    /// jumped — by an interrupting scroll. The slight tracking lag is imperceptible on indirect input.
    case indirectScroll
}

/// Visual geometry for the structured default label under the `.token` reveal style.
///
/// The action slot remains the hit target and threshold geometry; this profile only sizes the visible
/// token chrome inside that slot.
nonisolated public struct SwipeActionTokenProfile: Equatable, Sendable {
    public var restingWidth: CGFloat
    public var restingHeight: CGFloat
    public var titleSpacing: CGFloat
    public var stretchHorizontalInset: CGFloat

    public init(
        restingWidth: CGFloat = Self.iOSDefault.restingWidth,
        restingHeight: CGFloat = Self.iOSDefault.restingHeight,
        titleSpacing: CGFloat = Self.iOSDefault.titleSpacing,
        stretchHorizontalInset: CGFloat = Self.iOSDefault.stretchHorizontalInset
    ) {
        self.restingWidth = restingWidth
        self.restingHeight = restingHeight
        self.titleSpacing = titleSpacing
        self.stretchHorizontalInset = stretchHorizontalInset
    }

    public static let iOSDefault = SwipeCellDefaultPresentationConfiguration.iOSToken.chrome.tokenProfile
    public static let macOSDefault = SwipeCellDefaultPresentationConfiguration.macOSToken.chrome.tokenProfile

    func sanitized(fallback: SwipeActionTokenProfile) -> SwipeActionTokenProfile {
        SwipeActionTokenProfile(
            restingWidth: Self.positiveDistance(restingWidth, fallback: fallback.restingWidth),
            restingHeight: Self.positiveDistance(restingHeight, fallback: fallback.restingHeight),
            titleSpacing: Self.positiveDistance(titleSpacing, fallback: fallback.titleSpacing),
            stretchHorizontalInset: Self.positiveDistance(
                stretchHorizontalInset,
                fallback: fallback.stretchHorizontalInset
            )
        )
    }

    private static func positiveDistance(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return fallback }
        return value
    }
}

/// Indirect-scroll gain profile used when a container needs different slow-drag and fast-flick mapping.
nonisolated public struct SwipeCellScrollWheelGainProfile: Equatable, Sendable {
    public var fastReferenceRevealDistance: CGFloat
    public var slowReferenceRevealDistance: CGFloat
    public var adaptiveLowerDelta: CGFloat
    public var adaptiveUpperDelta: CGFloat
    public var fastReleaseIntentDistance: CGFloat
    public var fastReleaseOpenCommitRatio: CGFloat

    public init(
        fastReferenceRevealDistance: CGFloat = 48,
        slowReferenceRevealDistance: CGFloat = 48,
        adaptiveLowerDelta: CGFloat = 20,
        adaptiveUpperDelta: CGFloat = 40,
        fastReleaseIntentDistance: CGFloat? = nil,
        fastReleaseOpenCommitRatio: CGFloat = 1
    ) {
        self.fastReferenceRevealDistance = fastReferenceRevealDistance
        self.slowReferenceRevealDistance = slowReferenceRevealDistance
        self.adaptiveLowerDelta = adaptiveLowerDelta
        self.adaptiveUpperDelta = adaptiveUpperDelta
        self.fastReleaseIntentDistance =
            fastReleaseIntentDistance ?? fastReferenceRevealDistance * 0.15
        self.fastReleaseOpenCommitRatio = fastReleaseOpenCommitRatio
    }

    public static let listDefault = SwipeCellScrollWheelGainProfile(
        fastReferenceRevealDistance: 48,
        slowReferenceRevealDistance: 48,
        adaptiveLowerDelta: 20,
        adaptiveUpperDelta: 40,
        fastReleaseIntentDistance: 1,
        fastReleaseOpenCommitRatio: 1
    )

    public static let scrollViewDefault = SwipeCellScrollWheelGainProfile(
        fastReferenceRevealDistance: 600,
        slowReferenceRevealDistance: 48,
        adaptiveLowerDelta: 20,
        adaptiveUpperDelta: 40,
        fastReleaseIntentDistance: 1,
        fastReleaseOpenCommitRatio: 0.44
    )
}

/// Rendering policy for rasterizing SwipeCell's composed action shell with SwiftUI `drawingGroup`.
///
/// This is an opt-in rendering tool, not a performance promise. It adds an offscreen render pass, so
/// simple rows can become slower; enable it only after profiling or smoke-testing the specific row
/// composition that needs it.
nonisolated public enum SwipeCellDrawingGroupMode: Equatable, Sendable {
    case disabled
    case enabled(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear)
}

/// Destructive boundary haptic policy for active-drag arm and disarm cues.
nonisolated public enum SwipeCellHapticPolicy: Equatable, Sendable {
    case disabled
    case subtle
    case standard
    case prominent

    var emitsBoundaryFeedback: Bool {
        self != .disabled
    }
}

/// Single value carrier for SwipeCell geometry, motion, input, timing, style, feedback, and rendering defaults.
///
/// The `.swipeCellConfiguration` spelling follows issue #24; issue #18 still owns the final public naming.
nonisolated public struct SwipeCellConfiguration: Equatable, Sendable {
    public var geometry: Geometry
    public var motion: Motion
    public var input: PlatformInput
    public var timing: Timing
    public var style: Style
    public var feedback: Feedback
    public var rendering: Rendering

    public init(
        geometry: Geometry = Geometry(),
        motion: Motion = Motion(),
        input: PlatformInput = PlatformInput(),
        timing: Timing = Timing(),
        style: Style = Style(),
        feedback: Feedback = Feedback(),
        rendering: Rendering = Rendering()
    ) {
        self.geometry = geometry
        self.motion = motion
        self.input = input
        self.timing = timing
        self.style = style
        self.feedback = feedback
        self.rendering = rendering
    }

    public static let iOSDefault = SwipeCellDefaultPresentationConfiguration.iOSConfiguration.configuration
    public static let macOSDefault = SwipeCellDefaultPresentationConfiguration.macOSConfiguration.configuration

    public static var platformDefault: SwipeCellConfiguration {
        #if os(macOS)
            macOSDefault
        #else
            iOSDefault
        #endif
    }

    /// Returns a copy with one or more configuration domains replaced.
    public func copy(
        geometry: Geometry? = nil,
        motion: Motion? = nil,
        input: PlatformInput? = nil,
        timing: Timing? = nil,
        style: Style? = nil,
        feedback: Feedback? = nil,
        rendering: Rendering? = nil
    ) -> SwipeCellConfiguration {
        SwipeCellConfiguration(
            geometry: geometry ?? self.geometry,
            motion: motion ?? self.motion,
            input: input ?? self.input,
            timing: timing ?? self.timing,
            style: style ?? self.style,
            feedback: feedback ?? self.feedback,
            rendering: rendering ?? self.rendering
        )
    }

    /// Returns a copy after mutating selected fields.
    public func copy(_ update: (inout SwipeCellConfiguration) -> Void) -> SwipeCellConfiguration {
        var copy = self
        update(&copy)
        return copy
    }

    /// Returns a copy after replacing one writable field, including nested fields.
    public func copy<Value>(
        setting keyPath: WritableKeyPath<SwipeCellConfiguration, Value>,
        to value: Value
    ) -> SwipeCellConfiguration {
        copy { configuration in
            configuration[keyPath: keyPath] = value
        }
    }

    nonisolated public struct Geometry: Equatable, Sendable {
        public var defaultActionWidth: CGFloat
        public var normalOpenCommitThreshold: SwipeCellNormalOpenCommitThreshold
        public var maxFullSwipeActivationFraction: CGFloat
        public var destructiveActivationDefaults: SwipeCellDestructiveActivationDefaults
        var defaultOpenThreshold: CGFloat

        public init(
            defaultActionWidth: CGFloat = 72,
            normalOpenCommitThreshold: SwipeCellNormalOpenCommitThreshold = .ratio(0.5),
            maxFullSwipeActivationFraction: CGFloat = 0.9,
            destructiveActivationDefaults: SwipeCellDestructiveActivationDefaults = .init()
        ) {
            self.init(
                defaultActionWidth: defaultActionWidth,
                normalOpenCommitThreshold: normalOpenCommitThreshold,
                maxFullSwipeActivationFraction: maxFullSwipeActivationFraction,
                destructiveActivationDefaults: destructiveActivationDefaults,
                defaultOpenThreshold: 48
            )
        }

        init(
            defaultActionWidth: CGFloat = 72,
            normalOpenCommitThreshold: SwipeCellNormalOpenCommitThreshold = .ratio(0.5),
            maxFullSwipeActivationFraction: CGFloat = 0.9,
            destructiveActivationDefaults: SwipeCellDestructiveActivationDefaults = .init(),
            defaultOpenThreshold: CGFloat
        ) {
            self.defaultActionWidth = defaultActionWidth
            self.normalOpenCommitThreshold = normalOpenCommitThreshold
            self.maxFullSwipeActivationFraction = maxFullSwipeActivationFraction
            self.destructiveActivationDefaults = destructiveActivationDefaults
            self.defaultOpenThreshold = defaultOpenThreshold
        }
    }

    nonisolated public struct Motion: Equatable, Sendable {
        public var rubberBandCoefficient: CGFloat
        public var maxRubberBandDistance: CGFloat
        public var settleMinDuration: TimeInterval
        public var settleMaxDuration: TimeInterval
        public var settleCurve: TimingCurve
        public var releasePredictionDuration: CGFloat
        public var horizontalOwnershipBias: CGFloat
        /// Active-drag + gesture-release motion model. Defaults to direct touch; `macOSDefault` selects
        /// indirect scroll (issue #28). `@_spi` while the configuration API is unsettled (#18): set it via
        /// the platform profile or an `@_spi(ManualDebug)` import, not the public `init`.
        @_spi(ManualDebug) public var trackingStyle: SwipeCellTrackingStyle = .directTouch

        public init(
            rubberBandCoefficient: CGFloat = 0.12,
            maxRubberBandDistance: CGFloat = 36,
            settleMinDuration: TimeInterval = 0.28,
            settleMaxDuration: TimeInterval = 0.70,
            settleCurve: TimingCurve = TimingCurve(c0x: 0.215, c0y: 0.61, c1x: 0.43, c1y: 1.0),
            releasePredictionDuration: CGFloat = 0.25,
            horizontalOwnershipBias: CGFloat = 0
        ) {
            self.rubberBandCoefficient = rubberBandCoefficient
            self.maxRubberBandDistance = maxRubberBandDistance
            self.settleMinDuration = settleMinDuration
            self.settleMaxDuration = settleMaxDuration
            self.settleCurve = settleCurve
            self.releasePredictionDuration = releasePredictionDuration
            self.horizontalOwnershipBias = horizontalOwnershipBias
        }
    }

    nonisolated public struct TimingCurve: Equatable, Sendable {
        public var c0x: Double
        public var c0y: Double
        public var c1x: Double
        public var c1y: Double

        public init(c0x: Double, c0y: Double, c1x: Double, c1y: Double) {
            self.c0x = c0x
            self.c0y = c0y
            self.c1x = c1x
            self.c1y = c1y
        }
    }

    nonisolated public struct PlatformInput: Equatable, Sendable {
        public var scrollWheelTrackpadScale: CGFloat
        public var scrollWheelLineScale: CGFloat
        public var scrollWheelMinStartDelta: CGFloat
        public var scrollWheelEndSynthesisDelay: TimeInterval
        /// Fast-flick reference distance (`D_fast`) for indirect-scroll mapping and legacy gate fallback.
        public var scrollWheelReferenceRevealDistance: CGFloat
        /// Slow-drag reference distance (`D_slow`) for adaptive indirect-scroll position mapping.
        public var scrollWheelSlowReferenceRevealDistance: CGFloat
        public var scrollWheelAdaptiveLowerDelta: CGFloat
        public var scrollWheelAdaptiveUpperDelta: CGFloat
        /// Raw fast-release window distance. Invalid values fall back to the historical `D_fast * 0.15`.
        public var scrollWheelFastReleaseIntentDistance: CGFloat
        /// Release-only open bypass when visual movement is already close to the normal-open threshold.
        public var scrollWheelFastReleaseOpenCommitRatio: CGFloat
        /// Container-specific profile applied by `resolved(for: .scrollView)`.
        public var scrollViewScrollWheelGainProfile: SwipeCellScrollWheelGainProfile
        /// Upper bound on the progress added by a single scroll event, so a fast flick (or a coarse line
        /// wheel) eases in instead of teleporting the row. macOS seed; QA calibrates on device.
        public var scrollWheelMaxProgressStep: CGFloat

        public init(
            scrollWheelTrackpadScale: CGFloat = 1,
            scrollWheelLineScale: CGFloat = 10,
            scrollWheelMinStartDelta: CGFloat = 1,
            scrollWheelEndSynthesisDelay: TimeInterval = 0.12,
            scrollWheelReferenceRevealDistance: CGFloat =
                SwipeCellScrollWheelGainProfile.listDefault.fastReferenceRevealDistance,
            scrollWheelSlowReferenceRevealDistance: CGFloat? = nil,
            scrollWheelAdaptiveLowerDelta: CGFloat =
                SwipeCellScrollWheelGainProfile.listDefault.adaptiveLowerDelta,
            scrollWheelAdaptiveUpperDelta: CGFloat =
                SwipeCellScrollWheelGainProfile.listDefault.adaptiveUpperDelta,
            scrollWheelFastReleaseIntentDistance: CGFloat? =
                SwipeCellScrollWheelGainProfile.listDefault.fastReleaseIntentDistance,
            scrollWheelFastReleaseOpenCommitRatio: CGFloat =
                SwipeCellScrollWheelGainProfile.listDefault.fastReleaseOpenCommitRatio,
            scrollViewScrollWheelGainProfile: SwipeCellScrollWheelGainProfile = .scrollViewDefault,
            scrollWheelMaxProgressStep: CGFloat = 0.2
        ) {
            self.scrollWheelTrackpadScale = scrollWheelTrackpadScale
            self.scrollWheelLineScale = scrollWheelLineScale
            self.scrollWheelMinStartDelta = scrollWheelMinStartDelta
            self.scrollWheelEndSynthesisDelay = scrollWheelEndSynthesisDelay
            self.scrollWheelReferenceRevealDistance = scrollWheelReferenceRevealDistance
            self.scrollWheelSlowReferenceRevealDistance =
                scrollWheelSlowReferenceRevealDistance ?? scrollWheelReferenceRevealDistance
            self.scrollWheelAdaptiveLowerDelta = scrollWheelAdaptiveLowerDelta
            self.scrollWheelAdaptiveUpperDelta = scrollWheelAdaptiveUpperDelta
            self.scrollWheelFastReleaseIntentDistance =
                scrollWheelFastReleaseIntentDistance ?? scrollWheelReferenceRevealDistance * 0.15
            self.scrollWheelFastReleaseOpenCommitRatio = scrollWheelFastReleaseOpenCommitRatio
            self.scrollViewScrollWheelGainProfile = scrollViewScrollWheelGainProfile
            self.scrollWheelMaxProgressStep = scrollWheelMaxProgressStep
        }
    }

    nonisolated public struct Timing: Equatable, Sendable {
        public var minimumScrollResetDelta: CGFloat
        public var hapticSuppression: TimeInterval
        public var scrollResetSuppression: TimeInterval
        public var tapCloseSuppression: TimeInterval

        public init(
            minimumScrollResetDelta: CGFloat = 1,
            hapticSuppression: TimeInterval = 0.14,
            scrollResetSuppression: TimeInterval = 0.35,
            tapCloseSuppression: TimeInterval = 0.25
        ) {
            self.minimumScrollResetDelta = minimumScrollResetDelta
            self.hapticSuppression = hapticSuppression
            self.scrollResetSuppression = scrollResetSuppression
            self.tapCloseSuppression = tapCloseSuppression
        }
    }

    nonisolated public struct Style: Equatable, Sendable {
        public var defaultRevealStyle: SwipeActionsRevealStyle
        public var tokenRevealMinScale: CGFloat
        public var tokenRevealMinOpacity: Double
        public var tokenProfile: SwipeActionTokenProfile
        public var deformationOpacityFalloff: Double
        public var settlingAnimation: Animation

        public init(
            defaultRevealStyle: SwipeActionsRevealStyle = .slot,
            tokenRevealMinScale: CGFloat = 0.5,
            tokenRevealMinOpacity: Double = 0,
            tokenProfile: SwipeActionTokenProfile = .iOSDefault,
            deformationOpacityFalloff: Double = 0.35,
            settlingAnimation: Animation = .easeInOut(duration: 0.3)
        ) {
            self.defaultRevealStyle = defaultRevealStyle
            self.tokenRevealMinScale = tokenRevealMinScale
            self.tokenRevealMinOpacity = tokenRevealMinOpacity
            self.tokenProfile = tokenProfile
            self.deformationOpacityFalloff = deformationOpacityFalloff
            self.settlingAnimation = settlingAnimation
        }
    }

    nonisolated public struct Feedback: Equatable, Sendable {
        public var hapticPolicy: SwipeCellHapticPolicy

        public init(
            hapticPolicy: SwipeCellHapticPolicy = .standard
        ) {
            self.hapticPolicy = hapticPolicy
        }
    }

    nonisolated public struct Rendering: Equatable, Sendable {
        /// Rasterizes the composed action shell when enabled.
        ///
        /// Leave this disabled unless a specific row composition has been profiled or smoke-tested.
        /// The offscreen pass can help complex visuals, but it can also hurt simple rows.
        public var actionShellDrawingGroup: SwipeCellDrawingGroupMode

        public init(
            actionShellDrawingGroup: SwipeCellDrawingGroupMode = .disabled
        ) {
            self.actionShellDrawingGroup = actionShellDrawingGroup
        }
    }
}

private struct SwipeCellConfigurationEnvironmentKey: EnvironmentKey {
    static let defaultValue = SwipeCellConfiguration.platformDefault
}

extension EnvironmentValues {
    public var swipeCellConfiguration: SwipeCellConfiguration {
        get { self[SwipeCellConfigurationEnvironmentKey.self] }
        set { self[SwipeCellConfigurationEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Replaces the inherited SwipeCell configuration for this view subtree.
    ///
    /// This temporary spelling is intentionally local to the #24 configuration carrier; #18 may still
    /// revise public naming before v3 API freeze.
    public func swipeCellConfiguration(_ configuration: SwipeCellConfiguration) -> some View {
        environment(\.swipeCellConfiguration, configuration)
    }

    /// Mutates the inherited SwipeCell configuration, allowing nested scopes to override one field.
    ///
    /// The closure receives the already-resolved environment value, so omitted fields continue to
    /// inherit from outer configuration rather than from a parallel optional shadow model.
    public func swipeCellConfiguration(
        _ update: @escaping (inout SwipeCellConfiguration) -> Void
    ) -> some View {
        modifier(SwipeCellConfigurationOverrideModifier(update: update))
    }
}

private struct SwipeCellConfigurationOverrideModifier: ViewModifier {
    let update: (inout SwipeCellConfiguration) -> Void

    @Environment(\.swipeCellConfiguration) private var inheritedConfiguration

    func body(content: Content) -> some View {
        content.environment(
            \.swipeCellConfiguration,
            inheritedConfiguration.copy(update)
        )
    }
}

extension SwipeCellConfiguration {
    func resolved(for container: SwipeCellContainer) -> SwipeCellConfiguration {
        #if os(macOS)
            switch container {
            case .list:
                return self
            case .scrollView:
                let profile = input.scrollViewScrollWheelGainProfile
                return copy {
                    $0.input.scrollWheelReferenceRevealDistance = profile.fastReferenceRevealDistance
                    $0.input.scrollWheelSlowReferenceRevealDistance = profile.slowReferenceRevealDistance
                    $0.input.scrollWheelAdaptiveLowerDelta = profile.adaptiveLowerDelta
                    $0.input.scrollWheelAdaptiveUpperDelta = profile.adaptiveUpperDelta
                    $0.input.scrollWheelFastReleaseIntentDistance = profile.fastReleaseIntentDistance
                    $0.input.scrollWheelFastReleaseOpenCommitRatio = profile.fastReleaseOpenCommitRatio
                }
            }
        #else
            return self
        #endif
    }
}

struct SwipeCellResolvedCellConfiguration: Equatable {
    let configuration: SwipeCellConfiguration
    let actionWidth: CGFloat
    let revealStyle: SwipeActionsRevealStyle
    let settlingAnimation: Animation
    let openThreshold: CGFloat

    init(
        configuration: SwipeCellConfiguration,
        actionWidth: CGFloat? = nil,
        revealStyle: SwipeActionsRevealStyle? = nil,
        settlingAnimation: Animation? = nil,
        openThreshold: CGFloat? = nil
    ) {
        self.configuration = configuration
        self.actionWidth = Self.positiveDistance(
            actionWidth,
            fallback: configuration.geometry.defaultActionWidth
        )
        self.revealStyle = revealStyle ?? configuration.style.defaultRevealStyle
        self.settlingAnimation = settlingAnimation ?? configuration.style.settlingAnimation
        self.openThreshold = openThreshold ?? configuration.geometry.defaultOpenThreshold
    }

    private static func positiveDistance(_ value: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let value, value.isFinite, value > 0 else { return fallback }
        return value
    }
}
