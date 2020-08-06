//
//  File.swift
//  
//
//  Created by Yang Xu on 2020/8/6.
//

import Foundation
import SwiftUI

extension SwipeCellModifier{
    

    
    
    
    
    func body(content: Content) -> some View {
        if editMode?.wrappedValue == .active {dismissNotification()}
        return ZStack(alignment:.topLeading){
            ZStack{
                Color.clear.zIndex(0)
                
                //加载左侧按钮
                GeometryReader{ proxy in
                    ZStack{
                        if let lbs = leftSlot {
                            loadButtons(lbs,position: .left,frame:proxy.frame(in:.local))
                        }
                    }
                }.zIndex(1)
                //加载右侧按钮
                GeometryReader{ proxy in
                    ZStack{
                        if let rbs = rightSlot{
                            loadButtons(rbs,position: .right,frame:proxy.frame(in:.local))
                        }
                    }
                }.zIndex(2)
                  
                
                //加载Cell内容
                ZStack(alignment: swipeCellStyle.alignment){
                    Color.clear
                    content
                }
                .zIndex(3)
                .highPriorityGesture(TapGesture(count: 1), including:  status == .showCell && (currentCellID == cellID || currentCellID == nil) ? .subviews : .none)
                .contentShape(Rectangle())
                .onTapGesture(count: 1, perform: {
                    if status != .showCell{
                        resetStatus()
                        dismissNotification()
                    }
                })
                .offset(x:offset)
            }
        }
        .contentShape(Rectangle())
        .gesture(getGesture())
        .clipShape(Rectangle())
        .onReceive(resetNotice){ notice in
            //如果其他的cell发送通知或者list发送通知,则本cell复位
            if cellID != notice.object as? UUID {
                currentCellID = notice.object as? UUID ?? nil
                resetStatus()
            }
        }
        .onReceive(timer){_ in
            resetStatus()
        }
        .listRowInsets(EdgeInsets())
        
    }
    
 
    
    func setStatus(_ position:CellStatus){
        status = position
        guard let time =  swipeCellStyle.autoResetTime else {return}
        timer = Timer.publish(every: time, on: .main, in: .common)
        timer.connect().store(in: &cancellables)
    }
    
    func resetStatus(){
        status = .showCell
        withAnimation(.easeInOut){
            offset = 0
            leftOffset = -frameWidth
            rightOffset = frameWidth
        }
        feedStatus = .none
        cancellables.removeAll()
        currentCellID = nil
    }
    
    func successFeedBack(_ type:Vibration){
        #if os(iOS)
        type.vibrate()
        #endif
    }
    
    func dismissNotification(){
        NotificationCenter.default.post(name: .swipeCellReset, object: nil)
    }
    
}
