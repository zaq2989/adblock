//
//  Constants.swift
//  CleanViewVPN
//
//  Shared constants across all targets
//

import Foundation

// MARK: - Bundle Identifiers
struct BundleIdentifiers {
    static let hostApp = "com.example.cleanview"
    static let vpnExtension = "com.example.cleanview.vpn"
    static let contentBlocker = "com.example.cleanview.blocker"
}

// MARK: - App Groups
struct AppGroups {
    static let identifier = "group.com.example.cleanview.shared"
}

// MARK: - VPN Configuration
struct VPNConfig {
    static let tunnelBundleIdentifier = BundleIdentifiers.vpnExtension
    static let localizedDescription = "CleanView VPN"
    static let serverAddress = "127.0.0.1"
    static let localDNS = "127.0.0.1"

    // DNS Providers
    enum DNSProvider: String, CaseIterable {
        case system = "System Default"
        case cloudflare = "Cloudflare (1.1.1.1)"
        case custom = "Custom DNS"

        var addresses: [String] {
            switch self {
            case .system:
                return [] // Use system default
            case .cloudflare:
                return ["1.1.1.1", "1.0.0.1"]
            case .custom:
                return [] // User-defined
            }
        }
    }

    // Mock regions for MVP
    enum Region: String, CaseIterable {
        case automatic = "Automatic"
        case unitedStates = "United States"
        case europe = "Europe"

        var flag: String {
            switch self {
            case .automatic: return "🌍"
            case .unitedStates: return "🇺🇸"
            case .europe: return "🇪🇺"
            }
        }
    }
}

// MARK: - Subscription
struct Subscription {
    static let sharedSecret = "your-shared-secret-here" // Replace in production

    enum ProductID: String, CaseIterable {
        case free = "com.example.cleanview.free"
        case proMonthly = "com.example.cleanview.pro.monthly"
        case proYearly = "com.example.cleanview.pro.yearly"

        var displayName: String {
            switch self {
            case .free: return "Free"
            case .proMonthly: return "Pro Monthly"
            case .proYearly: return "Pro Yearly"
            }
        }
    }

    enum Tier: String {
        case free = "Free"
        case pro = "Pro"

        var features: [String] {
            switch self {
            case .free:
                return [
                    "Basic ad blocking",
                    "Standard DNS filtering",
                    "Manual rule updates"
                ]
            case .pro:
                return [
                    "Advanced ad & tracker blocking",
                    "Multiple DNS providers",
                    "Daily automatic rule updates",
                    "Multiple regions",
                    "Priority support"
                ]
            }
        }
    }
}

// MARK: - Rules & Filters
struct Rules {
    static let updateURL = URL(string: "https://rules.example.com/ios/default.json")!
    static let localFileName = "rules.json"
    static let blockedDomainsFileName = "blocked_domains.dat"

    // Sample blocked domains for MVP
    static let defaultBlockedDomains = [
        "doubleclick.net",
        "googleadservices.com",
        "googlesyndication.com",
        "google-analytics.com",
        "amazon-adsystem.com",
        "facebook.com/tr",
        "scorecardresearch.com",
        "outbrain.com",
        "taboola.com",
        "ads.twitter.com"
    ]
}

// MARK: - Storage Keys
struct StorageKeys {
    static let vpnEnabled = "vpn_enabled"
    static let selectedRegion = "selected_region"
    static let dnsProvider = "dns_provider"
    static let customDNSServers = "custom_dns_servers"
    static let whitelist = "whitelist"
    static let lastRuleUpdate = "last_rule_update"
    static let subscriptionTier = "subscription_tier"
    static let autoUpdateEnabled = "auto_update_enabled"
}

// MARK: - Notifications
struct NotificationNames {
    static let vpnStatusChanged = "com.example.cleanview.vpnStatusChanged"
    static let rulesUpdated = "com.example.cleanview.rulesUpdated"
    static let subscriptionChanged = "com.example.cleanview.subscriptionChanged"
}

// MARK: - Error Messages
struct ErrorMessages {
    static let vpnConnectionFailed = "Failed to connect to VPN"
    static let rulesUpdateFailed = "Failed to update blocking rules"
    static let subscriptionRestoreFailed = "Failed to restore purchases"
    static let contentBlockerReloadFailed = "Failed to reload content blocker"
}