import SwiftUI

struct AppLaunchView: View {
    @EnvironmentObject private var flow: AppFlowViewModel

    var body: some View {
        switch flow.destination {
        case .splash:
            SplashView()
        case .onboarding:
            OnboardingView()
        case .root:
            ContentView()
        }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(.indigo)
            Text("Unforgetty").font(.title.bold())
            ProgressView().accessibilityLabel("Cargando")
        }
    }
}
