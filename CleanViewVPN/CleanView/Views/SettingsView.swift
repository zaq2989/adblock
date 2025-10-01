//
//  SettingsView.swift
//  CleanView
//
//  App settings and configuration
//

import SwiftUI
import MessageUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedDNSProvider = VPNConfig.DNSProvider.cloudflare
    @State private var customDNSServers = ""
    @State private var autoUpdateEnabled = true
    @State private var showingReportIssue = false
    @State private var showingAbout = false
    @State private var showingPrivacyPolicy = false

    init() {
        // Load current settings
        let provider = UserDefaults.standard.string(forKey: StorageKeys.dnsProvider) ?? VPNConfig.DNSProvider.cloudflare.rawValue
        _selectedDNSProvider = State(initialValue: VPNConfig.DNSProvider(rawValue: provider) ?? .cloudflare)

        let servers = UserDefaults.standard.string(forKey: StorageKeys.customDNSServers) ?? ""
        _customDNSServers = State(initialValue: servers)

        _autoUpdateEnabled = State(initialValue: UserDefaults.standard.bool(forKey: StorageKeys.autoUpdateEnabled))
    }

    var body: some View {
        NavigationStack {
            Form {
                // DNS Settings
                dnsSection

                // Update Settings
                updateSection

                // Support
                supportSection

                // Advanced
                advancedSection

                // About
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingReportIssue) {
                ReportIssueView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }

    // MARK: - DNS Section
    private var dnsSection: some View {
        Section("DNS Provider") {
            ForEach(VPNConfig.DNSProvider.allCases, id: \.self) { provider in
                HStack {
                    VStack(alignment: .leading) {
                        Text(provider.rawValue)
                            .font(.body)
                        if !provider.addresses.isEmpty {
                            Text(provider.addresses.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if selectedDNSProvider == provider {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDNSProvider = provider
                }
            }

            if selectedDNSProvider == .custom {
                TextField("DNS Servers (comma separated)", text: $customDNSServers)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.numbersAndPunctuation)

                Text("Enter IP addresses separated by commas (e.g., 8.8.8.8, 8.8.4.4)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Update Section
    private var updateSection: some View {
        Section("Rule Updates") {
            Toggle("Automatic Updates", isOn: $autoUpdateEnabled)

            if autoUpdateEnabled {
                HStack {
                    Text("Update Frequency")
                    Spacer()
                    Text(subscriptionManager.isPro ? "Daily" : "Manual only")
                        .foregroundColor(.secondary)
                }

                if !subscriptionManager.isPro {
                    Label("Pro subscription required for automatic updates",
                          systemImage: "crown.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Button(action: forceUpdate) {
                HStack {
                    Label("Update Now", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if let date = RuleUpdateService.shared.lastUpdateDate {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Support Section
    private var supportSection: some View {
        Section("Support") {
            Button(action: { showingReportIssue = true }) {
                Label("Report Issue", systemImage: "exclamationmark.bubble")
            }

            Button(action: openSupportWebsite) {
                Label("Help Center", systemImage: "questionmark.circle")
            }

            Button(action: rateApp) {
                Label("Rate CleanView", systemImage: "star")
            }

            if subscriptionManager.isPro {
                Button(action: { subscriptionManager.manageSubscriptions() }) {
                    Label("Manage Subscription", systemImage: "creditcard")
                }
            }
        }
    }

    // MARK: - Advanced Section
    private var advancedSection: some View {
        Section("Advanced") {
            Button(action: resetStatistics) {
                Label("Reset Statistics", systemImage: "chart.bar.xaxis")
            }

            Button(action: clearCache) {
                Label("Clear Cache", systemImage: "trash")
            }

            Button(action: exportSettings) {
                Label("Export Settings", systemImage: "square.and.arrow.up")
            }

            HStack {
                Text("Storage Used")
                Spacer()
                Text(SharedStorage.formatBytes(SharedStorage.usedStorageSize))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        Section("About") {
            Button(action: { showingAbout = true }) {
                HStack {
                    Text("About CleanView")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: { showingPrivacyPolicy = true }) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Button(action: openTermsOfService) {
                Label("Terms of Service", systemImage: "doc.text")
            }

            Button(action: openSourceLicenses) {
                Label("Open Source Licenses", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Actions
    private func saveSettings() {
        UserDefaults.standard.set(selectedDNSProvider.rawValue, forKey: StorageKeys.dnsProvider)
        UserDefaults.standard.set(customDNSServers, forKey: StorageKeys.customDNSServers)
        UserDefaults.standard.set(autoUpdateEnabled, forKey: StorageKeys.autoUpdateEnabled)

        // If VPN is connected, reconnect to apply new DNS settings
        if VPNManager.shared.isConnected {
            Task {
                await VPNManager.shared.connect()
            }
        }
    }

    private func forceUpdate() {
        Task {
            await RuleUpdateService.shared.forceUpdate()
        }
    }

    private func resetStatistics() {
        ContentBlockerController.shared.resetStatistics()
    }

    private func clearCache() {
        SharedStorage.cleanup(olderThan: 0)
    }

    private func exportSettings() {
        // Export settings as JSON
        let settings = [
            "dnsProvider": selectedDNSProvider.rawValue,
            "customDNSServers": customDNSServers,
            "autoUpdateEnabled": autoUpdateEnabled,
            "whitelist": Array(WhitelistStore.shared.domains)
        ] as [String : Any]

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("cleanview-settings.json")
            try? data.write(to: url)

            // Share the file
            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }

    private func openSupportWebsite() {
        if let url = URL(string: "https://example.com/support") {
            UIApplication.shared.open(url)
        }
    }

    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXX") {
            UIApplication.shared.open(url)
        }
    }

    private func openTermsOfService() {
        if let url = URL(string: "https://example.com/terms") {
            UIApplication.shared.open(url)
        }
    }

    private func openSourceLicenses() {
        if let url = URL(string: "https://example.com/licenses") {
            UIApplication.shared.open(url)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Report Issue View
struct ReportIssueView: View {
    @Environment(\.dismiss) var dismiss
    @State private var issueType = "Blocking Issue"
    @State private var description = ""
    @State private var email = ""

    let issueTypes = ["Blocking Issue", "Connection Problem", "Performance", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Issue Type") {
                    Picker("Type", selection: $issueType) {
                        ForEach(issueTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(height: 150)
                }

                Section("Contact") {
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section {
                    Button(action: submitIssue) {
                        Text("Submit Report")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func submitIssue() {
        // Send issue report
        // In production, this would send to your backend
        print("Issue reported: \(issueType) - \(description)")
        dismiss()
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)

                    Text("CleanView VPN")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Privacy-focused ad blocker and VPN")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "shield.checkerboard",
                            title: "Advanced Blocking",
                            description: "Block ads, trackers, and annoying overlays"
                        )

                        FeatureRow(
                            icon: "lock.shield",
                            title: "Privacy Protection",
                            description: "No-logs policy and encrypted connections"
                        )

                        FeatureRow(
                            icon: "speedometer",
                            title: "Fast & Reliable",
                            description: "Optimized for speed with minimal latency"
                        )

                        FeatureRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Regular Updates",
                            description: "Constantly updated blocking rules"
                        )
                    }
                    .padding()

                    Text("© 2024 CleanView. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(privacyPolicyText)
                    .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var privacyPolicyText: String {
        """
        # Privacy Policy

        Last updated: January 2024

        ## No-Logs Policy

        CleanView does not collect, store, or share any personally identifiable information. We maintain a strict no-logs policy for all VPN connections.

        ## Data We Don't Collect

        - Browsing history
        - Traffic destination or content
        - DNS queries
        - IP addresses
        - Connection timestamps

        ## Minimal Data Collection

        We only collect anonymous usage statistics to improve our service:
        - Total number of blocked items
        - App crash reports (anonymized)
        - Subscription status

        ## Contact

        For privacy inquiries, contact privacy@example.com
        """
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager.shared)
}