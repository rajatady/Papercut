//
//  PapercutApp.swift
//  Papercut
//

import SwiftUI
import SwiftData

@main
struct PapercutApp: App {
    @State private var dependencies = AppDependencies.shared
    @State private var themeManager = ThemeManager()

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
