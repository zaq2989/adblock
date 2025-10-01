//
//  SubscriptionManager.swift
//  CleanView
//
//  StoreKit 2 subscription management
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // Published properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    @Published var currentTier: Subscription.Tier = .free
    @Published var isLoading = false
    @Published var purchaseError: Error?
    @Published var hasActiveSubscription = false
    @Published var expirationDate: Date?

    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        startTransactionListener()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    /// Load available subscription products
    func loadSubscriptions() async {
        isLoading = true
        purchaseError = nil

        do {
            // Request products from App Store
            let productIDs = Subscription.ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }

            // Check current entitlements
            await updatePurchasedProducts()
        } catch {
            print("Failed to load products: \(error)")
            purchaseError = error
        }

        isLoading = false
    }

    // MARK: - Purchase Management

    /// Purchase a subscription product
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        purchaseError = nil

        defer { isLoading = false }

        // Attempt purchase
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)

            // Update purchased products
            await updatePurchasedProducts()

            // Finish the transaction
            await transaction.finish()

            // Trigger rule update for new Pro users
            if currentTier == .pro {
                Task {
                    await RuleUpdateService.shared.checkForUpdates()
                }
            }

            return transaction

        case .userCancelled:
            print("User cancelled purchase")
            return nil

        case .pending:
            print("Purchase is pending")
            return nil

        @unknown default:
            return nil
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        defer { isLoading = false }

        do {
            // Sync with App Store
            try await AppStore.sync()

            // Update purchased products
            await updatePurchasedProducts()

            if purchasedProductIDs.isEmpty {
                purchaseError = NSError(
                    domain: "SubscriptionManager",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No purchases to restore"]
                )
            }
        } catch {
            print("Restore failed: \(error)")
            purchaseError = error
        }
    }

    // MARK: - Transaction Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Entitlement Management

    /// Update current purchased products and subscription tier
    private func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()
        var activeSub = false
        var latestExpiration: Date?

        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if transaction is still valid
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        purchasedIDs.insert(transaction.productID)
                        activeSub = true

                        // Track latest expiration
                        if latestExpiration == nil || expirationDate > latestExpiration! {
                            latestExpiration = expirationDate
                        }
                    }
                } else {
                    // Non-subscription purchase (shouldn't happen in this app)
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }

        // Update published properties
        purchasedProductIDs = purchasedIDs
        hasActiveSubscription = activeSub
        expirationDate = latestExpiration

        // Determine current tier
        if purchasedProductIDs.contains(Subscription.ProductID.proMonthly.rawValue) ||
           purchasedProductIDs.contains(Subscription.ProductID.proYearly.rawValue) {
            currentTier = .pro
        } else {
            currentTier = .free
        }

        // Save tier to UserDefaults for other app components
        UserDefaults.standard.set(currentTier.rawValue, forKey: StorageKeys.subscriptionTier)

        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name(NotificationNames.subscriptionChanged),
            object: nil,
            userInfo: ["tier": currentTier.rawValue]
        )
    }

    // MARK: - Transaction Listener

    /// Start listening for transaction updates
    private func startTransactionListener() {
        updateListenerTask = Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Update purchased products when new transaction arrives
                    await self.updatePurchasedProducts()

                    // Always finish transactions
                    await transaction.finish()
                } catch {
                    print("Transaction update failed: \(error)")
                }
            }
        }
    }

    // MARK: - Utility Functions

    /// Check if user has Pro features
    var isPro: Bool {
        currentTier == .pro
    }

    /// Get display price for a product
    func displayPrice(for product: Product) -> String {
        product.displayPrice
    }

    /// Get subscription period string
    func subscriptionPeriod(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }

        switch period.unit {
        case .day:
            return "\(period.value) day\(period.value > 1 ? "s" : "")"
        case .week:
            return "\(period.value) week\(period.value > 1 ? "s" : "")"
        case .month:
            return "\(period.value) month\(period.value > 1 ? "s" : "")"
        case .year:
            return "\(period.value) year\(period.value > 1 ? "s" : "")"
        @unknown default:
            return nil
        }
    }

    /// Get introductory offer if available
    func introductoryOffer(for product: Product) -> String? {
        guard let intro = product.subscription?.introductoryOffer else { return nil }

        let period: String
        switch intro.period.unit {
        case .day: period = "day"
        case .week: period = "week"
        case .month: period = "month"
        case .year: period = "year"
        @unknown default: return nil
        }

        switch intro.paymentMode {
        case .freeTrial:
            return "\(intro.period.value) \(period) free trial"
        case .payAsYouGo:
            return "\(intro.displayPrice) for \(intro.period.value) \(period)"
        case .payUpFront:
            return "\(intro.displayPrice) for \(intro.period.value) \(period)"
        @unknown default:
            return nil
        }
    }

    // MARK: - Manage Subscriptions

    /// Open subscription management in Settings
    func manageSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Custom Errors
enum StoreError: Error, LocalizedError {
    case verificationFailed
    case purchaseFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        case .purchaseFailed:
            return "Purchase failed"
        case .productNotFound:
            return "Product not found"
        }
    }
}