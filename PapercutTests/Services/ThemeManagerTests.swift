//
//  ThemeManagerTests.swift
//  PapercutTests
//

import Testing
import SwiftUI
@testable import Papercut

@Suite(.serialized)
struct ThemeManagerTests {

    // MARK: - Default State

    @MainActor
    @Test func init_defaultsToLightMode() {
        // Clear any stored value first
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        #expect(manager.mode == .light)
        #expect(manager.isDark == false)
        #expect(manager.colorScheme == .light)
    }

    // MARK: - Toggle

    @MainActor
    @Test func toggleTheme_switchesToDark() {
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        manager.toggleTheme()

        #expect(manager.mode == .dark)
        #expect(manager.isDark == true)
        #expect(manager.colorScheme == .dark)
    }

    @MainActor
    @Test func toggleTheme_switchesBackToLight() {
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        manager.toggleTheme() // -> dark
        manager.toggleTheme() // -> light

        #expect(manager.mode == .light)
        #expect(manager.isDark == false)
    }

    // MARK: - setMode

    @MainActor
    @Test func setMode_directlySetsDark() {
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        manager.setMode(.dark)

        #expect(manager.mode == .dark)
        #expect(manager.isDark == true)
    }

    @MainActor
    @Test func setMode_directlySetsLight() {
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        manager.setMode(.dark)
        manager.setMode(.light)

        #expect(manager.mode == .light)
    }

    // MARK: - Colors

    @MainActor
    @Test func colors_lightModeReturnsLightTokens() {
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        // In light mode, colors should be the light tokens
        // We can't directly compare Color values, but we can verify the function doesn't crash
        _ = manager.colors.background
        _ = manager.colors.textPrimary
        _ = manager.colors.accent
    }

    @MainActor
    @Test func colors_darkModeReturnsDarkTokens() {
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        manager.setMode(.dark)
        _ = manager.colors.background
        _ = manager.colors.textPrimary
        _ = manager.colors.accent
    }

    // MARK: - Persistence

    @MainActor
    @Test func persistence_togglePersistsToUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        manager.toggleTheme()

        let stored = UserDefaults.standard.string(forKey: "appThemeMode")
        #expect(stored == "dark")
    }

    @MainActor
    @Test func persistence_setModePersistsToUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "appThemeMode")
        let manager = ThemeManager()
        manager.setMode(.light)

        let stored = UserDefaults.standard.string(forKey: "appThemeMode")
        #expect(stored == "light")
    }

    // MARK: - Mode Enum

    @Test func modeEnum_rawValues() {
        #expect(ThemeManager.Mode.light.rawValue == "light")
        #expect(ThemeManager.Mode.dark.rawValue == "dark")
    }

    @Test func modeEnum_codable() throws {
        let data = try JSONEncoder().encode(ThemeManager.Mode.dark)
        let decoded = try JSONDecoder().decode(ThemeManager.Mode.self, from: data)
        #expect(decoded == .dark)
    }
}

// MARK: - ColorTokens Tests

@Suite(.serialized)
struct ColorTokensTests {

    @Test func lightTokens_haveAllProperties() {
        let tokens = ColorTokens.light
        _ = tokens.background
        _ = tokens.surface
        _ = tokens.glassOverlay
        _ = tokens.textPrimary
        _ = tokens.textSecondary
        _ = tokens.textTertiary
        _ = tokens.textMuted
        _ = tokens.accent
        _ = tokens.iconDefault
        _ = tokens.dotActive
        _ = tokens.dotInactive
        // If we get here without crashing, all tokens exist
    }

    @Test func darkTokens_haveAllProperties() {
        let tokens = ColorTokens.dark
        _ = tokens.background
        _ = tokens.surface
        _ = tokens.textPrimary
        _ = tokens.accent
    }

    @Test func glassOverlayOpacity_isReasonable() {
        #expect(ColorTokens.light.glassOverlayOpacity > 0)
        #expect(ColorTokens.light.glassOverlayOpacity <= 1)
        #expect(ColorTokens.dark.glassOverlayOpacity > 0)
        #expect(ColorTokens.dark.glassOverlayOpacity <= 1)
    }

    @Test func pastelConstants_exist() {
        _ = ColorTokens.pastelPink
        _ = ColorTokens.pastelSage
        _ = ColorTokens.pastelCoral
    }
}
