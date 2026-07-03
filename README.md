# SwipeCell

SwipeCell is a SwiftUI library for building swipeable rows in custom lists and
scrolling surfaces. It starts close to SwiftUI's `swipeActions` model, then adds
built-in slot and token renderers, structured action styling, ShapeStyle tints,
scoped coordination, and controlled customization inside the default renderer.

<video src="https://github.com/user-attachments/assets/927526af-791f-47ac-99b2-87b84ec2b3c8" controls autoplay muted loop playsinline></video>

## Requirements

- Swift 6.2
- iOS 18+
- macOS 15+
- Swift Package Manager

## Beta Status

SwipeCell v3 is currently published for beta testing from the `v3-beta` branch.
The public `main` branch remains the stable version until v3 is ready to
replace it. APIs and behavior on `v3-beta` may continue to change during the
beta period.

## Installation

Add SwipeCell to your package dependencies:

```swift
.package(url: "https://github.com/fatbobman/SwipeCell.git", branch: "v3-beta")
```

Then add the product to your target:

```swift
.product(name: "SwipeCell", package: "SwipeCell")
```

## Quick Start

Import SwipeCell, attach actions to each row, and place `swipeCellScope()` on the
container that should coordinate the rows.

```swift
import SwiftUI
import SwipeCell

struct InboxView: View {
    @State private var messages = Message.samples

    var body: some View {
        List(messages) { message in
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
        }
        .swipeCellScope()
    }

    private func archive(_ message: Message) {
        // Update your model here.
    }

    private func delete(_ message: Message) {
        messages.removeAll { $0.id == message.id }
    }
}
```

The row id passed to `swipeCellActions` should be stable for the life of that
row. The scope coordinates open rows and close behavior inside the container.

## Customize the Default Look

The default path can still use leading and trailing actions, ShapeStyle tint,
token reveal, and environment overrides.

```swift
List(messages) { message in
    MessageRow(message: message)
        .swipeCellActions(
            message.id,
            leading: [
                SwipeAction(
                    "Pin",
                    systemImage: "pin.fill",
                    tint: Color.green.gradient
                ) {
                    pin(message)
                },
            ],
            trailing: [
                SwipeAction(
                    "Delete",
                    systemImage: "trash.fill",
                    role: .destructive(),
                    tint: Color.red.gradient
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
            ],
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
.swipeCellScope()
```

For a broader default, override the configuration in the environment:

```swift
.swipeCellConfiguration { configuration in
    configuration.style.defaultRevealStyle = .token
}
```

## Documentation

- [Getting Started](Documentation/GettingStarted.md): the default SwiftUI-like
  path, from a minimal row to default visual tuning.
- [Guides](Documentation/Guides.md): real containers, manager and template
  recipes, destructive behavior, timing, and layout options.
- [Advanced](Documentation/Advanced.md): custom labels, custom styles, context,
  and tint plumbing inside the built-in slot/token renderer.

## License

SwipeCell is available under the [MIT license](LICENSE.md).
