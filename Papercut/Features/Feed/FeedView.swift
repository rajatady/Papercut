//
//  FeedView.swift
//  Papercut
//

import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(FeedViewModel.self) private var viewModel
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(ThemeManager.self) private var theme
    @State private var showingSettings = false
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var browserURL: URL?
    @State private var selectedTabIndex: Int = 0

    private let allTabs = FeedTab.allCases

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            theme.colors.background.ignoresSafeArea()

            if !viewModel.hasCategories {
                noCategoriesView
            } else if viewModel.isLoading && viewModel.papers.isEmpty {
                loadingView
            } else if let error = viewModel.error, viewModel.papers.isEmpty {
                errorView(error)
            } else if viewModel.displayPapers.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                // Horizontally swipeable tab content (full screen, behind header)
                horizontalTabPager
            }

            // Floating glass header (content scrolls behind this)
            FeedGlassHeader(
                tabs: allTabs,
                selectedIndex: $selectedTabIndex,
                isRefreshing: viewModel.isRefreshingInBackground,
                onSettings: { showingSettings = true }
            )

            // Toast overlay
            if let toast = viewModel.toastError {
                VStack {
                    Spacer()
                    FeedToast(message: toast) {
                        viewModel.dismissToast()
                    }
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .browserSheet(url: $browserURL)
        .animation(.easeInOut(duration: 0.3), value: viewModel.toastError != nil)
        .onChange(of: selectedTabIndex) { _, newIndex in
            let tab = allTabs[newIndex]
            guard viewModel.currentTab != tab else { return }
            Task {
                await viewModel.switchTab(to: tab)
            }
        }
        .onChange(of: viewModel.currentTab) { _, newTab in
            // Sync programmatic tab changes back to the pager
            if let index = allTabs.firstIndex(of: newTab), index != selectedTabIndex {
                selectedTabIndex = index
            }
        }
        .task {
            if viewModel.papers.isEmpty {
                await viewModel.loadPapers()
            }
        }
    }

    // MARK: - Horizontal Tab Pager

    private var horizontalTabPager: some View {
        TabView(selection: $selectedTabIndex) {
            ForEach(Array(allTabs.enumerated()), id: \.offset) { index, _ in
                verticalFeed
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Vertical Feed (per tab)

    private var verticalFeed: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.displayPapers.enumerated()), id: \.element.id) { index, paper in
                    paperCardContainer(paper: paper, index: index)
                        .containerRelativeFrame(.vertical)
                }

                // Loading more indicator
                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(theme.colors.textPrimary)
                        .frame(height: 100)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
    }

    // MARK: - Paper Card Container

    @ViewBuilder
    private func paperCardContainer(paper: Paper, index: Int) -> some View {
        let selectedStyle = viewModel.selectedStyle(for: paper)
        let isGenerating = viewModel.isSummarizing(paper)
        let streamingContent = viewModel.currentStreamingContent(for: paper)

        FullScreenPaperCard(
            paper: paper,
            currentSummary: streamingContent ?? viewModel.getCachedOrStoredSummary(for: paper, style: selectedStyle),
            selectedStyle: selectedStyle,
            isGeneratingSummary: isGenerating,
            onStyleSelected: { style in
                viewModel.setSelectedStyle(style, for: paper)
            },
            onOpenPDF: {
                if let url = paper.pdfURLObject {
                    browserURL = url
                }
            },
            onOpenAbstract: {
                if let url = paper.abstractURLObject {
                    browserURL = url
                }
            },
            onShare: {
                shareItems = viewModel.sharePaper(paper)
                showingShareSheet = true
            }
        )
        .onAppear {
            viewModel.onPaperAppear(paper, at: index)
        }
    }

    // MARK: - Empty States

    private var noCategoriesView: some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(theme.colors.textMuted)

            Text("Select Your Interests")
                .font(AppTypography.sectionTitle)
                .tracking(AppTypography.Tracking.sectionTitle)
                .foregroundStyle(theme.colors.textPrimary)

            Text("Choose research categories to start discovering papers")
                .font(AppTypography.bodyRegular)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingSettings = true
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.background)
                    .padding(.horizontal, 32)
                    .padding(.vertical, LayoutConstants.Card.padding)
                    .background(theme.colors.textPrimary)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.xl) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.colors.accent)

            Text("Loading papers...")
                .foregroundStyle(theme.colors.textMuted)
        }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(Color(hex: "E4A853"))

            Text("Something went wrong")
                .font(AppTypography.sectionTitle)
                .tracking(AppTypography.Tracking.sectionTitle)
                .foregroundStyle(theme.colors.textPrimary)

            Text(error.localizedDescription)
                .font(AppTypography.bodyRegular)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.background)
                    .padding(.horizontal, 32)
                    .padding(.vertical, LayoutConstants.Card.padding)
                    .background(theme.colors.textPrimary)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.xxxl) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(theme.colors.textMuted)

            Text("No Papers Found")
                .font(AppTypography.sectionTitle)
                .tracking(AppTypography.Tracking.sectionTitle)
                .foregroundStyle(theme.colors.textPrimary)

            Text("Pull down to refresh or try different categories")
                .font(AppTypography.bodyRegular)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Text("Refresh")
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.background)
                    .padding(.horizontal, 32)
                    .padding(.vertical, LayoutConstants.Card.padding)
                    .background(theme.colors.textPrimary)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    FeedView()
        .environment(PreferencesStore())
        .environment(AppDependencies.shared.feedViewModel)
        .environment(ThemeManager())
}
