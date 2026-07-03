import SwiftUI
import SwipeCell

struct CoordinationShowcaseView: View {
    @State private var messages = ShowcaseMessage.inboxSamples
    @State private var status = ShowcaseStatus.empty
    @State private var manager = SwipeCellManager()

    private var template: SwipeCellActionTemplate {
        SwipeCellActionTemplate(
            leading: [
                SwipeActionTemplate<ShowcaseMessage.ID>(
                    id: ShowcaseActionID.flag,
                    "Flag",
                    systemImage: "flag.fill",
                    tint: Color.yellow.gradient
                ) { id in
                    status = "Flagged \(subject(for: id))"
                }
            ],
            trailing: [
                SwipeActionTemplate<ShowcaseMessage.ID>(
                    id: ShowcaseActionID.delete,
                    "Delete",
                    systemImage: "trash.fill",
                    role: .destructive(),
                    tint: .red
                ) { id in
                    status = "Delete requested for \(subject(for: id))"
                },
                SwipeActionTemplate<ShowcaseMessage.ID>(
                    id: ShowcaseActionID.archive,
                    "Archive",
                    systemImage: "archivebox.fill",
                    tint: .blue
                ) { id in
                    status = "Archived \(subject(for: id))"
                },
            ]
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls

                List {
                    ForEach(messages) { message in
                        ShowcaseMessageRow(message: message)
                            .swipeCellActions(message.id)
                    }
                }
                .listStyle(.plain)
            }
            .safeAreaInset(edge: .bottom) {
                ShowcaseStatusBar(status: status)
            }
            .navigationTitle("Control")
            .showcaseInlineNavigationTitle()
            .swipeCellScope(manager: manager, actionTemplate: template)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShowcaseHeader(
                title: "Coordination",
                subtitle: "Caller-owned manager, programmatic open and template injection."
            )
            HStack(spacing: 10) {
                Button("Open Leading") {
                    openFirst(side: .leading)
                }
                .buttonStyle(.bordered)

                Button("Open Trailing") {
                    openFirst(side: .trailing)
                }
                .buttonStyle(.bordered)

                Button("Close All") {
                    let accepted = manager.close(animated: true)
                    status = accepted ? "Closed active row" : "No row was open"
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(.bar)
    }

    private func openFirst(side: SwipeCellSide) {
        guard let id = messages.first?.id else { return }
        let accepted = manager.open(id, side: side, animated: true)
        let sideName = side == .leading ? "leading" : "trailing"
        status = accepted ? "Opened \(sideName) actions" : "Row is not ready to open"
    }

    private func subject(for id: ShowcaseMessage.ID) -> String {
        messages.first(where: { $0.id == id })?.subject ?? "message"
    }
}
