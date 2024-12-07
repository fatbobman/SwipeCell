//
//  Created by Yang Xu on 2020/8/6.
//

import Foundation
import SwiftUI

extension SwipeCellModifier {
    func getGesture() -> _EndedGesture<_ChangedGesture<DragGesture>> {
        //为了避免editMode切换时的异常动画,所以在进入editmode后仍然继续绘制Slots,只是对手势做了处理,避免了滑动
        let nonEditGragMinDistance: CGFloat = {
            if #available(iOS 18, *) {
            #if compiler(>=6.0)
                return 20
            #endif
            }
            return 0
        }()
        return DragGesture(
            minimumDistance: editMode?.wrappedValue == .active ? 10000 : nonEditGragMinDistance,
            coordinateSpace: .local
        )
        .onChanged { value in
            var width = value.translation.width
            cancellables.removeAll()  //只要移动,定时清零
            
            // A gesture happened so don't reset
            self.shouldResetStatusOnAppear = false

            if currentCellID != cellID {
                currentCellID = cellID
                NotificationCenter.default.post(Notification(name: .swipeCellReset, object: cellID))
            }

            switch status {

            //在正常状态下
            case .showCell:
                if cellPosition == .left { width = max(0, width) }
                if cellPosition == .right { width = min(0, width) }

                //向右侧滑动
                if width > 0 {
                    if leftSlot?.slotStyle == .destructive {
                        //确保只在经过时震动一次,如果未释放,返回时还会震动一次,但并不激发action
                        if width > leftdestructiveWidth
                            && (feedStatus == .none || feedStatus == .feedAgain)
                        {
                            successFeedBack(swipeCellStyle.vibrationForDestructive)
                            feedStatus = .feedOnce
                        }
                        if width <= leftdestructiveWidth && feedStatus == .feedOnce {
                            successFeedBack(swipeCellStyle.vibrationForDestructive)
                            feedStatus = .feedAgain
                        }
                        //超过阈值,则移动减速
                        if width > leftdestructiveWidth {
                            width = leftdestructiveWidth + (width - leftdestructiveWidth) / 2
                        }
                    }
                    else {
                        //非销毁按钮,超过阈值移动减速
                        if width > leftSlotWidth {
                            width = leftSlotWidth + (width - leftSlotWidth) / 2
                        }
                    }
                }

                //向左侧滑动
                if width < 0 {
                    if rightSlot?.slotStyle == .destructive {
                        if width < -rightdestructiveWidth
                            && (feedStatus == .none || feedStatus == .feedAgain)
                        {
                            successFeedBack(swipeCellStyle.vibrationForDestructive)
                            feedStatus = .feedOnce
                        }
                        if width >= -rightdestructiveWidth && feedStatus == .feedOnce {
                            successFeedBack(swipeCellStyle.vibrationForDestructive)
                            feedStatus = .feedAgain
                        }
                        if width < -rightdestructiveWidth {
                            let tmp = -(-width - rightdestructiveWidth) / 2
                            width = -rightdestructiveWidth + tmp
                        }
                    }
                    else {
                        if width < -rightSlotWidth {
                            let tmp = -(-width - rightSlotWidth) / 2
                            width = -rightSlotWidth + tmp
                        }
                    }
                }

                withAnimation(.easeInOut) {
                    offset = width
                }
                lastButtonOffset(position: .left, slot: leftSlot)
                lastButtonOffset(position: .right, slot: rightSlot)

            //已处于左侧按钮完全展示状态
            case .showLeftSlot:
                if leftSlot?.slotStyle == .destructive {
                    if width > 0 {
                        if width + leftSlotWidth > leftdestructiveWidth
                            && (feedStatus == .none || feedStatus == .feedAgain)
                        {
                            successFeedBack(swipeCellStyle.vibrationForDestructive)
                            feedStatus = .feedOnce
                        }
                        if width + leftSlotWidth <= leftdestructiveWidth && feedStatus == .feedOnce
                        {
                            successFeedBack(swipeCellStyle.vibrationForDestructive)
                            feedStatus = .feedAgain
                        }
                        //超过阈值,则移动减速
                        if width + leftSlotWidth > leftdestructiveWidth {
                            withAnimation(.easeInOut) {
                                offset =
                                    leftdestructiveWidth
                                    + (width + leftSlotWidth - leftdestructiveWidth) / 5
                                lastButtonOffset(position: .left, slot: leftSlot)
                                lastButtonOffset(position: .right, slot: rightSlot)
                            }
                        }
                        else {
                            withAnimation(.easeInOut) {
                                offset = leftSlotWidth + width
                                lastButtonOffset(position: .left, slot: leftSlot)
                                lastButtonOffset(position: .right, slot: rightSlot)
                            }
                        }
                        return
                    }
                    else {
                        withAnimation(.easeInOut) {
                            offset = leftSlotWidth + width
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                        }
                    }
                    return
                }
                else {
                    if width > 0 {
                        withAnimation(.easeInOut) {
                            offset = leftSlotWidth + width / 10
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                        }
                    }
                    else {
                        withAnimation(.easeInOut) {
                            offset = leftSlotWidth + width
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                        }
                    }
                    return
                }

            case .showRightSlot:
                if rightSlot?.slotStyle == .destructive {
                    if width < 0 {
                        if -width + rightSlotWidth > rightdestructiveWidth
                            && (feedStatus == .none || feedStatus == .feedAgain)
                        {
                            successFeedBack(swipeCellStyle.vibrationForDestructive)
                            feedStatus = .feedOnce
                        }
                        if -width + rightSlotWidth <= rightdestructiveWidth
                            && feedStatus == .feedOnce
                        {
                            successFeedBack(swipeCellStyle.vibrationForDestructive)
                            feedStatus = .feedAgain
                        }
                        //超过阈值,则移动减速
                        if -width + rightSlotWidth > rightdestructiveWidth {
                            let tmp = -(-width + rightSlotWidth - rightdestructiveWidth) / 5
                            withAnimation(.easeInOut) {
                                offset = -rightdestructiveWidth + tmp
                                lastButtonOffset(position: .left, slot: leftSlot)
                                lastButtonOffset(position: .right, slot: rightSlot)
                            }
                        }
                        else {
                            withAnimation(.easeInOut) {
                                offset = -rightSlotWidth + width
                                lastButtonOffset(position: .left, slot: leftSlot)
                                lastButtonOffset(position: .right, slot: rightSlot)
                            }
                        }
                        return
                    }
                    else {
                        withAnimation(.easeInOut) {
                            offset = -rightSlotWidth + width
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                        }
                    }
                    return
                }
                else {
                    if width > 0 {
                        withAnimation(.easeInOut) {
                            offset = -rightSlotWidth + width
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                        }
                    }
                    else {
                        withAnimation(.easeInOut) {
                            offset = -rightSlotWidth + width / 10
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                        }
                    }
                    return
                }

            }

        }.onEnded { value in
            if currentCellID != cellID {
                currentCellID = cellID
                NotificationCenter.default.post(Notification(name: .swipeCellReset, object: cellID))
            }
            let width = value.translation.width

            if feedStatus == .feedAgain
                && (swipeCellStyle.destructiveWidth - abs(offset)) > swipeCellStyle.dismissWidth
            {
                resetStatus()
                return
            }

            switch status {
            case .showCell:
                if abs(width) < swipeCellStyle.appearWidth {
                    resetStatus()
                    return
                }

                if leftSlot?.slotStyle != .destructive {
                    if (cellPosition == .left || cellPosition == .both)
                        && width >= swipeCellStyle.appearWidth
                    {
                        withAnimation(leftSlot?.appearAnimation) {
                            offset = leftSlotWidth
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                            setStatus(.showLeftSlot)
                        }
                        return
                    }
                }
                else {
                    if (cellPosition == .left || cellPosition == .both)
                        && width >= swipeCellStyle.appearWidth && width <= leftdestructiveWidth
                    {
                        withAnimation(leftSlot?.appearAnimation) {
                            offset = leftSlotWidth
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                            setStatus(.showLeftSlot)
                        }
                        return
                    }

                    if (cellPosition == .left || cellPosition == .both)
                        && width > leftdestructiveWidth
                    {
                        resetStatus()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            leftSlot?.slots.last?.action()
                        }
                        return
                    }
                }

                if rightSlot?.slotStyle != .destructive {
                    if (cellPosition == .right || cellPosition == .both)
                        && width <= swipeCellStyle.appearWidth
                    {
                        withAnimation(rightSlot?.appearAnimation) {
                            offset = -rightSlotWidth
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                            setStatus(.showRightSlot)
                        }
                        return
                    }
                }
                else {
                    if (cellPosition == .right || cellPosition == .both)
                        && width <= swipeCellStyle.appearWidth && width >= -rightdestructiveWidth
                    {
                        withAnimation(rightSlot?.appearAnimation) {
                            offset = -rightSlotWidth
                            lastButtonOffset(position: .left, slot: leftSlot)
                            lastButtonOffset(position: .right, slot: rightSlot)
                            setStatus(.showRightSlot)
                        }
                        return
                    }

                    if (cellPosition == .right || cellPosition == .both)
                        && width < -rightdestructiveWidth
                    {
                        resetStatus()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            rightSlot?.slots.last?.action()
                        }
                        return
                    }
                }

