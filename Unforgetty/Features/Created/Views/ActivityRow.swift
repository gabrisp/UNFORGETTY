import SwiftUI

struct ActivityRow: View {
    let activity: ScheduledActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(activity.status.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if activity.status == .scheduled {
                    Text(activity.startDate, style: .date)
                    Text(activity.startDate, style: .time)
                }
            }
            .font(.caption)
            ActivityPreviewView(draft: activity.draft)
            if !activity.draft.tags.isEmpty {
                Text(activity.draft.tags.map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}
