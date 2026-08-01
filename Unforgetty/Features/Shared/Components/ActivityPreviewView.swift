import SwiftUI

/// The "frame" that simulates how `ActivityContentView` will look as a real Live Activity card.
struct ActivityPreviewView: View {
    let draft: LiveActivityDraft
    private let liveActivityMaxHeight: CGFloat = 160

    var body: some View {
        ActivityContentView(draft: draft, allowsTapBlur: false)
            .padding(contentPadding)
            .frame(maxWidth: .infinity, maxHeight: liveActivityMaxHeight, alignment: draft.style.contentAlignment)
            .clipped()
            .contentShape(.rect)
            .activityCardBackground(style: draft.style, kind: draft.kind, cornerRadius: 20)
    }

    private var contentPadding: CGFloat {
        switch draft.kind {
        case .check(.buttons): 12
        case .image: draft.style.imageInset
        case .music: 24
        default: 24
        }
    }
}