            case .showLeftSlot:
                if abs(width) < swipeCellStyle.dismissWidth
                    && (width + leftSlotWidth) <= leftdestructiveWidth
                {
                    withAnimation(leftSlot?.appearAnimation) {
                        offset = leftSlotWidth
                        lastButtonOffset(position: .left, slot: leftSlot)
                        lastButtonOffset(position: .right, slot: rightSlot)
                        setStatus(.showLeftSlot)
                    }
                    return
                }

                if leftSlot?.slotStyle == .destructive {
                    if feedStatus == .feedOnce {
                        resetStatus()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            leftSlot?.slots.last?.action()
                        }
                        return
                    }
                }
                if width < 0 && width <= -swipeCellStyle.dismissWidth {
                    resetStatus()
                    return
                }

                withAnimation(leftSlot?.appearAnimation) {
                    offset = leftSlotWidth
                    lastButtonOffset(position: .left, slot: leftSlot)
                    lastButtonOffset(position: .right, slot: rightSlot)
                    setStatus(.showLeftSlot)
                }
                return

            case .showRightSlot:
                if abs(width) < swipeCellStyle.dismissWidth
                    && (-width + rightSlotWidth) <= leftdestructiveWidth
                {
                    withAnimation(rightSlot?.appearAnimation) {
                        offset = -rightSlotWidth
                        lastButtonOffset(position: .left, slot: leftSlot)
                        lastButtonOffset(position: .right, slot: rightSlot)
                        setStatus(.showRightSlot)
                    }
                    return
                }

                if rightSlot?.slotStyle == .destructive {
                    if feedStatus == .feedOnce {
                        resetStatus()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            rightSlot?.slots.last?.action()
                        }
                        return
                    }
                }

                if width > 0 && width >= swipeCellStyle.dismissWidth {
                    resetStatus()
                    return
                }

                withAnimation(rightSlot?.appearAnimation) {
                    offset = -rightSlotWidth
                    lastButtonOffset(position: .left, slot: leftSlot)
                    lastButtonOffset(position: .right, slot: rightSlot)
                    setStatus(.showRightSlot)
                }

                return

            }
        }
    }
}
