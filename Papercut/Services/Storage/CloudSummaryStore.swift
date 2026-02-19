//
//  CloudSummaryStore.swift
//  Papercut
//

import Foundation

/// Stores paper summaries locally with UserDefaults
/// Can be extended to support iCloud sync when entitlements are configured
@MainActor
final class CloudSummaryStore {
    static let shared = CloudSummaryStore()

    private let summaryKeyPrefix = "summary_"
    private let localCache = NSCache<NSString, NSString>()
    private let userDefaults = UserDefaults.standard

    private init() {}

    // MARK: - Public Methods

    /// Save a summary
    func saveSummary(paperId: String, style: SummaryStyle, content: String) {
        let key = makeKey(paperId: paperId, style: style)

        // Save to UserDefaults
        userDefaults.set(content, forKey: key)

        // Cache in memory
        localCache.setObject(content as NSString, forKey: key as NSString)
    }

    /// Get a summary
    func getSummary(paperId: String, style: SummaryStyle) -> String? {
        let key = makeKey(paperId: paperId, style: style)

        // Check memory cache first
        if let cached = localCache.object(forKey: key as NSString) {
            return cached as String
        }

        // Check UserDefaults
        if let localValue = userDefaults.string(forKey: key) {
            localCache.setObject(localValue as NSString, forKey: key as NSString)
            return localValue
        }

        return nil
    }

    /// Check if a summary exists
    func hasSummary(paperId: String, style: SummaryStyle) -> Bool {
        getSummary(paperId: paperId, style: style) != nil
    }

    /// Get all summaries for a paper
    func getAllSummaries(paperId: String) -> [SummaryStyle: String] {
        var summaries: [SummaryStyle: String] = [:]

        for style in SummaryStyle.allCases {
            if let content = getSummary(paperId: paperId, style: style) {
                summaries[style] = content
            }
        }

        return summaries
    }

    /// Delete a summary
    func deleteSummary(paperId: String, style: SummaryStyle) {
        let key = makeKey(paperId: paperId, style: style)
        userDefaults.removeObject(forKey: key)
        localCache.removeObject(forKey: key as NSString)
    }

    /// Delete all summaries for a paper
    func deleteAllSummaries(paperId: String) {
        for style in SummaryStyle.allCases {
            deleteSummary(paperId: paperId, style: style)
        }
    }

    /// Clear all cached summaries
    func clearAll() {
        localCache.removeAllObjects()

        // Remove all summary keys from UserDefaults
        let allKeys = userDefaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(summaryKeyPrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private Methods

    private func makeKey(paperId: String, style: SummaryStyle) -> String {
        // Normalize paper ID (remove URL parts if present)
        let normalizedId = paperId
            .replacingOccurrences(of: "https://arxiv.org/abs/", with: "")
            .replacingOccurrences(of: "http://arxiv.org/abs/", with: "")
            .replacingOccurrences(of: "/", with: "_")

        return "\(summaryKeyPrefix)\(normalizedId)_\(style.rawValue)"
    }
}
