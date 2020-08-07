//
//  ContentView.swift
//  SwipeCellDemo
//
//  Created by Yang Xu on 2020/8/6.
//

import SwiftUI
import SwipeCell

struct ContentView: View {
    @State private var showSheet = false
    @State private var bookmark = false
    @State private var unread = false
    var body: some View {
        
        //Configure button
        let button1 = SwipeCellButton(buttonStyle: .titleAndImage, title: "Mark", systemImage: "bookmark", titleColor: .white, imageColor: .white, view: nil, backgroundColor: .green, action: {bookmark.toggle()}, feedback:true)
        let button2 = SwipeCellButton(buttonStyle: .titleAndImage, title: "New", systemImage: "plus.square", view:nil, backgroundColor: .blue, action: {showSheet.toggle()})
        let button3 = SwipeCellButton(buttonStyle: .view, title:"",systemImage: "", view: {
            AnyView(
                Group{
                    if unread {
                        Image(systemName: "envelope.badge")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                    else {
                        Image(systemName: "envelope.open")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                }
            )
        }, backgroundColor: .orange, action: {unread.toggle()}, feedback: false)
        let button4 = SwipeCellButton(buttonStyle: .titleAndImage, title: "Chat", systemImage: "bubble.left.and.bubble.right.fill", titleColor: .yellow, imageColor: .yellow, view: nil, backgroundColor: .pink, action: {showSheet.toggle()}, feedback: true)
        
        
        //Configure Slot ,Several Buttons can be placed in one Slot.
        let slot1 = SwipeCellSlot(slots: [button2,button1],slotStyle: .destructiveDelay)
        let slot2 = SwipeCellSlot(slots: [button4], slotStyle: .destructive, buttonWidth: 60)
        let slot3 = SwipeCellSlot(slots: [button1,button2,button4],slotStyle: .destructive)
        let slot4 = SwipeCellSlot(slots: [button3],slotStyle: .normal, buttonWidth: 60)
        
        return
            NavigationView{
                List{
                    demo1()
                        .swipeCell(cellPosition: .right, leftSlot: nil, rightSlot: slot1)
                    
                    demo2()
                        .swipeCell(cellPosition: .both, leftSlot: slot1, rightSlot: slot1)
                    
                    demo3()
                        .swipeCell(cellPosition: .right, leftSlot: nil, rightSlot: slot3)
                    
                    demo4()
                        .swipeCell(cellPosition: .both, leftSlot: slot2, rightSlot: slot2)
                    
                    demo5()
                        .swipeCell(cellPosition: .left, leftSlot: slot4, rightSlot: nil)
                    
                    demo6()
                        .swipeCell(cellPosition: .both, leftSlot: slot1, rightSlot: slot1 ,swipeCellStyle: SwipeCellStyle(alignment: .leading, dismissWidth: 20, appearWidth: 20, destructiveWidth: 240, vibrationForButton: .error, vibrationForDestructive: .heavy, autoResetTime: 3))
                    
                    ForEach(0..<30){ i in
                        Text("Scroll List can dismiss button")
                            .frame(height:100,alignment: .center)
                            .swipeCell(cellPosition: .both, leftSlot: slot1, rightSlot: slot1)
                    }
                }
                .navigationBarTitle("SwipeCell Demo",displayMode: .inline)
            }
            .dismissSwipeCellFast()
            .sheet(isPresented: $showSheet, content: {Text("Hello world")})
        
    }
    
    func demo1() -> some View{
        HStack{
            Spacer()
            Text("Swipe left")
            if bookmark {
                Image(systemName: "bookmark.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
            }
            else {
                Image(systemName: "bookmark")
                    .font(.largeTitle)
                    .foregroundColor(.green)
            }
            Spacer()
        }
        .frame(height:100)
    }
    
    func demo2() -> some View{
        HStack{
            Spacer()
            Text("Sliding on both sides")
            if bookmark {
                Image(systemName: "bookmark.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
            }
            else {
                Image(systemName: "bookmark")
                    .font(.largeTitle)
                    .foregroundColor(.green)
            }
            Spacer()
        }
        .frame(height:100)
    }
    
    func demo3() -> some View{
        HStack{
            Spacer()
            VStack{
                Text("Swipe left")
                Text("MutliButton with destructive button")
            }
            Spacer()
        }
        .frame(height:100)
    }
    
    func demo4() -> some View{
        HStack{
            Spacer()
            VStack{
                Text("Swipe right")
                Text("One destructive button")
            }
            Spacer()
        }
        .frame(height:100)
    }
    
    func demo5() -> some View{
        HStack{
            Spacer()
            VStack{
                Text("Swipe right")
                Text("Dynamic Button")
            }
            Spacer()
        }
        .frame(height:100)
    }
    
    func demo6() -> some View{
        HStack{
            Spacer()
            VStack{
                Text("You can set the auto reset duration ")
                Text("3 sec")
            }
            Spacer()
        }
        .frame(height:100)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

