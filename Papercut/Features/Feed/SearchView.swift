//
//  SearchView.swift
//  Papercut
//

import SwiftUI

struct SearchView: View {
    @Environment(FeedViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [Paper] = []
    @State private var recentSearches: [String] = []
    @State private var error: Error?
    @State private var selectedPaper: Paper?
    @State private var browserURL: URL?

    @FocusState private var isSearchFieldFocused: Bool

    private let suggestedTopics = [
        "transformer", "diffusion models", "large language models",
        "reinforcement learning", "neural networks", "computer vision",
        "natural language processing", "generative AI", "GPT",
        "attention mechanism", "BERT", "image generation"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    if isSearching {
                        loadingView
                    } else if let error = error {
                        searchErrorView(error)
                    } else if !searchResults.isEmpty {
                        searchResultsList
                    } else if searchText.isEmpty {
                        suggestionsView
                    } else if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                        noResultsView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .browserSheet(url: $browserURL)
        .onAppear {
            isSearchFieldFocused = true
            loadRecentSearches()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.colors.textMuted)

                TextField("Search papers...", text: $searchText)
                    .foregroundStyle(theme.colors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.colors.textMuted)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))

            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(theme.colors.textPrimary)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Suggestions View

    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxxl) {
                // Recent searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        HStack {
                            Text("Recent")
                                .font(.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            Spacer()

                            Button("Clear") {
                                clearRecentSearches()
                            }
                            .font(.caption)
                            .foregroundStyle(theme.colors.textMuted)
                        }

                        ForEach(recentSearches, id: \.self) { search in
                            Button {
                                searchText = search
                                performSearch()
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(theme.colors.textMuted)

                                    Text(search)
                                        .foregroundStyle(theme.colors.textPrimary)

                                    Spacer()

                                    Image(systemName: "arrow.up.left")
                                        .font(.caption)
                                        .foregroundStyle(theme.colors.textMuted)
                                }
                            }
                            .padding(.vertical, Spacing.md)
                        }
                    }
                }

                // Suggested topics
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Trending Topics")
                        .font(.headline)
                        .foregroundStyle(theme.colors.textPrimary)

                    FlowLayout(spacing: Spacing.md) {
                        ForEach(suggestedTopics, id: \.self) { topic in
                            Button {
                                searchText = topic
                                performSearch()
                            } label: {
                                Text(topic)
                                    .font(.subheadline)
                                    .padding(.horizontal, LayoutConstants.Card.padding)
                                    .padding(.vertical, Spacing.md)
                                    .background(theme.colors.surface)
                                    .foregroundStyle(theme.colors.textPrimary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(Spacing.xl)
        }
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                Text("\(searchResults.count) results for \"\(searchText)\"")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.xl)

                ForEach(searchResults, id: \.id) { paper in
                    SearchResultCard(paper: paper) {
                        selectedPaper = paper
                    }
                }

                // View in feed option
                if !searchResults.isEmpty {
                    Button {
                        viewModel.searchQuery = searchText
                        viewModel.isSearching = true
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.stack")
                            Text("View all in feed")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.colors.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.md)
                }
            }
            .padding(.vertical, Spacing.lg)
        }
        .sheet(item: $selectedPaper) { paper in
            PaperDetailSheet(paper: paper, browserURL: $browserURL)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.xl) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.colors.accent)

            Text("Searching ArXiv...")
                .foregroundStyle(theme.colors.textMuted)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(theme.colors.textMuted)

            Text("No papers found")
                .font(.headline)
                .foregroundStyle(theme.colors.textPrimary)

            Text("Try different keywords or check your spelling")
                .font(.subheadline)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }

    // MARK: - Search Error View

    private func searchErrorView(_ error: Error) -> some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundStyle(theme.colors.textMuted)

            Text("Search failed")
                .font(.headline)
                .foregroundStyle(theme.colors.textPrimary)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                self.error = nil
                performSearch()
            } label: {
                Text("Retry")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(theme.colors.accent)
                    .clipShape(Capsule())
            }
        }
        .frame(maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        saveRecentSearch(searchText)

        Task {
            do {
                searchResults = try await viewModel.paperRepository.searchPapers(
                    query: searchText,
                    page: 0
                )
            } catch {
                self.error = error
            }
            isSearching = false
        }
    }

    // MARK: - Recent Searches Persistence

    private func loadRecentSearches() {
        if let searches = UserDefaults.standard.stringArray(forKey: "recentSearches") {
            recentSearches = searches
        }
    }

    private func saveRecentSearch(_ search: String) {
        var searches = recentSearches
        searches.removeAll { $0 == search }
        searches.insert(search, at: 0)
        searches = Array(searches.prefix(10))
        recentSearches = searches
        UserDefaults.standard.set(searches, forKey: "recentSearches")
    }

    private func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "recentSearches")
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let paper: Paper
    let onTap: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Categories
                HStack(spacing: Spacing.sm) {
                    ForEach(paper.categories.prefix(2), id: \.self) { cat in
                        Text(cat)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 3)
                            .background(theme.colors.accent.opacity(0.2))
                            .foregroundStyle(theme.colors.accent)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(paper.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.textMuted)
                }

                // Title
                Text(paper.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Authors
                Text(paper.authors.shortDisplayString)
                    .font(.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .lineLimit(1)
            }
            .padding(LayoutConstants.Card.padding)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Paper Detail Sheet
struct PaperDetailSheet: View {
    let paper: Paper
    @Binding var browserURL: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(FeedViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var theme
    @State private var selectedStyle: SummaryStyle = .tldr
    @State private var isGenerating = false
    @State private var summaryContent: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(paper.categories, id: \.self) { cat in
                                Text(cat)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(theme.colors.accent.opacity(0.1))
                                    .foregroundStyle(theme.colors.accent)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Text(paper.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(paper.authors.displayString)
                        .font(.subheadline)
                        .foregroundStyle(theme.colors.textSecondary)

                    HStack {
                        Label(paper.formattedDate, systemImage: "calendar")
                        Spacer()
                        Text(paper.arXivId)
                    }
                    .font(.caption)
                    .foregroundStyle(theme.colors.textTertiary)

                    Divider()

                    // Quick summary section
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("AI Summary")
                            .font(.headline)
                            .foregroundStyle(theme.colors.textPrimary)

                        // Style picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.md) {
                                ForEach(SummaryStyle.quickAccessStyles, id: \.self) { style in
                                    Button {
                                        selectedStyle = style
                                        loadSummary()
                                    } label: {
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: style.iconName)
                                                .font(.caption)
                                            Text(style.displayName)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, Spacing.lg)
                                        .padding(.vertical, Spacing.md)
                                        .background(selectedStyle == style ? style.accentColor.opacity(0.2) : theme.colors.surface)
                                        .foregroundStyle(selectedStyle == style ? style.accentColor : theme.colors.textPrimary)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        // Summary content
                        if isGenerating {
                            HStack(spacing: Spacing.md) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Generating...")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                            .padding(.vertical, Spacing.xxl)
                        } else if let content = summaryContent {
                            Text(content)
                                .font(AppTypography.bodyRegular)
                                .foregroundStyle(theme.colors.textPrimary)
                                .lineSpacing(4)
                        } else {
                            Button {
                                loadSummary()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Generate Summary")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.colors.accent.opacity(0.1))
                                .foregroundStyle(theme.colors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
                            }
                        }
                    }
                    .padding()
                    .background(theme.colors.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))

                    Divider()

                    // Abstract
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Abstract")
                            .font(.headline)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text(paper.abstract)
                            .font(AppTypography.bodyRegular)
                            .foregroundStyle(theme.colors.textPrimary)
                            .lineSpacing(4)
                    }

                    // Action buttons
                    HStack(spacing: Spacing.lg) {
                        Button {
                            if let url = paper.pdfURLObject {
                                browserURL = url
                            }
                        } label: {
                            Label("View PDF", systemImage: "doc.text.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.colors.accent)
                                .foregroundStyle(theme.isDark ? .white : .white)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
                        }

                        Button {
                            if let url = paper.abstractURLObject {
                                browserURL = url
                            }
                        } label: {
                            Label("ArXiv", systemImage: "globe")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.colors.surface)
                                .foregroundStyle(theme.colors.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
                        }
                    }
                }
                .padding()
            }
            .background(theme.colors.background)
            .navigationTitle("Paper Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSummary()
        }
    }

    private func loadSummary() {
        // Check cache first
        if let cached = viewModel.getCachedOrStoredSummary(for: paper, style: selectedStyle) {
            summaryContent = cached
            return
        }

        // Generate new summary
        isGenerating = true
        summaryContent = nil

        Task {
            do {
                let summary = try await viewModel.paperRepository.summarize(paper: paper, style: selectedStyle)
                summaryContent = summary.content
            } catch {
                summaryContent = "Failed to generate summary. Please try again."
            }
            isGenerating = false
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

#Preview {
    SearchView()
        .environment(AppDependencies.shared.feedViewModel)
        .environment(ThemeManager())
}
