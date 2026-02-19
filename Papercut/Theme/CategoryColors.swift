//
//  CategoryColors.swift
//  Papercut
//

import SwiftUI

/// Centralized category-to-color mapping.
/// Extracted from FullScreenPaperCard for reuse across the app.
enum CategoryColors {
    struct Palette {
        let primary: Color
        let secondary: Color
        let tertiary: Color
    }

    static func palette(for categoryCode: String?) -> Palette {
        guard let code = categoryCode else { return defaults }
        if code.hasPrefix("cs.") { return cs }
        if code.hasPrefix("math.") { return math }
        if code.hasPrefix("stat.") { return stat }
        if code.hasPrefix("physics.") { return physics }
        if code.hasPrefix("q-bio.") { return qbio }
        if code.hasPrefix("q-fin.") { return qfin }
        if code.hasPrefix("econ.") { return econ }
        if code.hasPrefix("eess.") { return eess }
        return defaults
    }

    private static let cs = Palette(
        primary: Color(red: 0.3, green: 0.5, blue: 0.9),
        secondary: Color(red: 0.5, green: 0.3, blue: 0.8),
        tertiary: Color(red: 0.2, green: 0.6, blue: 0.6)
    )

    private static let math = Palette(
        primary: Color(red: 0.6, green: 0.3, blue: 0.8),
        secondary: Color(red: 0.4, green: 0.4, blue: 0.9),
        tertiary: Color(red: 0.7, green: 0.2, blue: 0.5)
    )

    private static let stat = Palette(
        primary: Color(red: 0.9, green: 0.5, blue: 0.3),
        secondary: Color(red: 0.8, green: 0.4, blue: 0.5),
        tertiary: Color(red: 0.7, green: 0.6, blue: 0.3)
    )

    private static let physics = Palette(
        primary: Color(red: 0.3, green: 0.7, blue: 0.8),
        secondary: Color(red: 0.2, green: 0.5, blue: 0.7),
        tertiary: Color(red: 0.4, green: 0.6, blue: 0.5)
    )

    private static let qbio = Palette(
        primary: Color(red: 0.3, green: 0.7, blue: 0.4),
        secondary: Color(red: 0.4, green: 0.6, blue: 0.3),
        tertiary: Color(red: 0.2, green: 0.5, blue: 0.5)
    )

    private static let qfin = Palette(
        primary: Color(red: 0.8, green: 0.6, blue: 0.3),
        secondary: Color(red: 0.7, green: 0.5, blue: 0.4),
        tertiary: Color(red: 0.6, green: 0.7, blue: 0.3)
    )

    private static let econ = Palette(
        primary: Color(red: 0.85, green: 0.75, blue: 0.3),
        secondary: Color(red: 0.7, green: 0.6, blue: 0.4),
        tertiary: Color(red: 0.8, green: 0.5, blue: 0.3)
    )

    private static let eess = Palette(
        primary: Color(red: 0.4, green: 0.6, blue: 0.8),
        secondary: Color(red: 0.3, green: 0.5, blue: 0.7),
        tertiary: Color(red: 0.5, green: 0.4, blue: 0.6)
    )

    private static let defaults = Palette(
        primary: Color(red: 0.3, green: 0.5, blue: 0.9),
        secondary: Color(red: 0.5, green: 0.3, blue: 0.8),
        tertiary: Color(red: 0.2, green: 0.6, blue: 0.6)
    )
}
