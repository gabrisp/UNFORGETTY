import SwiftUI

/// Renders a friend's snapshot through the exact same card view as any local activity
/// (`ActivityPreviewView`) — bridges via `LiveActivityDraft(snapshot:)` and fetches the actual
/// image bytes (music album art or a `.image`-kind background) from their respective URLs on
/// first appearance, since a snapshot never carries raw bytes (too big for the APNs content-state
/// payload), unlike a local draft's `musicAlbumArtData`/`backgroundImageData`.
struct ReceivedActivityPreviewView: View {
    let snapshot: FriendActivitySnapshot
    @State private var albumArtData: Data?
    @State private var imageData: Data?

    private var draft: LiveActivityDraft {
        var draft = LiveActivityDraft(snapshot: snapshot)
        draft.musicAlbumArtData = albumArtData
        draft.style.backgroundImageData = imageData
        return draft
    }

    var body: some View {
        ActivityPreviewView(draft: draft)
            .task(id: snapshot.musicAlbumArtURL) {
                await loadAlbumArtIfNeeded()
            }
            .task(id: snapshot.imageURL) {
                await loadImageIfNeeded()
            }
    }

    private func loadAlbumArtIfNeeded() async {
        guard albumArtData == nil, snapshot.kind == "music" else { return }
        guard let urlString = snapshot.musicAlbumArtURL, let url = URL(string: urlString) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        albumArtData = data
    }

    private func loadImageIfNeeded() async {
        guard imageData == nil, snapshot.kind == "image" else { return }
        guard let urlString = snapshot.imageURL, let url = URL(string: urlString) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        // Same decode-memory reasoning as FriendImageSnapshotView's widget-side fetch — this
        // in-app preview isn't under the same tight budget, but re-running it costs nothing and
        // keeps both rendering paths honest against however large an upload turns out to be.
        imageData = ImagePreparation.preparedBackgroundImageData(from: data)
    }
}
