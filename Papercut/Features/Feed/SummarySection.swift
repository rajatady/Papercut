//
//  SummarySection.swift
//  Papercut
//

import SwiftUI

struct SummarySection: View {
    let paper: Paper
    let enabledStyles: Set<SummaryStyle>
    let onSummarize: (SummaryStyle) -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var selectedStyle: SummaryStyle?
    @State private var isExpanded = false
    @State private var streamingContent: String = ""
    @State private var isStreaming = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Style chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(Array(enabledStyles).sorted { $0.rawValue < $1.rawValue }) { style in
                        SummaryStyleChip(
                            style: style,
                            isSelected: selectedStyle == style,
                            isLoading: isStreaming && selectedStyle == style,
                            hasContent: paper.hasSummary(for: style)
                        ) {
                            selectStyle(style)
                        }
                    }
                }
            }

            // Summary content
            if let style = selectedStyle {
                summaryContent(for: style)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedStyle)
    }

    @ViewBuilder
    private func summaryContent(for style: SummaryStyle) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Image(systemName: style.iconName)
                    .foregroundStyle(style.accentColor)

                Text(style.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.textPrimary)

                Spacer()

                Button {
                    withAnimation {
                        selectedStyle = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.colors.textMuted)
                }
                .buttonStyle(.plain)
            }

            // Content
            if isStreaming {
                Text(streamingContent.isEmpty ? "Generating summary..." : streamingContent)
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(streamingContent.isEmpty ? theme.colors.textMuted : theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let summary = paper.summary(for: style), summary.isComplete {
                Text(summary.content)
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    onSummarize(style)
                } label: {
                    Label("Generate Summary", systemImage: "sparkles")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(theme.colors.accent)
            }
        }
        .padding()
        .background(style.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
    }

    private func selectStyle(_ style: SummaryStyle) {
        withAnimation {
            if selectedStyle == style {
                selectedStyle = nil
            } else {
                selectedStyle = style

                // Auto-generate if no summary exists
                if !paper.hasSummary(for: style) {
                    onSummarize(style)
                }
            }
        }
    }

    // MARK: - Streaming Updates

    func updateStreamingContent(_ content: String) {
        streamingContent = content
        isStreaming = true
    }

    func finishStreaming() {
        isStreaming = false
        streamingContent = ""
    }
}

// MARK: - Observable Summary State
@Observable
final class SummarySectionState {
    var selectedStyle: SummaryStyle?
    var streamingContent: String = ""
    var isStreaming = false

    func startStreaming(style: SummaryStyle) {
        selectedStyle = style
        streamingContent = ""
        isStreaming = true
    }

    func updateContent(_ content: String) {
        streamingContent = content
    }

    func finishStreaming() {
        isStreaming = false
    }

    func reset() {
        selectedStyle = nil
        streamingContent = ""
        isStreaming = false
    }
}

#Preview {
    let paper = Paper(
        id: "2401.12345",
        title: "Sample Paper Title",
        abstract: "This is a sample abstract.",
        authors: [Author(name: "John Doe")],
        categories: ["cs.AI"],
        publishedDate: Date(),
        updatedDate: Date(),
        pdfURL: "https://arxiv.org/pdf/2401.12345",
        abstractURL: "https://arxiv.org/abs/2401.12345"
    )

    SummarySection(
        paper: paper,
        enabledStyles: SummaryStyle.defaultEnabled,
        onSummarize: { _ in }
    )
    .padding()
    .environment(ThemeManager())
}
