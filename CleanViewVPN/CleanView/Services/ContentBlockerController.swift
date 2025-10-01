//
//  ContentBlockerController.swift
//  CleanView
//
//  Manages Safari Content Blocker extension
//

import Foundation
import SafariServices
import Combine

@MainActor
class ContentBlockerController: ObservableObject {
    static let shared = ContentBlockerController()

    @Published var isEnabled = false
    @Published var isReloading = false
    @Published var lastError: Error?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        checkContentBlockerStatus()
    }

    // MARK: - Content Blocker Management

    /// Reload the content blocker with updated rules
    func reloadContentBlocker() async {
        isReloading = true
        lastError = nil

        defer { isReloading = false }

        do {
            // Reload the content blocker
            try await SFContentBlockerManager.reloadContentBlocker(
                withIdentifier: BundleIdentifiers.contentBlocker
            )

            print("Content blocker reloaded successfully")

            // Check if enabled
            await checkContentBlockerStatus()

        } catch {
            print("Failed to reload content blocker: \(error)")
            lastError = error
        }
    }

    /// Check if content blocker is enabled
    func checkContentBlockerStatus() {
        Task {
            do {
                let state = try await SFContentBlockerManager.getStateOfContentBlocker(
                    withIdentifier: BundleIdentifiers.contentBlocker
                )

                await MainActor.run {
                    self.isEnabled = state?.isEnabled ?? false
                }
            } catch {
                print("Failed to get content blocker state: \(error)")
                await MainActor.run {
                    self.isEnabled = false
                    self.lastError = error
                }
            }
        }
    }

    // MARK: - Rule Management

    /// Update content blocker rules
    func updateRules(with data: Data) async throws {
        guard let containerURL = SharedStorage.containerURL else {
            throw ContentBlockerError.containerNotFound
        }

        // Save rules to shared container
        let rulesURL = containerURL.appendingPathComponent(Rules.localFileName)
        try data.write(to: rulesURL)

        // Reload content blocker
        await reloadContentBlocker()
    }

    /// Apply whitelist to content blocker
    func applyWhitelist(_ domains: [String]) async {
        // Generate exception rules for whitelisted domains
        var rules: [[String: Any]] = []

        for domain in domains {
            let rule: [String: Any] = [
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": [domain]
                ],
                "action": [
                    "type": "ignore-previous-rules"
                ]
            ]
            rules.append(rule)
        }

        do {
            // Save whitelist rules
            let whitelistData = try JSONSerialization.data(withJSONObject: rules)
            guard let containerURL = SharedStorage.containerURL else { return }

            let whitelistURL = containerURL.appendingPathComponent("whitelist.json")
            try whitelistData.write(to: whitelistURL)

            // Merge with main rules and reload
            await mergeAndReloadRules()
        } catch {
            print("Failed to apply whitelist: \(error)")
        }
    }

    /// Merge main rules with whitelist and reload
    private func mergeAndReloadRules() async {
        guard let containerURL = SharedStorage.containerURL else { return }

        do {
            // Load main rules
            let rulesURL = containerURL.appendingPathComponent(Rules.localFileName)
            let rulesData = try Data(contentsOf: rulesURL)
            var mainRules = try JSONSerialization.jsonObject(with: rulesData) as? [[String: Any]] ?? []

            // Load whitelist rules if they exist
            let whitelistURL = containerURL.appendingPathComponent("whitelist.json")
            if FileManager.default.fileExists(atPath: whitelistURL.path) {
                let whitelistData = try Data(contentsOf: whitelistURL)
                let whitelistRules = try JSONSerialization.jsonObject(with: whitelistData) as? [[String: Any]] ?? []

                // Prepend whitelist rules (they need to come first to work)
                mainRules = whitelistRules + mainRules
            }

            // Save merged rules
            let mergedData = try JSONSerialization.data(withJSONObject: mainRules)
            let mergedURL = containerURL.appendingPathComponent("merged_rules.json")
            try mergedData.write(to: mergedURL)

            // Reload content blocker
            await reloadContentBlocker()
        } catch {
            print("Failed to merge rules: \(error)")
        }
    }

    // MARK: - Safari Integration

    /// Open Safari settings for content blocker
    func openSafariSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Show instructions for enabling content blocker
    func getEnableInstructions() -> String {
        """
        To enable the content blocker:

        1. Open Settings app
        2. Go to Safari > Extensions
        3. Enable "CleanView Blocker"
        4. Allow the extension to work on all websites

        The content blocker will automatically apply when browsing with Safari or Brave.
        """
    }

    // MARK: - Statistics

    /// Get blocking statistics (placeholder for MVP)
    func getStatistics() -> ContentBlockerStats {
        // In production, this would track actual blocked elements
        return ContentBlockerStats(
            blockedTrackers: UserDefaults.standard.integer(forKey: "blocked_trackers"),
            blockedAds: UserDefaults.standard.integer(forKey: "blocked_ads"),
            blockedPopups: UserDefaults.standard.integer(forKey: "blocked_popups")
        )
    }

    /// Reset statistics
    func resetStatistics() {
        UserDefaults.standard.set(0, forKey: "blocked_trackers")
        UserDefaults.standard.set(0, forKey: "blocked_ads")
        UserDefaults.standard.set(0, forKey: "blocked_popups")
    }
}

// MARK: - Data Models
struct ContentBlockerStats {
    let blockedTrackers: Int
    let blockedAds: Int
    let blockedPopups: Int

    var total: Int {
        blockedTrackers + blockedAds + blockedPopups
    }
}

// MARK: - Errors
enum ContentBlockerError: Error, LocalizedError {
    case containerNotFound
    case reloadFailed
    case rulesInvalid

    var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "Shared container not found"
        case .reloadFailed:
            return "Failed to reload content blocker"
        case .rulesInvalid:
            return "Invalid content blocking rules"
        }
    }
}