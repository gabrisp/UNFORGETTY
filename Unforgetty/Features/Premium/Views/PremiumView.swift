import SwiftUI

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ActivityStore

    var body: some View {
        NavigationStack {
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
                    if !store.isPremium {
                        Button("Mensual · unforgetty_premium_monthly") { Task { await store.purchase(productID: "unforgetty_premium_monthly") } }.buttonStyle(.borderedProminent)
                        Button("Anual · unforgetty_premium_yearly") { Task { await store.purchase(productID: "unforgetty_premium_yearly") } }.buttonStyle(.bordered)
                    }
                    Button("Restaurar compras") { Task { await store.restorePurchases() } }.buttonStyle(.plain)
                    if let error = store.purchaseError {
                        Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                    }
                }
                .padding()
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
    }
}
