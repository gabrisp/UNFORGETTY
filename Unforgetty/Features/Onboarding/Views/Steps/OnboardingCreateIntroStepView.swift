import SwiftUI

struct OnboardingCreateIntroStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            Text("Now let's create your first Live Activity")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("A note, a photo, a song, a checklist — whatever you don't want to forget. It'll live right on your Lock Screen, ready whenever you glance at it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }
}
