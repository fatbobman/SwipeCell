import SwiftUI
import SwipeCell

struct InboxShowcaseView: View {
    @State private var messages = ShowcaseMessage.inboxSamples
    @State private var deletedMessages: [DeletedMessage] = []
    @State private var status = ShowcaseStatus.empty

    var body: some View {
        NavigationStack {
            List {
                ForEach(messages) { message in
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
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .top) {
                ShowcaseHeader(
                    title: "Inbox",
                    subtitle: "Stable row ids, trailing actions, and a shared swipe scope."
                )
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom) {
                InboxStatusBar(
                    status: status,
                    canRestore: !deletedMessages.isEmpty,
                    restore: restoreLatestDeleted
                )
            }
            .navigationTitle("SwipeCell")
            .showcaseInlineNavigationTitle()
            .toolbar {
                Button("Restore") {
                    restoreLatestDeleted()
                }
                .disabled(deletedMessages.isEmpty)
            }
            .swipeCellScope()
        }
    }

    // Archive is a reversible state toggle with a row-level indicator; only Delete removes the
    // row, so the two trailing actions stay visually distinct in the demo. The toggle is
    // deliberately not wrapped in withAnimation: an icon transition would run while the closing
    // row is still translating back, which reads as the icon drifting.
    private func archive(_ id: ShowcaseMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].archived.toggle()
        status =
            messages[index].archived
            ? "Archived \(messages[index].subject)"
            : "Unarchived \(messages[index].subject)"
    }

    private func delete(_ id: ShowcaseMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let message = messages[index]
        withAnimation {
            messages.removeAll { $0.id == id }
        }
        deletedMessages.append(DeletedMessage(message: message, originalIndex: index))
        status = "Deleted \(message.subject)"
    }

    private func restoreLatestDeleted() {
        guard let deleted = deletedMessages.popLast() else { return }
        let index = min(deleted.originalIndex, messages.endIndex)
        withAnimation {
            messages.insert(deleted.message, at: index)
        }
        status = "Restored \(deleted.message.subject)"
    }
}

private struct DeletedMessage {
    let message: ShowcaseMessage
    let originalIndex: Int
}

private struct InboxStatusBar: View {
    let status: String
    let canRestore: Bool
    let restore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(status)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button("Restore") {
                restore()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canRestore)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
