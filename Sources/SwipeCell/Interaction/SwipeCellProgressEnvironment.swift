import SwiftUI

private struct SwipeCellNormalOpenProgressEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    public var swipeCellNormalOpenProgress: CGFloat {
        get { self[SwipeCellNormalOpenProgressEnvironmentKey.self] }
        set { self[SwipeCellNormalOpenProgressEnvironmentKey.self] = min(max(newValue, 0), 1) }
    }
}
