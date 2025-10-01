//
//  VPNManager.swift
//  CleanView
//
//  Manages NEPacketTunnelProvider configuration and connection
//

import Foundation
import NetworkExtension
import Combine

@MainActor
class VPNManager: ObservableObject {
    static let shared = VPNManager()

    // Published properties for UI binding
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionStatus: NEVPNStatus = .disconnected
    @Published var selectedRegion: VPNConfig.Region = .automatic
    @Published var lastError: Error?

    private var tunnelManager: NETunnelProviderManager?
    private var statusObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        observeVPNStatus()
    }

    // MARK: - Configuration

    /// Load existing VPN configuration or create new one
    func loadConfiguration() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()

            if let existingManager = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == VPNConfig.tunnelBundleIdentifier
            }) {
                tunnelManager = existingManager
            } else {
                tunnelManager = await createNewConfiguration()
            }

            updateConnectionStatus()
        } catch {
            print("Failed to load VPN configuration: \(error)")
            lastError = error
        }
    }

    /// Create new VPN configuration
    private func createNewConfiguration() async -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        let protocolConfig = NETunnelProviderProtocol()

        // Configure the protocol
        protocolConfig.providerBundleIdentifier = VPNConfig.tunnelBundleIdentifier
        protocolConfig.serverAddress = VPNConfig.serverAddress
        protocolConfig.providerConfiguration = [
            "region": selectedRegion.rawValue,
            "dnsProvider": UserDefaults.standard.string(forKey: StorageKeys.dnsProvider) ?? VPNConfig.DNSProvider.cloudflare.rawValue
        ]

        manager.protocolConfiguration = protocolConfig
        manager.localizedDescription = VPNConfig.localizedDescription
        manager.isEnabled = true

        // Configure on-demand rules (optional)
        manager.isOnDemandEnabled = false

        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
        } catch {
            print("Failed to save VPN configuration: \(error)")
        }

        return manager
    }

    // MARK: - Connection Management

    /// Connect to VPN
    func connect() async {
        guard let manager = tunnelManager else {
            await loadConfiguration()
            return
        }

        isConnecting = true
        lastError = nil

        do {
            // Update configuration with current settings
            if let protocolConfig = manager.protocolConfiguration as? NETunnelProviderProtocol {
                protocolConfig.providerConfiguration = [
                    "region": selectedRegion.rawValue,
                    "dnsProvider": UserDefaults.standard.string(forKey: StorageKeys.dnsProvider) ?? VPNConfig.DNSProvider.cloudflare.rawValue,
                    "whitelist": WhitelistStore.shared.domains
                ]
                manager.protocolConfiguration = protocolConfig
            }

            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()

            // Start the tunnel
            try manager.connection.startVPNTunnel()

            // Save state
            UserDefaults.standard.set(true, forKey: StorageKeys.vpnEnabled)
        } catch {
            print("Failed to connect VPN: \(error)")
            lastError = error
            isConnecting = false
        }
    }

    /// Disconnect from VPN
    func disconnect() {
        tunnelManager?.connection.stopVPNTunnel()
        UserDefaults.standard.set(false, forKey: StorageKeys.vpnEnabled)
    }

    /// Toggle VPN connection
    func toggleConnection() async {
        if isConnected {
            disconnect()
        } else {
            await connect()
        }
    }

    // MARK: - Status Observation

    private func observeVPNStatus() {
        NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateConnectionStatus()
            }
            .store(in: &cancellables)
    }

    private func updateConnectionStatus() {
        guard let manager = tunnelManager else {
            connectionStatus = .disconnected
            isConnected = false
            isConnecting = false
            return
        }

        connectionStatus = manager.connection.status

        switch connectionStatus {
        case .connected:
            isConnected = true
            isConnecting = false
        case .connecting, .reasserting:
            isConnected = false
            isConnecting = true
        case .disconnected, .disconnecting, .invalid:
            isConnected = false
            isConnecting = false
        @unknown default:
            isConnected = false
            isConnecting = false
        }

        // Post notification for other parts of app
        NotificationCenter.default.post(
            name: Notification.Name(NotificationNames.vpnStatusChanged),
            object: nil,
            userInfo: ["status": connectionStatus.rawValue]
        )
    }

    // MARK: - Region Management

    func changeRegion(_ region: VPNConfig.Region) async {
        selectedRegion = region
        UserDefaults.standard.set(region.rawValue, forKey: StorageKeys.selectedRegion)

        // Reconnect if currently connected
        if isConnected {
            disconnect()
            await connect()
        }
    }

    // MARK: - Statistics

    func getConnectionStatistics() -> (bytesIn: Int64, bytesOut: Int64, connectedTime: TimeInterval)? {
        guard isConnected,
              let session = tunnelManager?.connection as? NETunnelProviderSession else {
            return nil
        }

        // Note: Real statistics would require implementation in the packet tunnel provider
        // This is placeholder for MVP
        return (bytesIn: 0, bytesOut: 0, connectedTime: 0)
    }

    // MARK: - Error Handling

    func clearError() {
        lastError = nil
    }

    var errorMessage: String? {
        guard let error = lastError else { return nil }

        if let neError = error as? NEVPNError {
            switch neError.code {
            case .configurationInvalid:
                return "Invalid VPN configuration"
            case .configurationDisabled:
                return "VPN configuration is disabled"
            case .connectionFailed:
                return "Connection failed"
            case .configurationStale:
                return "Configuration needs update"
            case .configurationReadWriteFailed:
                return "Failed to save configuration"
            default:
                return "VPN error: \(neError.localizedDescription)"
            }
        }

        return error.localizedDescription
    }
}

// MARK: - VPN Status Extension
extension NEVPNStatus {
    var displayText: String {
        switch self {
        case .invalid:
            return "Invalid"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reasserting:
            return "Reconnecting..."
        case .disconnecting:
            return "Disconnecting..."
        @unknown default:
            return "Unknown"
        }
    }

    var displayColor: String {
        switch self {
        case .connected:
            return "green"
        case .connecting, .reasserting:
            return "yellow"
        case .disconnected, .disconnecting:
            return "red"
        case .invalid:
            return "gray"
        @unknown default:
            return "gray"
        }
    }
}