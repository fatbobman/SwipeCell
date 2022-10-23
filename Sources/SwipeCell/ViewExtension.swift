//
//  Created by Yang Xu on 2020/8/4.
//

import SwiftUI

extension View {
    /// Add a swipe cell modifier to the current view
    /// - Parameters:
    ///   - cellPosition: <#cellPosition description#>
    ///   - leftSlot: <#leftSlot description#>
    ///   - rightSlot: <#rightSlot description#>
    ///   - swipeCellStyle: <#swipeCellStyle description#>
    ///   - clip: <#clip description#>
    ///   - disable: <#disable description#>
    ///   - initalStatus: The initial status for the swipe cell. This can be used to assist with onboarding
    ///   - initialStatusResetDelay: The amount of time in seconds from when the view appears to when the initial status is reset
    /// - Returns: <#description#>
    @ViewBuilder public func swipeCell(
        cellPosition: SwipeCellSlotPosition,
        leftSlot: SwipeCellSlot?,
        rightSlot: SwipeCellSlot?,
        swipeCellStyle: SwipeCellStyle = .defaultStyle(),
        clip: Bool = true,
        disable: Bool = false,
        initalStatus: CellStatus = .showCell,
        initialStatusResetDelay: TimeInterval = 0.0
    ) -> some View {
        if cellPosition == .none ? true : disable {
            self.listRowInsets(EdgeInsets())
        } else {
            self
                .modifier(
                    SwipeCellModifier(
                        cellPosition: cellPosition,
                        leftSlot: leftSlot,
                        rightSlot: rightSlot,
                        swipeCellStyle: swipeCellStyle,
                        clip: clip,
                        initialStatusResetDelay: initialStatusResetDelay,
                        initialStatus: initalStatus
                    )
                )
        }
    }
}

extension View {
    @ViewBuilder public func _hidden(_ condition: Bool) -> some View {
        Group {
            if condition {
                self
            }
            else {
                EmptyView()
            }
        }
    }

    @ViewBuilder func ifIs<T>(_ condition: Bool, transform: (Self) -> T) -> some View
    where T: View {
        if condition {
            transform(self)
        }
        else {
            self
        }
    }

    func doSomething(_ action: () -> Void) -> some View {
        action()
        return self
    }
}

extension Notification.Name {
    public static let swipeCellReset = Notification.Name("com.swipeCell.reset")
}

public struct CellStatusKey: EnvironmentKey {
    public static var defaultValue: CellStatus = .showCell
}

extension EnvironmentValues {
    public var cellStatus: CellStatus {
        get { self[CellStatusKey.self] }
        set {
            self[CellStatusKey.self] = newValue
        }
    }
}
