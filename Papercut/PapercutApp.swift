//
//  PapercutApp.swift
//  Papercut
//

import SwiftUI
import SwiftData

@main
struct PapercutApp: App {
    @State private var dependencies = AppDependencies.shared
    @State private var themeManager: ThemeManager

    init() {
        let theme = ThemeManager()

        // Handle screenshot/UI-testing launch arguments
        if CommandLine.arguments.contains("--dark-mode") {
            if !theme.isDark { theme.toggleTheme() }
        }
        if CommandLine.arguments.contains("--light-mode") {
            if theme.isDark { theme.toggleTheme() }
        }
        if CommandLine.arguments.contains("--reset-onboarding") {
            AppDependencies.shared.preferencesStore.resetToDefaults()
        }
        if CommandLine.arguments.contains("--skip-onboarding") {
            let store = AppDependencies.shared.preferencesStore
            if !store.hasCompletedOnboarding {
                // Set some default categories so the feed has data
                store.setFollowedCategories(["cs.AI", "cs.LG", "cs.CL", "cs.CV"])
                store.completeOnboarding()
            }
        }

        _themeManager = State(initialValue: theme)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dependencies.preferencesStore)
                .environment(dependencies.feedViewModel)
                .environment(themeManager)
                .modelContainer(dependencies.modelContainer)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
