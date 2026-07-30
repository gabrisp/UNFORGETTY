import Foundation

#if canImport(RevenueCat)
import RevenueCat

@MainActor
extension ActivityStore {
    func preparePurchases(appUserID: String) async {
        let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? ""
        guard !key.isEmpty else { return }
        if !Purchases.isConfigured { Purchases.configure(withAPIKey: key, appUserID: appUserID) }
        await refreshPremiumStatus()
    }

    func refreshPremiumStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements["premium"]?.isActive == true
        } catch { purchaseError = error.localizedDescription }
    }

    func purchase(productID: String) async {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) else { throw PurchaseError.productUnavailable }
            let result = try await Purchases.shared.purchase(package: package)
            isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
            EventTracker.track("purchase_completed")
        } catch { purchaseError = error.localizedDescription }
    }

    func restorePurchases() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPremium = info.entitlements["premium"]?.isActive == true
            EventTracker.track("purchase_restored")
        } catch { purchaseError = error.localizedDescription }
    }
}

private enum PurchaseError: LocalizedError { case productUnavailable; var errorDescription: String? { "El producto no está disponible ahora." } }
#else
@MainActor
extension ActivityStore {
    func preparePurchases(appUserID: String) async { purchaseError = "RevenueCat aún no está disponible en esta compilación." }
    func purchase(productID: String) async { purchaseError = "RevenueCat aún no está disponible en esta compilación." }
    func restorePurchases() async { purchaseError = "RevenueCat aún no está disponible en esta compilación." }
}
#endif
