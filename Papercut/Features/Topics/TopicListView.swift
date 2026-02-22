//
//  TopicListView.swift
//  Papercut
//

import SwiftUI

struct TopicListView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var viewModel: TopicListViewModel
    @State private var showingAddTopic = false
    @State private var appeared = false
    @Binding var showingSearch: Bool
    @Binding var showingSettings: Bool
    @Binding var topicToOpen: Topic?
    var namespace: Namespace.ID

    init(
        viewModel: TopicListViewModel,
        showingSearch: Binding<Bool>,
        showingSettings: Binding<Bool>,
        topicToOpen: Binding<Topic?>,
        namespace: Namespace.ID
    ) {
        self._viewModel = State(initialValue: viewModel)
        self._showingSearch = showingSearch
        self._showingSettings = showingSettings
        self._topicToOpen = topicToOpen
        self.namespace = namespace
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            if viewModel.topics.isEmpty {
                emptyState
            } else {
                topicGrid
            }

            // Top fade
            LinearGradient(
                stops: [
                    .init(color: theme.colors.background, location: 0),
                    .init(color: theme.colors.background.opacity(0.8), location: 0.5),
                    .init(color: theme.colors.background.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            // Floating header buttons (top-right)
            VStack {
                HStack(spacing: Spacing.md) {
                    Spacer()

                    Button { showingSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(theme.colors.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                            .glassEffect(.regular, in: .circle)
                    }
                    .buttonStyle(SoftPressButtonStyle())

                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(theme.colors.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                            .glassEffect(.regular, in: .circle)
                    }
                    .buttonStyle(SoftPressButtonStyle())
                }
                .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                .padding(.top, Spacing.xs)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddTopic) {
            AddTopicSheet { name, query, sortBy in
                viewModel.createTopic(name: name, query: query, sortBy: sortBy)
            }
        }
        .onAppear {
            viewModel.loadTopics()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Hero
                VStack(spacing: Spacing.xxl) {
                    ZStack {
                        Circle()
                            .fill(theme.colors.accent.opacity(0.08))
                            .frame(width: 80, height: 80)

                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(theme.colors.accent)
                            .symbolEffect(.breathe.pulse, options: .repeating.speed(0.4))
                    }

                    VStack(spacing: Spacing.md) {
                        Text("Research Topics")
                            .font(AppTypography.displayTitle)
                            .tracking(AppTypography.Tracking.displayTitle)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("Build a living timeline of any research field.\nNever miss a paper again.")
                            .font(AppTypography.bodyRegular)
                            .foregroundStyle(theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .padding(.bottom, Spacing.xxxl + Spacing.md)

                // Use cases
                VStack(spacing: Spacing.lg) {
                    useCaseCard(
                        icon: "clock.arrow.circlepath",
                        color: theme.colors.accent,
                        title: "Chronological Timeline",
                        subtitle: "Every paper in your field, from earliest to latest — scroll through the evolution of ideas",
                        delay: 0.05
                    )

                    useCaseCard(
                        icon: "arrow.down.app.fill",
                        color: .orange,
                        title: "Persistent & Offline",
                        subtitle: "Papers are saved locally. Close the app, come back days later, and pick up exactly where you left off",
                        delay: 0.1
                    )

                    useCaseCard(
                        icon: "sparkles",
                        color: Color(hex: "E4A853"),
                        title: "AI Summaries Included",
                        subtitle: "Every paper in your topic gets on-device AI summaries — same experience as the main feed",
                        delay: 0.15
                    )

                    useCaseCard(
                        icon: "bell.badge.fill",
                        color: .blue,
                        title: "Stay Current",
                        subtitle: "New papers are detected automatically when you open a topic — see what's new since your last visit",
                        delay: 0.2
                    )
                }
                .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                .padding(.bottom, Spacing.xxxl + Spacing.xl)

                // CTA
                Button {
                    showingAddTopic = true
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Create Your First Topic")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(theme.colors.background)
                    .padding(.horizontal, 32)
                    .padding(.vertical, LayoutConstants.Card.padding)
                    .background(theme.colors.textPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(PressButtonStyle())
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)
                .padding(.bottom, LayoutConstants.Screen.scrollPaddingBottom)
            }
        }
        .onAppear {
            guard !appeared else { return }
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private func useCaseCard(icon: String, color: Color, title: String, subtitle: String, delay: Double) -> some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.18), color.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(theme.colors.textPrimary)

                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.colors.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.xl)
        .background(theme.colors.surface.opacity(theme.isDark ? 0.15 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
        .overlay {
            RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                .strokeBorder(color.opacity(0.12), lineWidth: 1)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.easeOut(duration: 0.5).delay(delay), value: appeared)
    }

    // MARK: - Topic Grid

    private var topicGrid: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                // Header
                HStack {
                    Text("Research Topics")
                        .font(AppTypography.sectionTitle)
                        .tracking(AppTypography.Tracking.sectionTitle)
                        .foregroundStyle(theme.colors.textPrimary)

                    Spacer()

                    Button {
                        showingAddTopic = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.colors.accent)
                    }
                    .buttonStyle(SoftPressButtonStyle())
                }
                .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                .padding(.top, 60)

                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.topics, id: \.id) { topic in
                        TopicCard(topic: topic, namespace: namespace) {
                            topicToOpen = topic
                        } onDelete: {
                            withAnimation(AppAnimation.Interactive.spring) {
                                viewModel.deleteTopic(topic)
                            }
                        }
                    }
                }
                .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                .padding(.bottom, LayoutConstants.Screen.scrollPaddingBottom)
            }
        }
    }
}

// MARK: - Topic Card

struct TopicCard: View {
    let topic: Topic
    var namespace: Namespace.ID
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Title (prominent)
                Text(topic.name)
                    .font(.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Query as subtle context
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.textTertiary)

                    Text(topic.query)
                        .font(.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                        .lineLimit(1)
                }

                // Bottom row: badges + metadata
                HStack(spacing: Spacing.sm) {
                    // Paper count badge
                    if topic.totalResults > 0 || topic.lastPaperCount > 0 {
                        let count = topic.totalResults > 0 ? topic.totalResults : topic.lastPaperCount
                        Text("\(count) papers")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 3)
                            .background(theme.colors.accent.opacity(0.15))
                            .foregroundStyle(theme.colors.accent)
                            .clipShape(Capsule())
                    }

                    // Population status
                    if topic.isPopulating {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Populating...")
                                .font(.caption2)
                        }
                        .foregroundStyle(theme.colors.textMuted)
                    }

                    Spacer()

                    if let lastChecked = topic.lastCheckedAt {
                        Text(lastChecked.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(theme.colors.textMuted)
                    }

                    Menu {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(theme.colors.textMuted)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(LayoutConstants.Card.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surface.opacity(theme.isDark ? 0.2 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                    .strokeBorder(theme.colors.surface.opacity(0.5), lineWidth: 1)
            }
            .shadow(color: theme.isDark ? .clear : .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(PressButtonStyle(scale: 0.98))
        .matchedTransitionSource(id: topic.id, in: namespace)
    }
}
