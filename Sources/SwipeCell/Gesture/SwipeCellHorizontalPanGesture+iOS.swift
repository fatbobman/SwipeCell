import Foundation
import SwiftUI

#if canImport(UIKit)
    struct SwipeCellHorizontalPanGesture: UIGestureRecognizerRepresentable {
        var configuration: SwipeCellConfiguration
        var onBegan: () -> Void
        var onChanged: (SwipeCellPanValue) -> Void
        var onEnded: (SwipeCellPanValue) -> Void
        var onCancelled: () -> Void

        func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
            Coordinator(motion: configuration.motion)
        }

        func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
            let recognizer = UIPanGestureRecognizer()
            recognizer.delegate = context.coordinator
            recognizer.maximumNumberOfTouches = 1
            // Must stay `true` (the UIKit default): once the horizontal pan begins, the row
            // content receives `touchesCancelled`, so an enclosing SwiftUI `Button` abandons its
            // press instead of firing on finger lift after a swipe. Pure taps never reach
            // `.began`, so tap/Button click paths are unaffected.
            recognizer.cancelsTouchesInView = true
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            return recognizer
        }

        func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
            context.coordinator.motion = configuration.motion
        }

        func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
            let translation = recognizer.translation(in: recognizer.view)
            let velocity = recognizer.velocity(in: recognizer.view)
            let translationSize = CGSize(width: translation.x, height: translation.y)
            let timestamp = ProcessInfo.processInfo.systemUptime
            let value = SwipeCellPanValue(
                translation: translationSize,
                predictedEndTranslation: SwipeCellPanIntent.predictedEndTranslation(
                    translation: translationSize,
                    velocity: velocity,
                    motion: configuration.motion
                ),
                velocity: velocity,
                timestamp: timestamp
            )

            switch recognizer.state {
            case .began:
                onBegan()
            case .changed:
                onChanged(value)
            case .ended:
                onEnded(value)
            case .cancelled, .failed:
                onCancelled()
            default:
                break
            }
        }

        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            var motion: SwipeCellConfiguration.Motion

            init(motion: SwipeCellConfiguration.Motion) {
                self.motion = motion
            }

            func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
                guard let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
                    return false
                }

                // Direction must be decided before SwiftUI claims the touch; otherwise List scroll loses.
                return SwipeCellPanIntent.isHorizontal(
                    velocity: panRecognizer.velocity(in: gestureRecognizer.view),
                    motion: motion
                )
            }

            func gestureRecognizer(
                _ gestureRecognizer: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
            ) -> Bool {
                // Tap/Button recognizers run alongside the pan so a Button row stays draggable
                // (a press must not pre-empt the pan before direction is known). Their click
                // path is cut by `cancelsTouchesInView` once the pan begins. List's scroll pan
                // stays exclusive.
                otherGestureRecognizer.view is UIScrollView == false
            }
        }
    }
#endif
