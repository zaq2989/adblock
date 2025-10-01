//
//  ContentBlockerRequestHandler.swift
//  CleanViewBlocker
//
//  Safari Content Blocker extension handler
//

import Foundation
import SafariServices
import OSLog

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {

    private let logger = Logger(subsystem: BundleIdentifiers.contentBlocker, category: "ContentBlocker")

    func beginRequest(with context: NSExtensionContext) {
        logger.info("Content blocker request started")

        // Get the URL for the blocking rules
        let rulesURL = getRulesURL()

        // Create attachment from rules file
        let attachment = NSItemProvider(contentsOf: rulesURL)!

        // Create extension item
        let item = NSExtensionItem()
        item.attachments = [attachment]

        // Complete request with rules
        context.completeRequest(returningItems: [item], completionHandler: nil)

        logger.info("Content blocker rules loaded successfully")
    }

    private func getRulesURL() -> URL {
        // First, try to load merged rules from shared container (includes whitelist)
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroups.identifier
        ) {
            let mergedRulesURL = containerURL.appendingPathComponent("merged_rules.json")
            if FileManager.default.fileExists(atPath: mergedRulesURL.path) {
                logger.debug("Loading merged rules from shared container")
                return mergedRulesURL
            }

            // Fall back to regular rules
            let rulesURL = containerURL.appendingPathComponent(Rules.localFileName)
            if FileManager.default.fileExists(atPath: rulesURL.path) {
                logger.debug("Loading rules from shared container")
                return rulesURL
            }
        }

        // Fall back to bundled rules
        if let bundleURL = Bundle.main.url(forResource: "Rules", withExtension: "json") {
            logger.debug("Loading bundled rules")
            return bundleURL
        }

        // Last resort: create minimal rules
        logger.warning("No rules found, creating minimal ruleset")
        return createMinimalRules()
    }

    private func createMinimalRules() -> URL {
        let minimalRules = [
            [
                "trigger": ["url-filter": ".*"],
                "action": [
                    "type": "css-display-none",
                    "selector": "div[class*='overlay'], div[class*='modal'], div[class*='popup']"
                ]
            ]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: minimalRules, options: .prettyPrinted)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("minimal_rules.json")
            try data.write(to: tempURL)
            return tempURL
        } catch {
            logger.error("Failed to create minimal rules: \(error)")
            // Return empty rules file
            let emptyURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("empty_rules.json")
            try? "[]".write(to: emptyURL, atomically: true, encoding: .utf8)
            return emptyURL
        }
    }
}

// MARK: - Rule Validation Extension
extension ContentBlockerRequestHandler {

    /// Validate rules JSON structure
    private func validateRules(at url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data)

            guard let rules = json as? [[String: Any]] else {
                logger.error("Rules are not in correct format")
                return false
            }

            // Basic validation
            for rule in rules {
                guard rule["trigger"] != nil,
                      rule["action"] != nil else {
                    logger.error("Rule missing trigger or action")
                    return false
                }
            }

            logger.debug("Rules validated successfully: \(rules.count) rules")
            return true

        } catch {
            logger.error("Failed to validate rules: \(error)")
            return false
        }
    }

    /// Merge multiple rule sets
    private func mergeRuleSets(_ urls: [URL]) -> URL? {
        var allRules: [[String: Any]] = []

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                if let rules = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    allRules.append(contentsOf: rules)
                }
            } catch {
                logger.error("Failed to load rules from \(url): \(error)")
            }
        }

        // Remove duplicates (simplified)
        // In production, implement proper deduplication logic

        do {
            let mergedData = try JSONSerialization.data(withJSONObject: allRules, options: .prettyPrinted)
            let mergedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("merged_content_rules.json")
            try mergedData.write(to: mergedURL)
            return mergedURL
        } catch {
            logger.error("Failed to merge rules: \(error)")
            return nil
        }
    }
}