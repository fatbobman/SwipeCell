# SwipeCell v3 Getting Started

This guide teaches the default SwipeCell path: start with a row that feels close
to SwiftUI `swipeActions`, then add the small visual controls that make SwipeCell
useful in real apps.

After this guide, continue with [Guides](Guides.md) for real containers,
manager/template recipes, destructive timing, and support boundaries. Use
[Advanced](Advanced.md) only when you need custom labels, custom styles, or
custom tint plumbing inside the built-in renderer.

## Establish Scope

A scope coordinates the rows inside a container. Put `swipeCellScope()` on the
view that owns the row collection, such as a `List` or `ScrollView`.

```swift
import SwiftUI
import SwipeCell

struct InboxView: View {
    @State private var messages = Message.samples

    var body: some View {
        List(messages) { message in
            MessageRow(message: message)
                .swipeCellActions(message.id, trailing: actions(for: message))
        }
        .swipeCellScope()
    }
}
```

Use a stable row id. If the id changes while the same row is on screen, SwipeCell
must treat it as a different row.

## Attach `swipeCellActions`

`swipeCellActions(_:leading:trailing:)` declares the actions for one row. The
first argument is the row identity; the action arrays describe what appears on
each side.

```swift
private func actions(for message: Message) -> [SwipeAction] {
    [
        SwipeAction(
            "Archive",
            systemImage: "archivebox.fill",
            tint: .blue
        ) {
            archive(message)
        },
    ]
}
```

The action content is structured: a title, an SF Symbol name, an optional role,
a tint, and a closure.

## Add Leading and Trailing Actions

Use `leading` and `trailing` to match the row direction you want to reveal.

```swift
MessageRow(message: message)
    .swipeCellActions(
        message.id,
        leading: [
            SwipeAction(
                "Pin",
                systemImage: "pin.fill",
                tint: .green
            ) {
                pin(message)
            },
        ],
        trailing: [
            SwipeAction(
                "Archive",
                systemImage: "archivebox.fill",
                tint: .blue
            ) {
                archive(message)
            },
        ]
    )
```

The row id should come from your model, not from the current array index.

## Optional: Stabilize Action Identity

The simple `SwipeAction("Archive", ...) { ... }` initializer is enough for most
rows. When inline actions are rebuilt often and the button identity should remain
stable, pass an action id. When the handler only needs the row id, use
`id:value:` to keep the action identity separate from the handler input.

```swift
private enum InboxAction: Hashable {
    case archive
    case delete
}

private func trailingActions(for message: Message) -> [SwipeAction] {
    [
        SwipeAction(
            id: InboxAction.delete,
            value: message.id,
            "Delete",
            systemImage: "trash.fill",
            role: .destructive(),
            tint: .red,
            action: delete
        ),
        SwipeAction(
            id: InboxAction.archive,
            value: message.id,
            "Archive",
            systemImage: "archivebox.fill",
            tint: .blue,
            action: archive
        ),
    ]
}

private func archive(_ id: Message.ID) {
    // Update your model here.
}

private func delete(_ id: Message.ID) {
    messages.removeAll { $0.id == id }
}
```

## Use a Destructive Action

Mark a destructive action with `role: .destructive()`.

```swift
MessageRow(message: message)
    .swipeCellActions(
        message.id,
        trailing: [
            SwipeAction(
                "Delete",
                systemImage: "trash.fill",
                role: .destructive(),
                tint: .red
            ) {
                delete(message)
            },
            SwipeAction(
                "Archive",
                systemImage: "archivebox.fill",
                tint: .blue
            ) {
                archive(message)
            },
        ]
    )
```

Put the destructive action first (index 0) in its side array — that position
owns the outermost full-swipe slot. Detailed activation and completion policies
belong in [Guides](Guides.md).

## Use ShapeStyle Tint

`SwipeAction` accepts `Color` and arbitrary SwiftUI `ShapeStyle` values. This
lets the default label and chrome use gradients without custom rendering.

Pass gradient-tinted actions into `.swipeCellActions` as you normally would:

```swift
SwipeAction(
    "Favorite",
    systemImage: "star.fill",
    tint: Color.yellow.gradient
) {
    favorite(message)
}

SwipeAction(
    "Delete",
    systemImage: "trash.fill",
    role: .destructive(),
    tint: LinearGradient(
        colors: [.red, .orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
) {
    delete(message)
}
```

## Choose Slot or Token Reveal Style

The default reveal style is `.slot`. Use `.token` on a row when you want compact
floating action tokens.

```swift
MessageRow(message: message)
    .swipeCellActions(
        message.id,
        leading: leadingActions(for: message),
        trailing: trailingActions(for: message),
        revealStyle: .token
    )
```

The top row shows `.slot`; the bottom row shows `.token` with compact capsules.

Use row-level `revealStyle` when a specific row should differ from the surrounding
defaults.

## Tune the Default Label

The default label can be tuned through environment modifiers. This keeps the
structured `SwipeAction` path while changing the rendered icon/title metrics or
display mode.

```swift
List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(
            message.id,
            trailing: trailingActions(for: message),
            revealStyle: .token
        )
}
.swipeActionDefaultLabelStyle(
    .system(
        iconSize: 18,
        titleSize: 11,
        iconWeight: .semibold,
        titleWeight: .semibold
    )
)
.swipeActionLabelDisplayMode(.iconOnly)
.swipeCellScope()
```

Use [Advanced](Advanced.md) when you need to replace the label view itself.

## Override Defaults with Environment Configuration

Use `swipeCellConfiguration` for a narrow environment override. Start with one
field at a time; the full configuration domain is covered in [Guides](Guides.md)
and later reference material.

```swift
List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(
            message.id,
            leading: leadingActions(for: message),
            trailing: trailingActions(for: message)
        )
}
.swipeCellConfiguration { configuration in
    configuration.style.defaultRevealStyle = .token
}
.swipeCellScope()
```

This changes the inherited default reveal style. A row-level `revealStyle`
argument still describes that row explicitly.

## Use Button and NavigationLink Rows

When the row itself is a `Button` or `NavigationLink`, attach
`swipeCellActions` to the row view, outside the label builder.

```swift
Button {
    open(message)
} label: {
    MessageRow(message: message)
}
.buttonStyle(.plain)
.swipeCellActions(
    message.id,
    trailing: trailingActions(for: message)
)
```

The same rule applies to `NavigationLink`: put the modifier on the
`NavigationLink`, not on a nested child inside its label.

## Where to Go Next

- Read [Guides](Guides.md) for List / ScrollView / Grid support, manager-driven
  open/close, action templates, destructive timing, and per-cell layout options.
- Read [Advanced](Advanced.md) for custom labels, custom action styles, and
  custom tint plumbing inside the built-in slot/token renderer.
