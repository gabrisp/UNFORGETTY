import SwiftUI

struct WeekdaySelectorView: View {
    let selection: Set<Weekday>
    let onToggle: (Weekday) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let isSelected = selection.contains(day)
                Button { onToggle(day) } label: {
                    Text(day.shortLabel)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15), in: .circle)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
