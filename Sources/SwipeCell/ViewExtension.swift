//
//  Created by Yang Xu on 2020/8/4.
//

import SwiftUI

extension View {
    public func swipeCell(
        cellPosition: SwipeCellSlotPosition,
        leftSlot: SwipeCellSlot?,
        rightSlot: SwipeCellSlot?,
        swipeCellStyle: SwipeCellStyle = .defaultStyle(),
        clip: Bool = true,
        disable: Bool = false
    ) -> some View {
        var d = disable
        if cellPosition == .none {
            d = true
        }
        if d {
            return AnyView(self.listRowInsets(EdgeInsets()))
        }
        else {
            return
                AnyView(
                self
                    .modifier(
                        SwipeCellModifier(
                            cellPosition: cellPosition,
                            leftSlot: leftSlot,
                            rightSlot: rightSlot,
                            swipeCellStyle: swipeCellStyle,
                            clip: clip
                        )
                    )

            )
        }
    }
}

extension View {
    public func _hidden(_ condition: Bool) -> some View {
        Group {
            if condition {
                AnyView(self)
            }
            else {
                AnyView(EmptyView())
            }
        }
    }

    func toAnyView() -> AnyView {
        AnyView(self)
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
