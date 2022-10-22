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
    @State private var showAlert = false

    var body: some View {

        //Configure button
        let button1 = SwipeCellButton(
            buttonStyle: .titleAndImage,
            title: "Mark",
            systemImage: "bookmark",
            titleColor: .white,
            imageColor: .white,
            view: nil,
            backgroundColor: .green,
            action: { bookmark.toggle() },
            feedback: true
        )
        let button2 = SwipeCellButton(
            buttonStyle: .titleAndImage,
            title: "New",
            systemImage: "plus.square",
            view: nil,
            backgroundColor: .blue,
            action: { showSheet.toggle() }
        )
        let button3 = SwipeCellButton(
            buttonStyle: .view,
            title: "",
            systemImage: "",
            view: {
                AnyView(
                    Group {
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
            },
            backgroundColor: .orange,
            action: { unread.toggle() },
            feedback: false
        )
        let button4 = SwipeCellButton(
            buttonStyle: .titleAndImage,
            title: "Chat",
            systemImage: "bubble.left.and.bubble.right.fill",
            titleColor: .yellow,
            imageColor: .yellow,
            view: nil,
            backgroundColor: .pink,
            action: { showSheet.toggle() },
            feedback: true
        )

        let button5 = SwipeCellButton(
            buttonStyle: .titleAndImage,
            title: "Delete",
            systemImage: "trash",
            titleColor: .white,
            imageColor: .white,
            view: nil,
            backgroundColor: .red,
            action: { showAlert.toggle() },
            feedback: true
        )

        //Configure Slot ,Several Buttons can be placed in one Slot.
        let slot1 = SwipeCellSlot(slots: [button2, button1])
        let slot2 = SwipeCellSlot(slots: [button4], slotStyle: .destructive, buttonWidth: 60)
        let slot3 = SwipeCellSlot(slots: [button1, button2, button4], slotStyle: .destructive)
        let slot4 = SwipeCellSlot(slots: [button3], slotStyle: .normal, buttonWidth: 60)
        let slot5 = SwipeCellSlot(slots: [button2, button5], slotStyle: .destructiveDelay)

        return
            NavigationView {
                List {
                    demo1()
                        .onTapGesture {
                            print("test")
                        }
                        .swipeCell(cellPosition: .right, leftSlot: nil, rightSlot: slot1)
                    Button(action: { print("button") }) {
                        demo2()
                    }
                    .swipeCell(
                        cellPosition: .both,
                        leftSlot: slot1,
                        rightSlot: slot1,
                        initalStatus: .showLeftSlot,
                        initialStatusResetDelay: 2.0
                    )

                    demo3()
                        .onTapGesture {
                            print("test")
                        }
                        .swipeCell(cellPosition: .right, leftSlot: nil, rightSlot: slot3)

                    demo4()
                        .onTapGesture {
                            print("test")
                        }
                        .swipeCell(cellPosition: .left, leftSlot: slot2, rightSlot: nil)

                    demo5()
                        .onTapGesture {
                            print("test")
                        }
                        .swipeCell(cellPosition: .left, leftSlot: slot4, rightSlot: nil)

                    demo6()
                        .onTapGesture {
                            print("test")
                        }
                        .swipeCell(
                            cellPosition: .both,
                            leftSlot: slot1,
                            rightSlot: slot1,
                            swipeCellStyle: SwipeCellStyle(
                                alignment: .leading,
                                dismissWidth: 20,
                                appearWidth: 20,
                                destructiveWidth: 240,
                                vibrationForButton: .error,
                                vibrationForDestructive: .heavy,
                                autoResetTime: 3
                            )
                        )
                    demo7()
                        .onTapGesture {
                            print("test")
                        }
                        .swipeCell(cellPosition: .right, leftSlot: nil, rightSlot: slot5)
                        .alert(isPresented: $showAlert) {
                            Alert(
                                title: Text("Are you sure"),
                                message: nil,
                                primaryButton: .destructive(
                                    Text("Delete"),
                                    action: {
                                        print("deleted")
                                        dismissDestructiveDelayButton()
                                    }
                                ),
                                secondaryButton: .cancel({ dismissDestructiveDelayButton() })
                            )
                        }
                    Group{
                    DemoShowStatus()
                    DoSomethingWithoutPress()
                    }

                    NavigationLink("ScrollView LazyVStack", destination: demo9())
                    NavigationLink("ScrollView single Cell", destination: Demo8())
                }
                .navigationBarTitle("SwipeCell Demo", displayMode: .inline)
                .toolbar {
                    EditButton()
                }
            }
            .dismissSwipeCell()
            .sheet(isPresented: $showSheet, content: { Text("Hello world") })

    }

    func demo1() -> some View {
        HStack {
            Spacer()
            Text("← Swipe left")
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
        .frame(height: 100)
    }

    func demo2() -> some View {
        HStack {
            Spacer()
            Text("← → Sliding on both sides")
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
        .frame(height: 100)
    }

    func demo3() -> some View {
        HStack {
            Spacer()
            VStack {
                Text("⇠ Swipe left")
                Text("MutliButton with destructive button")
            }
            Spacer()
        }
        .frame(height: 100)
    }

    func demo4() -> some View {
        HStack {
            Spacer()
            VStack {
                Text("⇢ Swipe right")
                Text("One destructive button")
            }
            Spacer()
        }
        .frame(height: 100)
    }

    func demo5() -> some View {
        HStack {
            Spacer()
            VStack {
                Text("→ Swipe right")
                Text("Dynamic Button")
            }
            Spacer()
        }
        .frame(height: 100)
    }

    func demo6() -> some View {
        HStack {
            Spacer()
            VStack {
                Text("← You can set the auto reset duration ")
                Text("please wait 3 sec")
            }
            Spacer()
        }
        .frame(height: 100)
    }

    func demo7() -> some View {
        HStack {
            Spacer()
            VStack {
                Text("← destructiveDelay Button")
                Text("click delete")
            }
            Spacer()
        }
        .frame(height: 100)
    }

    func demo9() -> some View {
        let button4 = SwipeCellButton(
            buttonStyle: .titleAndImage,
            title: "New",
            systemImage: "bubble.left.and.bubble.right.fill",
            titleColor: .white,
            imageColor: .white,
            view: nil,
            backgroundColor: .blue,
            action: {},
            feedback: true
        )

        let button5 = SwipeCellButton(
            buttonStyle: .titleAndImage,
            title: "Delete",
            systemImage: "trash",
            titleColor: .white,
            imageColor: .white,
            view: nil,
            backgroundColor: .red,
            action: {},
            feedback: true
        )
        let slot = SwipeCellSlot(slots: [button4, button5])
        let lists = (0...100).map { $0 }
        return ScrollView {
            LazyVStack {
                ForEach(lists, id: \.self) { item in
                    Text("Swipe in scrollView:\(item)")
                        .frame(height: 80)
                        .swipeCell(cellPosition: .both, leftSlot: slot, rightSlot: slot)
                        .dismissSwipeCellForScrollViewForLazyVStack()
                }
            }
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct Demo8: View {
    let button1 = SwipeCellButton(
        buttonStyle: .view,
        title: "",
        systemImage: "",
        view: {
            AnyView(
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            )
        },
        backgroundColor: .clear,
        action: {}
    )

    let button2 = SwipeCellButton(
        buttonStyle: .view,
        title: "",
        systemImage: "",
        view: {
            AnyView(
                Circle()
                    .fill(Color.orange)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "flag.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            )
        },
        backgroundColor: .clear,
        action: {}
    )

    let button3 = SwipeCellButton(
        buttonStyle: .view,
        title: "",
        systemImage: "",
        view: {
            AnyView(
                Circle()
                    .fill(Color.red)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "trash.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            )
        },
        backgroundColor: .clear,
        action: {}
    )

    let button4 = SwipeCellButton(
        buttonStyle: .view,
        title: "",
        systemImage: "",
        view: {
            AnyView(
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "envelope.badge.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            )
        },
        backgroundColor: .clear,
        action: {}
    )

    var body: some View {
        let rightSlot = SwipeCellSlot(slots: [button1, button2, button3], buttonWidth: 50)
        let leftSlot = SwipeCellSlot(slots: [button4], buttonWidth: 50)
        ScrollView {
            VStack {
                Text("SwipeCell in ScrollView")
                    .dismissSwipeCellForScrollView()  //目前在ScrollView下注入的方式在iOS14下有点问题,所以必须将dissmissSwipeCellForScrollView放置在ScrollView内部
                //dismissSwipeCellForScrollView 只能用于 VStack, 如果是LazyVStack请使用dismissSwipeCellForScrollViewForLazyVStack
                ForEach(0..<40) { _ in
                    Text("mail content....")
                }
                Text("End")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .swipeCell(cellPosition: .both, leftSlot: leftSlot, rightSlot: rightSlot, clip: false)
    }
}


struct DemoShowStatus:View{

    let button = SwipeCellButton(
        buttonStyle: .titleAndImage,
        title: "Mark",
        systemImage: "bookmark",
        titleColor: .white,
        imageColor: .white,
        view: nil,
        backgroundColor: .green,
        action: { },
        feedback: true
    )

    var slot:SwipeCellSlot{
        SwipeCellSlot(slots: [button])
    }

    @State var status:CellStatus = .showCell

    var body: some View{
        HStack{
            Text("Cell Status:")
            Text(status.rawValue)
                .foregroundColor(.red)
                //get the cell status from Environment
                .transformEnvironment(\.cellStatus, transform: { cellStatus in
                    let temp = cellStatus
                    DispatchQueue.main.async {
                        if self.status != temp {
                        self.status = temp
                        switch self.status{
                        case .showRightSlot:
                            print("do right action")
                        case .showLeftSlot:
                            print("do left action")
                        case .showCell:
                            break
                        }
                        }
                    }
                })
        }
        .frame(maxWidth:.infinity,alignment: .center)
        .frame(height:100)
        .swipeCell(cellPosition: .both, leftSlot: slot, rightSlot: slot)
    }
}

struct DoSomethingWithoutPress:View{
    let button = SwipeCellButton(
        buttonStyle: .titleAndImage,
        title: "Mark",
        systemImage: "bookmark",
        titleColor: .white,
        imageColor: .white,
        view: nil,
        backgroundColor: .green,
        action: { },
        feedback: true
    )

    var slotLeft:SwipeCellSlot{
        SwipeCellSlot(slots: [button],showAction: {print("do something Left")})
    }

    var slotRight:SwipeCellSlot{
        SwipeCellSlot(slots: [button],showAction: {print("do something Right")})
    }


    var body: some View{
        HStack{
            Text("Do something without press")
        }
        .frame(maxWidth:.infinity,alignment: .center)
        .frame(height:100)
        .swipeCell(cellPosition: .both, leftSlot: slotLeft, rightSlot: slotRight)
    }
}
