//  Created by Yang Xu on 2020/8/4.
//

import Combine
import Foundation
import SwiftUI
import UIKit

/*
 dismissSwipeCellFast响应及时,不过会产生和SwiftUI List的一些冲突,
 导致删除和选择会有问题.所以屏蔽的删除.如果你不需要选择并自己实现删除,这个版本会给你最快速的滚动后SwipeButton复位动作
 另外,这个dismissSwipeCellFast不支持Button响应,包括NavitionLink.如果你确定要使用,请使用onTapGesture来响应点击.
总之,如果如果你不很清楚,那么就使用dismissSwipeCell
*/
//MARK: dismissList1 not suggest now
extension View {
    public func dismissSwipeCellFast() -> some View {
        self
            .modifier(ScrollNotificationInject(showSelection: false))
    }
}

struct ScrollNotificationInject: ViewModifier {
    var showSelection: Bool
    @ObservedObject var delegate = Delegate()
    func body(content: Content) -> some View {
        content
            .introspectTableView { list in
                list.delegate = delegate
                list.allowsSelection = showSelection
            }
    }
}

class Delegate: NSObject, UITableViewDelegate, UIScrollViewDelegate, ObservableObject {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(name: .swipeCellReset, object: nil)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(name: .swipeCellReset, object: nil)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath)
        -> UITableViewCell.EditingStyle
    {
        return UITableViewCell.EditingStyle.none
    }
}

//MARK: dismissList
//这个版本对于SwiftUI的List支持更好一点(可以支持选择),.不过响应稍有延迟.另外,屏幕上的Cell必须要滚动至少一个才能开始dismiss
//如果在ForEach上使用了onDelete,系统会自动在Cell右侧添加删除按钮替代自定义的swipeButton.
struct ScrollNotificationWithoutInject: ViewModifier {
    let timeInterval: Double
    @State var timer = Timer.publish(every: 0.5, on: .main, in: .common)
    @State var cancellable: Set<AnyCancellable> = []
    @State var listView = UITableView()
    @State var hashValue: Int? = nil

    func body(content: Content) -> some View {
        content
            .introspectTableView { listView in

                self.listView = listView
            }
            .onAppear {
                timer = Timer.publish(every: timeInterval, on: .main, in: .common)
                timer.connect()
                    .store(in: &cancellable)
            }
            .onDisappear {
                cancellable = []
            }
            .onReceive(timer) { _ in
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

extension View {
    public func dismissSwipeCell(timeInterval: Double = 0.5) -> some View {
        self
            .modifier(ScrollNotificationWithoutInject(timeInterval: timeInterval))
    }
}

//ScrollView使用的dismiss.当前在ios13下使用没有问题,不过Introspect在iOS14的beta下无法获取数据.相信过段时间便能修复.
struct ScrollNotificationForScrollViewInject: ViewModifier {
    @State var timer = Timer.publish(every: 0.5, on: .main, in: .common)
    @State var cancellable: Set<AnyCancellable> = []
    @State var scrollView = UIScrollView()
    @State var offset: CGPoint? = nil
    func body(content: Content) -> some View {
        content
            .introspectScrollView { scrollView in
                self.scrollView = scrollView
            }
            .onAppear {
                timer = Timer.publish(every: 1, on: .main, in: .common)
                timer.connect()
                    .store(in: &cancellable)
            }
            .onDisappear {
                cancellable = []
            }
            .onReceive(timer) { _ in
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

extension View {
    public func dismissSwipeCellForScrollViewInject() -> some View {
        self
            .modifier(ScrollNotificationForScrollViewInject())
    }
}

public func dismissDestructiveDelayButton() {
    NotificationCenter.default.post(name: .swipeCellReset, object: nil)
}

//MARK: DismissScrollView for VStack
struct TopLeadingY: Equatable {
    let topLeadingY: CGFloat
}

struct ScrollViewPreferencKey: PreferenceKey {
    typealias Value = [TopLeadingY]
    static var defaultValue: Value = []
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}

struct DismissSwipeCellForScrollView: ViewModifier {
    @State var topleadingY: CGFloat? = nil
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear
                content
                    .preference(
                        key: ScrollViewPreferencKey.self,
                        value: [TopLeadingY(topLeadingY: proxy.frame(in: .global).minY)]
                    )
            }
        }
        .onPreferenceChange(ScrollViewPreferencKey.self) { preference in
            if topleadingY == nil {
                topleadingY = preference.first!.topLeadingY
            }
            if abs(topleadingY! - preference.first!.topLeadingY) < 10 {
                NotificationCenter.default.post(name: .swipeCellReset, object: nil)
            }
            else {
                topleadingY = preference.first!.topLeadingY
            }
        }
    }
}

extension View {
    public func dismissSwipeCellForScrollView() -> some View {
        self
            .modifier(DismissSwipeCellForScrollView())
    }
}

//MARK: DismissScrollView for LazyVStack
//LazyVStack的实现目前没有太好的方案.个别情况下会打断滑动按钮的出现动画
struct CellInfo: Equatable {
    let id: UUID
}

struct ScrollViewPreferencKeyForLazy: PreferenceKey {
    typealias Value = [CellInfo]
    static var defaultValue: Value = []
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}

struct DismissSwipeCellForScrollViewForLazy: ViewModifier {
    @State var cellinfos: [CellInfo] = []
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScrollViewPreferencKeyForLazy.self,
                            value: [CellInfo(id: UUID())]
                        )
                }
            )
            .onPreferenceChange(ScrollViewPreferencKeyForLazy.self) { preference in
                if cellinfos.count == 0 {
                    DispatchQueue.main.async {
                        cellinfos = preference
                    }
                }
                if cellinfos != preference {
                    NotificationCenter.default.post(name: .swipeCellReset, object: nil)
                }
                else {
                    DispatchQueue.main.async {
                        cellinfos = preference
                    }
                }
            }
    }
}

extension View {
    public func dismissSwipeCellForScrollViewForLazyVStack() -> some View {
        self
            .modifier(DismissSwipeCellForScrollViewForLazy())
    }
}


