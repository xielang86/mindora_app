import UIKit
import StoreKit

enum SubscriptionType {
    case free
    case monthly
    case yearly
}

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    // Published properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    // Add willAutoRenew property
    @Published var willAutoRenew: Bool = false
    
    private var latestTransaction: Transaction? = nil
    
    // Cache for checking status
    private var updates: Task<Void, Never>? = nil

    private override init() {
        super.init()
        updates = newTransactionListenerTask()
        
        // Refresh status when app becomes active (e.g. returning from subscription settings)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        updates?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidBecomeActive() {
        Task {
            await updateSubscriptionStatus()
        }
    }
    
    // MARK: - Legacy / Helper Properties for UI
    
    var isSubscribed: Bool {
        return !purchasedProductIDs.isEmpty
    }
    
    var currentPlan: SubscriptionType {
        if purchasedProductIDs.contains(Constants.Subscription.yearlyProductID) {
            return .yearly
        } else if purchasedProductIDs.contains(Constants.Subscription.monthlyProductID) {
            return .monthly
        }
        return .free
    }
    
    var expiryDate: Date {
        // Return actual expiration date from transaction, or distantPast if none
        return latestTransaction?.expirationDate ?? Date.distantPast
    }
    
    var tideDays: Int {
        guard let startDate = latestTransaction?.originalPurchaseDate else { return 0 }
        let components = Calendar.current.dateComponents([.day], from: startDate, to: Date())
        // Start counting from 1
        return max(1, (components.day ?? 0) + 1)
    }

    // MARK: - StoreKit API
    
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [
                Constants.Subscription.monthlyProductID,
                Constants.Subscription.yearlyProductID
            ])

            self.products = storeProducts
            // Post notification to let UI refresh prices
            NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)

            // Also check current entitlements when loading
            await updateSubscriptionStatus()
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check whether the transaction is verified.
            let transaction = try checkVerified(verification)
            
            // The transaction is verified. Deliver content to the user.
            await updateSubscriptionStatus()
            
            // Always finish a transaction.
            await transaction.finish()
            
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    func purchase(type: SubscriptionType) {
        let id = (type == .yearly) ? Constants.Subscription.yearlyProductID : Constants.Subscription.monthlyProductID
        guard let product = products.first(where: { $0.id == id }) else {
            print("Product not found for purchase")
            return
        }
        
        Task {
            do {
                try await purchase(product)
            } catch {
                print("Purchase failed: \(error)")
            }
        }
    }
    
    func restorePurchases() {
        Task {
            await restore()
        }
    }
    
    func restore() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }
    
    // For compatibility with old code that calls cancel (Management is usually outside app for StoreKit)
    func openSubscriptionManagement() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            Task {
                try? await AppStore.showManageSubscriptions(in: scene)
                await updateSubscriptionStatus()
            }
        }
    }
    
    // MARK: - Internal Logic

    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Deliver content to the user.
                    await self.updateSubscriptionStatus()
                    
                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit's verification.
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    private func updateSubscriptionStatus() async {
        var purchased: Set<String> = []
        var latestTrans: Transaction? = nil
        var isAutoRenewing = false
        
        // 1. Check Entitlements (Current Access)
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productType == .autoRenewable || transaction.productType == .nonRenewable {
                    if transaction.revocationDate == nil {
                         purchased.insert(transaction.productID)
                         
                         // Keep track of the transaction with the latest expiration date
                         if latestTrans == nil || (transaction.expirationDate ?? Date.distantPast) > (latestTrans?.expirationDate ?? Date.distantPast) {
                             latestTrans = transaction
                         }
                    }
                }
            } catch {
                print("Failed to verify transaction")
            }
        }
        
        // 2. Check Auto-Renew Status
        // We only care about auto-renew status if user has a valid subscription
        if let transaction = latestTrans, let groupID = transaction.subscriptionGroupID {
            do {
                let statuses = try await Product.SubscriptionInfo.status(for: groupID)
                for status in statuses {
                    guard case .verified(let renewalInfo) = status.renewalInfo else { continue }
                    if renewalInfo.willAutoRenew {
                        isAutoRenewing = true
                    }
                }
            } catch {
                print("Failed to fetch subscription status: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchased
        self.latestTransaction = latestTrans
        self.willAutoRenew = isAutoRenewing
        
        print("Final Status - Subscribed: \(!purchased.isEmpty), AutoRenew: \(isAutoRenewing)")
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
    }
    
    // Compatibility method for the old 'cancelSubscription' which likely just meant clearing verify status in mock
    // In real StoreKit, you can't cancel from app, only link to management.
    func cancelSubscription() {
        openSubscriptionManagement()
    }
}

enum StoreError: Error {
    case failedVerification
}
