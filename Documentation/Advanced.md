# SwipeCell v3 Advanced

Advanced covers customization inside SwipeCell's built-in slot and token
renderers. Start here after the default path feels clear: row scope, structured
`SwipeAction` values, slot/token reveal styles, ShapeStyle tint, and the default
label controls are covered in [Getting Started](GettingStarted.md) and
[Guides](Guides.md).

Use this guide when an action needs a custom label view, a shared custom action
style, progress-driven feedback, or stable tint identity for non-color
`ShapeStyle` values.

## Choose the Right Customization Level

Prefer the highest-level tool that expresses the change:

| Need | Use |
| --- | --- |
| Change action color, gradient, or material | `tint:` on `SwipeAction` |
| Change default icon/title metrics | `swipeActionDefaultLabelStyle(_:)` |
| Show only icons or both icon and title | `swipeActionLabelDisplayMode(_:)` |
| Use slot or token presentation for one row | `revealStyle:` on `swipeCellActions` |
| Let one action label react to progress or armed state | Custom label closure |
| Give all actions a shared chrome | Custom `SwipeActionStyle` |
| Keep arbitrary `ShapeStyle` tint stable across descriptor equality | `SwipeActionTint(key:_:)` |

Custom labels and custom styles still run inside SwipeCell's renderer. SwipeCell
continues to own side layout, equal action widths, hit testing, destructive
full-swipe activation, row coordination, and close/reset timing.

## Custom Labels

A custom label replaces the view rendered inside one action. SwipeCell still
supplies the action slot, context, tint, gesture handling, and trigger timing.

```swift
private enum InboxAction: Hashable {
    case more
}

private func trailingActions(for message: Message) -> [SwipeAction] {
    [
        SwipeAction(
            id: InboxAction.more,
            role: .normal(),
            tint: .purple
        ) {
            showMoreOptions(for: message)
        } label: { context in
            VStack(spacing: 5) {
                Image(systemName: context.isArmed ? "ellipsis.circle.fill" : "ellipsis.circle")
                    .font(.system(size: 19, weight: .semibold))

                Text(context.isArmed ? "Ready" : "More")
                    .font(.caption2.weight(.semibold))

                Capsule()
                    .fill(.white.opacity(0.75))
                    .frame(width: 18 + 20 * context.normalOpenProgress, height: 3)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.purple)
        },
    ]
}
```

The label closure receives `SwipeActionContext` every time SwipeCell publishes a
new action state. Keep the label a pure view of that context and any stable row
data captured by the action.

Custom labels own their visible chrome. In `.token`, the default token capsule
belongs to the structured default label, so a custom label does not
automatically inherit that capsule fill. If the custom label needs a filled
token, a full-slot background, or a different shape, draw it in the label or use
a custom `SwipeActionStyle`.

## `SwipeActionContext`

`SwipeActionContext` is the read-only state published to custom labels and
styles.

| Field | Meaning |
| --- | --- |
| `side` | The rendered side, leading or trailing. |
| `index` | The action index on that side. `0` is the outermost action. |
| `count` | Number of actions on that side. |
| `isOutermost` | Whether this action owns the outermost slot. |
| `role` | Public role kind: normal or destructive. |
| `normalOpenProgress` | Normalized progress toward the ordinary open extent. |
| `deformationProgress` | Normalized progress through destructive deformation. |
| `isArmed` | Continuous destructive fire-state for visual feedback. |
| `armChangeID` | Monotonic marker for active-drag fire-boundary crossings. |
| `armChangeKind` | Direction of the latest active-drag boundary crossing. |

Use `normalOpenProgress` for reveal intensity, progress bars, scale, or opacity.
Use `deformationProgress` and `isArmed` for destructive visual states. Prefer
`deformationProgress` and `isArmed`; the older destructive aliases are kept only
for source compatibility.

The context intentionally does not publish allocated action width, hit regions,
container frame values, or destructive activation thresholds. Those remain
renderer and interaction details so custom visuals cannot accidentally couple to
layout internals.

## Custom `SwipeActionStyle`

Use a custom style when multiple actions should share the same chrome while
keeping their structured labels.

```swift
struct CompactSwipeActionStyle: SwipeActionStyle {
    func makeBody(configuration: SwipeActionStyleConfiguration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.tint)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .opacity(0.72 + 0.28 * configuration.context.normalOpenProgress)
            }
    }
}
```

Apply the style where the actions should inherit it:

