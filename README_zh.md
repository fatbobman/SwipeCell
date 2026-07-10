# SwipeCell

SwipeCell 为 SwiftUI 列表与自定义滚动容器中的行视图提供可配置、可协调的侧滑操作。

![Swift](https://img.shields.io/badge/Swift-6.2+-orange?style=flat) ![Platforms](https://img.shields.io/badge/Platforms-iOS%2018+%20%7C%20macOS%2015+-blue?style=flat) ![License](https://img.shields.io/badge/License-MIT-green?style=flat) [![DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/fatbobman/SwipeCell)

[English](README.md) | 中文

## 动机

SwiftUI 原生侧滑操作很适合标准容器，但自定义列表和滚动容器通常既需要相同的交互模型，也需要更充分地掌控渲染、协调与破坏性操作。

SwipeCell 延续熟悉的 action 风格 API，同时提供自有的 slot 与 token 渲染器、作用域内的行协调，以及边界明确的定制能力。版本 3 目前通过 `v3-beta` 分支开放测试；在正式取代 `main` 上的稳定版本前，其 API 与行为仍可能调整。

## 功能

<video src="https://github.com/user-attachments/assets/927526af-791f-47ac-99b2-87b84ec2b3c8" controls autoplay muted loop playsinline></video>

- 面向 SwiftUI 的行侧滑操作，适用于 `List`、`ScrollView` 与自定义滚动容器
- 支持 leading 与 trailing 操作、slot 与 token 呈现、`ShapeStyle` tint，以及结构化标签样式
- 提供作用域协调、编程式打开与关闭、可复用 action template，以及可配置的破坏性操作
- 原生支持 iOS 18+ 与 macOS 15+

## 快速开始

通过 Swift Package Manager 从当前 beta 分支添加 SwipeCell：

```swift
dependencies: [
    .package(
        url: "https://github.com/fatbobman/SwipeCell.git",
        branch: "v3-beta"
    )
]
```

随后向 target 添加 `.product(name: "SwipeCell", package: "SwipeCell")`，并在 swipe-cell scope 内为行视图附加操作：

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

## 文档

- 想构建第一个侧滑行并调整默认外观？请阅读[快速入门](Documentation/GettingStarted.md)。
- 想了解容器、协调、模板、触发时机与破坏性操作的实践方案？请阅读[使用指南](Documentation/Guides.md)。
- 想创建自定义标签、样式与进度驱动的视觉效果？请阅读[进阶定制](Documentation/Advanced.md)。

## 许可证

SwipeCell 采用 MIT 许可证。详情请参阅 [LICENSE.md](LICENSE.md)。

## Author

**Fatbobman (肘子)** — Blog: [fatbobman.com](https://fatbobman.com) · X: [@fatbobman](https://x.com/fatbobman)

## Support

If this project helps you, please consider supporting my work:

- 📮 Subscribe to [Fatbobman's Swift Weekly](https://weekly.fatbobman.com) — fresh Swift and Apple-ecosystem insights every week
- ☕️ [Buy Me a Coffee](https://buymeacoffee.com/fatbobman)
