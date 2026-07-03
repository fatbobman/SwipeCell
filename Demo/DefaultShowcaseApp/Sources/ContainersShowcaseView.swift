import SwiftUI
import SwipeCell

struct ContainersShowcaseView: View {
    @State private var messages = ShowcaseMessage.containerSamples
    @State private var status = ShowcaseStatus.empty
    @State private var selectedMessage: ShowcaseMessage?

    var body: some View {
        NavigationStack {
            List {
                Section("List") {
                    let message = messages[0]

                    ShowcaseMessageRow(message: message)
                        .swipeCellActions(
                            message.id,
                            trailing: ShowcaseActions.quickStartTrailing(
                                for: message,
                                archive: archive,
                                delete: delete
                            )
                        )
                }

                Section("ScrollView + LazyVStack") {
                    NavigationLink("Open ScrollView sample") {
                        LazyStackContainerView(
                            messages: messages,
                            status: $status
                        )
                    }
                }

                Section("Button row") {
                    let message = messages[2]

                    Button {
                        status = "Button tapped: \(message.subject)"
                    } label: {
                        ShowcaseMessageRow(message: message)
                    }
                    .buttonStyle(.plain)
                    .swipeCellActions(
                        message.id,
                        trailing: ShowcaseActions.quickStartTrailing(
                            for: message,
                            archive: archive,
                            delete: delete
                        )
                    )
                }

                Section("NavigationLink row") {
                    let message = messages[3]

                    NavigationLink(value: message) {
                        ShowcaseMessageRow(message: message)
                    }
                    .swipeCellActions(
                        message.id,
                        trailing: ShowcaseActions.quickStartTrailing(
                            for: message,
                            archive: archive,
                            delete: delete
                        )
                    )
                }
            }
            .showcaseGroupedListStyle()
            .safeAreaInset(edge: .bottom) {
                ShowcaseStatusBar(status: status)
            }
            .navigationTitle("Containers")
            .showcaseInlineNavigationTitle()
            .navigationDestination(for: ShowcaseMessage.self) { message in
                ShowcaseMessageDetail(message: message)
            }
            .swipeCellScope()
        }
    }

    private func archive(_ id: ShowcaseMessage.ID) {
        status = "Archived \(subject(for: id))"
    }

    private func delete(_ id: ShowcaseMessage.ID) {
        status = "Delete requested for \(subject(for: id))"
    }

    private func subject(for id: ShowcaseMessage.ID) -> String {
        messages.first(where: { $0.id == id })?.subject ?? "message"
    }
}

private struct LazyStackContainerView: View {
    let messages: [ShowcaseMessage]
    @Binding var status: String

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(messages) { message in
                    ShowcaseMessageRow(message: message)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .swipeCellActions(
                            message.id,
                            trailing: ShowcaseActions.quickStartTrailing(
                                for: message,
                                archive: archive,
                                delete: delete
                            )
                        )
                }
            }
            .padding(16)
        }
        .navigationTitle("LazyVStack")
        .showcaseInlineNavigationTitle()
        .safeAreaInset(edge: .bottom) {
            ShowcaseStatusBar(status: status)
        }
        .swipeCellScope(container: .scrollView)
    }

    private func archive(_ id: ShowcaseMessage.ID) {
        status = "Archived \(subject(for: id))"
    }

    private func delete(_ id: ShowcaseMessage.ID) {
        status = "Delete requested for \(subject(for: id))"
    }

    private func subject(for id: ShowcaseMessage.ID) -> String {
        messages.first(where: { $0.id == id })?.subject ?? "message"
    }
}

private struct ShowcaseMessageDetail: View {
    let message: ShowcaseMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message.sender)
                .font(.headline)
            Text(message.subject)
                .font(.title3.weight(.semibold))
            Text(message.preview)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .navigationTitle("Message")
        .showcaseInlineNavigationTitle()
    }
}
