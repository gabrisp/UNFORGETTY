import SwiftUI

struct CreatedActivitiesView: View {
    @EnvironmentObject private var store: ActivityStore
    @StateObject private var viewModel = CreatedActivitiesViewModel()
    @Binding var progress: CGFloat

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 20) {
                ForEach(viewModel.visibleActivities(from: store.activities)) { activity in
                    ActivityRow(activity: activity)
                        .contextMenu {
                            if !activity.draft.isStrict {
                                Button(role: .destructive) { store.delete(activity) } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .adoptForIGTabBar($progress)
    }
}
