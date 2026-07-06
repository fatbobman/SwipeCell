import SwiftUI
import SwipeCell

struct BehaviorsShowcaseView: View {
    @State private var messages = ShowcaseMessage.behaviorSamples
    @State private var status = ShowcaseStatus.empty
    @State private var pendingDelete: PendingDelete?
    @State private var isDeleteDialogPresented = false

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
            .toolbar {
                Button("Reset") {
                    reset()
                }
            }
            .confirmationDialog(
                "Delete \"\(pendingDelete?.subject ?? "message")\"?",
                isPresented: $isDeleteDialogPresented,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    resolvePendingDelete(confirmed: true)
                }
                Button("Keep", role: .cancel) {
                    resolvePendingDelete(confirmed: false)
                }
            }
            .onChange(of: isDeleteDialogPresented) { _, isPresented in
                // Tap-outside dismissal skips both button actions; normalize it to cancel so the
                // held-expanded row is never stranded. resolvePendingDelete is idempotent, so this
                // is a no-op when a button already resolved.
                if !isPresented {
                    resolvePendingDelete(confirmed: false)
                }
            }
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
                    snooze(id)
                },
                holdExpandedDeleteAction(for: message),
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

    /// `.directTrigger` removes the row as soon as the full swipe lands; `.triggerAfterReset`
    /// collapses first, then the library calls this same closure. Both stay id-only.
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
        ) { id in
            delete(id)
        }
    }

    /// `.triggerHoldExpanded` keeps the row in its hold geometry until the dialog resolves; the
    /// controller is only used for the cancel path — a confirmed delete removes the row instead,
    /// which is a legal terminal state without resolving the controller.
    private func holdExpandedDeleteAction(for message: ShowcaseMessage) -> SwipeAction {
        SwipeAction(
            id: ShowcaseActionID.delete,
            value: message.id,
            "Delete",
            systemImage: "trash.fill",
            role: .destructive(.init(completion: .triggerHoldExpanded)),
            tint: .red
        ) { id, controller in
            pendingDelete = PendingDelete(
                id: id,
                subject: subject(for: id),
                controller: controller
            )
            isDeleteDialogPresented = true
            status = "Confirm delete for \(subject(for: id))"
        }
    }

    /// Single resolution funnel for the hold-expanded confirmation: dialog buttons and the
    /// dismissal fallback all land here, and the first caller wins.
    private func resolvePendingDelete(confirmed: Bool) {
        guard let pending = pendingDelete else { return }
        pendingDelete = nil
        if confirmed {
            withAnimation {
                messages.removeAll { $0.id == pending.id }
            }
            status = "Deleted \(pending.subject)"
        } else {
            pending.controller.collapse()
            status = "Kept \(pending.subject)"
        }
    }

    private func reset() {
        withAnimation {
            messages = ShowcaseMessage.behaviorSamples
        }
        status = ShowcaseStatus.empty
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
        let subject = subject(for: id)
        withAnimation {
            messages.removeAll { $0.id == id }
        }
        status = "Deleted \(subject)"
    }

    private func pin(_ id: ShowcaseMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        withAnimation {
            messages[index].pinned.toggle()
        }
        status =
            messages[index].pinned
            ? "Pinned \(messages[index].subject)"
            : "Unpinned \(messages[index].subject)"
    }

    private func snooze(_ id: ShowcaseMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        withAnimation {
            messages[index].snoozed.toggle()
        }
        status = "Held open for \(messages[index].subject)"
    }

    private func subject(for id: ShowcaseMessage.ID) -> String {
        messages.first(where: { $0.id == id })?.subject ?? "message"
    }
}

private struct PendingDelete {
    let id: ShowcaseMessage.ID
    let subject: String
    let controller: SwipeActionTriggerController
}
