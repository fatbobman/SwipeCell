//
//  Created by Yang Xu on 2020/8/6.
//

import Foundation
import SwiftUI

extension SwipeCellModifier {

    func body(content: Content) -> some View {
        if editMode?.wrappedValue == .active { dismissNotification() }

        return ZStack(alignment: .topLeading) {
            Color.clear.zIndex(0)
            ZStack {

                //加载左侧按钮
                GeometryReader { proxy in
                    ZStack {
                        if let lbs = leftSlot {
                            loadButtons(lbs, position: .left, frame: proxy.frame(in: .local))

                        }
                    }
                }.zIndex(1)
                //加载右侧按钮
                GeometryReader { proxy in
                    ZStack {
                        if let rbs = rightSlot {
                            loadButtons(rbs, position: .right, frame: proxy.frame(in: .local))
                        }
                    }
                }.zIndex(2)

                //加载Cell内容
                ZStack(alignment: swipeCellStyle.alignment) {
                    Color.clear
                    content
                        .environment(\.cellStatus, status)
                }
                .zIndex(3)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture(count: 1)
                    .onEnded {
                        resetStatus()
                        dismissNotification()
                    },
                    including: currentCellID == nil ? .subviews : .gesture
                )
                .offset(x: offset)
            }
        }
        .contentShape(Rectangle())
        .myGesture(
            getGesture(),
            editMode: editMode,
            onChanged: handlePanGestureOnChangedEvent(width:),
            onEnded: handlePanGestureEndedEvent(width:)
        )
        .onAppear {
            self.setStatus(status)
            switch status {
            case .showLeftSlot:
                offset = leftSlotWidth
            case .showRightSlot:
                offset = rightSlotWidth
            default:
                break
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + initialStatusResetDelay) {
                if shouldResetStatusOnAppear {
                    resetStatus()
                }
            }
        }
        .ifIs(clip) {
            $0.clipShape(Rectangle())
        }
        .onChange(of: status){ status in
            switch status {
            case .showLeftSlot:
                leftSlot?.showAction?()
            case .showRightSlot:
                rightSlot?.showAction?()
            case .showCell:
                break
            }
        }
        .onReceive(resetNotice) { notice in
            //            if status == .showCell {return}
            //如果其他的cell发送通知或者list发送通知,则本cell复位
            if cellID != notice.object as? UUID {
                resetStatus()
                currentCellID = notice.object as? UUID ?? nil
            }

        }
        .onReceive(timer) { _ in
            resetStatus()
        }
        .ifIs(
            (leftSlot?.slots.count == 1 && leftSlot?.slotStyle == .destructive)
                || (rightSlot?.slots.count == 1 && rightSlot?.slotStyle == .destructive)
        ) {
            $0.onChange(of: offset) { offset in
                //当前向右
                if offset > 0 && leftSlot?.slots.count == 1 && leftSlot?.slotStyle == .destructive {
                    guard let leftSlot = leftSlot else { return }
                    if leftSlot.slotStyle == .destructive && leftSlot.slots.count == 1 {
                        if feedStatus == .feedOnce {
                            withAnimation(.easeInOut) {
                                spaceWidth = offset - leftSlot.buttonWidth
                            }
                        }
                        if feedStatus == .feedAgain {
                            withAnimation(.easeInOut) {
                                spaceWidth = 0
                            }
                        }
                    }
                }
                //当前向左
                if offset < 0 && rightSlot?.slots.count == 1 && rightSlot?.slotStyle == .destructive
                {
                    guard let rightSlot = rightSlot else { return }
                    if rightSlot.slotStyle == .destructive && rightSlot.slots.count == 1 {
                        if feedStatus == .feedOnce {
                            withAnimation(.easeInOut) {
                                spaceWidth = -(abs(offset) - rightSlot.buttonWidth)
                            }
                        }
                        if feedStatus == .feedAgain {
                            withAnimation(.easeInOut) {
                                spaceWidth = 0
                            }
                        }
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets())

    }

    func setStatus(_ position: CellStatus) {
        status = position
        guard let time = swipeCellStyle.autoResetTime else { return }
        timer = Timer.publish(every: time, on: .main, in: .common)
        timer.connect().store(in: &cancellables)
    }

    /// Set the status and associated values to ``CellStatus.showCell``
    func resetStatus() {
        status = .showCell
        withAnimation(.easeInOut) {
            offset = 0
            leftOffset = -frameWidth
            rightOffset = frameWidth
            spaceWidth = 0
            showDalayButtonWith = 0
        }
        feedStatus = .none
        cancellables.removeAll()
        currentCellID = nil
        // since we reset, we won't have to do it again
        shouldResetStatusOnAppear = false

    }

    func successFeedBack(_ type: Vibration) {
        #if os(iOS)
            type.vibrate()
        #endif
    }

    func dismissNotification() {
        NotificationCenter.default.post(name: .swipeCellReset, object: nil)
    }

}

extension View {
    @ViewBuilder
    func myGesture(
        _ g:_EndedGesture<_ChangedGesture<DragGesture>>,
        editMode: Binding<EditMode>?,
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping (CGFloat) -> Void
    ) -> some View {
        if #available(iOS 18, *) {
            gesture(
                SWCPanGesture(editMode: editMode ?? .constant(.inactive)) { recognizer in
                    let width = recognizer.translation(in: recognizer.view).x
                    let state = recognizer.state
                    switch state {
                    case .changed:
                        onChanged(width)
                    case .ended:
                        onEnded(width)
                    default:
                        break
                    }
                }
            )
        } else {
            gesture(g)
        }
    }
}

@available(iOS 18.0, *)
struct SWCPanGesture: UIGestureRecognizerRepresentable {
    @Binding var editMode: EditMode
    var handle: (UIPanGestureRecognizer) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { .init() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer()
        gesture.delegate = context.coordinator
        gesture.isEnabled = true
        return gesture
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        if editMode == .active {
            recognizer.isEnabled = false
        } else {
            recognizer.isEnabled = true
        }
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        handle(recognizer)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer else { return false }

            let velocity = panRecognizer.velocity(in: gestureRecognizer.view)
            return abs(velocity.y) < abs(velocity.x)
        }
    }
}
