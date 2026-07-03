# SwipeCell v3 Guides

This guide covers real-app recipes after the default path in
[Getting Started](GettingStarted.md): container choices, caller-owned
coordination, action templates, destructive timing, row-level layout, default
label controls, and progress-driven row feedback.

SwipeCell v3 is built around the default slot/token renderer. The recipes below
customize that renderer and its coordination model; custom labels and custom
styles are covered in [Advanced](Advanced.md).

## Configuration Priority

When the same behavior can be configured in more than one place, SwipeCell uses
the nearest, most explicit value:

1. Platform defaults from `SwipeCellConfiguration.platformDefault`.
2. Environment overrides from `swipeCellConfiguration`.
3. Row-level arguments on `swipeCellActions`, such as `actionWidth`,
   `revealStyle`, and `settlingAnimation`.
4. Action-level role payloads, such as destructive activation and completion.

Use environment configuration for a section-wide default, and row-level
arguments only when a specific row should differ from its neighbors.

```swift
List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(
            message.id,
            trailing: trailingActions(for: message),
            revealStyle: message.isMuted ? .token : nil
        )
}
.swipeCellConfiguration { configuration in
    configuration.style.defaultRevealStyle = .slot
    configuration.geometry.defaultActionWidth = 76
}
.swipeCellScope()
```

The environment default above applies to every row in the scope. The muted row
still uses `.token` because its `revealStyle` argument is more explicit.

## Real Containers

Put one `swipeCellScope` on the container that owns the swipeable rows. Rows
inside the same scope coordinate with each other, so opening one row closes the
previous visible row.

### List

`List` is the default container. The no-argument scope uses the `.list`
container profile.

```swift
List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(
            message.id,
            trailing: trailingActions(for: message)
        )
}
.swipeCellScope()
```

### ScrollView and LazyVStack

For a custom scrolling stack, put the scope on the `ScrollView` and use
`container: .scrollView`.

```swift
ScrollView {
    LazyVStack(spacing: 10) {
        ForEach(messages) { message in
            MessageRow(message: message)
                .swipeCellActions(
                    message.id,
                    trailing: trailingActions(for: message)
                )
        }
    }
    .padding(16)
}
.swipeCellScope(container: .scrollView)
```

The `container` value describes the event-delivery scenario. It currently
matters for macOS indirect scroll handling; iOS direct touch treats the
container profiles equivalently.

### Single Cell ScrollView

For a detail page with one swipeable surface, attach the row identity to the
whole swipeable content and keep a single scope around that `ScrollView`.

```swift
ScrollView {
    MessageDetail(message: message)
        .swipeCellActions(
            message.id,
            trailing: trailingActions(for: message)
        )
}
.swipeCellScope(container: .scrollView)
```

This pattern treats the whole scrollable detail surface as the swipe owner. It
is useful for mail-detail style screens where the content is not a repeated row.

### Button and NavigationLink Rows

When the row itself is a `Button` or `NavigationLink`, attach
`swipeCellActions` to that outer control, not to a nested child inside its label.

```swift
NavigationLink(value: message) {
    MessageRow(message: message)
}
.swipeCellActions(
    message.id,
    trailing: trailingActions(for: message)
)
```

Closed rows keep their normal tap behavior. A horizontal swipe reveals the
actions instead of triggering the button or navigation target.

## Manager and Programmatic Open / Close

Most lists do not need to create a manager. Use a caller-owned
`SwipeCellManager` when another control should open or close rows.

```swift
struct InboxView: View {
    @State private var messages = Message.samples
    @State private var manager = SwipeCellManager()

    var body: some View {
        VStack {
            HStack {
                Button("Open First") {
                    guard let id = messages.first?.id else { return }
                    manager.open(id, side: .trailing, animated: true)
                }

                Button("Close") {
                    manager.close(animated: true)
                }
            }

            List(messages) { message in
                MessageRow(message: message)
                    .swipeCellActions(
                        message.id,
                        trailing: trailingActions(for: message)
                    )
            }
        }
        .swipeCellScope(manager: manager)
    }
}
```

`open(_:side:animated:)` returns `false` when the target row is not currently
registered or cannot open that side. `close(animated:)` returns `false` when no
row is open. Treat those booleans as command acceptance, not as animation
completion callbacks.

The public manager recipe is limited to caller-owned scope plus programmatic
open and close. Internal lifecycle methods are not part of the guide path.

## Action Template Injection

