//
//  AppTypography.swift
//  Papercut
//

import SwiftUI

enum AppTypography {
    // Display styles — serif (editorial/luxury feel)
    static let displayTitle = Font.system(size: 32, weight: .regular, design: .serif)
    static let displayLarge = Font.system(size: 38, weight: .regular, design: .serif)
    static let sectionTitle = Font.system(size: 22, weight: .semibold, design: .serif)

    // Body styles — system sans-serif
    static let bodyRegular = Font.system(size: 15, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .medium)
    static let bodySmall = Font.system(size: 13, weight: .medium)
    static let bodySmallBold = Font.system(size: 13, weight: .bold)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionMedium = Font.system(size: 12, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .regular)

    // Letter spacing constants
    enum Tracking {
        static let displayTitle: CGFloat = -0.5
        static let displayLarge: CGFloat = -1.5
        static let sectionTitle: CGFloat = -0.3
        static let labelCategory: CGFloat = 0.3
        static let labelSmall: CGFloat = 0.2
        static let iconLabel: CGFloat = 0.2
    }
}