```swift
List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(
            message.id,
            trailing: trailingActions(for: message),
            revealStyle: .token
        )
}
.swipeActionStyle(CompactSwipeActionStyle())
.swipeCellScope()
```

`configuration.label` is the resolved action label, either the structured default
label or a custom label. `configuration.context` is the same per-action context
available to custom labels. `configuration.tint` is the resolved tint for that
action.

A style changes the action body's appearance. It does not change row identity,
action width, side placement, open/close thresholds, destructive activation, or
action fire timing. Put those decisions in `swipeCellActions`, `SwipeAction`
roles, and configuration APIs covered by [Guides](Guides.md).

## `SwipeActionStyleConfiguration.tint`

`configuration.tint` is a `SwipeActionTint`, and `SwipeActionTint` conforms to
`ShapeStyle`. Use it anywhere SwiftUI accepts a shape style:

```swift
struct PillSwipeActionStyle: SwipeActionStyle {
    func makeBody(configuration: SwipeActionStyleConfiguration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                configuration.tint,
                in: Capsule()
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .opacity(opacity(for: configuration.context))
    }

    private func opacity(for context: SwipeActionContext) -> Double {
        context.role == .destructive
            ? 1
            : 1 - 0.35 * Double(context.deformationProgress)
    }
}
```

The action that supplies the tint stays simple:

```swift
SwipeAction(
    "Archive",
    systemImage: "archivebox.fill",
    tint: LinearGradient(
        colors: [.blue, .indigo],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
) {
    archive(message)
}
```

Unkeyed non-color shape styles render correctly. Their equality is conservative:
two freshly built gradient values are not assumed to be the same action tint.

## `SwipeActionTint(key:_:)`

Use `SwipeActionTint(key:_:)` when a non-color `ShapeStyle` should participate
in stable `SwipeAction` equality. This is useful for inline action arrays that
are rebuilt often and should compare as the same descriptor when the semantic
tint has not changed.

```swift
private enum InboxTintKey: Hashable, Sendable {
    case archiveGradient
}

SwipeAction(
    id: InboxAction.archive,
    "Archive",
    systemImage: "archivebox.fill",
    tint: SwipeActionTint(
        key: InboxTintKey.archiveGradient,
        LinearGradient(
            colors: [.blue, .indigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
) {
    archive(message)
}
```

The key represents the identity of the tint, not a cached drawing resource. If
the visual meaning changes, change the key.

## Combine Labels, Styles, and Configuration

Custom labels and custom styles compose. A custom label can provide special
content for one action, while the style provides shared chrome for every action
in the styled subtree.

```swift
MessageRow(message: message)
    .swipeCellActions(
        message.id,
        trailing: [
            SwipeAction(
                id: InboxAction.more,
                tint: .purple
            ) {
                showMoreOptions(for: message)
            } label: { context in
                Label(
                    context.isArmed ? "Ready" : "More",
                    systemImage: context.isArmed ? "checkmark.circle.fill" : "ellipsis.circle"
                )
            }
        ],
        revealStyle: .slot
    )
    .swipeActionStyle(PillSwipeActionStyle())
```

Use this composition sparingly. If a change can be expressed with structured
labels, tint, or the default label style, keep it on the simpler path.

## Boundaries and Non-goals

Advanced customization is visual customization inside SwipeCell's built-in
renderer:

- Custom labels replace label content for one action.
- Custom styles replace action body chrome for a styled subtree.
- `SwipeActionContext` publishes normalized interaction state for visuals.
- `SwipeActionTint` carries color, shape style, and keyed tint identity.

The following remain owned by SwipeCell:

- Side layout and equal-width action slots.
- Hit testing and row gesture recognition.
- Destructive activation geometry and release resolution.
- Row coordination through `swipeCellScope` and `SwipeCellManager`.
- Close/reset lifecycle and action trigger timing.

If a design needs different action counts, action widths, reveal style, manager
control, templates, or destructive completion policies, use the configuration
and coordination APIs in [Guides](Guides.md) before reaching for a custom label
or style.

## Platform Notes for Custom Labels

Keep custom labels resilient across iOS and macOS:

- Drive visual state from `SwipeActionContext`, not from guessed frame sizes.
- Keep labels legible at the configured action width.
- Do not assume a destructive action has fired just because `isArmed` is true;
  it is visual state, not an action callback.
- Avoid putting model mutation into label views. Mutate state from the
  `SwipeAction` handler.
- Test token rows separately when the label draws its own chrome, because token
  presentation is intentionally more compact than slot presentation.
