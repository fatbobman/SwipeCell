import Foundation
import SwiftUI

struct SwipeCellPinnedCloseAnimationModifier: ViewModifier {
    let token: Int
    let animation: Animation
    let onCompletion: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .modifier(
                SwipeCellPinnedCloseCompletionObserver(
                    token: token,
                    onCompletion: onCompletion
                )
            )
            .animation(animation, value: token)
    }
}

private struct SwipeCellPinnedCloseCompletionObserver: AnimatableModifier {
    let token: Int
    let onCompletion: (Int) -> Void
    var progress: CGFloat

    init(token: Int, onCompletion: @escaping (Int) -> Void) {
        self.token = token
        self.onCompletion = onCompletion
        progress = CGFloat(token)
    }

    var animatableData: CGFloat {
        get { progress }
        set {
            progress = newValue
            notifyCompletionIfFinished()
        }
    }

    func body(content: Content) -> some View {
        content
    }

    private func notifyCompletionIfFinished() {
        guard token > 0, progress == CGFloat(token) else { return }

        DispatchQueue.main.async {
            onCompletion(token)
        }
    }
}
