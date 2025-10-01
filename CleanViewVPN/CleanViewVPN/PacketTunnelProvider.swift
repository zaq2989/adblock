//
//  PacketTunnelProvider.swift
//  CleanViewVPN
//
//  NEPacketTunnelProvider implementation for local VPN
//

import NetworkExtension
import Network
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let logger = Logger(subsystem: BundleIdentifiers.vpnExtension, category: "PacketTunnel")
    private var dnsEngine: DNSEngine?
    private var ruleEngine: RuleEngine?
    private let dnsQueue = DispatchQueue(label: "com.example.cleanview.dns", qos: .userInitiated)
    private var networkMonitor: NWPathMonitor?

    // MARK: - Tunnel Lifecycle

    override func startTunnel(options: [String : NSObject]? = nil) async throws {
        logger.info("Starting packet tunnel")

        // Initialize rule engine
        ruleEngine = RuleEngine()
        await ruleEngine?.loadRules()

        // Initialize DNS engine
        dnsEngine = DNSEngine(ruleEngine: ruleEngine!)

        // Configure tunnel settings
        try await configureTunnel()

        // Start network monitoring
        startNetworkMonitoring()

        // Start processing packets
        startPacketProcessing()

        logger.info("Packet tunnel started successfully")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        logger.info("Stopping packet tunnel with reason: \(reason.rawValue)")

        // Stop network monitoring
        networkMonitor?.cancel()
        networkMonitor = nil

        // Clean up DNS engine
        dnsEngine?.stop()
        dnsEngine = nil

        // Clean up rule engine
        ruleEngine = nil

        logger.info("Packet tunnel stopped")
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        logger.debug("Received app message")

        // Handle messages from the host app
        if let message = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] {
            if let command = message["command"] as? String {
                switch command {
                case "reloadRules":
                    await ruleEngine?.loadRules()
                    return "success".data(using: .utf8)

                case "getStatistics":
                    let stats = getStatistics()
                    return try? JSONSerialization.data(withJSONObject: stats)

                case "updateWhitelist":
                    if let whitelist = message["whitelist"] as? [String] {
                        ruleEngine?.updateWhitelist(whitelist)
                    }
                    return "success".data(using: .utf8)

                default:
                    logger.warning("Unknown command: \(command)")
                }
            }
        }

        return nil
    }

    override func sleep() async {
        logger.info("Tunnel going to sleep")
        // Pause non-critical operations
    }

    override func wake() {
        logger.info("Tunnel waking up")
        // Resume operations
    }

    // MARK: - Configuration

    private func configureTunnel() async throws {
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: VPNConfig.serverAddress)

        // Configure IPv4
        let ipv4Settings = NEIPv4Settings(addresses: [VPNConfig.localDNS], subnetMasks: ["255.255.255.255"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        tunnelSettings.ipv4Settings = ipv4Settings

        // Configure DNS
        let dnsServers = getDNSServers()
        let dnsSettings = NEDNSSettings(servers: dnsServers)
        dnsSettings.matchDomains = [""] // Match all domains
        tunnelSettings.dnsSettings = dnsSettings

        // Configure MTU
        tunnelSettings.mtu = NSNumber(value: 1400)

        // Apply settings
        try await setTunnelNetworkSettings(tunnelSettings)
        logger.info("Tunnel settings applied successfully")
    }

    private func getDNSServers() -> [String] {
        // Get DNS provider from configuration
        if let providerConfig = protocolConfiguration.providerConfiguration,
           let dnsProviderString = providerConfig["dnsProvider"] as? String,
           let dnsProvider = VPNConfig.DNSProvider(rawValue: dnsProviderString) {

            switch dnsProvider {
            case .system:
                return [VPNConfig.localDNS] // Use local DNS for filtering
            case .cloudflare:
                return [VPNConfig.localDNS] // Still use local for filtering
            case .custom:
                if let customServers = providerConfig["customDNSServers"] as? String {
                    return customServers.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                }
            }
        }

        return [VPNConfig.localDNS]
    }

    // MARK: - Packet Processing

    private func startPacketProcessing() {
        // Read packets from the tunnel
        Task {
            await readPackets()
        }

        // Start DNS server
        dnsEngine?.start(on: 53)
    }

    private func readPackets() async {
        while true {
            do {
                // Read packets from the virtual interface
                let packets = try await packetFlow.readPackets()

                for packet in packets {
                    await processPacket(packet.data, protocolFamily: packet.protocolFamily)
                }
            } catch {
                logger.error("Error reading packets: \(error)")
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }

    private func processPacket(_ data: Data, protocolFamily: NSNumber) async {
        // For MVP, we focus on DNS packets (UDP port 53)
        // In production, implement full packet inspection

        guard protocolFamily.intValue == AF_INET else { return }

        // Check if it's a DNS packet (simplified check)
        if isDNSPacket(data) {
            // Process DNS query
            if let response = await dnsEngine?.processDNSPacket(data) {
                // Send response back through tunnel
                await writePacket(response, protocolFamily: protocolFamily)
            }
        } else {
            // Forward non-DNS packets as-is (simplified for MVP)
            // In production, implement proper packet routing
            await writePacket(data, protocolFamily: protocolFamily)
        }
    }

    private func isDNSPacket(_ data: Data) -> Bool {
        // Simplified DNS packet detection
        // Check for UDP header and port 53
        guard data.count > 28 else { return false } // Minimum IP + UDP header

        // Check IP protocol (offset 9, should be 17 for UDP)
        if data[9] != 17 { return false }

        // Check destination port (offset 22-23 for destination port)
        let destPort = (UInt16(data[22]) << 8) | UInt16(data[23])
        return destPort == 53
    }

    private func writePacket(_ data: Data, protocolFamily: NSNumber) async {
        do {
            try await packetFlow.writePackets([NEPacket(data: data, protocolFamily: protocolFamily)])
        } catch {
            logger.error("Error writing packet: \(error)")
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            self?.logger.info("Network path updated: \(path.status)")

            if path.status == .satisfied {
                // Network is available
                Task {
                    await self?.ruleEngine?.loadRules()
                }
            }
        }

        let queue = DispatchQueue(label: "com.example.cleanview.network.monitor")
        networkMonitor?.start(queue: queue)
    }

    // MARK: - Statistics

    private func getStatistics() -> [String: Any] {
        let stats = dnsEngine?.getStatistics() ?? DNSStatistics()
        return [
            "queriesBlocked": stats.queriesBlocked,
            "queriesAllowed": stats.queriesAllowed,
            "totalQueries": stats.totalQueries,
            "cacheHits": stats.cacheHits,
            "uptime": ProcessInfo.processInfo.systemUptime
        ]
    }

    // MARK: - Helpers

    private func logMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0
            logger.debug("Memory usage: \(usedMemory, format: .fixed(precision: 2)) MB")
        }
    }
}

// MARK: - NEProviderStopReason Extension
extension NEProviderStopReason {
    var description: String {
        switch self {
        case .none:
            return "No specific reason"
        case .userInitiated:
            return "User initiated"
        case .providerFailed:
            return "Provider failed"
        case .noNetworkAvailable:
            return "No network available"
        case .unrecoverableNetworkChange:
            return "Unrecoverable network change"
        case .providerDisabled:
            return "Provider disabled"
        case .authenticationCanceled:
            return "Authentication canceled"
        case .configurationFailed:
            return "Configuration failed"
        case .idleTimeout:
            return "Idle timeout"
        case .configurationDisabled:
            return "Configuration disabled"
        case .configurationRemoved:
            return "Configuration removed"
        case .superceded:
            return "Superceded"
        case .userLogout:
            return "User logout"
        case .userSwitch:
            return "User switch"
        case .connectionFailed:
            return "Connection failed"
        case .sleep:
            return "Device sleep"
        case .appUpdate:
            return "App update"
        @unknown default:
            return "Unknown reason"
        }
    }
}