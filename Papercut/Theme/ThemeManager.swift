//
//  ThemeManager.swift
//  Papercut
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ThemeManager {
    enum Mode: String, Codable {
        case light
        case dark
    }

    private(set) var mode: Mode

    var colors: ColorTokens {
        mode == .light ? .light : .dark
    }

    var colorScheme: ColorScheme {
        mode == .light ? .light : .dark
    }

    var isDark: Bool {
        mode == .dark
    }

    private static let storageKey = "appThemeMode"

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.mode = Mode(rawValue: stored ?? "") ?? .light
    }

    func toggleTheme() {
        mode = (mode == .light) ? .dark : .light
        UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
    }

    func setMode(_ newMode: Mode) {
        mode = newMode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
    }
}
