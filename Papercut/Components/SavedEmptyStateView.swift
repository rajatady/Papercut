//
//  SavedEmptyStateView.swift
//  Papercut
//

import SwiftUI

struct SavedEmptyStateView: View {
    let theme: ThemeManager

    @State private var showStep1 = false
    @State private var showStep2 = false
    @State private var showStep3 = false
    @State private var bookmarkBounce = false
    @State private var pulseRing = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated bookmark icon with pulse
            ZStack {
                // Pulse rings
                Circle()
                    .stroke(theme.colors.accent.opacity(0.15), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseRing ? 1.3 : 0.8)
                    .opacity(pulseRing ? 0 : 0.6)

                Circle()
                    .fill(theme.colors.accent.opacity(0.1))
                    .frame(width: 90, height: 90)

                Image(systemName: "bookmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(theme.colors.accent)
                    .scaleEffect(bookmarkBounce ? 1.15 : 1.0)
            }

            VStack(spacing: Spacing.md) {
                Text("No saved papers yet")
                    .font(AppTypography.sectionTitle)
                    .tracking(AppTypography.Tracking.sectionTitle)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("Papers you save will appear here")
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            // Animated step-by-step guide
            VStack(spacing: Spacing.xxl) {
                stepRow(
                    step: "1",
                    icon: "hand.draw.fill",
                    text: "Swipe through papers",
                    isVisible: showStep1
                )

                stepRow(
                    step: "2",
                    icon: "bookmark.fill",
                    text: "Tap the bookmark icon to save",
                    isVisible: showStep2
                )

                stepRow(
                    step: "3",
                    icon: "tray.full.fill",
                    text: "Access them anytime, even offline",
                    isVisible: showStep3
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, Spacing.lg)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseRing = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).repeatForever(autoreverses: true).delay(0.5)) {
                bookmarkBounce = true
            }

            // Stagger the steps in
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { showStep1 = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) { showStep2 = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.9)) { showStep3 = true }
        }
    }

    private func stepRow(step: String, icon: String, text: String, isVisible: Bool) -> some View {
        HStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(theme.colors.accent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(theme.colors.accent)
            }

            Text(text)
                .font(AppTypography.bodyRegular)
                .foregroundStyle(theme.colors.textPrimary)

            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 15)
    }
}

#Preview {
    SavedEmptyStateView(theme: ThemeManager())
}
