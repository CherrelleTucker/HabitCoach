import Foundation
import StoreKit
import os.log
#if canImport(SwiftUI)
import SwiftUI
#endif

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "PurchaseManager")

@MainActor @Observable
class PurchaseManager {
    static let productID = "com.ctuckersolutions.habitcoach.premium"
    static let unlockKey = "is_premium_unlocked"

    var isPremium: Bool = false
    var purchaseInProgress: Bool = false
    var errorMessage: String?

    #if os(iOS)
    var product: Product?
    private var transactionListener: Task<Void, Never>?
    #endif

    init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.unlockKey)
        #if os(iOS)
        transactionListener = listenForTransactions()
        Task {
            await loadProduct()
            await validateEntitlements()
        }
        #endif
    }

    // MARK: - iOS StoreKit

    #if os(iOS)
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            if product == nil {
                logger.warning("Product not found for ID: \(Self.productID)")
            }
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    func purchase() async {
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            errorMessage = "Unable to connect to the App Store. Please check your connection and try again."
            return
        }
        purchaseInProgress = true
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                unlock()
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval"
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            errorMessage = "Purchase failed. Please try again."
        }
        purchaseInProgress = false
    }

    func restore() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID {
                unlock()
                found = true
                break
            }
        }
        if !found {
            errorMessage = "No previous purchase found. If you've purchased before, make sure you're signed in with the same Apple ID."
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        let expectedID = Self.productID
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result,
                   transaction.productID == expectedID {
                    await transaction.finish()
                    await MainActor.run { [weak self] in
                        self?.unlock()
                    }
                }
            }
        }
    }

    /// Re-validates premium status against StoreKit entitlements on each launch.
    private func validateEntitlements() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID {
                found = true
                break
            }
        }
        if found && !isPremium {
            unlock()
        } else if !found && isPremium {
            // Purchase was refunded or is no longer valid
            isPremium = false
            UserDefaults.standard.set(false, forKey: Self.unlockKey)
            logger.info("Premium revoked — entitlement not found")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    #endif

    // MARK: - Unlock

    func unlock() {
        isPremium = true
        UserDefaults.standard.set(true, forKey: Self.unlockKey)
        logger.info("Premium unlocked")
        #if os(iOS)
        ConnectivityService.shared.sendPremiumStatus(true)
        #endif
    }
}

// MARK: - Environment Key

private struct PurchaseManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = PurchaseManager()
}

extension EnvironmentValues {
    var purchaseManager: PurchaseManager {
        get { self[PurchaseManagerKey.self] }
        set { self[PurchaseManagerKey.self] = newValue }
    }
}
