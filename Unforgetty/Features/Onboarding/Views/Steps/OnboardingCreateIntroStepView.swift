import SwiftUI

struct OnboardingCreateIntroStepView: View {
    var body: some View {
        OnboardingStepLayout(
            title: "Now let's create your first Live Activity",
            subtitle: "A note, a photo, a song, a checklist — whatever you don't want to forget. It'll live right on your Lock Screen, ready whenever you glance at it.",
            textAtTop: false
        ) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
                .padding(.bottom, 8)
        }
    }
}
