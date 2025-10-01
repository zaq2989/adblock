//
//  WhitelistStore.swift
//  CleanView
//
//  Manages domain whitelist persistence
//

import Foundation
import Combine

/// Manages whitelisted domains that bypass filtering
@MainActor
class WhitelistStore: ObservableObject {
    static let shared = WhitelistStore()

    @Published var domains: Set<String> = []
    @Published var isLoading = false
    @Published var lastError: Error?

    private let fileName = "whitelist.json"
    private var cancellables = Set<AnyCancellable>()

    private init() {
        load()
        setupAutoSave()
    }

    // MARK: - Domain Management

    /// Add domain to whitelist
    func add(_ domain: String) {
        let normalized = normalizeDomain(domain)
        domains.insert(normalized)
        notifyVPN()
    }

    /// Remove domain from whitelist
    func remove(_ domain: String) {
        let normalized = normalizeDomain(domain)
        domains.remove(normalized)
        notifyVPN()
    }

    /// Toggle domain in whitelist
    func toggle(_ domain: String) {
        let normalized = normalizeDomain(domain)
        if domains.contains(normalized) {
            domains.remove(normalized)
        } else {
            domains.insert(normalized)
        }
        notifyVPN()
    }

    /// Check if domain is whitelisted
    func isWhitelisted(_ domain: String) -> Bool {
        let normalized = normalizeDomain(domain)
        return domains.contains(normalized) || isSubdomainWhitelisted(normalized)
    }

    /// Check if subdomain is covered by whitelist
    private func isSubdomainWhitelisted(_ domain: String) -> Bool {
        let parts = domain.split(separator: ".")
        for i in 0..<parts.count {
            let parent = parts[i...].joined(separator: ".")
            if domains.contains(parent) {
                return true
            }
        }
        return false
    }

    /// Clear all whitelisted domains
    func clearAll() {
        domains.removeAll()
        notifyVPN()
    }

    // MARK: - Import/Export

    /// Export whitelist as text
    func exportAsText() -> String {
        domains.sorted().joined(separator: "\n")
    }

    /// Import whitelist from text
    func importFromText(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && isValidDomain(trimmed) {
                domains.insert(normalizeDomain(trimmed))
            }
        }
        notifyVPN()
    }

    /// Share whitelist as file
    func shareAsFile() -> URL? {
        let text = exportAsText()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whitelist.txt")

        do {
            try text.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to create whitelist file: \(error)")
            return nil
        }
    }

    // MARK: - Persistence

    /// Load whitelist from storage
    func load() {
        isLoading = true
        lastError = nil

        defer { isLoading = false }

        do {
            if SharedStorage.fileExists(fileName) {
                let data = try SharedStorage.load(from: fileName)
                let decoded = try JSONDecoder().decode(WhitelistData.self, from: data)
                domains = Set(decoded.domains)
            } else {
                // Initialize with empty whitelist
                domains = []
            }
        } catch {
            print("Failed to load whitelist: \(error)")
            lastError = error
            domains = []
        }
    }

    /// Save whitelist to storage
    func save() {
        do {
            let data = WhitelistData(
                domains: Array(domains).sorted(),
                updatedAt: Date()
            )
            try SharedStorage.saveJSON(data, to: fileName)
        } catch {
            print("Failed to save whitelist: \(error)")
            lastError = error
        }
    }

    /// Setup auto-save on changes
    private func setupAutoSave() {
        $domains
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
                self?.applyToContentBlocker()
            }
            .store(in: &cancellables)
    }

    // MARK: - VPN Integration

    /// Notify VPN of whitelist changes
    private func notifyVPN() {
        // If VPN is connected, reconnect to apply changes
        if VPNManager.shared.isConnected {
            Task {
                await VPNManager.shared.connect()
            }
        }
    }

    /// Apply whitelist to content blocker
    private func applyToContentBlocker() {
        Task {
            await ContentBlockerController.shared.applyWhitelist(Array(domains))
        }
    }

    // MARK: - Validation

    /// Normalize domain (remove protocol, www, trailing slash)
    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.lowercased()

        // Remove protocol
        for prefix in ["https://", "http://", "//"] {
            if normalized.hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count))
            }
        }

        // Remove www
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }

        // Remove path and query
        if let index = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<index])
        }
        if let index = normalized.firstIndex(of: "?") {
            normalized = String(normalized[..<index])
        }

        // Remove port
        if let index = normalized.firstIndex(of: ":") {
            normalized = String(normalized[..<index])
        }

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Validate domain format
    private func isValidDomain(_ domain: String) -> Bool {
        let normalized = normalizeDomain(domain)

        // Basic validation
        if normalized.isEmpty || normalized.contains(" ") {
            return false
        }

        // Check for valid characters
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        if normalized.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return false
        }

        // Must contain at least one dot
        if !normalized.contains(".") {
            return false
        }

        // Check format
        let parts = normalized.split(separator: ".")
        return parts.count >= 2 && parts.allSatisfy { !$0.isEmpty }
    }

    // MARK: - Suggestions

    /// Get domain from current URL
    func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else { return nil }
        return normalizeDomain(host)
    }

    /// Suggest domains based on common issues
    func getSuggestions() -> [WhitelistSuggestion] {
        [
            WhitelistSuggestion(
                domain: "example.com",
                reason: "Example site for testing",
                category: .testing
            ),
            // Add more suggestions based on user patterns
        ]
    }
}

// MARK: - Data Models
struct WhitelistData: Codable {
    let domains: [String]
    let updatedAt: Date
}

struct WhitelistSuggestion {
    let domain: String
    let reason: String
    let category: Category

    enum Category {
        case testing
        case commonService
        case userRequest
    }
}