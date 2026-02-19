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
    @State private var showSuggestions = true

    @FocusState private var isSearchFieldFocused: Bool

    private let suggestedTopics = [
        "transformer", "diffusion models", "large language models",
        "reinforcement learning", "neural networks", "computer vision",
        "natural language processing", "generative AI", "GPT",
        "attention mechanism", "BERT", "image generation"
    ]

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                    .padding(.top, Spacing.lg)

                if isSearching {
                    loadingView
                } else if let error = error {
                    searchErrorView(error)
                } else if !searchResults.isEmpty {
                    searchResultsList
                } else if showSuggestions {
                    suggestionsView
                } else if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                    noResultsView
                }
            }
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSearchFieldFocused ? theme.colors.accent : theme.colors.textMuted)

                TextField("Search papers, authors, topics...", text: $searchText)
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { _, newValue in
                        if newValue.isEmpty {
                            searchResults = []
                            showSuggestions = true
                            error = nil
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        withAnimation(AppAnimation.Interactive.spring) {
                            searchText = ""
                            searchResults = []
                            showSuggestions = true
                            error = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.colors.textMuted)
                    }
                    .buttonStyle(SoftPressButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
            .background(theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.7))
            .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                    .strokeBorder(
                        isSearchFieldFocused ? theme.colors.accent.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            }

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .buttonStyle(SoftPressButtonStyle())
        }
        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
        .padding(.bottom, Spacing.md)
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
    }

    // MARK: - Suggestions View

    private var suggestionsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xxxl) {
                // Recent searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        HStack {
                            Label("Recent", systemImage: "clock")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.colors.textPrimary)

                            Spacer()

                            Button {
                                withAnimation(AppAnimation.Interactive.spring) {
                                    clearRecentSearches()
                                }
                            } label: {
                                Text("Clear")
                                    .font(.caption)
                                    .foregroundStyle(theme.colors.textMuted)
                            }
                            .buttonStyle(SoftPressButtonStyle())
                        }

                        ForEach(Array(recentSearches.enumerated()), id: \.element) { index, search in
                            Button {
                                searchText = search
                                performSearch()
                            } label: {
                                HStack(spacing: Spacing.lg) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.subheadline)
                                        .foregroundStyle(theme.colors.textMuted)
                                        .frame(width: 24)

                                    Text(search)
                                        .font(AppTypography.bodyRegular)
                                        .foregroundStyle(theme.colors.textPrimary)

                                    Spacer()

                                    Image(systemName: "arrow.up.left")
                                        .font(.caption)
                                        .foregroundStyle(theme.colors.textTertiary)
                                }
                                .padding(.vertical, Spacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressButtonStyle(scale: 0.98))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // Suggested topics
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Label("Explore Topics", systemImage: "sparkles")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.colors.textPrimary)

                    FlowLayout(spacing: Spacing.md) {
                        ForEach(Array(suggestedTopics.enumerated()), id: \.element) { index, topic in
                            Button {
                                searchText = topic
                                performSearch()
                            } label: {
                                Text(topic)
                                    .font(.subheadline)
                                    .padding(.horizontal, Spacing.xl)
                                    .padding(.vertical, Spacing.md)
                                    .background(theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.7))
                                    .foregroundStyle(theme.colors.textPrimary)
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(theme.colors.surface, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(PressButtonStyle())
                        }
                    }
                }

                // Search tips
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Label("Search Tips", systemImage: "lightbulb")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.colors.textPrimary)

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        tipRow(text: "Search by title, author, or topic")
                        tipRow(text: "Use quotes for exact phrases")
                        tipRow(text: "Try ArXiv IDs like \"2401.12345\"")
                    }
                }
                .padding(.top, Spacing.md)
            }
            .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
            .padding(.top, Spacing.xl)
        }
        .transition(.opacity)
    }

    private func tipRow(text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(theme.colors.textTertiary)
                .frame(width: 4, height: 4)

            Text(text)
                .font(.caption)
                .foregroundStyle(theme.colors.textMuted)
        }
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Spacing.md) {
                // Results count
                HStack {
                    Text("\(searchResults.count) results")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.colors.textMuted)

                    Text("for")
                        .font(.caption)
                        .foregroundStyle(theme.colors.textTertiary)

                    Text("\"\(searchText)\"")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.colors.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                .padding(.top, Spacing.md)

                ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, paper in
                    SearchResultCard(paper: paper) {
                        selectedPaper = paper
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 12)),
                        removal: .opacity
                    ))
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * 0.04),
                        value: searchResults.count
                    )
                }

                // View in feed
                if !searchResults.isEmpty {
                    Button {
                        viewModel.searchQuery = searchText
                        viewModel.isSearching = true
                        dismiss()
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.subheadline)
                            Text("View all in feed")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(theme.colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                        .background(theme.colors.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                                .strokeBorder(theme.colors.accent.opacity(0.2), lineWidth: 1)
                        }
                    }
                    .buttonStyle(PressButtonStyle())
                    .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
        }
        .sheet(item: $selectedPaper) { paper in
            PaperDetailSheet(paper: paper, browserURL: $browserURL)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.xxl) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.colors.accent)

            Text("Searching ArXiv...")
                .font(AppTypography.bodyRegular)
                .foregroundStyle(theme.colors.textMuted)
        }
        .frame(maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(theme.colors.textMuted)

            VStack(spacing: Spacing.md) {
                Text("No papers found")
                    .font(AppTypography.sectionTitle)
                    .tracking(AppTypography.Tracking.sectionTitle)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("Try different keywords or check your spelling")
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 40)
        .transition(.opacity)
    }

    // MARK: - Search Error View

    private func searchErrorView(_ error: Error) -> some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(theme.colors.textMuted)

            VStack(spacing: Spacing.md) {
                Text("Search failed")
                    .font(AppTypography.sectionTitle)
                    .tracking(AppTypography.Tracking.sectionTitle)
                    .foregroundStyle(theme.colors.textPrimary)

                Text(error.localizedDescription)
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                self.error = nil
                performSearch()
            } label: {
                Text("Retry")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.background)
                    .padding(.horizontal, 32)
                    .padding(.vertical, LayoutConstants.Card.padding)
                    .background(theme.colors.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressButtonStyle())
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 40)
        .transition(.opacity)
    }

    // MARK: - Actions

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        showSuggestions = false
        isSearching = true
        error = nil
        saveRecentSearch(query)

        Task {
            do {
                let results = try await viewModel.paperRepository.searchPapers(
                    query: query,
                    page: 0
                )
                withAnimation(AppAnimation.Interactive.spring) {
                    searchResults = results
                }
            } catch {
                self.error = error
            }
            withAnimation { isSearching = false }
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
        searches.removeAll { $0.lowercased() == search.lowercased() }
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
                // Categories + date
                HStack(spacing: Spacing.sm) {
                    ForEach(paper.categories.prefix(2), id: \.self) { cat in
                        Text(cat)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 3)
                            .background(
                                CategoryColors.palette(for: cat).primary.opacity(0.15)
                            )
                            .foregroundStyle(
                                CategoryColors.palette(for: cat).primary
                            )
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if paper.isRecent {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 8))
                            Text("NEW")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: "E4A853"))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color(hex: "E4A853").opacity(0.15))
                        .clipShape(Capsule())
                    }

                    Text(paper.formattedDate)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.textMuted)
                }

                // Title
                Text(paper.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                // Authors
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.2")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.textTertiary)

                    Text(paper.authors.shortDisplayString)
                        .font(.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                        .lineLimit(1)
                }

                // Abstract preview
                Text(paper.abstract)
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            .padding(LayoutConstants.Card.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surface.opacity(theme.isDark ? 0.2 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                    .strokeBorder(theme.colors.surface.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(PressButtonStyle(scale: 0.98))
        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
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
            ScrollView(showsIndicators: false) {
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
                                    .background(
                                        CategoryColors.palette(for: cat).primary.opacity(0.12)
                                    )
                                    .foregroundStyle(
                                        CategoryColors.palette(for: cat).primary
                                    )
                                    .clipShape(Capsule())
                            }
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
                        Label(paper.formattedDate, systemImage: "calendar")
                        Spacer()
                        Text(paper.arXivId)
                    }
                    .font(.caption)
                    .foregroundStyle(theme.colors.textTertiary)

                    Divider()
                        .background(theme.colors.surface)

                    // Quick summary section
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(theme.colors.accent)
                            Text("AI Summary")
                                .font(.headline)
                                .foregroundStyle(theme.colors.textPrimary)
                        }

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
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, Spacing.lg)
                                        .padding(.vertical, Spacing.md)
                                        .background(selectedStyle == style ? style.accentColor.opacity(0.25) : theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.6))
                                        .foregroundStyle(selectedStyle == style ? style.accentColor : theme.colors.textPrimary)
                                        .clipShape(Capsule())
                                        .overlay {
                                            Capsule()
                                                .strokeBorder(selectedStyle == style ? style.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                        }
                                    }
                                    .buttonStyle(PressButtonStyle())
                                    .sensoryFeedback(.selection, trigger: selectedStyle)
                                }
                            }
                        }

                        // Summary content
                        if isGenerating {
                            HStack(spacing: Spacing.md) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(selectedStyle.accentColor)
                                Text("Generating with on-device AI...")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.colors.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Spacing.xxl)
                        } else if let content = summaryContent {
                            Text(content)
                                .font(AppTypography.bodyRegular)
                                .foregroundStyle(theme.colors.textPrimary)
                                .lineSpacing(4)
                                .transition(.opacity)
                        } else {
                            Button {
                                loadSummary()
                            } label: {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "sparkles")
                                    Text("Generate Summary")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.xl)
                                .background(theme.colors.accent.opacity(0.1))
                                .foregroundStyle(theme.colors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.lg))
                                .overlay {
                                    RoundedRectangle(cornerRadius: Spacing.lg)
                                        .strokeBorder(theme.colors.accent.opacity(0.2), lineWidth: 1)
                                }
                            }
                            .buttonStyle(PressButtonStyle())
                        }
                    }
                    .padding(Spacing.xl)
                    .background(theme.colors.surface.opacity(theme.isDark ? 0.15 : 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                            .strokeBorder(selectedStyle.accentColor.opacity(0.15), lineWidth: 1)
                    }

                    Divider()
                        .background(theme.colors.surface)

                    // Abstract
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Abstract")
                            .font(.headline)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text(paper.abstract)
                            .font(AppTypography.bodyRegular)
                            .foregroundStyle(theme.colors.textPrimary.opacity(0.9))
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
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.xl)
                                .background(theme.colors.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
                        }
                        .buttonStyle(PressButtonStyle())

                        Button {
                            if let url = paper.abstractURLObject {
                                browserURL = url
                            }
                        } label: {
                            Label("ArXiv", systemImage: "globe")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.xl)
                                .background(theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.7))
                                .foregroundStyle(theme.colors.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius))
                                .overlay {
                                    RoundedRectangle(cornerRadius: LayoutConstants.Card.borderRadius)
                                        .strokeBorder(theme.colors.surface, lineWidth: 1)
                                }
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }
                .padding(LayoutConstants.Screen.paddingHorizontal)
            }
            .background(theme.colors.background)
            .navigationTitle("Paper Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.accent)
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
            withAnimation { summaryContent = cached }
            return
        }

        // Generate new summary
        isGenerating = true
        summaryContent = nil

        Task {
            do {
                let summary = try await viewModel.paperRepository.summarize(paper: paper, style: selectedStyle)
                withAnimation { summaryContent = summary.content }
            } catch {
                summaryContent = "Failed to generate summary. Please try again."
            }
            withAnimation { isGenerating = false }
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
