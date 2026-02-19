//
//  AppDependencies.swift
//  Papercut
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()

    // MARK: - Services
    let preferencesStore: PreferencesStore
    let arXivService: ArXivServiceProtocol
    let summarizationService: any SummarizationServiceProtocol

    // MARK: - SwiftData
    let modelContainer: ModelContainer

    // MARK: - Repository (requires modelContext, so created lazily)
    private var _paperRepository: PaperRepository?

    var paperRepository: PaperRepository {
        if let existing = _paperRepository {
            return existing
        }
        let repo = PaperRepository(
            arXivService: arXivService,
            summarizationService: summarizationService,
            modelContext: modelContainer.mainContext
        )
        _paperRepository = repo
        return repo
    }

    // MARK: - ViewModels
    private var _feedViewModel: FeedViewModel?

    var feedViewModel: FeedViewModel {
        if let existing = _feedViewModel {
            return existing
        }
        let vm = FeedViewModel(
            repository: paperRepository,
            preferencesStore: preferencesStore
        )
        _feedViewModel = vm
        return vm
    }

    private init() {
        // Initialize preferences store
        self.preferencesStore = PreferencesStore()

        // Initialize services
        self.arXivService = ArXivService()
        self.summarizationService = SummarizationServiceFactory.create()

        // Initialize SwiftData container
        let schema = Schema([
            Paper.self,
            Summary.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

// MARK: - Environment Keys
private struct PreferencesStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = AppDependencies.shared.preferencesStore
}

private struct FeedViewModelKey: EnvironmentKey {
    @MainActor static let defaultValue = AppDependencies.shared.feedViewModel
}

extension EnvironmentValues {
    var preferencesStore: PreferencesStore {
        get { self[PreferencesStoreKey.self] }
        set { self[PreferencesStoreKey.self] = newValue }
    }

    var feedViewModel: FeedViewModel {
        get { self[FeedViewModelKey.self] }
        set { self[FeedViewModelKey.self] = newValue }
    }
}
