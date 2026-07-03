import SwiftUI
import SwipeCell

struct BehaviorsShowcaseView: View {
    @State private var messages = ShowcaseMessage.behaviorSamples
    @State private var status = ShowcaseStatus.empty

    var body: some View {
        NavigationStack {
            List {
                ForEach(messages) { message in
                    ShowcaseMessageRow(message: message, accessory: accessory(for: message))
                        .swipeCellActions(
                            message.id,
                            leading: ShowcaseActions.pinLeading(for: message, pin: pin),
                            trailing: trailingActions(for: message)
                        )
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .top) {
                ShowcaseHeader(
                    title: "Behaviors",
                    subtitle: "Leading, trailing, destructive, and timing recipes."
                )
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom) {
                ShowcaseStatusBar(status: status)
            }
            .navigationTitle("Behaviors")
            .showcaseInlineNavigationTitle()
            .swipeCellScope()
        }
    }

    private func trailingActions(for message: ShowcaseMessage) -> [SwipeAction] {
        switch message.id {
        case "behavior-after-collapse":
            [
                SwipeAction(
                    id: ShowcaseActionID.archive,
                    value: message.id,
                    "Archive",
                    systemImage: "archivebox.fill",
                    tint: .blue,
                    fireTiming: .afterCollapse
                ) { id in
                    status = "Archived after collapse: \(subject(for: id))"
                },
                deleteAction(for: message, completion: .triggerAfterReset),
            ]
        case "behavior-hold-open":
            [
                SwipeAction(
                    id: ShowcaseActionID.snooze,
                    value: message.id,
                    "Snooze",
                    systemImage: "clock.fill",
                    tint: .orange,
                    fireTiming: .triggerAndHoldOpen
                ) { id in
                    status = "Held open for \(subject(for: id))"
                },
                deleteAction(for: message, completion: .triggerHoldExpanded),
            ]
        case "behavior-destructive":
            [
                deleteAction(for: message, completion: .directTrigger),
                SwipeAction(
                    id: ShowcaseActionID.archive,
                    value: message.id,
                    "Archive",
                    systemImage: "archivebox.fill",
                    tint: .blue,
                    action: archive
                ),
            ]
        default:
            ShowcaseActions.quickStartTrailing(
                for: message,
                archive: archive,
                delete: delete
            )
        }
    }

    private func deleteAction(
        for message: ShowcaseMessage,
        completion: SwipeActionCompletion
    ) -> SwipeAction {
        SwipeAction(
            id: ShowcaseActionID.delete,
            value: message.id,
            "Delete",
            systemImage: "trash.fill",
            role: .destructive(.init(completion: completion)),
            tint: .red
        ) { id, controller in
            status = "Delete requested for \(subject(for: id))"
            if completion == .triggerHoldExpanded {
                controller.holdExpanded()
            } else {
                controller.collapse()
            }
        }
    }

    private func accessory(for message: ShowcaseMessage) -> String {
        switch message.id {
        case "behavior-after-collapse":
            "after collapse"
        case "behavior-hold-open":
            "hold open"
        case "behavior-destructive":
            "destructive"
        default:
            "both sides"
        }
    }

    private func archive(_ id: ShowcaseMessage.ID) {
        status = "Archived \(subject(for: id))"
    }

    private func delete(_ id: ShowcaseMessage.ID) {
        status = "Deleted \(subject(for: id))"
    }

    private func pin(_ id: ShowcaseMessage.ID) {
        status = "Pinned \(subject(for: id))"
    }

    private func subject(for id: ShowcaseMessage.ID) -> String {
        messages.first(where: { $0.id == id })?.subject ?? "message"
    }
}
