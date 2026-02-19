//
//  PaperCardView.swift
//  Papercut
//

import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    let enabledStyles: Set<SummaryStyle>
    let onSummarize: (Paper, SummaryStyle) -> Void
    let onOpenPDF: (Paper) -> Void
    let onShare: (Paper) -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var isAbstractExpanded = false
    @State private var summaryState = SummarySectionState()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Categories & Date
            HStack {
                HStack(spacing: Spacing.sm) {
                    ForEach(paper.categories.prefix(3), id: \.self) { category in
                        CategoryBadge(category: category)
                    }
                }

                Spacer()

                if paper.isRecent {
                    Label("New", systemImage: "sparkle")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }

                Text(paper.formattedDate)
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
            }

            // Title
            Text(paper.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(isAbstractExpanded ? nil : 3)
                .onTapGesture {
                    withAnimation {
                        isAbstractExpanded.toggle()
                    }
                }

            // Authors
            Text(paper.authors.shortDisplayString)
                .font(.subheadline)
                .foregroundStyle(theme.colors.textSecondary)

            // Abstract (expandable)
            if isAbstractExpanded {
                Text(paper.abstract)
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            // Summary Section
            SummarySection(
                paper: paper,
                enabledStyles: enabledStyles
            ) { style in
                onSummarize(paper, style)
            }

            // Action buttons
            HStack(spacing: Spacing.xl) {
                Button {
                    onOpenPDF(paper)
                } label: {
                    Label("PDF", systemImage: "doc.text")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(theme.colors.accent)

                Button {
                    onShare(paper)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Spacer()

                // ArXiv ID
                Text(paper.arXivId)
                    .font(.caption)
                    .foregroundStyle(theme.colors.textTertiary)
            }
        }
        .padding()
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
        .shadow(color: theme.isDark ? .clear : .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Compact Paper Card (for lists)
struct CompactPaperCardView: View {
    let paper: Paper

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                ForEach(paper.categories.prefix(2), id: \.self) { category in
                    CategoryBadge(category: category)
                }

                Spacer()

                Text(paper.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.textMuted)
            }

            Text(paper.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(2)

            Text(paper.authors.shortDisplayString)
                .font(.caption)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .padding(Spacing.lg)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
    }
}

#Preview {
    let paper = Paper(
        id: "https://arxiv.org/abs/2401.12345v1",
        title: "Attention Is All You Need: A Comprehensive Study of Transformer Architectures for Natural Language Processing",
        abstract: "The dominant sequence transduction models are based on complex recurrent or convolutional neural networks that include an encoder and a decoder. The best performing models also connect the encoder and decoder through an attention mechanism. We propose a new simple network architecture, the Transformer, based solely on attention mechanisms, dispensing with recurrence and convolutions entirely.",
        authors: [
            Author(name: "Ashish Vaswani"),
            Author(name: "Noam Shazeer"),
            Author(name: "Niki Parmar"),
            Author(name: "Jakob Uszkoreit")
        ],
        categories: ["cs.CL", "cs.LG", "cs.AI"],
        publishedDate: Date(),
        updatedDate: Date(),
        pdfURL: "https://arxiv.org/pdf/2401.12345",
        abstractURL: "https://arxiv.org/abs/2401.12345"
    )

    ScrollView {
        PaperCardView(
            paper: paper,
            enabledStyles: SummaryStyle.defaultEnabled,
            onSummarize: { _, _ in },
            onOpenPDF: { _ in },
            onShare: { _ in }
        )
        .padding()
    }
    .environment(ThemeManager())
}
