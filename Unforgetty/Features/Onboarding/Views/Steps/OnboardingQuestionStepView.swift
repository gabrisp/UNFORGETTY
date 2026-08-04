import SwiftUI

/// Shared shape for both pain-point questions ("forgot something important" / "thought of
/// someone") — same single-select option-row UI, parameterized by copy and the bound answer, so
/// adding a third question later is just another call site, not another near-identical view.
struct OnboardingQuestionStepView: View {
    let question: String
    @Binding var answer: OnboardingAnswer?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(question)
                .font(.title.bold())
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(OnboardingAnswer.allCases) { option in
                    optionRow(option)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func optionRow(_ option: OnboardingAnswer) -> some View {
        let isSelected = answer == option
        return Button {
            Haptics.selection()
            answer = option
        } label: {
            HStack {
                Text(option.title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .liquidGlassCard(tint: isSelected ? Color.yellow.opacity(0.3) : Color.secondary.opacity(0.1), cornerRadius: 16, interactive: true)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
