//
//  WhitelistView.swift
//  CleanView
//
//  Manage whitelisted domains
//

import SwiftUI

struct WhitelistView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var whitelistStore = WhitelistStore.shared
    @State private var newDomain = ""
    @State private var showingAddDomain = false
    @State private var showingImport = false
    @State private var showingExport = false
    @State private var searchText = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    var filteredDomains: [String] {
        let sortedDomains = whitelistStore.domains.sorted()
        if searchText.isEmpty {
            return sortedDomains
        }
        return sortedDomains.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Stats section
                statsSection

                // Actions section
                actionsSection

                // Domains list
                if !filteredDomains.isEmpty {
                    domainsSection
                } else if !searchText.isEmpty {
                    noResultsSection
                } else {
                    emptyStateSection
                }
            }
            .navigationTitle("Whitelist")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search domains")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddDomain = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDomain) {
                AddDomainView { domain in
                    addDomain(domain)
                }
            }
            .sheet(isPresented: $showingImport) {
                ImportWhitelistView { text in
                    importDomains(text)
                }
            }
            .sheet(isPresented: $showingExport) {
                ExportWhitelistView(domains: Array(whitelistStore.domains))
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Whitelisted Sites")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(whitelistStore.domains.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Protection Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(whitelistStore.domains.isEmpty ? "Full" : "Selective")
                        .font(.title3)
                        .foregroundColor(whitelistStore.domains.isEmpty ? .green : .orange)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        Section("Actions") {
            Button(action: { showingAddDomain = true }) {
                Label("Add Domain", systemImage: "plus.circle")
            }

            Button(action: { showingImport = true }) {
                Label("Import List", systemImage: "square.and.arrow.down")
            }

            Button(action: { showingExport = true }) {
                Label("Export List", systemImage: "square.and.arrow.up")
            }

            if !whitelistStore.domains.isEmpty {
                Button(role: .destructive, action: clearAllDomains) {
                    Label("Clear All", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Domains Section
    private var domainsSection: some View {
        Section("Whitelisted Domains") {
            ForEach(filteredDomains, id: \.self) { domain in
                DomainRow(domain: domain) {
                    removeDomain(domain)
                }
            }
        }
    }

    // MARK: - Empty States
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)

                Text("No Whitelisted Sites")
                    .font(.headline)

                Text("All sites are currently protected. Add sites here if you experience issues with specific websites.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Add First Domain") {
                    showingAddDomain = true
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    private var noResultsSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text("No Results")
                    .font(.headline)

                Text("No domains match '\(searchText)'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Actions
    private func addDomain(_ domain: String) {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Extract domain from URL if needed
        let extracted = whitelistStore.extractDomain(from: trimmed) ?? trimmed

        whitelistStore.add(extracted)
    }

    private func removeDomain(_ domain: String) {
        whitelistStore.remove(domain)
    }

    private func importDomains(_ text: String) {
        whitelistStore.importFromText(text)
    }

    private func clearAllDomains() {
        whitelistStore.clearAll()
    }
}

// MARK: - Domain Row
struct DomainRow: View {
    let domain: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(domain)
                    .font(.body)

                Text("Filtering disabled for this site")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Domain View
struct AddDomainView: View {
    @Environment(\.dismiss) var dismiss
    @State private var domain = ""
    @State private var showingPasteButton = false
    let onAdd: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Enter Domain") {
                    HStack {
                        TextField("example.com", text: $domain)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)

                        if showingPasteButton {
                            Button("Paste") {
                                if let clipboard = UIPasteboard.general.string {
                                    domain = clipboard
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Text("Enter the domain you want to whitelist. The app will automatically extract the domain from URLs.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Examples") {
                    ForEach(["example.com", "news.site.com", "app.service.io"], id: \.self) { example in
                        Button(action: { domain = example }) {
                            HStack {
                                Text(example)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left.circle")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Domain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(domain)
                        dismiss()
                    }
                    .disabled(domain.isEmpty)
                }
            }
            .onAppear {
                // Check if clipboard has content
                showingPasteButton = UIPasteboard.general.hasStrings
            }
        }
    }
}

// MARK: - Import Whitelist View
struct ImportWhitelistView: View {
    @Environment(\.dismiss) var dismiss
    @State private var importText = ""
    let onImport: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Import Domains") {
                    TextEditor(text: $importText)
                        .frame(height: 200)
                        .font(.system(.body, design: .monospaced))

                    Text("Enter one domain per line")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Paste from Clipboard") {
                        if let clipboard = UIPasteboard.general.string {
                            importText = clipboard
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Import Whitelist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        onImport(importText)
                        dismiss()
                    }
                    .disabled(importText.isEmpty)
                }
            }
        }
    }
}

// MARK: - Export Whitelist View
struct ExportWhitelistView: View {
    @Environment(\.dismiss) var dismiss
    let domains: [String]

    private var exportText: String {
        domains.sorted().joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Export Domains") {
                    ScrollView {
                        Text(exportText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 200)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }

                Section {
                    Button("Copy to Clipboard") {
                        UIPasteboard.general.string = exportText
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)

                    Button("Share") {
                        shareWhitelist()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Export Whitelist")
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

    private func shareWhitelist() {
        if let url = WhitelistStore.shared.shareAsFile() {
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
}

// MARK: - Preview
#Preview {
    WhitelistView()
}