import SwiftUI

/// Replaces the "+" Add button in the home toolbar's Friends-browsing mode — adding a new
/// activity doesn't make sense there, but managing friend requests does. Reuses
/// `SocialSettingsSection` (the same pending-requests + add-by-username UI already shown in
/// Settings > Social) rather than duplicating that logic in a second place.
struct FriendRequestsSheet: View {
    @StateObject private var social = SocialSettingsModel()
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                SocialSettingsSection(model: social)
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
            }
            .refreshable { await social.refresh() }
        }
        .task { await social.refresh() }
        .preferredColorScheme(.dark)
    }
}
