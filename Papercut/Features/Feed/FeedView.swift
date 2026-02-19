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
    @State private var showingSearch = false
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var browserURL: URL?
    @State private var selectedTab: FeedTab = .latest

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Latest", systemImage: "clock.fill", value: .latest) {
                feedContent
            }

            Tab("Trending", systemImage: "flame.fill", value: .trending) {
                feedContent
            }

            Tab("Saved", systemImage: "bookmark.fill", value: .saved) {
                feedContent
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .browserSheet(url: $browserURL)
        .onChange(of: selectedTab) { _, newTab in
            guard viewModel.currentTab != newTab else { return }
            Task {
                await viewModel.switchTab(to: newTab)
            }
        }
        .onChange(of: viewModel.currentTab) { _, newTab in
            if newTab != selectedTab {
                selectedTab = newTab
            }
        }
        .onChange(of: preferencesStore.followedCategories) {
            Task {
                await viewModel.refresh()
            }
        }
        .task {
            if viewModel.papers.isEmpty {
                await viewModel.loadPapers()
            }
        }
    }

    // MARK: - Feed Content (shared across tabs)

    private var feedContent: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            if !viewModel.hasCategories && viewModel.currentTab != .saved {
                noCategoriesView
            } else if viewModel.currentTab == .saved && viewModel.displayPapers.isEmpty && !viewModel.isLoading {
                savedEmptyView
            } else if viewModel.isLoading && viewModel.papers.isEmpty {
                loadingView
            } else if let error = viewModel.error, viewModel.papers.isEmpty {
                errorView(error)
            } else if viewModel.displayPapers.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                verticalFeed
            }

            // Top fade — smooths card edges behind status bar
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

                    if viewModel.isRefreshingInBackground {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(theme.colors.textMuted)
                    }

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
        .animation(.easeInOut(duration: 0.3), value: viewModel.toastError != nil)
    }

    // MARK: - Vertical Feed

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
            },
            onToggleBookmark: {
                viewModel.toggleBookmark(for: paper)
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
            .buttonStyle(PressButtonStyle())

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
            .buttonStyle(PressButtonStyle())

            Spacer()
        }
    }

    private var savedEmptyView: some View {
        SavedEmptyStateView(theme: theme)
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
            .buttonStyle(PressButtonStyle())

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
