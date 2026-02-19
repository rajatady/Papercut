//
//  AppColors.swift
//  Papercut
//

import SwiftUI

struct ColorTokens {
    // Core surfaces
    let background: Color
    let surface: Color
    let glassOverlay: Color
    let glassOverlayOpacity: Double

    // Text hierarchy
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textMuted: Color

    // Semantic
    let accent: Color
    let iconDefault: Color
    let dotActive: Color
    let dotInactive: Color

    // Pastel accent trio (constant across themes)
    static let pastelPink = Color(hex: "F2C6CF")
    static let pastelSage = Color(hex: "B8CCCA")
    static let pastelCoral = Color(hex: "E4BCB2")
}

extension ColorTokens {
    static let light = ColorTokens(
        background: Color(hex: "F5F5F3"),
        surface: Color(hex: "E4E4E2"),
        glassOverlay: Color(hex: "F5F5F3"),
        glassOverlayOpacity: 0.92,
        textPrimary: Color(hex: "1A1A1A"),
        textSecondary: Color(hex: "4A4A4A"),
        textTertiary: Color(hex: "C0C0C0"),
        textMuted: Color(hex: "999999"),
        accent: Color(hex: "8BAF8B"),
        iconDefault: Color(hex: "5A5A5A"),
        dotActive: Color(hex: "1A1A1A"),
        dotInactive: Color.black.opacity(0.10)
    )

    static let dark = ColorTokens(
        background: Color(hex: "121212"),
        surface: Color(hex: "1E1E1E"),
        glassOverlay: Color(hex: "121212"),
        glassOverlayOpacity: 0.92,
        textPrimary: Color(hex: "F0F0F0"),
        textSecondary: Color(hex: "B0B0B0"),
        textTertiary: Color(hex: "555555"),
        textMuted: Color(hex: "777777"),
        accent: Color(hex: "8BAF8B"),
        iconDefault: Color(hex: "A0A0A0"),
        dotActive: Color(hex: "F0F0F0"),
        dotInactive: Color.white.opacity(0.15)
    )
}

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
