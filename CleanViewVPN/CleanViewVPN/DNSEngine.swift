//
//  DNSEngine.swift
//  CleanViewVPN
//
//  DNS query interception and filtering engine
//

import Foundation
import Network
import OSLog

/// DNS filtering engine for blocking ads and trackers
class DNSEngine {
    private let logger = Logger(subsystem: BundleIdentifiers.vpnExtension, category: "DNSEngine")
    private let ruleEngine: RuleEngine
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.example.cleanview.dns.engine", qos: .userInitiated)
    private var statistics = DNSStatistics()
    private var cache = DNSCache()
    private let upstreamDNS = ["1.1.1.1", "1.0.0.1"] // Cloudflare DNS

    init(ruleEngine: RuleEngine) {
        self.ruleEngine = ruleEngine
    }

    // MARK: - Server Management

    /// Start DNS server on specified port
    func start(on port: UInt16) {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        guard let port = NWEndpoint.Port(rawValue: port) else {
            logger.error("Invalid port number: \(port)")
            return
        }

        listener = try? NWListener(using: parameters, on: port)
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)
        logger.info("DNS server started on port \(port)")
    }

    /// Stop DNS server
    func stop() {
        listener?.cancel()
        listener = nil
        logger.info("DNS server stopped")
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Connection error: \(error)")
                connection.cancel()
                return
            }

            if let data = data, !data.isEmpty {
                Task {
                    await self.handleDNSQuery(data, connection: connection)
                }
            }

            if isComplete {
                connection.cancel()
            }
        }
    }

    // MARK: - DNS Processing

    /// Process DNS packet (simplified for MVP)
    func processDNSPacket(_ packet: Data) async -> Data? {
        // Parse DNS query
        guard let query = parseDNSQuery(packet) else {
            logger.error("Failed to parse DNS query")
            return nil
        }

        // Check cache
        if let cachedResponse = cache.get(for: query.domain) {
            statistics.cacheHits += 1
            return cachedResponse
        }

        // Check if domain should be blocked
        if await ruleEngine.shouldBlock(query.domain) {
            statistics.queriesBlocked += 1
            logger.debug("Blocked domain: \(query.domain)")
            return createBlockedResponse(for: query)
        }

        statistics.queriesAllowed += 1

        // Forward to upstream DNS (simplified for MVP)
        if let response = await forwardToUpstreamDNS(packet) {
            cache.set(response, for: query.domain)
            return response
        }

        return nil
    }

    private func handleDNSQuery(_ data: Data, connection: NWConnection) async {
        statistics.totalQueries += 1

        if let response = await processDNSPacket(data) {
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        } else {
            connection.cancel()
        }
    }

    // MARK: - DNS Parsing (Simplified)

    private func parseDNSQuery(_ data: Data) -> DNSQuery? {
        // Simplified DNS parsing for MVP
        // In production, use a proper DNS library

        guard data.count >= 12 else { return nil }

        // Extract transaction ID
        let transactionID = data.prefix(2)

        // Skip to question section (offset 12)
        var offset = 12
        var domain = ""

        // Parse domain name
        while offset < data.count {
            let length = Int(data[offset])
            if length == 0 { break }

            offset += 1
            if offset + length > data.count { break }

            if !domain.isEmpty { domain += "." }
            domain += String(data: data[offset..<(offset + length)], encoding: .ascii) ?? ""
            offset += length
        }

        return DNSQuery(transactionID: transactionID, domain: domain.lowercased(), originalData: data)
    }

    // MARK: - Response Generation

    private func createBlockedResponse(for query: DNSQuery) -> Data {
        // Create NXDOMAIN response
        var response = Data()

        // Copy transaction ID
        response.append(query.transactionID)

        // Flags: Response + NXDOMAIN
        response.append(contentsOf: [0x81, 0x83])

        // Question count: 1
        response.append(contentsOf: [0x00, 0x01])

        // Answer count: 0
        response.append(contentsOf: [0x00, 0x00])

        // Authority count: 0
        response.append(contentsOf: [0x00, 0x00])

        // Additional count: 0
        response.append(contentsOf: [0x00, 0x00])

        // Copy original question section
        if query.originalData.count > 12 {
            response.append(query.originalData[12...])
        }

        return response
    }

    // MARK: - Upstream DNS (Simplified for MVP)

    private func forwardToUpstreamDNS(_ query: Data) async -> Data? {
        // In MVP, return a mock response
        // In production, implement actual DNS over HTTPS or UDP forwarding

        logger.debug("Forwarding DNS query to upstream (mock for MVP)")

        // For MVP, just pass through with a simple response
        // Real implementation would use Network.framework or URLSession for DoH
        return nil
    }

    // MARK: - Statistics

    func getStatistics() -> DNSStatistics {
        return statistics
    }

    func resetStatistics() {
        statistics = DNSStatistics()
    }
}

// MARK: - Data Models

struct DNSQuery {
    let transactionID: Data
    let domain: String
    let originalData: Data
}

struct DNSStatistics {
    var totalQueries: Int = 0
    var queriesBlocked: Int = 0
    var queriesAllowed: Int = 0
    var cacheHits: Int = 0

    var blockRate: Double {
        guard totalQueries > 0 else { return 0 }
        return Double(queriesBlocked) / Double(totalQueries) * 100
    }
}

// MARK: - DNS Cache

class DNSCache {
    private var cache = [String: CachedEntry]()
    private let queue = DispatchQueue(label: "com.example.cleanview.dns.cache", attributes: .concurrent)
    private let maxEntries = 1000
    private let ttl: TimeInterval = 300 // 5 minutes

    struct CachedEntry {
        let response: Data
        let timestamp: Date
    }

    func get(for domain: String) -> Data? {
        queue.sync {
            guard let entry = cache[domain] else { return nil }

            // Check if entry is still valid
            if Date().timeIntervalSince(entry.timestamp) > ttl {
                cache.removeValue(forKey: domain)
                return nil
            }

            return entry.response
        }
    }

    func set(_ response: Data, for domain: String) {
        queue.async(flags: .barrier) {
            // Implement simple LRU by removing oldest entries if cache is full
            if self.cache.count >= self.maxEntries {
                // Remove oldest entry
                if let oldestKey = self.cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
                    self.cache.removeValue(forKey: oldestKey)
                }
            }

            self.cache[domain] = CachedEntry(response: response, timestamp: Date())
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - DNS over HTTPS (Stub for future implementation)

class DoHClient {
    private let session = URLSession.shared
    private let logger = Logger(subsystem: BundleIdentifiers.vpnExtension, category: "DoHClient")

    func query(_ domain: String) async -> String? {
        // Stub for DoH implementation
        // In production, implement actual DNS over HTTPS queries
        logger.debug("DoH query for domain: \(domain) (stub)")
        return nil
    }
}