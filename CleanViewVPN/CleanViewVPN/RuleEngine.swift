//
//  RuleEngine.swift
//  CleanViewVPN
//
//  Domain blocking rules engine
//

import Foundation
import OSLog

/// Manages and applies blocking rules for domains
class RuleEngine {
    private let logger = Logger(subsystem: BundleIdentifiers.vpnExtension, category: "RuleEngine")
    private var blockedDomains = Set<String>()
    private var whitelist = Set<String>()
    private let queue = DispatchQueue(label: "com.example.cleanview.rules", attributes: .concurrent)

    // MARK: - Rule Loading

    /// Load blocking rules from shared container
    func loadRules() async {
        logger.info("Loading blocking rules")

        // Load blocked domains
        loadBlockedDomains()

        // Load whitelist
        loadWhitelist()

        logger.info("Loaded \(blockedDomains.count) blocked domains and \(whitelist.count) whitelisted domains")
    }

    private func loadBlockedDomains() {
        queue.async(flags: .barrier) {
            // Try to load from shared container
            if let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroups.identifier
            ) {
                let domainsURL = containerURL.appendingPathComponent(Rules.blockedDomainsFileName)

                if let data = try? Data(contentsOf: domainsURL),
                   let content = String(data: data, encoding: .utf8) {
                    self.blockedDomains = Set(content.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                        .filter { !$0.isEmpty })
                    self.logger.debug("Loaded \(self.blockedDomains.count) domains from file")
                } else {
                    // Use default list if file not found
                    self.blockedDomains = Set(Rules.defaultBlockedDomains.map { $0.lowercased() })
                    self.logger.info("Using default blocked domains list")
                }
            } else {
                // Fallback to default list
                self.blockedDomains = Set(Rules.defaultBlockedDomains.map { $0.lowercased() })
                self.logger.warning("Could not access shared container, using defaults")
            }

            // Add additional hardcoded domains for comprehensive blocking
            self.addCommonAdDomains()
        }
    }

    private func loadWhitelist() {
        queue.async(flags: .barrier) {
            if let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroups.identifier
            ) {
                let whitelistURL = containerURL.appendingPathComponent("whitelist.json")

                if let data = try? Data(contentsOf: whitelistURL) {
                    do {
                        let decoded = try JSONDecoder().decode(WhitelistData.self, from: data)
                        self.whitelist = Set(decoded.domains.map { $0.lowercased() })
                        self.logger.debug("Loaded \(self.whitelist.count) whitelisted domains")
                    } catch {
                        self.logger.error("Failed to decode whitelist: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Rule Application

    /// Check if a domain should be blocked
    func shouldBlock(_ domain: String) async -> Bool {
        let normalizedDomain = domain.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return await withCheckedContinuation { continuation in
            queue.async {
                // Check whitelist first
                if self.isWhitelisted(normalizedDomain) {
                    continuation.resume(returning: false)
                    return
                }

                // Check if domain is in block list
                let blocked = self.isDomainBlocked(normalizedDomain)
                continuation.resume(returning: blocked)
            }
        }
    }

    private func isDomainBlocked(_ domain: String) -> Bool {
        // Direct match
        if blockedDomains.contains(domain) {
            return true
        }

        // Check parent domains (e.g., "ads.example.com" matches "example.com")
        let parts = domain.split(separator: ".")
        for i in 0..<parts.count {
            let parentDomain = parts[i...].joined(separator: ".")
            if blockedDomains.contains(parentDomain) {
                return true
            }
        }

        // Check for wildcard patterns (simplified)
        for blockedDomain in blockedDomains {
            if blockedDomain.hasPrefix("*.") {
                let pattern = String(blockedDomain.dropFirst(2))
                if domain.hasSuffix(pattern) || domain == pattern {
                    return true
                }
            }
        }

        return false
    }

    private func isWhitelisted(_ domain: String) -> Bool {
        // Direct match
        if whitelist.contains(domain) {
            return true
        }

        // Check parent domains
        let parts = domain.split(separator: ".")
        for i in 0..<parts.count {
            let parentDomain = parts[i...].joined(separator: ".")
            if whitelist.contains(parentDomain) {
                return true
            }
        }

        return false
    }

    // MARK: - Dynamic Updates

    /// Update whitelist from host app
    func updateWhitelist(_ domains: [String]) {
        queue.async(flags: .barrier) {
            self.whitelist = Set(domains.map { $0.lowercased() })
            self.logger.info("Updated whitelist with \(domains.count) domains")
        }
    }

    /// Add a domain to blocklist
    func addBlockedDomain(_ domain: String) {
        queue.async(flags: .barrier) {
            self.blockedDomains.insert(domain.lowercased())
        }
    }

    /// Remove a domain from blocklist
    func removeBlockedDomain(_ domain: String) {
        queue.async(flags: .barrier) {
            self.blockedDomains.remove(domain.lowercased())
        }
    }

    // MARK: - Common Ad Domains

    private func addCommonAdDomains() {
        // Comprehensive list of common ad/tracking domains
        let additionalDomains = [
            // Google
            "doubleclick.net", "*.doubleclick.net",
            "googleadservices.com", "*.googleadservices.com",
            "googlesyndication.com", "*.googlesyndication.com",
            "googletagmanager.com", "*.googletagmanager.com",
            "google-analytics.com", "*.google-analytics.com",
            "googletagservices.com", "*.googletagservices.com",

            // Facebook/Meta
            "facebook.com/tr", "pixel.facebook.com",
            "facebook-analytics.com", "*.facebook-analytics.com",
            "connect.facebook.net",

            // Amazon
            "amazon-adsystem.com", "*.amazon-adsystem.com",
            "amazontrust.com", "*.amazontrust.com",

            // Microsoft
            "ads.microsoft.com", "*.ads.microsoft.com",
            "ads1.msads.net", "ads2.msads.net",
            "adsyndication.msn.com",

            // Twitter
            "ads-twitter.com", "*.ads-twitter.com",
            "analytics.twitter.com",

            // Adobe
            "demdex.net", "*.demdex.net",
            "omtrdc.net", "*.omtrdc.net",

            // Content recommendation
            "outbrain.com", "*.outbrain.com",
            "taboola.com", "*.taboola.com",
            "revcontent.com", "*.revcontent.com",
            "content-ad.net", "*.content-ad.net",

            // Analytics
            "scorecardresearch.com", "*.scorecardresearch.com",
            "quantserve.com", "*.quantserve.com",
            "chartbeat.com", "*.chartbeat.com",
            "mixpanel.com", "*.mixpanel.com",
            "segment.io", "*.segment.io",
            "hotjar.com", "*.hotjar.com",
            "mouseflow.com", "*.mouseflow.com",
            "crazyegg.com", "*.crazyegg.com",

            // Ad networks
            "adsrvr.org", "*.adsrvr.org",
            "adnxs.com", "*.adnxs.com",
            "adzerk.net", "*.adzerk.net",
            "pubmatic.com", "*.pubmatic.com",
            "openx.net", "*.openx.net",
            "rubiconproject.com", "*.rubiconproject.com",
            "criteo.com", "*.criteo.com",
            "criteo.net", "*.criteo.net",
            "casalemedia.com", "*.casalemedia.com",
            "contextweb.com", "*.contextweb.com",
            "yieldmo.com", "*.yieldmo.com",

            // Mobile ads
            "mopub.com", "*.mopub.com",
            "applovin.com", "*.applovin.com",
            "applvn.com", "*.applvn.com",
            "inmobi.com", "*.inmobi.com",
            "startapp.com", "*.startapp.com",
            "unity3d.com/ads", "unityads.unity3d.com",
            "vungle.com", "*.vungle.com",

            // Tracking pixels
            "pixel.wp.com", "pixel.jetpack.com",
            "t.co", "analytics.tiktok.com",
            "tr.snapchat.com", "sc-analytics.appspot.com",

            // Other common trackers
            "branch.io", "*.branch.io",
            "adjust.com", "*.adjust.com",
            "kochava.com", "*.kochava.com",
            "appsflyer.com", "*.appsflyer.com",
            "singular.net", "*.singular.net",
            "amplitude.com", "*.amplitude.com",
            "bugsnag.com", "*.bugsnag.com",
            "sentry.io", "*.sentry.io",
            "newrelic.com", "*.newrelic.com"
        ]

        for domain in additionalDomains {
            blockedDomains.insert(domain.lowercased())
        }
    }

    // MARK: - Statistics

    func getBlockedDomainsCount() -> Int {
        queue.sync {
            return blockedDomains.count
        }
    }

    func getWhitelistedDomainsCount() -> Int {
        queue.sync {
            return whitelist.count
        }
    }

    /// Export current rules for debugging
    func exportRules() -> [String: Any] {
        queue.sync {
            return [
                "blockedDomains": Array(blockedDomains).sorted(),
                "whitelistedDomains": Array(whitelist).sorted(),
                "totalBlocked": blockedDomains.count,
                "totalWhitelisted": whitelist.count
            ]
        }
    }
}

// MARK: - Data Models
private struct WhitelistData: Codable {
    let domains: [String]
    let updatedAt: Date
}