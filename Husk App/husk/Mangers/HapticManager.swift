//
//  HapticManager.swift
//  husk
//
//  Created by Nathan Ellis on 31/05/2025.
//


import SwiftUI
import CoreHaptics
struct HapticManager {

    @AppStorage("isHapticFeedbackOn") static private var isHapticFeedbackEnabled: Bool = true

    static func selectionChanged() {
        if isHapticFeedbackEnabled {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }

    static func impactOccurred(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        if isHapticFeedbackEnabled {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    static func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        if isHapticFeedbackEnabled {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }
}
