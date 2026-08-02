import SwiftUI

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ActivityStore
    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var overlayHeight: CGFloat = 260

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(.vertical) {
                    VStack(spacing: 20) {
                        PaywallMarqueeShowcase()
                            .padding(.horizontal, -16)
                            .padding(.top, 4)

                        Image(systemName: store.isPremium ? "checkmark.seal.fill" : "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(.indigo)
                        Text(store.isPremium ? "Premium activo" : "Unforgetty Premium").font(.title.bold())
                        Text("Actividades y programaciones ilimitadas.").multilineTextAlignment(.center).foregroundStyle(.secondary)

                        // Reserves room so the fixed bottom overlay never covers the last bit of
                        // scrollable content — measured from the overlay itself, not guessed.
                        if !store.isPremium {
                            Color.clear.frame(height: overlayHeight)
                        }
                    }
                    .padding()
                }

                if !store.isPremium {
                    bottomPurchaseOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .task {
            await store.loadOfferings()
            if selectedProductID == nil {
                selectedProductID = store.availablePackages.first(where: { $0.productID.localizedCaseInsensitiveContains("year") })?.productID
                    ?? store.availablePackages.first?.productID
                    ?? "unforgetty_premium_yearly"
            }
        }
    }

    private var bottomPurchaseOverlay: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ForEach(displayedPackages) { package in
                    PaywallPackageCardView(package: package, isSelected: package.productID == selectedProductID) {
                        Haptics.selection()
                        selectedProductID = package.productID
                    }
                }
            }

            Button {
                purchaseSelected()
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continuar").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedProductID == nil || isPurchasing)

            Button("Restaurar compras") {
                Task { await store.restorePurchases() }
            }
            .buttonStyle(.plain)
            .font(.footnote)

            if let error = store.purchaseError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { overlayHeight = $0 }
    }

    /// Falls back to placeholder cards (no real price/trial text, still purchasable by product ID)
    /// if RevenueCat's offerings haven't loaded — e.g. no network on first paywall presentation.
    private var displayedPackages: [PremiumPackageInfo] {
        guard store.availablePackages.isEmpty else { return store.availablePackages }
        return [
            PremiumPackageInfo(productID: "unforgetty_premium_monthly", title: "Mensual", priceString: "—", periodLabel: "/mes", trialLabel: nil),
            PremiumPackageInfo(productID: "unforgetty_premium_yearly", title: "Anual", priceString: "—", periodLabel: "/año", trialLabel: nil)
        ]
    }

    private func purchaseSelected() {
        guard let selectedProductID else { return }
        Haptics.medium()
        isPurchasing = true
        Task {
            await store.purchase(productID: selectedProductID)
            isPurchasing = false
        }
    }
}

private struct PaywallPackageCardView: View {
    let package: PremiumPackageInfo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(package.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                (
                    Text(package.priceString).font(.title3.weight(.bold))
                    + Text(package.periodLabel).font(.footnote).foregroundStyle(.secondary)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .frame(minHeight: 84)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.indigo.opacity(0.16) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.indigo : Color.secondary.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if let trialLabel = package.trialLabel {
                Text(trialLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green, in: .capsule)
                    .offset(x: 6, y: -8)
            }
        }
    }
}