Use templates when many rows share the same row-agnostic actions. The template
is declared once at the container level, then each row resolves it by row id.

```swift
private enum InboxAction: Hashable {
    case flag
    case archive
    case delete
}

private var inboxTemplate: SwipeCellActionTemplate {
    SwipeCellActionTemplate(
        leading: [
            SwipeActionTemplate<Message.ID>(
                id: InboxAction.flag,
                "Flag",
                systemImage: "flag.fill",
                tint: Color.yellow.gradient
            ) { id in
                flag(id)
            },
        ],
        trailing: [
            SwipeActionTemplate<Message.ID>(
                id: InboxAction.delete,
                "Delete",
                systemImage: "trash.fill",
                role: .destructive(),
                tint: .red
            ) { id in
                delete(id)
            },
            SwipeActionTemplate<Message.ID>(
                id: InboxAction.archive,
                "Archive",
                systemImage: "archivebox.fill",
                tint: .blue
            ) { id in
                archive(id)
            },
        ]
    )
}

List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(message.id)
}
.swipeCellScope(actionTemplate: inboxTemplate)
```

There are two template types:

- `SwipeActionTemplate<RowID>` describes one action slot. It is generic over the
  row id type and receives the row id when the action fires.
- `SwipeCellActionTemplate` is the cell-level bundle for both sides. It erases
  `RowID` at construction so it can live in the scope environment.

Use `swipeCellScope(actionTemplate:)` for the common template in a container.
Use `swipeCellActionTemplate(_:)` to override the nearest template for a smaller
subtree. Rows that call the id-only `swipeCellActions(rowID)` resolve the nearest
template.

### Template Stop Rule

Templates are for row-agnostic actions. If the label, role, tint, or behavior
depends on row state beyond the row id, use inline actions for that row.

```swift
MessageRow(message: message)
    .swipeCellActions(
        message.id,
        trailing: message.isPinned
            ? unpinActions(for: message)
            : pinActions(for: message)
    )
```

This keeps state-dependent UI honest. A template receives only the row id; it
should not be used to hide row-specific branching behind a shared action bundle.

## Fire Timing

`SwipeActionFireTiming` controls when a normal action closure runs after an
action button is tapped.

| Timing | Use when |
|---|---|
| `.immediate` | The action can run as soon as the button is tapped. This is the default. |
| `.afterCollapse` | The row should visibly collapse before the action mutates data, such as deleting a row from the collection. |
| `.triggerAndHoldOpen` | The action should run immediately and keep the row in its triggered/open presentation until caller code closes it. |

```swift
SwipeAction(
    "Archive",
    systemImage: "archivebox.fill",
    tint: .blue,
    fireTiming: .afterCollapse
) {
    archive(message)
}
```

Use `.triggerAndHoldOpen` with a caller-owned manager when the user flow needs a
separate confirmation or status step.

```swift
SwipeAction(
    "Snooze",
    systemImage: "clock.fill",
    tint: .orange,
    fireTiming: .triggerAndHoldOpen
) {
    showSnoozeControls = true
}

Button("Done") {
    manager.close(animated: true)
}
```

## Destructive Actions

A destructive action is declared with `role: .destructive()`. The first action
on a side, index 0, owns the outermost full-swipe slot.

```swift
SwipeAction(
    "Delete",
    systemImage: "trash.fill",
    role: .destructive(),
    tint: .red
) {
    delete(message)
}
```

Direct button taps and full-swipe release are different paths:

- A button tap uses normal action timing. If a destructive completion policy
  needs a collapse boundary, the tap degrades to `.afterCollapse`.
- A full-swipe release uses `SwipeActionDestructive` activation and completion.

### Activation

Activation controls how far the user must swipe before a full-swipe release
fires the destructive action.

```swift
SwipeAction(
    "Delete",
    systemImage: "trash.fill",
    role: .destructive(
        .init(
            activation: .rowWidthFraction(0.65),
            completion: .triggerAfterReset
        )
    ),
    tint: .red
) {
    delete(message)
}
```

Available activation policies:

| Activation | Meaning |
|---|---|
| `.automatic` | Use the current side's configuration default. |
| `.actionWidthMultiplier(x)` | Activate after `x` action widths. |
| `.openExtentPlusDistance(points)` | Activate after normal open extent plus a fixed distance. |
| `.openExtentPlusActionWidths(x)` | Activate after normal open extent plus `x` action widths. |
| `.rowWidthFraction(x)` | Activate after a fraction of the row width. |

