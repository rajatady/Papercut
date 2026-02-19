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
