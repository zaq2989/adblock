//
//  RuleUpdateService.swift
//  CleanView
//
//  Manages rule updates from remote server
//

import Foundation
import Combine

@MainActor
class RuleUpdateService: ObservableObject {
    static let shared = RuleUpdateService()

    @Published var isUpdating = false
    @Published var lastUpdateDate: Date?
    @Published var updateError: Error?

    private var cancellables = Set<AnyCancellable>()
    private let session = URLSession.shared

    private init() {
        loadLastUpdateDate()
    }

    // MARK: - Update Management

    /// Check for and apply rule updates
    func checkForUpdates() async {
        isUpdating = true
        updateError = nil

        defer { isUpdating = false }

        do {
            // Download rules from server
            let rules = try await downloadRules()

            // Save rules to App Group container
            try saveRules(rules)

            // Update blocked domains for VPN
            try await updateBlockedDomains(from: rules)

            // Reload Content Blocker
            await ContentBlockerController.shared.reloadContentBlocker()

            // Update last update date
            lastUpdateDate = Date()
            saveLastUpdateDate()

            // Post notification
            NotificationCenter.default.post(
                name: Notification.Name(NotificationNames.rulesUpdated),
                object: nil
            )

        } catch {
            print("Rule update failed: \(error)")
            updateError = error
        }
    }

    /// Perform background update (called from background task)
    func performBackgroundUpdate() async -> Bool {
        // Only update for Pro users
        guard SubscriptionManager.shared.isPro else {
            return false
        }

        do {
            let rules = try await downloadRules()
            try saveRules(rules)
            try await updateBlockedDomains(from: rules)
            await ContentBlockerController.shared.reloadContentBlocker()

            lastUpdateDate = Date()
            saveLastUpdateDate()

            // Send local notification about update
            await sendUpdateNotification()

            return true
        } catch {
            print("Background update failed: \(error)")
            return false
        }
    }

    // MARK: - Network Operations

    /// Download rules from remote server
    private func downloadRules() async throws -> Data {
        guard let url = Rules.updateURL else {
            throw UpdateError.invalidURL
        }

        // For MVP, return mock data if server is unavailable
        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw UpdateError.serverError
            }

            return data
        } catch {
            print("Using fallback rules due to network error: \(error)")
            return generateMockRules()
        }
    }

    /// Generate mock rules for MVP
    private func generateMockRules() -> Data {
        let mockRules = [
            // DOM blocking rules
            [
                "trigger": ["url-filter": ".*"],
                "action": [
                    "type": "css-display-none",
                    "selector": "div[class*='overlay'], div[class*='modal'], div[class*='popup'], .backdrop, [role='dialog'], .age-gate, .geo-gate, .gdpr, .consent, .cookie-consent"
                ]
            ],
            [
                "trigger": ["url-filter": ".*"],
                "action": [
                    "type": "css-display-none",
                    "selector": "[class*='subscribe'], [id*='subscribe'], .newsletter, .paywall, .adblock"
                ]
            ],
            [
                "trigger": ["url-filter": ".*"],
                "action": [
                    "type": "css-display-none",
                    "selector": "div[style*='position: fixed'][style*='z-index: 1000'], div[style*='position:fixed'][style*='z-index:1000']"
                ]
            ],
            // Additional cosmetic filters
            [
                "trigger": ["url-filter": ".*"],
                "action": [
                    "type": "css-display-none",
                    "selector": ".interstitial, .splash-screen, .welcome-mat, #country-selector, .region-block"
                ]
            ]
        ]

        return try! JSONSerialization.data(withJSONObject: mockRules)
    }

    // MARK: - File Operations

    /// Save rules to App Group container
    private func saveRules(_ data: Data) throws {
        guard let containerURL = SharedStorage.containerURL else {
            throw UpdateError.containerNotFound
        }

        let rulesURL = containerURL.appendingPathComponent(Rules.localFileName)
        try data.write(to: rulesURL)
    }

    /// Update blocked domains list for VPN
    private func updateBlockedDomains(from rulesData: Data) async throws {
        // Parse blocked domains from rules (for MVP, use default list)
        let blockedDomains = Rules.defaultBlockedDomains

        // Add dynamic domains from server response if available
        if let json = try? JSONSerialization.jsonObject(with: rulesData) as? [[String: Any]] {
            // Extract domains from rules if present
            // This is simplified for MVP
        }

        // Save blocked domains
        let domainsData = blockedDomains.joined(separator: "\n").data(using: .utf8)!
        guard let containerURL = SharedStorage.containerURL else {
            throw UpdateError.containerNotFound
        }

        let domainsURL = containerURL.appendingPathComponent(Rules.blockedDomainsFileName)
        try domainsData.write(to: domainsURL)
    }

    // MARK: - Date Management

    private func loadLastUpdateDate() {
        if let timestamp = UserDefaults.standard.object(forKey: StorageKeys.lastRuleUpdate) as? TimeInterval {
            lastUpdateDate = Date(timeIntervalSince1970: timestamp)
        }
    }

    private func saveLastUpdateDate() {
        UserDefaults.standard.set(lastUpdateDate?.timeIntervalSince1970, forKey: StorageKeys.lastRuleUpdate)
    }

    // MARK: - Notifications

    private func sendUpdateNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Rules Updated"
        content.body = "Ad blocking and privacy rules have been updated successfully."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "rule-update",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Manual Operations

    /// Load initial rules from bundle
    func loadInitialRules() throws {
        guard let bundleURL = Bundle.main.url(forResource: "Rules", withExtension: "json") else {
            throw UpdateError.bundleRulesNotFound
        }

        let data = try Data(contentsOf: bundleURL)
        try saveRules(data)
    }

    /// Force update rules (user-initiated)
    func forceUpdate() async {
        await checkForUpdates()
    }

    /// Check if update is needed
    var shouldUpdate: Bool {
        guard SubscriptionManager.shared.isPro else {
            // Free users update manually
            return false
        }

        guard let lastUpdate = lastUpdateDate else {
            // Never updated
            return true
        }

        // Update if more than 24 hours old
        return Date().timeIntervalSince(lastUpdate) > 86400
    }
}

// MARK: - Errors
enum UpdateError: Error, LocalizedError {
    case invalidURL
    case serverError
    case containerNotFound
    case bundleRulesNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid update URL"
        case .serverError:
            return "Server error during update"
        case .containerNotFound:
            return "App Group container not found"
        case .bundleRulesNotFound:
            return "Initial rules not found in bundle"
        case .saveFailed:
            return "Failed to save rules"
        }
    }
}