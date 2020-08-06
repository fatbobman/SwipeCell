//  Created by Yang Xu on 2020/8/4.
//

import Foundation
import SwiftUI
import Introspect
import Combine

//这个版本的dismiss响应及时,不过会产生和SwiftUI List的一些冲突,导致删除和选择会有问题.所以屏蔽的删除.如果你不需要选择并自己实现删除,这个版本会给你最快速的滚动后SwipeButton复位动作
extension View{
    public func dismissSwipeCellFast() -> some View{
        self
            .modifier(ScrollNotificationInject(showSelection:false))
    }
}

struct ScrollNotificationInject:ViewModifier{
    var showSelection:Bool
    @ObservedObject var delegate = Delegate()
    func body(content: Content) -> some View {
        content
            .introspectTableView{ list in
                list.delegate = delegate
                list.allowsSelection = showSelection
            }
    }
}

import UIKit
class Delegate:NSObject,UITableViewDelegate, UIScrollViewDelegate,ObservableObject{
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(name: .swipeCellReset, object: nil)
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView){
        NotificationCenter.default.post(name: .swipeCellReset, object: nil)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle{
        return UITableViewCell.EditingStyle.none
    }
}


//这个版本对于SwiftUI的List支持更好一点(可以支持选择),.不过响应稍有延迟.另外,屏幕上的Cell必须要滚动至少一个才能开始dismiss
//如果在ForEach上使用了onDelete,系统会自动在Cell右侧添加删除按钮替代自定义的swipeButton.
struct ScrollNotificationWithoutInject:ViewModifier{
    @State var timer = Timer.publish(every: 0.5, on: .main, in: .common)
    @State var cancellable:Set<AnyCancellable> = []
    @State var listView = UITableView()
    @State var hashValue:Int? = nil
    
    func body(content: Content) -> some View {
        content
            .introspectTableView{ listView in
                
                self.listView = listView
            }
            .onAppear{
                timer = Timer.publish(every: 1, on: .main, in: .common)
                timer.connect()
                    .store(in: &cancellable)
            }
            .onDisappear{
                cancellable = []
            }
            .onReceive(timer){ _ in
                if hashValue == nil {
                    hashValue = listView.visibleCells.first.hashValue
                }
                if hashValue != listView.visibleCells.first.hashValue {
                    NotificationCenter.default.post(name: .swipeCellReset, object: nil)
                    hashValue = listView.visibleCells.first.hashValue
                }
            }
    }
}

extension View{
    public func dismissSwipeCell() -> some View{
        self
            .modifier(ScrollNotificationWithoutInject())
    }
}


//ScrollView使用的dismiss.当前在ios13下使用没有问题,不过Introspect在iOS14的beta下无法获取数据.相信过段时间便能修复.
struct ScrollNotificationForScrollView:ViewModifier{
    @State var timer = Timer.publish(every: 0.5, on: .main, in: .common)
    @State var cancellable:Set<AnyCancellable> = []
    @State var scrollView = UIScrollView()
    @State var offset:CGPoint? = nil
    func body(content: Content) -> some View {
        content
            .introspectScrollView{scrollView in
                self.scrollView = scrollView
            }
            .onAppear{
                timer = Timer.publish(every: 1, on: .main, in: .common)
                timer.connect()
                    .store(in: &cancellable)
            }
            .onDisappear{
                cancellable = []
            }
            .onReceive(timer){ _ in
                if offset == nil {
                    offset = scrollView.contentOffset
                }
                if scrollView.contentOffset != offset {
                    offset = scrollView.contentOffset
                    NotificationCenter.default.post(name: .swipeCellReset, object: nil)
                }
            }
    }
}

extension View{
    public func dismissSwipeCellForScrollView() -> some View{
        self
            .modifier(ScrollNotificationForScrollView())
    }
}
