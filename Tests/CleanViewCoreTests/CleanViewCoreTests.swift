import XCTest
@testable import CleanViewCore
@testable import SharedUtilities

final class CleanViewCoreTests: XCTestCase {

    // MARK: - VPN Manager Tests

    func testVPNConfiguration() {
        XCTAssertEqual(VPNConfig.localDNS, "127.0.0.1")
        XCTAssertNotNil(VPNConfig.Region.allCases)
        XCTAssertGreaterThan(VPNConfig.Region.allCases.count, 0)
    }

    func testDNSProviders() {
        XCTAssertEqual(VPNConfig.DNSProvider.cloudflare.addresses, ["1.1.1.1", "1.0.0.1"])
        XCTAssertTrue(VPNConfig.DNSProvider.system.addresses.isEmpty)
    }

    // MARK: - Subscription Tests

    func testSubscriptionTiers() {
        XCTAssertNotEqual(Subscription.Tier.free.features, Subscription.Tier.pro.features)
        XCTAssertGreaterThan(Subscription.Tier.pro.features.count, Subscription.Tier.free.features.count)
    }

    func testProductIDs() {
        XCTAssertTrue(Subscription.ProductID.allCases.contains(.proMonthly))
        XCTAssertTrue(Subscription.ProductID.allCases.contains(.proYearly))
    }

    // MARK: - Storage Tests

    func testStorageKeys() {
        XCTAssertNotNil(StorageKeys.vpnEnabled)
        XCTAssertNotNil(StorageKeys.selectedRegion)
        XCTAssertNotNil(StorageKeys.whitelist)
    }

    // MARK: - Rule Management Tests

    func testDefaultBlockedDomains() {
        XCTAssertFalse(Rules.defaultBlockedDomains.isEmpty)
        XCTAssertTrue(Rules.defaultBlockedDomains.contains("doubleclick.net"))
    }

    // MARK: - Performance Tests

    func testDomainMatchingPerformance() {
        let domains = Set(Rules.defaultBlockedDomains)

        measure {
            for _ in 0..<1000 {
                _ = domains.contains("test.doubleclick.net")
            }
        }
    }
}