import SwiftUI

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ActivityStore
    @State private var selectedProductID: String?
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            // `.frame(maxWidth: .infinity)`/`.clipped()` further down were still letting the
            // marquee's true (much wider than the screen) ideal width leak into how wide the
            // ancestor VStack itself gets laid out — `maxWidth: .infinity` is an ALLOWANCE, not a
            // cap, so any child free to report a bigger ideal size can still inflate it, and
            // `.clipped()` only stops that view's own rendering from bleeding, not its reported
            // size from propagating. `GeometryReader` sidesteps the ambiguity entirely: read the
            // real, measured screen width once, then hard-lock every layer of this screen to
            // exactly that value with `.frame(width:)` — a fixed width, unlike `maxWidth`, cannot
            // be exceeded by anything inside it no matter what that content demands.
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ScrollView(.vertical) {
                        VStack(spacing: 20) {
                            PaywallMarqueeShowcase()
                                .padding(.horizontal, -16)
                                .padding(.top, 4)
                                .frame(width: proxy.size.width)
                                .clipped()

                            Image(systemName: store.isPremium ? "checkmark.seal.fill" : "sparkles")
                                .font(.largeTitle)
                                .foregroundStyle(.indigo)
                            Text(store.isPremium ? "Premium activo" : "Unforgetty Premium").font(.title.bold())
                            Text("Actividades y programaciones ilimitadas.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(width: proxy.size.width)
                    }
                    .frame(width: proxy.size.width)

                    if !store.isPremium {
                        bottomPurchaseOverlay
                            .frame(width: proxy.size.width)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
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
            .frame(maxWidth: .infinity)

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
            .tint(.yellow)
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
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
                    .lineLimit(1)
                (
                    Text(package.priceString).font(.title3.weight(.bold))
                    + Text(package.periodLabel).font(.footnote).foregroundStyle(.secondary)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .frame(minHeight: 84)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.yellow.opacity(0.18) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.yellow : Color.secondary.opacity(0.18), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        // Without an explicit maxWidth here, an un-truncatable child (the price text, before the
        // lineLimit/minimumScaleFactor above) could force this whole card — and with it the
        // footer's HStack — wider than the screen instead of sharing space with its sibling card.
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if let trialLabel = package.trialLabel {
                Text(trialLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green, in: .capsule)
                    // Inset instead of poking outside the card's own bounds — an offset badge on
                    // the rightmost card in the row could push past the footer's own edge.
                    .padding(6)
            }
        }
    }
}
