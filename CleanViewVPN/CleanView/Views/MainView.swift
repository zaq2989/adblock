//
//  MainView.swift
//  CleanView
//
//  Main app interface with VPN control
//

import SwiftUI
import NetworkExtension

struct MainView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var contentBlocker = ContentBlockerController.shared
    @StateObject private var ruleUpdate = RuleUpdateService.shared
    @State private var showingSettings = false
    @State private var showingSubscription = false
    @State private var showingWhitelist = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Status card
                        statusCard

                        // VPN toggle
                        vpnToggleCard

                        // Region selector
                        if subscriptionManager.isPro {
                            regionCard
                        }

                        // Statistics
                        statisticsCard

                        // Quick actions
                        quickActionsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("CleanView")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showingWhitelist) {
                WhitelistView()
            }
            .alert("VPN Error", isPresented: .constant(vpnManager.lastError != nil)) {
                Button("OK") {
                    vpnManager.clearError()
                }
            } message: {
                Text(vpnManager.errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            // Connection status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(vpnManager.connectionStatus.displayText)
                    .font(.headline)

                Spacer()

                if vpnManager.isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // Protection level
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protection Level")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(protectionLevel)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(subscriptionManager.currentTier.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(subscriptionManager.isPro ? .green : .orange)
                }
            }

            // Content blocker status
            if !contentBlocker.isEnabled {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("Content blocker disabled in Safari")
                        .font(.caption)

                    Spacer()

                    Button("Enable") {
                        contentBlocker.openSafariSettings()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - VPN Toggle Card
    private var vpnToggleCard: some View {
        VStack(spacing: 16) {
            // Toggle button
            Button(action: toggleVPN) {
                ZStack {
                    Circle()
                        .fill(vpnManager.isConnected ? Color.green : Color(.systemGray3))
                        .frame(width: 120, height: 120)

                    Image(systemName: vpnManager.isConnected ? "shield.fill" : "shield.slash.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
            }
            .disabled(vpnManager.isConnecting)
            .scaleEffect(vpnManager.isConnecting ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: vpnManager.isConnecting)

            Text(vpnManager.isConnected ? "Tap to Disconnect" : "Tap to Connect")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Region Card
    private var regionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Server Region")
                .font(.headline)

            Menu {
                ForEach(VPNConfig.Region.allCases, id: \.self) { region in
                    Button(action: { selectRegion(region) }) {
                        Label("\(region.flag) \(region.rawValue)",
                              systemImage: vpnManager.selectedRegion == region ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Text("\(vpnManager.selectedRegion.flag) \(vpnManager.selectedRegion.rawValue)")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Statistics Card
    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Protection Statistics")
                .font(.headline)

            HStack {
                StatItem(
                    icon: "shield.checkerboard",
                    title: "Blocked Ads",
                    value: formatNumber(contentBlocker.getStatistics().blockedAds)
                )

                Divider()

                StatItem(
                    icon: "eye.slash",
                    title: "Blocked Trackers",
                    value: formatNumber(contentBlocker.getStatistics().blockedTrackers)
                )

                Divider()

                StatItem(
                    icon: "rectangle.on.rectangle.slash",
                    title: "Blocked Popups",
                    value: formatNumber(contentBlocker.getStatistics().blockedPopups)
                )
            }
            .frame(height: 60)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Quick Actions Card
    private var quickActionsCard: some View {
        VStack(spacing: 12) {
            // Update rules
            Button(action: updateRules) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Update Blocking Rules")
                    Spacer()
                    if ruleUpdate.isUpdating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let date = ruleUpdate.lastUpdateDate {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
            .disabled(ruleUpdate.isUpdating)

            // Whitelist
            Button(action: { showingWhitelist = true }) {
                HStack {
                    Image(systemName: "checkmark.shield")
                    Text("Manage Whitelist")
                    Spacer()
                    Text("\(WhitelistStore.shared.domains.count) sites")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }

            // Subscription
            if !subscriptionManager.isPro {
                Button(action: { showingSubscription = true }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Upgrade to Pro")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Helpers
    private var statusColor: Color {
        switch vpnManager.connectionStatus {
        case .connected:
            return .green
        case .connecting, .reasserting:
            return .yellow
        case .disconnected, .disconnecting, .invalid:
            return .red
        @unknown default:
            return .gray
        }
    }

    private var protectionLevel: String {
        if !vpnManager.isConnected {
            return "Disabled"
        } else if !contentBlocker.isEnabled {
            return "Partial"
        } else {
            return "Maximum"
        }
    }

    private func toggleVPN() {
        Task {
            await vpnManager.toggleConnection()
        }
    }

    private func selectRegion(_ region: VPNConfig.Region) {
        Task {
            await vpnManager.changeRegion(region)
        }
    }

    private func updateRules() {
        Task {
            await ruleUpdate.checkForUpdates()
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "0"
    }
}

// MARK: - Stat Item Component
struct StatItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview {
    MainView()
        .environmentObject(VPNManager.shared)
        .environmentObject(SubscriptionManager.shared)
}