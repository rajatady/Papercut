//
//  ContentView.swift
//  Papercut
//

import SwiftUI

struct ContentView: View {
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Group {
            if preferencesStore.hasCompletedOnboarding {
                FeedView()
            } else {
                OnboardingView()
            }
        }
        .background(theme.colors.background.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .environment(PreferencesStore())
        .environment(AppDependencies.shared.feedViewModel)
        .environment(ThemeManager())
}
