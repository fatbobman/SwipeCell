//
//  Created by Yang Xu on 2020/8/4.
//

import SwiftUI

extension View{
    public func swipeCell(cellPosition:SwipeCellSlotPosition,leftSlot:SwipeCellSlot?,rightSlot:SwipeCellSlot?,swipeCellStyle:SwipeCellStyle = .defaultStyle(),disable:Bool = false) -> some View{
        var d = disable
        if cellPosition == .none {
            d = true
        }
        if d {
          return  AnyView(self.listRowInsets(EdgeInsets()))
        }
        else {
          return  AnyView(
                self
                  .modifier(SwipeCellModifier(cellPosition: cellPosition, leftSlot: leftSlot, rightSlot: rightSlot, swipeCellStyle: swipeCellStyle))
            )
        }
    }
}



extension View{
    public func hidden(_ condition:Bool) -> some View{
        Group{
        if condition {
            AnyView(self)
        }
        else {
            AnyView(EmptyView())
        }
        }
    }
    
    func toAnyView() -> AnyView{
        AnyView(self)
    }
    
     @ViewBuilder func ifIs<T>(_ condition: Bool, transform: (Self) -> T) -> some View where T: View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    func doSomething(_ action:()->Void) -> some View{
        action()
        return self
    }
}

extension Notification.Name{
  public static let swipeCellReset = Notification.Name("com.swipeCell.reset")
}

//struct CellOffset:ViewModifier{
//    let i:Int
//    let count:Int
//    let position:SwipeCellSlotPosition
//    let width:CGFloat
//    let slot:SwipeCellSlot
//    @Binding var feedStatus:FeedStatus
//    @State var offset:CGFloat = 0
//    
//    init(i:Int,count:Int,position:SwipeCellSlotPosition,width:CGFloat,slot:SwipeCellSlot,feedStatus:Binding<FeedStatus>){
//        self.i = i
//        self.count = count
//        self.position = position
//        self.width = width
//        self.slot = slot
//        self._feedStatus = feedStatus
//    }
//    func body(content: Content) -> some View {
//        content
//            .offset(x:offset)
//            .onAppear{
////                withAnimation(.easeInOut){
//                offset = cellOffset(i: i, count:count, position: position,width: width,slot:slot)
////                }
//            }
//    }
//    
//    private func cellOffset(i:Int,count:Int,position:SwipeCellSlotPosition,width:CGFloat,slot:SwipeCellSlot) -> CGFloat{
//        var n = i
//        if slot.slotStyle == .destructive && n == count - 1  && feedStatus == .feedOnce {
//            n = 0
//        }
//        if slot.slotStyle == .destructive && n == count - 1 && feedStatus == .feedAgain {
//            n = i
//        }
//        let cellOffset = offset * (CGFloat(count - n) / CGFloat(count) )
//        if position == .left {
//            return -width + cellOffset
//        }
//        else {
//            return width + cellOffset
//        }
//    }
//}
