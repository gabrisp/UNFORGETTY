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

    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.offering(identifier: "default") ?? offerings.current
            availablePackages = (offering?.availablePackages ?? []).map(Self.packageInfo)
        } catch { purchaseError = error.localizedDescription }
    }

    private static func packageInfo(_ package: Package) -> PremiumPackageInfo {
        let product = package.storeProduct
        let isYearly = product.productIdentifier.localizedCaseInsensitiveContains("year") || product.productIdentifier.localizedCaseInsensitiveContains("annual")

        var trialLabel: String?
        if let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial {
            let count = intro.subscriptionPeriod.value
            let unit: String
            switch intro.subscriptionPeriod.unit {
            case .day: unit = count == 1 ? "día" : "días"
            case .week: unit = count == 1 ? "semana" : "semanas"
            case .month: unit = count == 1 ? "mes" : "meses"
            case .year: unit = count == 1 ? "año" : "años"
            @unknown default: unit = ""
            }
            trialLabel = "\(count) \(unit) gratis"
        }

        return PremiumPackageInfo(
            productID: product.productIdentifier,
            title: isYearly ? "Anual" : "Mensual",
            priceString: product.localizedPriceString,
            periodLabel: isYearly ? "/año" : "/mes",
            trialLabel: trialLabel
        )
    }

    func purchase(productID: String) async {
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.offering(identifier: "default") ?? offerings.current
            guard let package = offering?.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) else { throw PurchaseError.productUnavailable }
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
    func loadOfferings() async {}
    func purchase(productID: String) async { purchaseError = "RevenueCat aún no está disponible en esta compilación." }
    func restorePurchases() async { purchaseError = "RevenueCat aún no está disponible en esta compilación." }
}
#endif
