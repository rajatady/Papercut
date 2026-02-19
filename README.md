<p align="center">
  <img src="Papercut/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" height="128" alt="Papercut" style="border-radius: 24px;" />
</p>

<h1 align="center">Papercut</h1>

<p align="center">
  <strong>Swipe through research. AI explains the rest.</strong>
</p>

<p align="center">
  A beautiful, privacy-first research paper reader for iOS.<br/>
  Browse, search, and summarize papers from arXiv — entirely on-device.
</p>

<p align="center">
  No login. No tracking. No analytics. No cloud. Just papers.
</p>

---

## What is Papercut?

Papercut turns arXiv into a TikTok-style feed of research papers. One paper per screen. Swipe up to discover. Tap for AI-powered summaries. Everything happens on your device.

**Swipe up** through the latest and trending papers in your fields. **Tap for AI magic** — get TL;DRs, key findings, math explained, code walkthroughs, and more. **Search anything** across arXiv's 2M+ papers. **Save for later** with a single tap.

Your reading habits, interests, and saved papers never leave your phone.

## Features

- **Full-screen paper feed** — Swipe vertically through papers like a social feed. Each card shows title, authors, categories, and an AI summary.
- **On-device AI summaries** — 7 summary styles (TL;DR, Key Findings, Math Explained, Code Explained, Methodology, Implications, ELI5) generated entirely on-device using Apple Foundation Models. No API keys, no cloud processing.
- **Smart summarization queue** — Summaries are pre-generated in priority order: current paper first, then nearby papers, with intelligent priority demotion as you scroll.
- **Latest & Trending tabs** — Latest papers sorted by submission date. Trending papers from the last 30 days sorted by relevance.
- **Persistent bookmarks** — Save papers with a single tap. Bookmarked papers survive cache cleanup and appear in the Saved tab.
- **Powerful search** — Full-text search across arXiv's 2M+ papers. Search by title, author, topic, or ArXiv ID.
- **Category filtering** — Follow specific arXiv categories (cs.AI, math.CO, physics.gen-ph, etc.) to curate your feed.
- **Dark & light mode** — Warm neutral palette with full dark mode support. Liquid Glass UI on iOS 26.
- **Offline-ready** — Papers and summaries are cached locally in SwiftData.

## Privacy

Papercut is built on a simple principle: **your data stays on your device**.

- No user accounts or login
- No analytics or telemetry
- No tracking of any kind
- No data sent to any server (except arXiv API for fetching papers)
- AI summaries generated on-device via Apple Foundation Models
- All preferences, bookmarks, and cached data stored locally

## Requirements

- iOS 26.0+
- Xcode 26+
- iPhone with Apple Silicon (for on-device AI summaries)

## Getting Started

1. Clone the repo:
   ```bash
   git clone https://github.com/rajatady/Papercut.git
   ```
2. Open `Papercut.xcodeproj` in Xcode
3. Select your device or simulator
4. Build and run

No API keys, no configuration, no `.env` files. It just works.

## Architecture

```
Papercut/
├── Models/          # SwiftData models (Paper, Summary, Author, Category)
├── Features/
│   ├── Feed/        # Main feed, full-screen cards, search, view model
│   ├── Onboarding/  # Category selection onboarding
│   └── Settings/    # App settings, category picker, summary styles
├── Components/      # Reusable views (badges, chips, empty states)
├── Services/
│   ├── ArXiv/       # ArXiv API client, XML parser, endpoints
│   ├── Summarization/ # On-device AI summarization with @Generable schemas
│   ├── Repositories/  # Data layer (PaperRepository, PreferencesStore)
│   └── Storage/     # Local summary cache
└── Theme/           # Design system (colors, typography, spacing, animations)
```

**Key design decisions:**
- **SwiftData** for persistence — papers, summaries, and bookmarks
- **`@Observable` view models** with `@MainActor` isolation
- **`@Generable` structured output** — AI summaries use Apple's constrained decoding for guaranteed clean output (no markdown, no emojis, controlled length)
- **Priority-based summarization queue** — critical/high/medium/low priorities with automatic demotion
- **Generation-based load cancellation** — tab switches discard stale API responses

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

- [Report a Bug](https://github.com/rajatady/Papercut/issues/new?labels=bug)
- [Request a Feature](https://github.com/rajatady/Papercut/issues/new?labels=enhancement)

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with SwiftUI, SwiftData, and Apple Foundation Models.
</p>
