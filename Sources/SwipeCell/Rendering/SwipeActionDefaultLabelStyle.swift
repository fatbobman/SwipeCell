import SwiftUI

nonisolated public struct SwipeActionDefaultLabelStyle: Equatable, Sendable {
    public var iconFont: Font
    public var titleFont: Font
    public var iconSlotSize: CGFloat {
        didSet {
            iconSlotSize = Self.sanitizedPositiveMetric(iconSlotSize, fallback: Self.defaultIconSlotSize)
        }
    }
    public var textSlotHeight: CGFloat {
        didSet {
            textSlotHeight = Self.sanitizedPositiveMetric(textSlotHeight, fallback: Self.defaultTextSlotHeight)
        }
    }

    public init(
        iconFont: Font = Self.defaultIconFont,
        titleFont: Font = Self.defaultTitleFont,
        iconSlotSize: CGFloat = Self.defaultIconSlotSize,
        textSlotHeight: CGFloat = Self.defaultTextSlotHeight
    ) {
        self.iconFont = iconFont
        self.titleFont = titleFont
        self.iconSlotSize = Self.sanitizedPositiveMetric(iconSlotSize, fallback: Self.defaultIconSlotSize)
        self.textSlotHeight = Self.sanitizedPositiveMetric(textSlotHeight, fallback: Self.defaultTextSlotHeight)
    }

    public static let `default` = SwipeActionDefaultLabelStyle()

    public static func system(
        iconSize: CGFloat = defaultIconPointSize,
        titleSize: CGFloat = defaultTitlePointSize,
        iconWeight: Font.Weight = .semibold,
        titleWeight: Font.Weight = .semibold,
        iconSlotSize: CGFloat = defaultIconSlotSize,
        textSlotHeight: CGFloat = defaultTextSlotHeight
    ) -> SwipeActionDefaultLabelStyle {
        SwipeActionDefaultLabelStyle(
            iconFont: .system(
                size: sanitizedPositiveMetric(iconSize, fallback: defaultIconPointSize),
                weight: iconWeight
            ),
            titleFont: .system(
                size: sanitizedPositiveMetric(titleSize, fallback: defaultTitlePointSize),
                weight: titleWeight
            ),
            iconSlotSize: iconSlotSize,
            textSlotHeight: textSlotHeight
        )
    }

    @usableFromInline static let defaultIconFont: Font =
        SwipeCellDefaultPresentationConfiguration.defaultLabelMetrics.iconFont
    @usableFromInline static let defaultTitleFont: Font =
        SwipeCellDefaultPresentationConfiguration.defaultLabelMetrics.titleFont
    @usableFromInline static let defaultIconSlotSize: CGFloat =
        SwipeCellDefaultPresentationConfiguration.defaultLabelMetrics.iconSlotSize
    @usableFromInline static let defaultTextSlotHeight: CGFloat =
        SwipeCellDefaultPresentationConfiguration.defaultLabelMetrics.textSlotHeight
    @usableFromInline static let defaultIconPointSize: CGFloat = 17
    @usableFromInline static let defaultTitlePointSize: CGFloat = 11

    static func sanitizedPositiveMetric(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else {
            return fallback
        }

        return value
    }
}

private struct SwipeActionDefaultLabelStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue = SwipeActionDefaultLabelStyle.default
}

extension EnvironmentValues {
    public var swipeActionDefaultLabelStyle: SwipeActionDefaultLabelStyle {
        get { self[SwipeActionDefaultLabelStyleEnvironmentKey.self] }
        set { self[SwipeActionDefaultLabelStyleEnvironmentKey.self] = newValue }
    }
}

extension View {
    public func swipeActionDefaultLabelStyle(_ style: SwipeActionDefaultLabelStyle) -> some View {
        environment(\.swipeActionDefaultLabelStyle, style)
    }
}
