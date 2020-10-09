//
//  Test.swift
//  Demo
//
//  Created by Yang Xu on 2020/10/9.
//

import SwiftUI
import SwipeCell

struct Test: View {
    var body: some View {
        let button1 = SwipeCellButton(buttonStyle: .titleAndImage, title: "Mark", systemImage: "bookmark", titleColor: .white, imageColor: .white, view: nil, backgroundColor: .green, action: {}, feedback:true)
        let button2 = SwipeCellButton(buttonStyle: .titleAndImage, title: "New", systemImage: "plus.square", view:nil, backgroundColor: .blue, action: {})
        let slot = SwipeCellSlot(slots: [button2,button1])
        return
            NavigationView{
                ScrollView{
                    LazyVStack{
                        ForEach(0..<100){ item in
                            NavigationLink(destination:Text("Swipe in scrollView:\(item)"),label:linkButton)
                                .frame(height:80)
                                .swipeCell(cellPosition: .both, leftSlot:slot, rightSlot: slot)
                                .dismissSwipeCellForScrollViewForLazyVStack()
                        }
                    }
                }
        }
    }
    
    func linkButton() -> some View{
        HStack{
            Text("test")
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

struct Test_Previews: PreviewProvider {
    static var previews: some View {
        Test()
    }
}
