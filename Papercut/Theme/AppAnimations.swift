//
//  AppAnimations.swift
//  Papercut
//

import SwiftUI

enum AppAnimation {
    /// Breathing blob / gradient pulsing
    enum Breathe {
        static let scaleUp: CGFloat = 1.015
        static let scaleDown: CGFloat = 0.985
        static let duration: Double = 3.5
        static let animation: Animation = .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }

    /// Spring snap for page/card transitions
    enum SpringSnap {
        static let response: Double = 0.5
        static let dampingFraction: Double = 0.8
        static let spring: Animation = .spring(response: response, dampingFraction: dampingFraction)
    }

    /// Staggered grid/card entry
    enum StaggeredEntry {
        static let scaleFrom: CGFloat = 0.4
        static let baseDelay: Double = 0.05
        static let itemDelay: Double = 0.06
        static let duration: Double = 0.4
    }

    /// Shimmer loading effect
    enum Shimmer {
        static let duration: Double = 1.5
    }

    /// Liquid dot indicators
    enum LiquidDots {
        static let collapsedWidth: CGFloat = 8
        static let expandedWidth: CGFloat = 18
        static let spring: Animation = .spring(response: 0.3, dampingFraction: 0.7)
    }

    /// Interactive spring for button presses, toggles
    enum Interactive {
        static let spring: Animation = .spring(response: 0.3, dampingFraction: 0.6)
    }
}

// MARK: - Press-feedback Button Styles

/// Scales down on press with a snappy spring bounce-back.
/// Used for chips, CTA buttons, and generate buttons.
struct PressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.90

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Press style for icon buttons (settings, search, action bar icons).
/// Shrinks more aggressively so small targets feel responsive.
struct SoftPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.spring(response: 0.15, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
