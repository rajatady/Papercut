//
//  TopicDetailView.swift
//  Papercut
//

import SwiftUI

struct TopicDetailView: View {
    let topic: Topic
    var namespace: Namespace.ID

    @Environment(FeedViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var browserURL: URL?
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showingEditTopic = false
    @State private var scrolledPaperId: String?

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            if viewModel.tabStates[.topics]?.loadState == .loading && topicPapers.isEmpty {
                populatingView
            } else if topicPapers.isEmpty {
                emptyView
            } else {
                topicFeed
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

            // Floating overlays (topic pill + edit button)
            VStack {
                HStack(spacing: Spacing.md) {
                    // Topic name pill (left)
                    Text(topic.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.colors.textSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .glassEffect(.regular, in: .capsule)

                    Spacer()

                    // Edit button
                    Button { showingEditTopic = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                            .glassEffect(.regular, in: .circle)
                    }
                    .buttonStyle(SoftPressButtonStyle())
                }
                .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
                .padding(.top, Spacing.xs)

                Spacer()

                // Population progress indicator
                if let progress = viewModel.topicPopulationProgress {
                    populationProgressPill(fetched: progress.fetched, total: progress.total)
                        .padding(.bottom, 100)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(SoftPressButtonStyle())
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingEditTopic) {
            AddTopicSheet(
                topic: topic,
                onUpdate: { name, query, sortBy in
                    viewModel.topicRepository.updateTopic(topic, name: name, query: query, sortBy: sortBy)
                    // If query changed, re-populate
                    if topic.paperIds.isEmpty {
                        viewModel.populateActiveTopic()
                    }
                }
            )
        }
        .browserSheet(url: $browserURL)
        .task {
            viewModel.openTopic(topic)
            // Restore scroll position
            if let savedPosition = topic.scrollPosition {
                scrolledPaperId = savedPosition
            }
        }
        .onDisappear {
            viewModel.closeTopic()
        }
    }

    // MARK: - Computed

    private var topicPapers: [Paper] {
        viewModel.tabStates[.topics]?.papers ?? []
    }

    // MARK: - Topic Feed (same as main feed)

    private var topicFeed: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(topicPapers.enumerated()), id: \.element.id) { index, paper in
                    topicPaperCard(paper: paper, index: index)
                        .containerRelativeFrame(.vertical)
                        .id(paper.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: viewModel.lastBoundaryReached != nil) { oldValue, newValue in
            newValue
        }
        .scrollPosition(id: $scrolledPaperId)
        .onChange(of: scrolledPaperId) { _, newId in
            if let newId {
                viewModel.tabStates[.topics]?.scrollPosition = newId
            }
        }
    }

    @ViewBuilder
    private func topicPaperCard(paper: Paper, index: Int) -> some View {
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

    // MARK: - Population Progress

    private func populationProgressPill(fetched: Int, total: Int) -> some View {
        HStack(spacing: Spacing.md) {
            ProgressView()
                .controlSize(.mini)
                .tint(theme.colors.textSecondary)

            Text("Loading research timeline... \(fetched) / \(total)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - States

    private var populatingView: some View {
        VStack(spacing: Spacing.xxl) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.colors.accent)

            VStack(spacing: Spacing.md) {
                Text("Building Timeline")
                    .font(AppTypography.sectionTitle)
                    .tracking(AppTypography.Tracking.sectionTitle)
                    .foregroundStyle(theme.colors.textPrimary)

                if let progress = viewModel.topicPopulationProgress {
                    Text("Fetching \(progress.fetched) of \(progress.total) papers...")
                        .font(AppTypography.bodyRegular)
                        .foregroundStyle(theme.colors.textSecondary)
                } else {
                    Text("Discovering papers for \"\(topic.query)\"...")
                        .font(AppTypography.bodyRegular)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(theme.colors.textMuted)

            Text("No papers found")
                .font(AppTypography.sectionTitle)
                .tracking(AppTypography.Tracking.sectionTitle)
                .foregroundStyle(theme.colors.textPrimary)

            Text("Try editing the topic query")
                .font(AppTypography.bodyRegular)
                .foregroundStyle(theme.colors.textSecondary)

            Button {
                showingEditTopic = true
            } label: {
                Text("Edit Topic")
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
    }
}
