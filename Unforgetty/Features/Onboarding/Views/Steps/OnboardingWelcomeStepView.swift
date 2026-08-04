import SwiftUI

struct OnboardingWelcomeStepView: View {
    // The two things the app actually does — remembering for yourself, and letting someone else
    // know you're thinking of them — alternate as a pair (title+subtitle always change together,
    // one shared index) rather than independently, so they read as one coherent message each time.
    private static let messages: [(title: String, subtitle: String)] = [
        ("Never forget what matters", "Keep the things you can't afford to forget on your Lock Screen."),
        ("Let them know you remember", "Show someone you're thinking of them.")
    ]

    @State private var messageIndex = 0

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Pinned to the bottom of whatever space this step is given (between the shared
                // header and the shared footer button) rather than sitting centered — the leading
                // Spacer expands to consume all the slack, so the content itself sinks to the floor.
                PaywallMarqueeShowcase(rowCount: 3)
                    .padding(.horizontal, -32)
                    .frame(maxWidth: .infinity)
                    
                
                VStack(spacing: 12) {
                    Text(Self.messages[messageIndex].title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                    Text(Self.messages[messageIndex].subtitle)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.easeInOut(duration: 0.6)) {
                    messageIndex = (messageIndex + 1) % Self.messages.count
                }
            }
        }
    }
}
