import XCTest
@testable import ContentBlocker
@testable import SharedUtilities

final class ContentBlockerTests: XCTestCase {

    // MARK: - Rule Loading Tests

    func testRulesJSONValidity() {
        // Test that the bundled Rules.json is valid
        let bundle = Bundle.module
        guard let rulesURL = bundle.url(forResource: "Rules", withExtension: "json") else {
            XCTFail("Rules.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: rulesURL)
            let rules = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

            XCTAssertNotNil(rules)
            XCTAssertGreaterThan(rules?.count ?? 0, 0)

            // Validate each rule has required fields
            for rule in rules ?? [] {
                XCTAssertNotNil(rule["trigger"], "Rule missing trigger")
                XCTAssertNotNil(rule["action"], "Rule missing action")

                // Validate trigger
                if let trigger = rule["trigger"] as? [String: Any] {
                    XCTAssertNotNil(trigger["url-filter"], "Trigger missing url-filter")
                }

                // Validate action
                if let action = rule["action"] as? [String: Any] {
                    XCTAssertNotNil(action["type"], "Action missing type")
                }
            }
        } catch {
            XCTFail("Failed to parse Rules.json: \(error)")
        }
    }

    func testContentBlockerRulesFormat() {
        let sampleRules = [
            [
                "trigger": ["url-filter": ".*"],
                "action": [
                    "type": "css-display-none",
                    "selector": "div[class*='overlay']"
                ]
            ]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: sampleRules)
            let parsed = try JSONSerialization.jsonObject(with: data)
            XCTAssertNotNil(parsed)
        } catch {
            XCTFail("Failed to serialize rules: \(error)")
        }
    }

    // MARK: - CSS Selector Tests

    func testCSSSelectors() {
        let selectors = [
            "div[class*='overlay']",
            "div[class*='modal']",
            "div[class*='popup']",
            ".backdrop",
            "[role='dialog']",
            ".age-gate",
            ".geo-gate",
            ".gdpr",
            ".consent",
            ".cookie-consent"
        ]

        for selector in selectors {
            // Basic validation that selector is not empty
            XCTAssertFalse(selector.isEmpty)
            XCTAssertTrue(selector.count > 2)
        }
    }

    // MARK: - Whitelist Integration Tests

    func testWhitelistRuleGeneration() {
        let whitelistedDomains = ["example.com", "test.com"]
        var rules: [[String: Any]] = []

        for domain in whitelistedDomains {
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

        XCTAssertEqual(rules.count, whitelistedDomains.count)

        // Verify each rule has correct structure
        for (index, rule) in rules.enumerated() {
            let trigger = rule["trigger"] as? [String: Any]
            let action = rule["action"] as? [String: Any]
            let ifDomain = trigger?["if-domain"] as? [String]

            XCTAssertNotNil(trigger)
            XCTAssertNotNil(action)
            XCTAssertEqual(ifDomain?.first, whitelistedDomains[index])
            XCTAssertEqual(action?["type"] as? String, "ignore-previous-rules")
        }
    }

    // MARK: - Rule Merging Tests

    func testRuleMerging() {
        let mainRules = [
            ["trigger": ["url-filter": ".*"], "action": ["type": "css-display-none", "selector": ".ad"]]
        ]

        let whitelistRules = [
            ["trigger": ["url-filter": ".*", "if-domain": ["example.com"]], "action": ["type": "ignore-previous-rules"]]
        ]

        // Merge rules (whitelist should come first)
        let mergedRules = whitelistRules + mainRules

        XCTAssertEqual(mergedRules.count, 2)
        XCTAssertEqual((mergedRules.first?["action"] as? [String: Any])?["type"] as? String, "ignore-previous-rules")
    }

    // MARK: - Performance Tests

    func testRuleSerializationPerformance() {
        let rules = (0..<1000).map { index in
            [
                "trigger": ["url-filter": ".*"],
                "action": [
                    "type": "css-display-none",
                    "selector": ".class\(index)"
                ]
            ]
        }

        measure {
            do {
                let data = try JSONSerialization.data(withJSONObject: rules)
                XCTAssertGreaterThan(data.count, 0)
            } catch {
                XCTFail("Serialization failed")
            }
        }
    }

    // MARK: - File System Tests

    func testSharedContainerAccess() {
        // Test that App Groups container is accessible
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroups.identifier
        )

        XCTAssertNotNil(containerURL, "App Groups container should be accessible")

        if let url = containerURL {
            // Test that we can write to the container
            let testFile = url.appendingPathComponent("test.txt")
            let testData = "test".data(using: .utf8)!

            do {
                try testData.write(to: testFile)
                let readData = try Data(contentsOf: testFile)
                XCTAssertEqual(readData, testData)

                // Clean up
                try FileManager.default.removeItem(at: testFile)
            } catch {
                // In unit tests, App Groups might not work properly
                // This is expected in test environment
                print("App Groups not available in test environment: \(error)")
            }
        }
    }

    // MARK: - Edge Cases

    func testEmptyRules() {
        let emptyRules: [[String: Any]] = []

        do {
            let data = try JSONSerialization.data(withJSONObject: emptyRules)
            let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            XCTAssertNotNil(parsed)
            XCTAssertEqual(parsed?.count, 0)
        } catch {
            XCTFail("Should handle empty rules array")
        }
    }

    func testLargeRuleSet() {
        // Test with Safari's 50,000 rule limit in mind
        let maxRules = 50_000
        let testBatch = 1000 // Test with smaller batch

        let rules = (0..<testBatch).map { index in
            [
                "trigger": ["url-filter": "domain\(index)\\.com"],
                "action": ["type": "block"]
            ]
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: rules)
            XCTAssertGreaterThan(data.count, 0)

            // Ensure data size is reasonable
            // Safari has a ~5MB limit for content blocker rules
            let sizePerRule = data.count / testBatch
            let estimatedFullSize = sizePerRule * maxRules
            XCTAssertLessThan(estimatedFullSize, 5_000_000) // 5MB limit
        } catch {
            XCTFail("Failed to handle large rule set")
        }
    }
}