### Completion

Completion controls what happens after a destructive full-swipe release fires.

| Completion | Use when |
|---|---|
| `.directTrigger` | Run immediately and let SwipeCell collapse through the normal trigger path. This is the default. |
| `.triggerAfterReset` | Collapse first, then run the action. Use this when removing the row should not fight the close animation. |
| `.triggerHoldExpanded` | Run immediately and keep the row expanded until your code resolves it. |

For hold-expanded flows, the trigger controller is a one-shot resolver. Call
exactly one of `holdExpanded()` or `collapse()` from the destructive action. If
you hold the row and need to close it later, use a caller-owned
`SwipeCellManager`.

```swift
@State private var pendingDestructiveID: Message.ID?
@State private var manager = SwipeCellManager()

SwipeAction(
    id: InboxAction.delete,
    value: message.id,
    "Delete",
    systemImage: "trash.fill",
    role: .destructive(.init(completion: .triggerHoldExpanded)),
    tint: .red
) { id, controller in
    pendingDestructiveID = id
    controller.holdExpanded()
}

Button("Resolve") {
    guard let id = pendingDestructiveID else { return }
    markAsHandled(id)
    manager.close(animated: true)
    pendingDestructiveID = nil
}

List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(
            message.id,
            trailing: trailingActions(for: message)
        )
}
.swipeCellScope(manager: manager)
```

Call `controller.collapse()` instead of `holdExpanded()` when the action should
close from inside the destructive handler. Do not call both methods on the same
controller.

## Per-Cell Layout Options

Use row-level layout options for local presentation differences.

```swift
MessageRow(message: message)
    .swipeCellActions(
        message.id,
        trailing: trailingActions(for: message),
        actionWidth: message.isCompact ? 56 : nil,
        revealStyle: message.isImportant ? .token : nil,
        settlingAnimation: .easeInOut(duration: 0.22)
    )
```

- `actionWidth` changes the width of each action slot on that row.
- `revealStyle` chooses `.slot` or `.token` for that row.
- `settlingAnimation` changes the visible settle animation for that row.

Prefer environment defaults when most rows should share the same look. Prefer
row-level options when the row has a real local reason to differ.

## Default Label Display Modes

The default label can show icon and title, or icon only.

```swift
List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(
            message.id,
            trailing: trailingActions(for: message),
            revealStyle: .token
        )
}
.swipeActionLabelDisplayMode(.iconOnly)
.swipeActionDefaultLabelStyle(
    .system(
        iconSize: 18,
        titleSize: 11,
        iconWeight: .bold,
        titleWeight: .semibold
    )
)
.swipeCellScope()
```

Use `.iconOnly` for dense rows or compact token-style actions. Keep
`.iconAndTitle` when discoverability matters more than density.

## Progress-Driven Row Feedback

Rows can read `swipeCellNormalOpenProgress` from the environment to drive light
background or badge feedback while the row opens. The value is normalized around
the normal open range.

```swift
struct MessageRow: View {
    let message: Message

    @Environment(\.swipeCellNormalOpenProgress) private var normalOpenProgress

    var body: some View {
        HStack {
            Text(message.subject)
            Spacer()
        }
        .padding()
        .background {
            Rectangle()
                .fill(message.tint.opacity(0.14 * normalOpenProgress))
        }
    }
}
```

Keep this feedback lightweight. For custom action labels or custom action chrome
that need `SwipeActionContext`, continue with [Advanced](Advanced.md).

## Support Matrix

| Container | Scope | Status | Notes |
|---|---|---|---|
| `List` | `.swipeCellScope()` | Supported | Baseline container for repeated rows. |
| `ScrollView + LazyVStack` | `.swipeCellScope(container: .scrollView)` | Supported | Main custom-scroll container path. |
| Single-cell `ScrollView` | `.swipeCellScope(container: .scrollView)` | Supported | Treat the whole scroll surface as the swipe owner. |
| Button row | Scope on the containing list or stack | Supported | Attach `swipeCellActions` to the `Button` itself. |
| NavigationLink row | Scope on the containing list or stack | Supported | Attach `swipeCellActions` to the `NavigationLink` itself. |
| `LazyVGrid` | `.swipeCellScope(container: .scrollView)` | Limited | Use compact action widths and test the exact grid layout. |

`LazyVGrid` is a compact-cell layout, not a full-width row layout. Keep it
limited until the exact grid dimensions, action count, and destructive reach are
validated in the app that uses it.
