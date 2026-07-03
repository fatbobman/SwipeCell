import CoreGraphics
import Testing

@testable import SwipeCell

@Suite("SwipeCell pan intent")
struct SwipeCellPanIntentTests {
    @Test("clear velocity decides horizontal intent")
    func clearVelocityDecidesHorizontalIntent() {
        #expect(SwipeCellPanIntent.isHorizontal(velocity: CGPoint(x: 20, y: 8)))
        #expect(!SwipeCellPanIntent.isHorizontal(velocity: CGPoint(x: 8, y: 20)))
    }

    @Test("translation breaks tied velocity without accepting ambiguous input")
    func translationBreaksTiedVelocity() {
        #expect(
            SwipeCellPanIntent.isHorizontal(
                translation: CGPoint(x: 12, y: 4),
                velocity: .zero
            )
        )
        #expect(
            !SwipeCellPanIntent.isHorizontal(
                translation: CGPoint(x: 4, y: 12),
                velocity: .zero
            )
        )
        #expect(
            !SwipeCellPanIntent.isHorizontal(
                translation: CGPoint(x: 8, y: 8),
                velocity: .zero
            )
        )
    }

    @Test("scroll-wheel delta resolves horizontal intent by dominant axis")
    func deltaUsesDominantAxis() {
        #expect(SwipeCellPanIntent.isHorizontal(delta: CGSize(width: 12, height: 4)))
        #expect(!SwipeCellPanIntent.isHorizontal(delta: CGSize(width: 4, height: 12)))
        #expect(!SwipeCellPanIntent.isHorizontal(delta: CGSize(width: 8, height: 8)))
    }
}
