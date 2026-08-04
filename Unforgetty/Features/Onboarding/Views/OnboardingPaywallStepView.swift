import StoreKit
import SwiftUI

/// A dedicated, English-only paywall for onboarding — deliberately NOT `PremiumView` (which is
/// Spanish, matching the rest of the app's UI, and reused elsewhere via `flow.isShowingPaywall`).
/// Onboarding is English end-to-end per explicit instruction, so this mirrors PremiumView's
/// purchase mechanics (same `ActivityStore.loadOfferings()`/`purchase(productID:)` calls) with its
/// own English copy, and finishes onboarding on skip or on a successful purchase rather than
/// calling `dismiss()` — this view is never sheet-presented, it's inline onboarding content.
struct OnboardingPaywallStepView: View {
    @EnvironmentObject private var store: ActivityStore
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var presentedSheet: OnboardingPaywallSheet?

    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internetservices/itunes/dev/stdeula/")!
    // PLACEHOLDER — same caveat as PremiumView.privacyPolicyURL: must be replaced with a real
    // hosted privacy policy before release.
    private static let privacyPolicyURL = URL(string: "https://example.com")!

    private var isShowingOfferCodeRedemption: Binding<Bool> {
        Binding(
            get: { presentedSheet == .redeemCode },
            set: { presentedSheet = $0 ? .redeemCode : nil }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    PaywallMarqueeShowcase()
                        .padding(.horizontal, -16)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    VStack(spacing: 8) {
                        Text("Unlock everything")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text("Start your free trial to send unlimited pings, schedule ahead, and save everything you create.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }

            bottomPurchaseOverlay
        }
        .task {
            await store.loadOfferings()
            if selectedProductID == nil {
                selectedProductID = store.availablePackages.first(where: { $0.productID.localizedCaseInsensitiveContains("year") })?.productID
                    ?? store.availablePackages.first?.productID
                    ?? "unforgetty_premium_yearly"
            }
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { viewModel.finishOnboarding() }
        }
    }

    private var bottomPurchaseOverlay: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ForEach(displayedPackages) { package in
                    OnboardingPaywallPackageCardView(package: package, isSelected: package.productID == selectedProductID) {
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
                        Text("Start Free Trial").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.yellow)
            .disabled(selectedProductID == nil || isPurchasing)

            HStack(spacing: 16) {
                Button("Restore") {
                    Task { await store.restorePurchases() }
                }
                Button("Redeem Code") {
                    presentedSheet = .redeemCode
                }
                Link("Terms", destination: Self.termsOfUseURL)
                Link("Privacy", destination: Self.privacyPolicyURL)
            }
            .buttonStyle(.plain)
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let error = store.purchaseError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Not now") {
                viewModel.finishOnboarding()
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
        .offerCodeRedemption(isPresented: isShowingOfferCodeRedemption)
    }

    private var displayedPackages: [PremiumPackageInfo] {
        guard store.availablePackages.isEmpty else { return store.availablePackages }
        return [
            PremiumPackageInfo(productID: "unforgetty_premium_monthly", title: "Monthly", priceString: "—", periodLabel: "/mo", trialLabel: nil),
            PremiumPackageInfo(productID: "unforgetty_premium_yearly", title: "Yearly", priceString: "—", periodLabel: "/yr", trialLabel: nil)
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

private enum OnboardingPaywallSheet: Identifiable {
    case redeemCode
    var id: Self { self }
}

private struct OnboardingPaywallPackageCardView: View {
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
                    .padding(6)
            }
        }
    }
}
