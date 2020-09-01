import SwiftUI
import Combine

enum CellStatus:String{
    case showCell,showLeftSlot,showRightSlot
}

enum FeedStatus{
    case none,feedOnce,feedAgain
}

struct SwipeCellModifier:ViewModifier{
    @State var cellPosition:SwipeCellSlotPosition
    let leftSlot:SwipeCellSlot?
    let rightSlot:SwipeCellSlot?
    let swipeCellStyle:SwipeCellStyle
    let clip:Bool
    
    @State var status:CellStatus = .showCell
    @State var showDalayButtonWith:CGFloat = 0
    
    @State var offset:CGFloat = 0
    
    @State var frameWidth:CGFloat = 99999
    @State var leftOffset:CGFloat = -10000
    @State var rightOffset:CGFloat = 10000
    @State var spaceWidth:CGFloat = 0
    
    
    let cellID = UUID()
   
    @State var currentCellID:UUID? = nil
    @State var resetNotice = NotificationCenter.default.publisher(for: .swipeCellReset)
    
    @State var feedStatus:FeedStatus = .none
    
    
    var leftSlotWidth:CGFloat{
        guard let ls = leftSlot else {return 0}
        return CGFloat(ls.slots.count) * ls.buttonWidth
    }
    
    var rightSlotWidth:CGFloat{
        guard let rs = rightSlot else {return 0}
        return CGFloat(rs.slots.count) * rs.buttonWidth
    }
    
    var leftdestructiveWidth:CGFloat{
        max(swipeCellStyle.destructiveWidth,leftSlotWidth + 70)
    }
    
    var rightdestructiveWidth:CGFloat{
        max(swipeCellStyle.destructiveWidth,rightSlotWidth + 70)
    }
    @Environment(\.editMode) var editMode
    
    @State var timer = Timer.publish(every: 1, on: .main, in: .common)
    @State var cancellables:Set<AnyCancellable> = []
    
    func buttonView(_ slot:SwipeCellSlot,_ i:Int) -> some View{
        let button = slot.slots[i]
        let viewStyle = button.buttonStyle
        
        func emptyView() -> AnyView{
            AnyView(
                Text("nil").foregroundColor(button.titleColor)
            )
        }
        
        switch viewStyle{
        case .image:
            guard let image = button.systemImage else {
                return emptyView()
            }
            return AnyView(
                Image(systemName: image)
                    .font(.system(size: 23))
                    .foregroundColor(button.imageColor)
            )
        case .title:
            guard let title = button.title else {
                return emptyView()
            }
            return AnyView(
                Text(title)
                    .font(.callout)
                    .bold()
                    .foregroundColor(button.titleColor)
            )
        case .titleAndImage:
            guard let title = button.title,let image = button.systemImage else {
                return emptyView()
            }
            return AnyView(
                VStack(spacing:5){
                    Image(systemName: image)
                        .font(.system(size: 23))
                        .foregroundColor(button.imageColor)
                    Text(title)
                        .font(.callout)
                        .bold()
                        .foregroundColor(button.titleColor)
                }
            )
            
        case .view:
            guard let view = button.view else {
                return emptyView()
            }
            return view()
        }
    }
    
    
    
