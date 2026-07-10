# SwipeCell

SwipeCell brings configurable, coordinated swipe actions to rows in SwiftUI lists and custom scrolling surfaces.

![Swift](https://img.shields.io/badge/Swift-6.2+-orange?style=flat) ![Platforms](https://img.shields.io/badge/Platforms-iOS%2018+%20%7C%20macOS%2015+-blue?style=flat) ![License](https://img.shields.io/badge/License-MIT-green?style=flat) [![DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/fatbobman/SwipeCell)

English | [中文](README_zh.md)

## Motivation

SwiftUI's native swipe actions are a natural fit for standard containers, but custom lists and scrolling surfaces often need the same interaction model with greater control over rendering, coordination, and destructive behavior.

SwipeCell keeps the familiar action-based API while providing its own slot and token renderers, scoped row coordination, and controlled customization. Version 3 is currently available for beta testing from the `v3-beta` branch, so its API and behavior may still evolve before replacing the stable release on `main`.

## Features

<video src="https://github.com/user-attachments/assets/927526af-791f-47ac-99b2-87b84ec2b3c8" controls autoplay muted loop playsinline></video>

- SwiftUI-first row actions for `List`, `ScrollView`, and custom scrolling surfaces
- Leading and trailing actions with slot or token presentation, `ShapeStyle` tints, and structured label styling
- Scoped coordination, programmatic open and close, reusable action templates, and configurable destructive behavior
- Native support for iOS 18+ and macOS 15+

## Quick Start

Add SwipeCell with Swift Package Manager from the current beta branch:

```swift
dependencies: [
    .package(
        url: "https://github.com/fatbobman/SwipeCell.git",
        branch: "v3-beta"
    )
]
```

Then add `.product(name: "SwipeCell", package: "SwipeCell")` to your target and attach actions to a row inside a swipe-cell scope:

```swift
import SwiftUI
import SwipeCell

struct InboxView: View {
    var body: some View {
        List(1...5, id: \.self) { messageID in
            Text("Message \(messageID)")
                .swipeCellActions(
                    messageID,
                    trailing: [
                        SwipeAction(
                            "Delete",
                            systemImage: "trash.fill",
                            role: .destructive(),
                            tint: .red
                        ) {
                            print("Delete message \(messageID)")
                        }
                    ]
                )
        }
        .swipeCellScope()
    }
}
```

## Documentation

- Want to build your first row and tune the default appearance? Read [Getting Started](Documentation/GettingStarted.md).
- Want recipes for containers, coordination, templates, timing, and destructive actions? Read [Guides](Documentation/Guides.md).
- Want to create custom labels, styles, and progress-driven visuals? Read [Advanced](Documentation/Advanced.md).

## License

SwipeCell is available under the MIT license. See [LICENSE.md](LICENSE.md) for more information.

## Author

**Fatbobman (肘子)** — Blog: [fatbobman.com](https://fatbobman.com) · X: [@fatbobman](https://x.com/fatbobman)

## Support

If this project helps you, please consider supporting my work:

- 📮 Subscribe to [Fatbobman's Swift Weekly](https://weekly.fatbobman.com) — fresh Swift and Apple-ecosystem insights every week
- ☕️ [Buy Me a Coffee](https://buymeacoffee.com/fatbobman)
