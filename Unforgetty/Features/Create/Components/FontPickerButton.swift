import SwiftUI

struct FontPickerButton: View {
    @Binding var selection: ActivityStyle.FontChoice
    @State private var showingPopover = false

    var body: some View {
        Button { showingPopover = true } label: {
            HStack(spacing: 6) {
                Text(selection.title)
                Image(systemName: "chevron.down").font(.caption2)
            }
        }
        .contentShape(.rect)
        .popover(isPresented: $showingPopover) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(ActivityStyle.FontChoice.allCases) { choice in
                    Button {
                        selection = choice
                        showingPopover = false
                    } label: {
                        HStack {
                            Text(choice.title)
                            Spacer()
                            if choice == selection { Image(systemName: "checkmark") }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .frame(width: 180)
            .presentationCompactAdaptation(.popover)
        }
    }
}
