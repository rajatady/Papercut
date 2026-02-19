//
//  AppSpacing.swift
//  Papercut
//

import SwiftUI

/// 4px-base spacing scale
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
    static let xxxl: CGFloat = 24
}

/// Layout constants for specific UI elements
enum LayoutConstants {
    enum Card {
        static let borderRadius: CGFloat = 18
        static let padding: CGFloat = 14
    }

    enum Screen {
        static let paddingHorizontal: CGFloat = 22
        static let scrollPaddingBottom: CGFloat = 50
    }

    enum Header {
        static let paddingHorizontal: CGFloat = 20
        static let paddingTop: CGFloat = 6
        static let paddingBottom: CGFloat = 10
    }

    enum Dot {
        static let size: CGFloat = 6
        static let activeWidth: CGFloat = 18
        static let gap: CGFloat = 6
    }

    enum Avatar {
        static let size: CGFloat = 36
        static let borderRadius: CGFloat = 18
        static let borderWidth: CGFloat = 2.5
        static let overlap: CGFloat = -10
    }

    enum IconCircle {
        static let size: CGFloat = 36
        static let borderRadius: CGFloat = 18
    }
}
