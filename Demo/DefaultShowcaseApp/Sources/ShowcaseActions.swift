import SwiftUI
import SwipeCell

@MainActor
enum ShowcaseActions {
    static func quickStartTrailing(
        for message: ShowcaseMessage,
        archive: @escaping (ShowcaseMessage.ID) -> Void,
        delete: @escaping (ShowcaseMessage.ID) -> Void
    ) -> [SwipeAction] {
        [
            SwipeAction(
                id: ShowcaseActionID.delete,
                value: message.id,
                "Delete",
                systemImage: "trash.fill",
                role: .destructive(),
                tint: .red,
                action: delete
            ),
            SwipeAction(
                id: ShowcaseActionID.archive,
                value: message.id,
                "Archive",
                systemImage: "archivebox.fill",
                tint: .blue,
                action: archive
            ),
        ]
    }

    static func leading(
        for message: ShowcaseMessage,
        flag: @escaping (ShowcaseMessage.ID) -> Void
    ) -> [SwipeAction] {
        [
            SwipeAction(
                id: ShowcaseActionID.flag,
                value: message.id,
                "Flag",
                systemImage: "flag.fill",
                tint: Color.yellow.gradient,
                action: flag
            )
        ]
    }

    static func pinLeading(
        for message: ShowcaseMessage,
        pin: @escaping (ShowcaseMessage.ID) -> Void
    ) -> [SwipeAction] {
        [
            SwipeAction(
                id: ShowcaseActionID.pin,
                value: message.id,
                "Pin",
                systemImage: "pin.fill",
                tint: .indigo,
                action: pin
            )
        ]
    }
}
