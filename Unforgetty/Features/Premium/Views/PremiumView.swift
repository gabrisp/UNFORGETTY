import SwiftUI

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ActivityStore
    @State private var selectedProductID: String?
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            // A genuine sibling layout, not an overlapping one — the footer used to be layered on
            // top of the scroll content via ZStack(alignment: .bottom), which needed a manually
            // measured Color.clear spacer at the bottom of the scroll content just to keep the
            // footer from covering it. Any mismatch between that guessed/measured height and the
            // real content let the scroll content visibly run into/behind the footer. A plain
            // VStack sidesteps the whole problem: the footer takes exactly the space it needs, and
            // the ScrollView gets whatever's left above it — no overlap possible, no spacer needed.
            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    VStack(spacing: 20) {
                        PaywallMarqueeShowcase()
                            .padding(.horizontal, -16)
                            .padding(.top, 4)
                            // The marquee's cards size to their own content (see PaywallShowcase's
                            // MarqueeRow), so its true ideal width is 3 full sets of cards side by
                            // side — hundreds of points wider than the screen, by design, since
                            // that's what the infinite-scroll loop needs. `.frame(maxWidth: .infinity)`
                            // further up this VStack does not cap that demand back down (it only
                            // allows growth, it never shrinks), so this needs its own explicit clip
                            // right at the source to stop it from inflating every ancestor's
                            // reported width all the way up.
                            .clipped()

                        Image(systemName: store.isPremium ? "checkmark.seal.fill" : "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(.indigo)
                        Text(store.isPremium ? "Premium activo" : "Unforgetty Premium").font(.title.bold())
                        Text("Actividades y programaciones ilimitadas.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }
                    .padding()
                }

                if !store.isPremium {
                    bottomPurchaseOverlay
                }
            }
            .frame(maxWidth: .infinity)
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
