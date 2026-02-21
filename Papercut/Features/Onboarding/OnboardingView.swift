//
//  OnboardingView.swift
//  Papercut
//

import SwiftUI

struct OnboardingView: View {
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(ThemeManager.self) private var theme
    @State private var currentPage = 0
    @State private var selectedCategories: Set<String> = []
    @State private var animateGradient = false
    @State private var digestTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var notificationPermissionDenied = false

    private let popularCategories = [
        ("cs.AI", "AI", "cpu.fill"),
        ("cs.LG", "Machine Learning", "brain"),
        ("cs.CL", "Language & NLP", "text.bubble.fill"),
        ("cs.CV", "Computer Vision", "eye.fill"),
        ("cs.NE", "Neural Networks", "point.3.connected.trianglepath.dotted"),
        ("cs.RO", "Robotics", "gearshape.2.fill"),
        ("stat.ML", "Statistics ML", "chart.bar.fill"),
        ("physics.comp-ph", "Computational Physics", "atom"),
        ("q-bio.NC", "Neuroscience", "brain.head.profile.fill"),
        ("econ.GN", "Economics", "chart.line.uptrend.xyaxis"),
        ("cs.CR", "Security", "lock.shield.fill"),
        ("cs.SE", "Software Engineering", "chevron.left.forwardslash.chevron.right")
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            animatedBackground

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    categorySelectionPage.tag(1)
                    featuresPage.tag(2)
                    notificationPage.tag(3)
                    readyPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                LiquidDotsIndicator(totalPages: 5, currentPage: currentPage)
                    .padding(.bottom, Spacing.lg)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        ZStack {
            theme.colors.background

            // Pastel overlays for warmth
            Circle()
                .fill(ColorTokens.pastelPink.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: animateGradient ? -50 : 50, y: animateGradient ? -100 : -200)

            Circle()
                .fill(ColorTokens.pastelSage.opacity(0.15))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: animateGradient ? 80 : -60, y: animateGradient ? 100 : 200)

            Circle()
                .fill(ColorTokens.pastelCoral.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: animateGradient ? -30 : 70, y: animateGradient ? 200 : 50)
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo/Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.accent, ColorTokens.pastelSage],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundStyle(theme.colors.textPrimary)
            }

            VStack(spacing: Spacing.xl) {
                Text("Papercut")
                    .font(AppTypography.displayLarge)
                    .tracking(AppTypography.Tracking.displayLarge)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("Swipe through research.\nAI explains the rest.")
                    .font(.title3)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Feature highlights
            VStack(spacing: Spacing.xxl) {
                featureRow(icon: "hand.draw.fill", text: "Swipe to discover papers")
                featureRow(icon: "sparkles", text: "AI-powered summaries")
                featureRow(icon: "function", text: "Math & code explained simply")
            }
            .padding(.horizontal, 40)

            Spacer()

            nextButton(title: "Let's Go") {
                withAnimation(.spring()) {
                    currentPage = 1
                }
            }
        }
        .padding()
    }

    // MARK: - Category Selection Page

    private var categorySelectionPage: some View {
        VStack(spacing: Spacing.xxxl) {
            VStack(spacing: Spacing.md) {
                Text("What interests you?")
                    .font(AppTypography.sectionTitle)
                    .tracking(AppTypography.Tracking.sectionTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("Pick at least 3 to personalize your feed")
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .padding(.top, 60)

            // Category grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Spacing.lg) {
                    ForEach(Array(popularCategories.enumerated()), id: \.element.0) { index, category in
                        categoryCard(code: category.0, name: category.1, icon: category.2)
                            .staggeredEntry(index: index, total: popularCategories.count)
                    }
                }
                .padding(.horizontal)
            }

            // Selected count
            HStack {
                Text("\(selectedCategories.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(selectedCategories.count >= 3 ? theme.colors.accent : Color(hex: "E4A853"))

                if selectedCategories.count < 3 {
                    Text("• Need \(3 - selectedCategories.count) more")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "E4A853"))
                }
            }

            nextButton(title: "Continue", disabled: selectedCategories.count < 3) {
                preferencesStore.setFollowedCategories(Array(selectedCategories))
                withAnimation(.spring()) {
                    currentPage = 2
                }
            }
        }
        .padding()
    }

    // MARK: - Features Page

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("How it works")
                .font(AppTypography.sectionTitle)
                .tracking(AppTypography.Tracking.sectionTitle)
                .fontWeight(.bold)
                .foregroundStyle(theme.colors.textPrimary)

            VStack(spacing: Spacing.xxxl) {
                featureCard(
                    icon: "hand.point.up.fill",
                    color: theme.colors.accent,
                    title: "Swipe Up",
                    description: "Like stories — one paper per screen"
                )

                featureCard(
                    icon: "sparkles",
                    color: ColorTokens.pastelCoral,
                    title: "Tap for AI Magic",
                    description: "Get TL;DR, key findings, math explained & more"
                )

                featureCard(
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: ColorTokens.pastelSage,
                    title: "Code & Math",
                    description: "Complex concepts made simple"
                )

                featureCard(
                    icon: "magnifyingglass",
                    color: ColorTokens.pastelPink,
                    title: "Search Anything",
                    description: "Find papers on any topic instantly"
                )
            }
            .padding(.horizontal, Spacing.xxxl)

            Spacer()

            nextButton(title: "Almost There") {
                withAnimation(.spring()) {
                    currentPage = 3 // notification page
                }
            }
        }
        .padding()
    }

    // MARK: - Notification Page

    private var notificationPage: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.pastelCoral, ColorTokens.pastelPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(theme.colors.textPrimary)
            }

            VStack(spacing: Spacing.xl) {
                Text("Stay in the Loop")
                    .font(AppTypography.sectionTitle)
                    .tracking(AppTypography.Tracking.sectionTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("Never miss important research")
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            VStack(spacing: Spacing.lg) {
                featureCard(
                    icon: "newspaper.fill",
                    color: theme.colors.accent,
                    title: "Daily Digest",
                    description: "A morning summary of new papers in your fields"
                )

                featureCard(
                    icon: "sparkles",
                    color: ColorTokens.pastelCoral,
                    title: "Topic Alerts",
                    description: "Know when research drops in topics you follow"
                )

                featureCard(
                    icon: "flame.fill",
                    color: ColorTokens.pastelSage,
                    title: "Trending Papers",
                    description: "Don't miss breakout research"
                )
            }
            .padding(.horizontal, Spacing.xxxl)

            // Time picker
            HStack {
                Label("Delivery time", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.textSecondary)

                Spacer()

                DatePicker("", selection: $digestTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(theme.colors.accent)
            }
            .padding(.horizontal, 32)

            if notificationPermissionDenied {
                Text("You can enable notifications later in Settings")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "E4A853"))
                    .transition(.opacity)
            }

            Spacer()

            // Enable button
            nextButton(title: "Enable Notifications") {
                Task {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: digestTime)
                    preferencesStore.setDailyDigestTime(
                        hour: components.hour ?? 9,
                        minute: components.minute ?? 0
                    )
                    let granted = await preferencesStore.setNotificationsEnabled(true)
                    if !granted {
                        withAnimation { notificationPermissionDenied = true }
                    }
                    withAnimation(.spring()) {
                        currentPage = 4
                    }
                }
            }

            // Skip link
            Button {
                withAnimation(.spring()) {
                    currentPage = 4
                }
            } label: {
                Text("Maybe Later")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.textMuted)
            }
            .padding(.bottom, 16)
        }
        .padding()
    }

    // MARK: - Ready Page

    private var readyPage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(theme.colors.accent.opacity(0.2))
                    .frame(width: 150, height: 150)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(theme.colors.accent)
            }

            VStack(spacing: Spacing.xl) {
                Text("You're all set!")
                    .font(AppTypography.displayTitle)
                    .tracking(AppTypography.Tracking.displayTitle)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("Start swiping through the latest research")
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Selected categories preview
            VStack(spacing: Spacing.lg) {
                Text("Your interests")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.textMuted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(Array(selectedCategories), id: \.self) { code in
                            if let cat = popularCategories.first(where: { $0.0 == code }) {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: cat.2)
                                        .font(.caption)
                                    Text(cat.1)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.sm)
                                .background(theme.colors.surface)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .foregroundStyle(theme.colors.textPrimary)

            Spacer()

            nextButton(title: "Start Exploring") {
                preferencesStore.completeOnboarding()
            }
        }
        .padding()
    }

    // MARK: - Components

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.xl) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(theme.colors.accent)
                .frame(width: 40)

            Text(text)
                .font(AppTypography.bodyRegular)
                .foregroundStyle(theme.colors.textPrimary)

            Spacer()
        }
    }

    private func categoryCard(code: String, name: String, icon: String) -> some View {
        let isSelected = selectedCategories.contains(code)

        return Button {
            withAnimation(.spring(response: 0.3)) {
                if isSelected {
                    selectedCategories.remove(code)
                } else {
                    selectedCategories.insert(code)
                }
            }
        } label: {
            VStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textSecondary)
                    .frame(height: 34)

                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .background(isSelected ? theme.colors.accent.opacity(0.3) : theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.5))
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.xl)
                    .strokeBorder(isSelected ? theme.colors.accent : Color.clear, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: Spacing.xl))
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func featureCard(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .background(theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.xl))
    }

    private func nextButton(title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
                .background(
                    LinearGradient(
                        colors: disabled ? [theme.colors.textMuted.opacity(0.3), theme.colors.textMuted.opacity(0.3)] : [theme.colors.accent, ColorTokens.pastelSage],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.xl))
        }
        .disabled(disabled)
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
}

#Preview {
    OnboardingView()
        .environment(PreferencesStore())
        .environment(ThemeManager())
}
