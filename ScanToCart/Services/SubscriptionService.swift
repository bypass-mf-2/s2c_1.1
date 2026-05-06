import Foundation
import RevenueCat

/// Wraps the RevenueCat Swift SDK. Mirrors the React Native version's
/// `subscription.ts` (initRevenueCat / checkSubscriptionStatus / getOfferings
/// / purchasePackage / restorePurchases).
///
/// v1 ships in "flavor A" mode: paywall is visible from Profile but no
/// features are gated by the entitlement. Real gating activates in a
/// future update.
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    static let entitlementID = "premium"

    private(set) var isConfigured = false
    private(set) var isPremium = false
    private(set) var availablePackages: [Package] = []

    func configure() {
        let key = Config.revenueCatAPIKey
        guard !key.isEmpty else {
            print("[RevenueCat] No API key — subscription checks skipped")
            return
        }
        Purchases.configure(withAPIKey: key)
        #if DEBUG
        Purchases.logLevel = .info
        #endif
        isConfigured = true
        Task { await refreshStatus() }
    }

    @discardableResult
    func refreshStatus() async -> Bool {
        guard isConfigured else { return true }
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements[Self.entitlementID]?.isActive == true
            return true
        } catch {
            return false
        }
    }

    func loadOfferings() async {
        guard isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            availablePackages = offerings.current?.availablePackages ?? []
        } catch {
            availablePackages = []
        }
    }

    /// Returns `true` on successful purchase, `false` if user cancelled.
    /// Throws on actual errors.
    func purchase(_ package: Package) async throws -> Bool {
        guard isConfigured else { return false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            isPremium = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
            return isPremium
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        guard isConfigured else { return false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPremium = info.entitlements[Self.entitlementID]?.isActive == true
            return isPremium
        } catch {
            return false
        }
    }
}
