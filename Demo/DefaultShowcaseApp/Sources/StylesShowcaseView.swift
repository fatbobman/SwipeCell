import SwiftUI
import SwipeCell

struct StylesShowcaseView: View {
    @State private var messages = ShowcaseMessage.styleSamples
    @State private var status = ShowcaseStatus.empty

    var body: some View {
        NavigationStack {
            List {
                Section("Slot and token") {
                    row(at: 0, revealStyle: .slot, accessory: ".slot")
                    row(at: 1, revealStyle: .token, accessory: ".token")
                }

                Section("ShapeStyle tint") {
                    gradientRow
                }

                Section("Default label controls") {
                    row(at: 3, accessory: "scope token")
                        .swipeActionLabelDisplayMode(.iconOnly)
                        .swipeActionDefaultLabelStyle(
                            .system(
                                iconSize: 18,
                                titleSize: 11,
                                iconWeight: .bold,
                                titleWeight: .semibold
                            )
                        )
                }

                Section("Custom label in default renderer") {
                    customLabelRow
                }
            }
            .showcaseGroupedListStyle()
            .safeAreaInset(edge: .bottom) {
                ShowcaseStatusBar(status: status)
            }
            .navigationTitle("Styles")
            .showcaseInlineNavigationTitle()
            .swipeCellScope()
            .swipeCellConfiguration { configuration in
                configuration.style.defaultRevealStyle = .token
            }
        }
    }

    private func row(
        at index: Int,
        revealStyle: SwipeActionsRevealStyle? = nil,
        accessory: String
    ) -> some View {
        let message = messages[index]

        return ShowcaseMessageRow(message: message, accessory: accessory)
            .swipeCellActions(
                message.id,
                leading: ShowcaseActions.leading(for: message, flag: flag),
                trailing: ShowcaseActions.quickStartTrailing(
                    for: message,
                    archive: archive,
                    delete: delete
                ),
                revealStyle: revealStyle
            )
    }

    private var gradientRow: some View {
        let message = messages[2]

        return ShowcaseMessageRow(message: message, accessory: "gradient")
            .swipeCellActions(
                message.id,
                trailing: [
                    SwipeAction(
                        id: ShowcaseActionID.archive,
                        value: message.id,
                        "Archive",
                        systemImage: "archivebox.fill",
                        tint: LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        action: archive
                    ),
                    SwipeAction(
                        id: ShowcaseActionID.delete,
                        value: message.id,
                        "Delete",
                        systemImage: "trash.fill",
                        role: .destructive(),
                        tint: LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        action: delete
                    ),
                ],
                revealStyle: .slot
            )
    }

    private var customLabelRow: some View {
        let message = messages[4]

        return ShowcaseMessageRow(message: message, accessory: "label")
            .swipeCellActions(
                message.id,
                trailing: [
                    SwipeAction(
                        id: ShowcaseActionID.markRead,
                        tint: .purple,
                        action: {
                            markRead(message.id)
                        }
                    ) { context in
                        ProgressBadgeLabel(
                            title: "Read",
                            systemImage: "envelope.open.fill",
                            context: context
                        )
                    }
                ],
                revealStyle: .slot
            )
            .swipeActionStyle(SoftSwipeActionStyle())
    }

    private func archive(_ id: ShowcaseMessage.ID) {
        status = "Archived \(subject(for: id))"
    }

    private func delete(_ id: ShowcaseMessage.ID) {
        status = "Delete requested for \(subject(for: id))"
    }

    private func flag(_ id: ShowcaseMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        withAnimation {
            messages[index].flagged.toggle()
        }
        status =
            messages[index].flagged
            ? "Flagged \(messages[index].subject)"
            : "Unflagged \(messages[index].subject)"
    }

    private func markRead(_ id: ShowcaseMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        withAnimation {
            messages[index].unread.toggle()
        }
        status =
            messages[index].unread
            ? "Marked \(messages[index].subject) unread"
            : "Marked \(messages[index].subject) read"
    }

    private func subject(for id: ShowcaseMessage.ID) -> String {
        messages.first(where: { $0.id == id })?.subject ?? "message"
    }
}
