import SwiftUI

/// The "frame" that simulates how `ActivityContentView` will look as a real Live Activity card.
struct ActivityPreviewView: View {
    let draft: LiveActivityDraft
    private let liveActivityMaxHeight: CGFloat = 300

    var body: some View {
        ActivityContentView(draft: draft)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: liveActivityMaxHeight, alignment: .topLeading)
            .clipped()
            .contentShape(.rect)
            .liquidGlassCard(tint: Color(hex: draft.style.backgroundHex), cornerRadius: 20)
    }
}
