//
//  FullScreenPaperCard.swift
//  Papercut
//

import SwiftUI

struct FullScreenPaperCard: View {
    let paper: Paper
    let currentSummary: String?
    let selectedStyle: SummaryStyle
    let isGeneratingSummary: Bool
    let onStyleSelected: (SummaryStyle) -> Void
    let onOpenPDF: () -> Void
    let onOpenAbstract: () -> Void
    let onShare: () -> Void
    let onToggleBookmark: () -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var showAbstract = false
    @State private var animateSummary = false
    @State private var breatheScale: CGFloat = 1.0
    @State private var showBookmarkOverlay = false

    /// Top offset: clearance for floating header overlay (wordmark + buttons)
    private let topInset: CGFloat = 54
    /// Bottom offset: breathing room above container edge (tab bar is handled by TabView)
    private let bottomInset: CGFloat = Spacing.lg

    private var palette: CategoryColors.Palette {
        CategoryColors.palette(for: paper.primaryCategory)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient based on primary category
                backgroundGradient
                    .ignoresSafeArea()

                // Content with proper spacing
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: topInset)

                    // Category & Date row
                    categoryDateRow
                        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)

                    Spacer()
                        .frame(height: Spacing.lg)

                    // Title
                    titleSection
                        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)

                    Spacer()
                        .frame(height: Spacing.sm)

                    // Authors
                    authorsSection
                        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)

                    Spacer()
                        .frame(height: Spacing.lg)

                    // Summary card - takes remaining space
                    summaryCard
                        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)

                    Spacer()
                        .frame(height: Spacing.md)

                    // Style selector chips
                    styleSelector
                        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)

                    Spacer()
                        .frame(minHeight: Spacing.md, maxHeight: Spacing.xl)

                    // Bottom actions
                    bottomActions
                        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                        .padding(.bottom, bottomInset)
                }

                // Double-tap bookmark overlay (Instagram-style)
                if showBookmarkOverlay {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 80, weight: .thin))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
        }
        .sheet(isPresented: $showAbstract) {
            AbstractSheet(paper: paper, onOpenInBrowser: onOpenAbstract)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: showBookmarkOverlay)
        .onAppear {
            withAnimation(AppAnimation.Breathe.animation) {
                breatheScale = AppAnimation.Breathe.scaleUp
            }
        }
    }

    private func handleDoubleTap() {
        // Only bookmark if not already bookmarked
        if !paper.isBookmarked {
            onToggleBookmark()
        }

        // Show overlay animation regardless
        withAnimation(.easeOut(duration: 0.2)) {
            showBookmarkOverlay = true
        }

        // Dismiss after a short moment
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeIn(duration: 0.3)) {
                showBookmarkOverlay = false
            }
        }
    }

    // MARK: - Background (Mesh Gradient Style)

    private var backgroundGradient: some View {
        ZStack {
            // Base background
            theme.colors.background

            // Mesh gradient blob - primary color
            RadialGradient(
                colors: [
                    palette.primary.opacity(theme.isDark ? 0.5 : 0.25),
                    palette.primary.opacity(theme.isDark ? 0.3 : 0.12),
                    palette.primary.opacity(0)
                ],
                center: .init(x: 0.3, y: 0.2),
                startRadius: 0,
                endRadius: 300
            )
            .scaleEffect(breatheScale)

            // Secondary accent blob
            RadialGradient(
                colors: [
                    palette.secondary.opacity(theme.isDark ? 0.4 : 0.18),
                    palette.secondary.opacity(theme.isDark ? 0.15 : 0.06),
                    palette.secondary.opacity(0)
                ],
                center: .init(x: 0.8, y: 0.7),
                startRadius: 0,
                endRadius: 250
            )
            .scaleEffect(breatheScale)

            // Subtle third accent for depth
            RadialGradient(
                colors: [
                    palette.tertiary.opacity(theme.isDark ? 0.25 : 0.1),
                    palette.tertiary.opacity(0)
                ],
                center: .init(x: 0.1, y: 0.8),
                startRadius: 0,
                endRadius: 180
            )
            .scaleEffect(breatheScale)
        }
    }

    // MARK: - Category & Date Row

    private var categoryDateRow: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            // Categories — show up to 3, scrollable if they overflow
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(paper.categories.prefix(3), id: \.self) { cat in
                        Text(cat)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundStyle(theme.colors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.colors.glassOverlay.opacity(theme.colors.glassOverlayOpacity))
                            .clipShape(Capsule())
                    }

                    if paper.categories.count > 3 {
                        Text("+\(paper.categories.count - 3)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(theme.colors.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(theme.colors.glassOverlay.opacity(theme.colors.glassOverlayOpacity * 0.5))
                            .clipShape(Capsule())
                    }
                }
            }

            // Date & New badge — pinned to trailing edge
            HStack(spacing: Spacing.md) {
                if paper.isRecent {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(Color(hex: "E4A853"))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color(hex: "E4A853").opacity(0.2))
                    .clipShape(Capsule())
                }

                Text(paper.formattedDate)
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
            }
            .fixedSize()
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        Text(paper.title)
            .font(AppTypography.displayTitle)
            .tracking(AppTypography.Tracking.displayTitle)
            .foregroundStyle(theme.colors.textPrimary)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Authors Section

    private var authorsSection: some View {
        HStack {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundStyle(theme.colors.textMuted)

            Text(paper.authors.displayString)
                .font(.subheadline)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)

            Spacer()

            // ArXiv ID
            Text(paper.arXivId)
                .font(.caption)
                .foregroundStyle(theme.colors.textTertiary)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                Image(systemName: selectedStyle.iconName)
                    .foregroundStyle(selectedStyle.accentColor)

                Text(selectedStyle.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.textPrimary)

                Spacer()

                if isGeneratingSummary {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(selectedStyle.accentColor)
                        Text("AI generating...")
                            .font(.caption)
                            .foregroundStyle(theme.colors.textMuted)
                    }
                }
            }

            Divider()
                .background(theme.colors.surface)

            // Content area with scroll
            ScrollView(.vertical, showsIndicators: false) {
                if isGeneratingSummary && (currentSummary?.isEmpty ?? true) {
                    VStack(spacing: Spacing.lg) {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(selectedStyle.accentColor)
                        Text("Generating summary with on-device AI...")
                            .font(.subheadline)
                            .foregroundStyle(theme.colors.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else if let summary = currentSummary, !summary.isEmpty {
                    Text(summary)
                        .font(AppTypography.bodyRegular)
                        .foregroundStyle(theme.colors.textPrimary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                } else {
                    Button {
                        onStyleSelected(selectedStyle)
                    } label: {
                        VStack(spacing: Spacing.lg) {
                            Image(systemName: "sparkles")
                                .font(.title)
                                .foregroundStyle(selectedStyle.accentColor)

                            Text("Tap to generate \(selectedStyle.displayName)")
                                .font(.subheadline)
                                .foregroundStyle(selectedStyle.accentColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
        }
        .padding(Spacing.xl)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                // Base glass effect
                theme.colors.surface.opacity(theme.isDark ? 0.15 : 0.5)

                // Subtle gradient matching selected style
                RadialGradient(
                    colors: [
                        selectedStyle.accentColor.opacity(0.15),
                        selectedStyle.accentColor.opacity(0.05),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 200
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius + 2))
        .overlay {
            RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius + 2)
                .strokeBorder(selectedStyle.accentColor.opacity(0.2), lineWidth: 1)
        }
    }

    // MARK: - Style Selector

    private var styleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(SummaryStyle.quickAccessStyles, id: \.self) { style in
                    styleChip(style)
                }

                // More button
                Menu {
                    ForEach(SummaryStyle.allCases.filter { !SummaryStyle.quickAccessStyles.contains($0) }) { style in
                        Button {
                            onStyleSelected(style)
                        } label: {
                            Label(style.displayName, systemImage: style.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "ellipsis")
                        Text("More")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(theme.colors.surface.opacity(theme.isDark ? 0.2 : 0.5))
                    .foregroundStyle(theme.colors.textPrimary)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func styleChip(_ style: SummaryStyle) -> some View {
        let isSelected = selectedStyle == style
        let hasContent = paper.hasSummary(for: style) || CloudSummaryStore.shared.hasSummary(paperId: paper.id, style: style)

        return Button {
            onStyleSelected(style)
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: style.iconName)
                    .font(.caption)

                Text(style.displayName)
                    .font(.caption)
                    .fontWeight(.medium)

                if hasContent && !isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? style.accentColor.opacity(0.3) : theme.colors.surface.opacity(theme.isDark ? 0.2 : 0.5))
            .foregroundStyle(isSelected ? style.accentColor : theme.colors.textPrimary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? style.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(PressButtonStyle())
        .sensoryFeedback(.selection, trigger: selectedStyle)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: 0) {
            // Bookmark Button
            Button {
                withAnimation(AppAnimation.Interactive.spring) {
                    onToggleBookmark()
                }
            } label: {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: paper.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(paper.isBookmarked ? Color(hex: "E4C95B") : theme.colors.textPrimary)
                        .scaleEffect(paper.isBookmarked ? 1.1 : 1.0)
                    Text(paper.isBookmarked ? "Saved" : "Save")
                        .font(.caption2)
                        .foregroundStyle(paper.isBookmarked ? Color(hex: "E4C95B") : theme.colors.textPrimary)
                }
                .frame(minWidth: 50)
            }
            .buttonStyle(SoftPressButtonStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: paper.isBookmarked)

            Spacer()

            // PDF Button
            actionButton(icon: "doc.text.fill", label: "PDF", action: onOpenPDF)

            Spacer()

            // Abstract toggle
            actionButton(icon: "text.justify.left", label: "Abstract") {
                showAbstract = true
            }

            Spacer()

            // ArXiv Link
            actionButton(icon: "globe", label: "ArXiv", action: onOpenAbstract)

            Spacer()

            // Share Button
            actionButton(icon: "square.and.arrow.up", label: "Share", action: onShare)
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.xl)
        .background(theme.colors.surface.opacity(theme.isDark ? 0.1 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.xl))
    }

    @State private var actionTapCount = 0

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            actionTapCount += 1
            action()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(theme.colors.textPrimary)
            .frame(minWidth: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressButtonStyle())
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: actionTapCount)
    }
}

// MARK: - Abstract Sheet
struct AbstractSheet: View {
    let paper: Paper
    let onOpenInBrowser: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Categories
                    HStack(spacing: Spacing.sm) {
                        ForEach(paper.categories, id: \.self) { cat in
                            Text(cat)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.xs)
                                .background(theme.colors.accent.opacity(0.1))
                                .foregroundStyle(theme.colors.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(paper.title)
                        .font(AppTypography.sectionTitle)
                        .tracking(AppTypography.Tracking.sectionTitle)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(paper.authors.displayString)
                        .font(.subheadline)
                        .foregroundStyle(theme.colors.textSecondary)

                    HStack {
                        Text("Published: \(paper.formattedDate)")
                        Spacer()
                        Text(paper.arXivId)
                    }
                    .font(.caption)
                    .foregroundStyle(theme.colors.textTertiary)

                    Divider()

                    Text("Abstract")
                        .font(.headline)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(paper.abstract)
                        .font(AppTypography.bodyRegular)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineSpacing(4)

                    // Open in browser button
                    Button {
                        onOpenInBrowser()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open on ArXiv")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.colors.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
                    }
                    .padding(.top, Spacing.md)
                }
                .padding()
            }
            .background(theme.colors.background)
            .navigationTitle("Full Abstract")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(theme.colors.accent)
                }
            }
        }
    }
}

#Preview {
    let paper = Paper(
        id: "https://arxiv.org/abs/2401.12345v1",
        title: "Attention Is All You Need: Transformer Architecture for Neural Machine Translation",
        abstract: "We propose a new simple network architecture...",
        authors: [Author(name: "Ashish Vaswani"), Author(name: "Noam Shazeer")],
        categories: ["cs.CL", "cs.LG"],
        publishedDate: Date(),
        updatedDate: Date(),
        pdfURL: "https://arxiv.org/pdf/2401.12345",
        abstractURL: "https://arxiv.org/abs/2401.12345"
    )

    FullScreenPaperCard(
        paper: paper,
        currentSummary: "This paper introduces the Transformer, a model based entirely on attention mechanisms. It achieves state-of-the-art results in machine translation while being faster to train.",
        selectedStyle: .tldr,
        isGeneratingSummary: false,
        onStyleSelected: { _ in },
        onOpenPDF: {},
        onOpenAbstract: {},
        onShare: {},
        onToggleBookmark: {}
    )
    .environment(ThemeManager())
}
