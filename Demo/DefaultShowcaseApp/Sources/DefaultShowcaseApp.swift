import SwiftUI

@main
struct DefaultShowcaseApp: App {
    var body: some Scene {
        WindowGroup {
            ShowcaseRootView()
        }
    }
}

struct ShowcaseRootView: View {
    var body: some View {
        TabView {
            InboxShowcaseView()
                .tabItem {
                    Label("Inbox", systemImage: "tray.full")
                }

            StylesShowcaseView()
                .tabItem {
                    Label("Styles", systemImage: "paintpalette")
                }

            BehaviorsShowcaseView()
                .tabItem {
                    Label("Behaviors", systemImage: "arrow.left.arrow.right")
                }

            ContainersShowcaseView()
                .tabItem {
                    Label("Containers", systemImage: "rectangle.stack")
                }

            CoordinationShowcaseView()
                .tabItem {
                    Label("Control", systemImage: "slider.horizontal.3")
                }
        }
    }
}
