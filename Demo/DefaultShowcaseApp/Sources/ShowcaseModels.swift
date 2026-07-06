import SwiftUI

enum ShowcaseActionID: String, Hashable {
    case archive
    case delete
    case flag
    case pin
    case markRead
    case snooze
}

struct ShowcaseMessage: Identifiable, Hashable {
    let id: String
    var sender: String
    var subject: String
    var preview: String
    var unread: Bool
    var archived = false
    var flagged = false
    var pinned = false
    var snoozed = false
    var tint: Color

    static let inboxSamples: [ShowcaseMessage] = [
        ShowcaseMessage(
            id: "inbox-swiftui-state",
            sender: "SwiftUI Weekly",
            subject: "State-driven rows",
            preview: "Use stable ids, structured actions, and a scope around the list.",
            unread: true,
            tint: .blue
        ),
        ShowcaseMessage(
            id: "inbox-design-review",
            sender: "Design Review",
            subject: "Default renderer check",
            preview: "Archive and Delete use built-in slot rendering with no custom renderer.",
            unread: false,
            tint: .pink
        ),
        ShowcaseMessage(
            id: "inbox-release-notes",
            sender: "Release Notes",
            subject: "Ready for docs",
            preview: "This quick-start section is the documentation code source.",
            unread: true,
            tint: .green
        ),
        ShowcaseMessage(
            id: "inbox-qa",
            sender: "QA",
            subject: "Container behavior",
            preview: "Rows coordinate through the surrounding swipe cell scope.",
            unread: false,
            tint: .orange
        ),
    ]

    static let styleSamples: [ShowcaseMessage] = [
        ShowcaseMessage(
            id: "style-slot",
            sender: "Slot",
            subject: "Slot reveal",
            preview: "Default label chrome fills the action slot.",
            unread: false,
            tint: .indigo
        ),
        ShowcaseMessage(
            id: "style-token",
            sender: "Token",
            subject: "Token reveal",
            preview: "Token reveal keeps a compact visible action surface.",
            unread: true,
            tint: .teal
        ),
        ShowcaseMessage(
            id: "style-gradient",
            sender: "Tint",
            subject: "ShapeStyle tint",
            preview: "ShapeStyle tints still run inside the default renderer.",
            unread: false,
            tint: .purple
        ),
        ShowcaseMessage(
            id: "style-scope-default",
            sender: "Scope",
            subject: "Inherited token style",
            preview: "This row omits revealStyle and inherits the scope default.",
            unread: true,
            tint: .cyan
        ),
        ShowcaseMessage(
            id: "style-custom-label",
            sender: "Label",
            subject: "Custom label",
            preview: "Only the label view is custom; layout remains library-owned.",
            unread: true,
            tint: .brown
        ),
    ]

    static let behaviorSamples: [ShowcaseMessage] = [
        ShowcaseMessage(
            id: "behavior-leading",
            sender: "Both Sides",
            subject: "Leading and trailing",
            preview: "Pin on the leading side, Archive and Delete on trailing.",
            unread: false,
            tint: .yellow
        ),
        ShowcaseMessage(
            id: "behavior-after-collapse",
            sender: "Timing",
            subject: "Run after collapse",
            preview: "Use after-collapse timing when a mutation should wait for close.",
            unread: true,
            tint: .mint
        ),
        ShowcaseMessage(
            id: "behavior-hold-open",
            sender: "Hold",
            subject: "Trigger and hold open",
            preview: "Keep the row open while the caller decides what happens next.",
            unread: false,
            tint: .brown
        ),
        ShowcaseMessage(
            id: "behavior-destructive",
            sender: "Destructive",
            subject: "Destructive full swipe",
            preview: "The destructive recipe stays in the structured action model.",
            unread: true,
            tint: .red
        ),
    ]

    static let containerSamples: [ShowcaseMessage] = [
        ShowcaseMessage(
            id: "container-list",
            sender: "List",
            subject: "List row",
            preview: "The common List host path.",
            unread: false,
            tint: .blue
        ),
        ShowcaseMessage(
            id: "container-scroll",
            sender: "Scroll",
            subject: "LazyVStack row",
            preview: "Use a scroll-view scope when rows live outside List.",
            unread: true,
            tint: .green
        ),
        ShowcaseMessage(
            id: "container-button",
            sender: "Button",
            subject: "Button row",
            preview: "The modifier is attached to the outer Button.",
            unread: false,
            tint: .orange
        ),
        ShowcaseMessage(
            id: "container-navigation",
            sender: "Navigation",
            subject: "NavigationLink row",
            preview: "The modifier is attached to the NavigationLink itself.",
            unread: false,
            tint: .purple
        ),
    ]
}

enum ShowcaseStatus {
    static let empty = "Ready"
}
