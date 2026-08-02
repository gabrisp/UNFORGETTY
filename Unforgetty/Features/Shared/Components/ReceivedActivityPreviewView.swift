import SwiftUI

/// Renders a friend's snapshot through the exact same card view as any local activity
/// (`ActivityPreviewView`) — bridges via `LiveActivityDraft(snapshot:)` and fetches album art from
/// `musicAlbumArtURL` on first appearance, since a snapshot never carries the raw bytes (too big
/// for the APNs content-state payload), unlike a local draft's `musicAlbumArtData`.
struct ReceivedActivityPreviewView: View {
    let snapshot: FriendActivitySnapshot
    @State private var albumArtData: Data?

    private var draft: LiveActivityDraft {
        var draft = LiveActivityDraft(snapshot: snapshot)
        draft.musicAlbumArtData = albumArtData
        return draft
    }

    var body: some View {
        ActivityPreviewView(draft: draft)
            .task(id: snapshot.musicAlbumArtURL) {
                await loadAlbumArtIfNeeded()
            }
    }

    private func loadAlbumArtIfNeeded() async {
        guard albumArtData == nil, snapshot.kind == "music" else { return }
        guard let urlString = snapshot.musicAlbumArtURL, let url = URL(string: urlString) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        albumArtData = data
    }
}
