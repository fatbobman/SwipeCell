//
//  Created by Yang Xu on 2020/8/4.
//

import AudioToolbox
import Foundation
import SwiftUI

public enum SwipeCellSlotPosition: Int {
    case left, right, both, none
}

public enum SwipeCellSlotStyle {
    case normal, destructive, destructiveDelay, delay
}

public enum SwipeButtonStyle {
    case title, image, titleAndImage, view
}

public struct SwipeCellButton {
    public let buttonStyle: SwipeButtonStyle
    public let title: LocalizedStringKey?
    public let systemImage: String?
    public let titleColor: Color
    public let imageColor: Color
    public let view: (() -> AnyView)?
    public let backgroundColor: Color
    public let action: () -> Void
    public let feedback: Bool

    public init(
        buttonStyle: SwipeButtonStyle,
        title: LocalizedStringKey?,
        systemImage: String?,
        titleColor: Color = .white,
        imageColor: Color = .white,
        view: (() -> AnyView)?,
        backgroundColor: Color,
        action: @escaping () -> Void,
        feedback: Bool = true
    ) {
        self.buttonStyle = buttonStyle
        self.title = title
        self.systemImage = systemImage
        self.titleColor = titleColor
        self.imageColor = imageColor
        self.view = view
        self.backgroundColor = backgroundColor
        self.action = action
        self.feedback = feedback
    }
}

public struct SwipeCellSlot {
    public let buttonWidth: CGFloat  //按钮宽度
    public let slots: [SwipeCellButton]  //按钮数据
    public let slotStyle: SwipeCellSlotStyle  //是否包含销毁按钮,销毁按钮只能是最后一个添加
    public let appearAnimation: Animation
    public let dismissAnimation: Animation
    public let showAction: (() -> Void)?

    public init(
        slots: [SwipeCellButton],
        slotStyle: SwipeCellSlotStyle = .normal,
        buttonWidth: CGFloat = 74,
        appearAnimation: Animation = .easeOut(duration: 0.5),
        dismissAnimation: Animation = .interactiveSpring(),
        showAction: (() -> Void)? = nil
    ) {
        self.buttonWidth = buttonWidth
        self.slots = slots
        self.slotStyle = slotStyle
        self.appearAnimation = appearAnimation
        self.dismissAnimation = dismissAnimation
        self.showAction = showAction
    }

}

public struct SwipeCellStyle {
    public let destructiveWidth: CGFloat
    public let dismissWidth: CGFloat
    public let appearWidth: CGFloat
    public let alignment: Alignment
    public let vibrationForButton: Vibration
    public let vibrationForDestructive: Vibration
    public let autoResetTime: TimeInterval?

    public init(
        alignment: Alignment,
        dismissWidth: CGFloat,
        appearWidth: CGFloat,
        destructiveWidth: CGFloat = 180,
        vibrationForButton: Vibration,
        vibrationForDestructive: Vibration,
        autoResetTime: TimeInterval? = nil
    ) {
        self.destructiveWidth = destructiveWidth
        self.appearWidth = appearWidth
        self.dismissWidth = dismissWidth
        self.alignment = alignment
        self.vibrationForButton = vibrationForButton
        self.vibrationForDestructive = vibrationForDestructive
        self.autoResetTime = autoResetTime
    }

    public static func defaultStyle() -> SwipeCellStyle {
        SwipeCellStyle(
            alignment: .leading,
            dismissWidth: 30,
            appearWidth: 30,
            destructiveWidth: 220,
            vibrationForButton: .soft,
            vibrationForDestructive: .medium,
            autoResetTime: nil
        )
    }
}

public enum Vibration {
    case error
    case success
    case warning
    case light
    case medium
    case heavy
    @available(iOS 13.0, *)
    case soft
    @available(iOS 13.0, *)
    case rigid
    case selection
    case oldSchool
    case mute

    public func vibrate() {
        switch self {
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        case .rigid:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .oldSchool:
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        case .mute:
            break
        }
    }
}