    func slotView(slot:SwipeCellSlot,i:Int,position:SwipeCellSlotPosition)-> some View{
        let buttons = slot.slots
        
        return Rectangle()
            .fill(buttons[i].backgroundColor)
            .overlay(
                ZStack(alignment: position == .left ? .trailing : .leading){
                    Color.clear

                        buttonView(slot, i)
                            .contentShape(Rectangle())
                            .onTapGesture{
                                if slot.slotStyle == .destructiveDelay && i == slot.slots.count - 1 {
                                withAnimation(.easeInOut){
                                    if position == .left {
                                        showDalayButtonWith = slot.buttonWidth * CGFloat(slot.slots.count - 1)
                                    }
                                    else {
                                        showDalayButtonWith = -slot.buttonWidth * CGFloat(slot.slots.count - 1)
                                    }
                                }
                                }
                                buttons[i].action()
                                if buttons[i].feedback {
                                    successFeedBack(swipeCellStyle.vibrationForButton)
                                }
                                if !(slot.slotStyle == .destructiveDelay && i == slot.slots.count - 1) {
                                resetStatus()
                                }
                            }
                            .frame(width:slot.buttonWidth)
                            .offset(x:spaceWidth)
                            .alignmentGuide(.trailing, computeValue: { d in
                                if slot.slotStyle == .destructive && slot.slots.count == 1 && position == .left {
                                    var result:CGFloat = 0
                                    if offset > slot.buttonWidth {
                                        result =  d[.trailing] + offset - slot.buttonWidth
                                    }
                                    else {
                                        result =  d[.trailing]
                                    }
                                    return result
                                } else {
                                 return d[.trailing]
                                }
                            })
                            .alignmentGuide(.leading, computeValue: {d in
                                if slot.slotStyle == .destructive && slot.slots.count == 1 && position == .right {
                                    var result:CGFloat = 0
                                    if abs(offset) > slot.buttonWidth {
                                        result =  d[.leading]  + slot.buttonWidth - abs(offset)
                                    }
                                    else {
                                        result =  d[.leading]
                                    }
                                    
                                    return result
                                }
                                else {
                                return d[.leading]
                                }
                            })
                            
                }
            )
            .contentShape(Rectangle())
            .onTapGesture{
                resetStatus()
            }
    }
    
//    func getNameId(i:Int,position:SwipeCellSlotPosition) -> Int {
//        cellID.hashValue + i + position.rawValue
//    }
    
//    @State var count = 0
    
    func loadButtons(_ slot:SwipeCellSlot,position:SwipeCellSlotPosition,frame:CGRect) -> some View{
        let buttons = slot.slots
        
        if slot.slotStyle == .destructive && leftOffset == -10000 && position == .left {
            leftOffset = cellOffset(i: buttons.count - 1, count: buttons.count, position: position,width: frame.width,slot:slot)
        }
        
        if slot.slotStyle == .destructive && rightOffset == 10000 && position == .right {
            rightOffset = cellOffset(i: buttons.count - 1, count: buttons.count, position: position,width: frame.width,slot:slot)
        }
        
        if slot.slotStyle == .destructive {
            //单button的销毁按钮
            if buttons.count == 1{
                return AnyView(
                    slotView(slot: slot, i: 0, position: position)
                        .offset(x:cellOffset(i: 0, count: buttons.count, position: position,width: frame.width,slot:slot))
                )
            }
            else {
                return AnyView(
                    ZStack{
                        ForEach(0..<buttons.count - 1 ,id:\.self){ i in
                            slotView(slot: slot, i: i, position: position)
                                .offset(x:cellOffset(i: i, count: buttons.count, position: position,width: frame.width,slot:slot))
                                .zIndex(Double(i))
                        }
                        //销毁按钮
                        if slot.slotStyle == .destructive && position == .left {
                        slotView(slot: slot, i: buttons.count - 1, position: .left)
                            .zIndex(10)
                            .offset(x:leftOffset)
                            .animation(.easeInOut)

                        }

                        if slot.slotStyle == .destructive && position == .right {
                            slotView(slot: slot, i: buttons.count - 1, position: .right)
                              .offset(x:rightOffset)
                              .zIndex(10)
                              .animation(.easeInOut)
                        }
                    }
                )
            }
        }
        else {
            
            return AnyView(
                ZStack{
                    ForEach(0..<buttons.count ,id:\.self){ i in
                        if slot.slotStyle == .destructiveDelay && i == buttons.count - 1 {
                        slotView(slot: slot, i: i, position: position)
                            .offset(x:cellOffset(i: i, count: buttons.count, position: position,width: frame.width,slot:slot) + showDalayButtonWith)
                            .zIndex(Double(i))
                        }
                        else {
                            slotView(slot: slot, i: i, position: position)
                                .offset(x:cellOffset(i: i, count: buttons.count, position: position,width: frame.width,slot:slot) )
                                .zIndex(Double(i))
                        }
                    }
                }
            )
        }
    }
    
