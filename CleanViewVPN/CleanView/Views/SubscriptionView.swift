//
//  SubscriptionView.swift
//  CleanView
//
//  Subscription management and upgrade interface
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Current subscription status
                    if subscriptionManager.hasActiveSubscription {
                        currentSubscriptionCard
                    }

                    // Features comparison
                    featuresSection

                    // Products
                    if !subscriptionManager.products.isEmpty {
                        productsSection
                    }

                    // Actions
                    actionsSection

                    // Legal text
                    legalText
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Restore Purchases", isPresented: $showingRestoreAlert) {
                Button("OK") { }
            } message: {
                Text(restoreMessage)
            }
            .overlay {
                if subscriptionManager.isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 10)
                }
            }
            .task {
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.loadSubscriptions()
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("CleanView Pro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Unlock advanced features for maximum protection")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Current Subscription Card
    private var currentSubscriptionCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(subscriptionManager.currentTier.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundColor(.green)
            }

            if let expirationDate = subscriptionManager.expirationDate {
                HStack {
                    Text("Renews")
                    Spacer()
                    Text(expirationDate, style: .date)
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            Button(action: {
                subscriptionManager.manageSubscriptions()
            }) {
                Text("Manage Subscription")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Features")
                .font(.headline)

            // Features grid
            VStack(spacing: 12) {
                FeatureComparisonRow(
                    feature: "Ad & Tracker Blocking",
                    free: true,
                    pro: true
                )

                FeatureComparisonRow(
                    feature: "Overlay Removal",
                    free: true,
                    pro: true
                )

                FeatureComparisonRow(
                    feature: "Daily Rule Updates",
                    free: false,
                    pro: true
                )

                FeatureComparisonRow(
                    feature: "Multiple Regions",
                    free: false,
                    pro: true
                )

                FeatureComparisonRow(
                    feature: "Custom DNS",
                    free: false,
                    pro: true
                )

                FeatureComparisonRow(
                    feature: "Priority Support",
                    free: false,
                    pro: true
                )

                FeatureComparisonRow(
                    feature: "No Ads in App",
                    free: false,
                    pro: true
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Products Section
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Plan")
                .font(.headline)

            ForEach(subscriptionManager.products.filter { $0.id != Subscription.ProductID.free.rawValue },
                    id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    onSelect: { selectedProduct = product }
                )
            }

            // Subscribe button
            if let product = selectedProduct {
                Button(action: { subscribe(to: product) }) {
                    HStack {
                        Text("Subscribe to \(product.displayName)")
                        Spacer()
                        Text(product.displayPrice)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: restorePurchases) {
                Text("Restore Purchases")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if subscriptionManager.hasActiveSubscription {
                Button(action: {
                    subscriptionManager.manageSubscriptions()
                }) {
                    Text("Cancel Subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Legal Text
    private var legalText: some View {
        VStack(spacing: 8) {
            Text("Subscriptions will automatically renew unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("Terms of Service") {
                    if let url = URL(string: "https://example.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }

                Text("•")

                Button("Privacy Policy") {
                    if let url = URL(string: "https://example.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(.caption2)
        }
        .padding(.top)
    }

    // MARK: - Actions
    private func subscribe(to product: Product) {
        Task {
            do {
                if let transaction = try await subscriptionManager.purchase(product) {
                    print("Purchase successful: \(transaction.productID)")
                    dismiss()
                }
            } catch {
                print("Purchase failed: \(error)")
            }
        }
    }

    private func restorePurchases() {
        Task {
            await subscriptionManager.restorePurchases()

            if subscriptionManager.hasActiveSubscription {
                restoreMessage = "Your purchases have been restored successfully!"
            } else {
                restoreMessage = "No purchases found to restore. If you believe this is an error, please contact support."
            }
            showingRestoreAlert = true
        }
    }
}

// MARK: - Feature Comparison Row
struct FeatureComparisonRow: View {
    let feature: String
    let free: Bool
    let pro: Bool

    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)

            Spacer()

            // Free tier
            Image(systemName: free ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(free ? .green : .gray)
                .frame(width: 40)

            // Pro tier
            Image(systemName: pro ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(pro ? .green : .gray)
                .frame(width: 40)
        }
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.headline)

                        if let period = SubscriptionManager.shared.subscriptionPeriod(for: product) {
                            Text(period)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if let intro = SubscriptionManager.shared.introductoryOffer(for: product) {
                            Text(intro)
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }

                // Show savings for yearly plan
                if product.id.contains("yearly") {
                    Text("Save 20% compared to monthly")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }

                // Selection indicator
                if isSelected {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    SubscriptionView()
}