import SwiftUI

/// Replaces the "+" Add button in the home toolbar's Friends-browsing mode — adding a new
/// activity doesn't make sense there, but managing friend requests does. Reuses
/// `SocialSettingsSection` (the same pending-requests + add-by-username UI already shown in
/// Settings > Social) rather than duplicating that logic in a second place.
struct FriendRequestsSheet: View {
    @StateObject private var social = SocialSettingsModel()
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                SocialSettingsSection(model: social)
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.light()
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
            .refreshable { await refresh() }
        }
        // A "Done" button was redundant here — swipe-to-dismiss (never disabled on this sheet)
        // already closes it.
        .presentationDetents([.medium, .large])
        .task { await refresh() }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await social.refresh()
    }
}