    func offsetForSingleDestructiveButton(slot:SwipeCellSlot,position:SwipeCellSlotPosition){
        if slot.slotStyle == .destructive && slot.slots.count == 1 {
            switch position{
            case .left:
                print("left")
                DispatchQueue.main.async {
                spaceWidth = 0
                }
                if feedStatus == .feedOnce {
                    DispatchQueue.main.async {
                    withAnimation(.easeInOut){
                        spaceWidth = offset - slot.buttonWidth
                    }
                    }
                }
                if feedStatus == .feedAgain{
                    DispatchQueue.main.async {
                    withAnimation(.easeInOut){
                        spaceWidth = 0
                    }
                    }
                }

            case .right:
                DispatchQueue.main.async {
                spaceWidth = 0
                }
                if feedStatus == .feedOnce {
                    DispatchQueue.main.async {
                    withAnimation(.easeInOut){
                    spaceWidth = offset + slot.buttonWidth
                    }
                    }
                }
                if feedStatus == .feedAgain {
                    DispatchQueue.main.async {
                    withAnimation(.easeInOut){
                    spaceWidth = 0
                    }
                    }
                }
            default:
                DispatchQueue.main.async {
                    withAnimation(.easeInOut){
                spaceWidth = 0
                    }
                }
            }
        }
        else {
            DispatchQueue.main.async {
                withAnimation(.easeInOut){
            spaceWidth = 0
                }
            }
        }
    }
    
    func cellOffset(i:Int,count:Int,position:SwipeCellSlotPosition,width:CGFloat,slot:SwipeCellSlot) -> CGFloat {
        
        
        if frameWidth == 99999 {
            DispatchQueue.main.async {
                frameWidth = width
            }
        }
        var result:CGFloat = 0
        
        let cellOffset = offset * (CGFloat(count - i) / CGFloat(count) )
        if position == .left {
            result = -width + cellOffset
            
        }
        else {
            result = width + cellOffset
        }
        

        return result
    }
    
    func lastButtonOffset(position:SwipeCellSlotPosition,slot:SwipeCellSlot?) {
    
        guard let slot = slot, slot.slotStyle == .destructive else {

            if position == .left {
                withAnimation(.easeInOut){
                leftOffset = -frameWidth
                }
            } else {
                withAnimation(.easeInOut){
                rightOffset = frameWidth
                }
            }
            return
        }
        
        let count = slot.slots.count
        
        var result:CGFloat = 0
        
        let cellOffset = offset * (CGFloat(1) / CGFloat(count) )
        if position == .left {
            withAnimation(.easeInOut){
            result = -frameWidth + cellOffset
            }
            
        }
        else {
            withAnimation(.easeInOut){
            result = frameWidth + cellOffset
            }
        }
        
        if feedStatus == .feedOnce {
            if position == .left {
                withAnimation(.easeInOut){
                result = -frameWidth + offset
                }
                withAnimation(.easeInOut){
                    leftOffset = result
                }
            }
            else {
                withAnimation(.easeInOut){
                result = frameWidth + offset
                }
                withAnimation(.easeInOut){
                    rightOffset = result
                }
            }
        } else if feedStatus == .feedAgain {
            if position == .left {
                withAnimation(.easeInOut){
                    leftOffset = result
                }
            }
            else {
                withAnimation(.easeInOut){
                    rightOffset = result
                }
            }
        }
        else {
            
            if position == .left {
                withAnimation(.easeInOut){
                leftOffset = result
                }
            }
            else {
                withAnimation(.easeInOut){
                rightOffset = result
                }
            }
        }
    }
    
}



