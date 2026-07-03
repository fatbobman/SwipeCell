import SwiftUI

/// Type-erased fill style for action chrome.
///
/// Plain colors keep value equality. Arbitrary `ShapeStyle` values need a caller-supplied key to
/// participate in descriptor equality; unkeyed styles render but compare unequal by design.
nonisolated public struct SwipeActionTint: ShapeStyle, Equatable {
    private struct StableKey: @unchecked Sendable, Equatable {
        let value: AnyHashable

        static func == (lhs: StableKey, rhs: StableKey) -> Bool {
            lhs.value == rhs.value
        }
    }

    private enum Identity: Sendable {
        case color(Color)
        case key(StableKey)
        case unkeyed
    }

    private let style: AnyShapeStyle
    private let identity: Identity

    public init(_ color: Color) {
        self.style = AnyShapeStyle(color)
        self.identity = .color(color)
    }

    public init<Style: ShapeStyle>(_ style: Style) {
        if let tint = style as? SwipeActionTint {
            self = tint
        } else {
            self.style = AnyShapeStyle(style)
            self.identity = .unkeyed
        }
    }

    public init<Style: ShapeStyle>(
        key: some Hashable & Sendable,
        _ style: Style
    ) {
        self.style = AnyShapeStyle(style)
        self.identity = .key(StableKey(value: AnyHashable(key)))
    }

    public func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        style
    }

    public static func == (lhs: SwipeActionTint, rhs: SwipeActionTint) -> Bool {
        switch (lhs.identity, rhs.identity) {
        case (.color(let lhsColor), .color(let rhsColor)):
            lhsColor == rhsColor
        case (.key(let lhsKey), .key(let rhsKey)):
            lhsKey == rhsKey
        case (.unkeyed, _), (_, .unkeyed):
            false
        case (.color, .key), (.key, .color):
            false
        }
    }
}
