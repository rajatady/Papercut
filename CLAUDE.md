# Papercut — Technical Context

## What This Is

Papercut is a SwiftUI iOS app that presents arXiv research papers in a full-screen, vertically-scrollable feed (TikTok-style). It generates AI summaries on-device using Apple Foundation Models. Privacy-first: no accounts, no analytics, no cloud processing.

**Repo:** `github.com/rajatady/Papercut`
**License:** MIT
**Target:** iOS 26+, Xcode 26+, Apple Silicon iPhones

## Project Structure

```
Papercut/
├── PapercutApp.swift              # App entry, injects all @Observable dependencies
├── ContentView.swift              # Root view — shows Onboarding or FeedView
├── Models/
│   ├── Paper.swift                # @Model — SwiftData entity, main data object
│   ├── Summary.swift              # @Model — cached summaries per paper+style
│   ├── Author.swift               # Nested in Paper
│   ├── Category.swift             # ArXiv category codes + display names
│   ├── SummaryStyle.swift         # 7 styles: tldr, keyFindings, mathExplained, codeExplained, methodology, implications, eli5
│   └── UserPreferences.swift      # @Model — persisted user prefs
├── Features/
│   ├── Feed/
│   │   ├── FeedView.swift         # Native TabView (Latest/Trending/Saved), floating glass header buttons
│   │   ├── FeedViewModel.swift    # @Observable @MainActor — data loading, tab switching, summarization orchestration
│   │   ├── FullScreenPaperCard.swift  # Single paper card — title, authors, categories, summary, actions
│   │   ├── SearchView.swift       # Full-text arXiv search with themed results
│   │   ├── PaperCardView.swift    # Compact card variant
│   │   └── SummarySection.swift   # Summary display with style chips
│   ├── Onboarding/
│   │   └── OnboardingView.swift   # 4-page onboarding with category selection
│   └── Settings/
│       ├── SettingsView.swift     # App settings + GitHub feedback links
│       ├── CategoryPickerView.swift
│       └── SummaryStylePicker.swift
├── Components/
│   ├── CategoryBadge.swift        # Category pill with color from CategoryColors
│   ├── SummaryStyleChip.swift     # Style selector chip
│   ├── SavedEmptyStateView.swift  # Empty state for Saved tab
│   ├── LoadingCardView.swift      # Shimmer placeholder
│   └── FeedGlassHeader.swift      # UNUSED — replaced by native TabView, can delete
├── Services/
│   ├── ArXiv/
│   │   ├── ArXivService.swift     # API client
│   │   ├── ArXivEndpoint.swift    # URL builder — latest, trending (30-day window), search
│   │   └── ArXivXMLParser.swift   # Atom feed XML parser
│   ├── Summarization/
│   │   ├── SummarizationService.swift  # @Generable schema orchestration, priority queue
│   │   └── Schemas/               # Per-style @Generable output schemas
│   ├── Repositories/
│   │   ├── PaperRepository.swift  # SwiftData CRUD — returns persisted objects (not raw API copies)
│   │   └── PreferencesStore.swift # @Observable — wraps UserPreferences SwiftData model
│   └── Storage/
│       └── SummaryStorageService.swift  # Local summary cache
└── Theme/
    ├── AppColors.swift            # ColorTokens (light/dark), Color(hex:) extension
    ├── AppTypography.swift        # Serif display fonts, body fonts, tracking values
    ├── AppSpacing.swift           # Spacing enum (xxs..xxxl), LayoutConstants
    ├── AppAnimations.swift        # PressButtonStyle, SoftPressButtonStyle, animation params
    ├── CategoryColors.swift       # Per-category color palettes for gradients
    └── ThemeManager.swift         # @Observable — light/dark toggle, persisted to UserDefaults
```

## Key Patterns

### Dependency Injection
All shared state uses `@Observable` classes injected via SwiftUI `.environment()`:
- `FeedViewModel` — feed data + summarization state
- `PreferencesStore` — user preferences (categories, styles, sort order)
- `ThemeManager` — light/dark mode

### Generation-Based Load Cancellation
`FeedViewModel.loadGeneration` (UInt) increments on every load. Async code checks `guard myGeneration == loadGeneration` before mutating state. `switchTab()` cancels `activeLoadTask` before starting a new one. This prevents stale API responses from overwriting the active tab's data.

### SwiftData Object Identity
`PaperRepository.fetchPapers()` must return the actual SwiftData-managed `Paper` objects, not raw copies from the API response. This preserves `isBookmarked` state. When a paper already exists in the store, we update its fields but return the existing managed object.

### AI Summarization
Uses Apple Foundation Models with `@Generable` structured output schemas. Each of the 7 `SummaryStyle` values has a corresponding schema that constrains the model's output format (no markdown, no emojis, controlled length). Summaries are queued by priority: current paper = critical, adjacent papers = high, nearby = medium.

### Design System
`Theme/` directory contains all design tokens. Views access them via `@Environment(ThemeManager.self)`. Colors are semantic (`textPrimary`, `surface`, `accent`), not hardcoded. Typography uses serif design for display text. Spacing uses a 2px-base scale.

### Native TabView
Uses iOS 26 `TabView` with `Tab("Label", systemImage:, value:)` API for automatic Liquid Glass tab bar. `.tabBarMinimizeBehavior(.onScrollDown)` hides tabs while scrolling. Floating glass search + settings buttons sit in an overlay above the feed.

### Touch Feedback
Two custom `ButtonStyle` implementations: `PressButtonStyle` (scale 0.90) for primary actions, `SoftPressButtonStyle` (scale 0.82) for secondary. All interactive elements are 44pt minimum tap targets. `.sensoryFeedback()` modifiers use changing trigger values (not constants).

## ArXiv API
- **Latest:** sorted by `submittedDate` descending, filtered by followed categories
- **Trending:** last 30 days by `submittedDate` range, sorted by `relevance`
- **Search:** `all:` prefix searches title/abstract/authors/comments/journal. Keyword matching across 2M+ papers. No semantic/fuzzy search.

## Known Issues / Cleanup
- `Components/FeedGlassHeader.swift` is unused — was replaced by native TabView. Safe to delete.
- Xcode project has duplicate build file warnings (cosmetic, doesn't affect compilation)
- PDF saving for bookmarked papers not yet implemented

## Build
Open `Papercut.xcodeproj` in Xcode 26+. No SPM dependencies, no API keys, no configuration files. Build and run.
