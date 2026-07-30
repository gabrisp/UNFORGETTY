import SwiftUI

struct OnboardingStep1View: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge.fill").font(.system(size: 56)).foregroundStyle(.indigo)
            Text("No olvides lo importante").font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text("Crea notas y listas privadas que te acompañan en la pantalla bloqueada.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
            Button("Continuar") { viewModel.finishOnboarding() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }
}
