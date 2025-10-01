import XCTest
@testable import VPNExtension
@testable import SharedUtilities

final class VPNExtensionTests: XCTestCase {

    // MARK: - DNS Engine Tests

    func testDNSStatisticsInitialization() {
        let stats = DNSStatistics()
        XCTAssertEqual(stats.totalQueries, 0)
        XCTAssertEqual(stats.queriesBlocked, 0)
        XCTAssertEqual(stats.queriesAllowed, 0)
        XCTAssertEqual(stats.cacheHits, 0)
        XCTAssertEqual(stats.blockRate, 0.0)
    }

    func testDNSStatisticsBlockRate() {
        var stats = DNSStatistics()
        stats.totalQueries = 100
        stats.queriesBlocked = 25
        XCTAssertEqual(stats.blockRate, 25.0)
    }

    // MARK: - Rule Engine Tests

    func testRuleEngineInitialization() async {
        let ruleEngine = RuleEngine()
        await ruleEngine.loadRules()

        // Test that default blocked domains are loaded
        let blockedCount = ruleEngine.getBlockedDomainsCount()
        XCTAssertGreaterThan(blockedCount, 0)
    }

    func testDomainBlocking() async {
        let ruleEngine = RuleEngine()
        await ruleEngine.loadRules()

        // Test known ad domain
        let shouldBlock = await ruleEngine.shouldBlock("doubleclick.net")
        XCTAssertTrue(shouldBlock)

        // Test subdomain blocking
        let shouldBlockSubdomain = await ruleEngine.shouldBlock("ads.doubleclick.net")
        XCTAssertTrue(shouldBlockSubdomain)

        // Test non-ad domain
        let shouldNotBlock = await ruleEngine.shouldBlock("apple.com")
        XCTAssertFalse(shouldNotBlock)
    }

    func testWhitelistFunctionality() async {
        let ruleEngine = RuleEngine()
        await ruleEngine.loadRules()

        // Add domain to whitelist
        ruleEngine.updateWhitelist(["doubleclick.net"])

        // Test that whitelisted domain is not blocked
        let shouldNotBlock = await ruleEngine.shouldBlock("doubleclick.net")
        XCTAssertFalse(shouldNotBlock)
    }

    // MARK: - DNS Cache Tests

    func testDNSCacheStorage() {
        let cache = DNSCache()
        let testData = "test response".data(using: .utf8)!

        cache.set(testData, for: "example.com")

        let retrieved = cache.get(for: "example.com")
        XCTAssertEqual(retrieved, testData)
    }

    func testDNSCacheExpiry() {
        let cache = DNSCache()
        let testData = "test response".data(using: .utf8)!

        // Note: In real tests, we'd need to mock time or use dependency injection
        cache.set(testData, for: "example.com")

        // Immediately retrieved data should exist
        XCTAssertNotNil(cache.get(for: "example.com"))

        // After clearing, should be nil
        cache.clear()
        XCTAssertNil(cache.get(for: "example.com"))
    }

    // MARK: - Performance Tests

    func testRuleMatchingPerformance() async {
        let ruleEngine = RuleEngine()
        await ruleEngine.loadRules()

        measure {
            Task {
                for _ in 0..<100 {
                    _ = await ruleEngine.shouldBlock("test.example.com")
                }
            }
        }
    }

    func testDNSCachePerformance() {
        let cache = DNSCache()
        let testData = "test response".data(using: .utf8)!

        // Pre-populate cache
        for i in 0..<100 {
            cache.set(testData, for: "domain\(i).com")
        }

        measure {
            for i in 0..<1000 {
                _ = cache.get(for: "domain\(i % 100).com")
            }
        }
    }

    // MARK: - Memory Tests

    func testMemoryUsage() async {
        let ruleEngine = RuleEngine()
        await ruleEngine.loadRules()

        // Ensure memory usage is reasonable
        let blockedCount = ruleEngine.getBlockedDomainsCount()

        // Rough estimate: each domain ~50 bytes, should be under 5MB for 100k domains
        let estimatedMemory = blockedCount * 50
        XCTAssertLessThan(estimatedMemory, 5_000_000) // 5MB limit
    }
}