import Foundation
import SwiftUI
import UIKit

enum EncouragementSystem {
    static func message(for injury: InjuryRecord) -> String {
        let pct = injury.progress
        switch pct {
        case 0..<0.15:    return "You've got this! Day one is always the hardest."
        case 0.15..<0.35: return "Great start! Keep following your care steps."
        case 0.35..<0.55: return "Halfway there, your body is doing amazing work!"
        case 0.55..<0.75: return "Looking good! You're healing really well."
        case 0.75..<0.95: return "Almost there! Just a few more days of care."
        default:           return "You did it! Fully recovered. Well done!"
        }
    }

    static let calmMessages: [String] = [
        "Take a breath. Let's handle this together",
        "Stay calm, we've got you covered"
    ]

    static func randomCalmMessage() -> String {
        calmMessages.randomElement() ?? calmMessages[0]
    }
}

struct HapticFeedback {
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

