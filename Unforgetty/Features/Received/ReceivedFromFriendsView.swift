import SwiftUI
import ActivityKit

/// Browses pings received from friends — same card look and same "tap centers the card in place,
/// no sheet" animation as the main tab's own-activity list (`CreateActivityV2View`), but content
/// here is never editable in place: the toolbar instead offers reload/copy/re-edit/delete.
struct ReceivedFromFriendsView: View {
    @EnvironmentObject private var store: ActivityStore
    @EnvironmentObject private var flow: AppFlowViewModel
    @State private var receivedPings: [ReceivedFriendPing] = []
    @State private var selectedPing: ReceivedFriendPing?
    @State private var cardHeights: [String: CGFloat] = [:]
    @State private var containerSize: CGSize = .zero

    private let animation: Animation = .interactiveSpring(response: 0.55, dampingFraction: 0.8)

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    ForEach(receivedPings) { ping in
                        pingCardView(ping)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .scrollDisabled(selectedPing != nil)
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar { toolbarContent }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
            .background(Color.secondarybg.ignoresSafeArea())
        }
        .onAppear(perform: load)
    }

    private var navigationTitle: String {
        if let selectedPing { return "@\(selectedPing.fromUsername)" }
        return "From Friends"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let selectedPing {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.light()
                    withAnimation(animation) { self.selectedPing = nil }
                } label: {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    reload(selectedPing)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Reload")

                Menu {
                    Button {
                        copy(selectedPing)
                    } label: {
                        Label("Copiar", systemImage: "doc.on.doc")
                    }
                    Button {
                        reedit(selectedPing)
                    } label: {
                        Label("Reeditar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        delete(selectedPing)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

    @ViewBuilder
    private func pingCardView(_ ping: ReceivedFriendPing) -> some View {
        let isCurrent = ping.id == selectedPing?.id
        let isSomethingSelected = selectedPing != nil

        VStack(alignment: .leading, spacing: 10) {
            if isCurrent {
                Text("From @\(ping.fromUsername)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ReceivedActivityPreviewView(snapshot: ping.snapshot)
                .overlay(alignment: .topTrailing) {
                    if !isSomethingSelected {
                        Text("Received from @\(ping.fromUsername) on \(Self.dateFormatter.string(from: ping.receivedAt))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.trailing)
                            .padding(.top, 10)
                            .padding(.trailing, 12)
                            .padding(.leading, 40)
                    }
                }

            if isCurrent, let message = ping.message, !message.isEmpty {
                Text("Message: \(message)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeights[ping.id] = $0 }
        .contentShape(.rect)
        .onTapGesture {
            guard selectedPing == nil else { return }
            Haptics.light()
            withAnimation(animation) { selectedPing = ping }
        }
        .visualEffect { [containerSize, isSomethingSelected] content, proxy in
            let rect = proxy.frame(in: .scrollView)
            let centeredOffset = -rect.minY
            let hiddenOffset = containerSize.height - rect.minY
            let pushOffset = isCurrent ? centeredOffset : hiddenOffset

            return content
                .scaleEffect(isSomethingSelected && !isCurrent ? 0.95 : 1, anchor: .top)
                .offset(y: isSomethingSelected ? pushOffset : 0)
                .opacity(isSomethingSelected && !isCurrent ? 0 : 1)
        }
        .allowsHitTesting(isSomethingSelected ? isCurrent : true)
        .disabled(isSomethingSelected && !isCurrent)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private func load() {
        receivedPings = WidgetContentStore.receivedFriendPings()
        if let selectedPing {
            self.selectedPing = receivedPings.first { $0.notificationID == selectedPing.notificationID }
        }
    }

    /// Re-syncs this ping's stored copy from whatever the actually-running Live Activity currently
    /// shows — `saveReceivedFriendPing` only ever writes once (idempotent against the widget's
    /// repeated `.onAppear`), so a later `.update` push's changed content never lands here on its
    /// own until this is called.
    private func reload(_ ping: ReceivedFriendPing) {
        Haptics.light()
        if
            let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.attributes.notificationID == ping.notificationID }),
            let fromUsername = activity.content.state.fromUsername,
            let snapshot = activity.content.state.friendSnapshot
        {
            WidgetContentStore.updateReceivedFriendPing(notificationID: ping.notificationID, fromUsername: fromUsername, message: activity.content.state.message, snapshot: snapshot)
        }
        load()
    }

    private func copy(_ ping: ReceivedFriendPing) {
        Haptics.light()
        store.copiedEditions = ActivityEditionsClipboard(snapshot: ping.snapshot)
    }

    private func reedit(_ ping: ReceivedFriendPing) {
        Haptics.light()
        let activity = ScheduledActivity(draft: LiveActivityDraft(snapshot: ping.snapshot), surface: .liveActivity, startDate: .now, status: .draft)
        store.save(activity)
        withAnimation(animation) {
            selectedPing = nil
        }
        flow.openActivityForEditing(activity.id)
    }

    private func delete(_ ping: ReceivedFriendPing) {
        Haptics.light()
        WidgetContentStore.deleteReceivedFriendPing(notificationID: ping.notificationID)
        cardHeights.removeValue(forKey: ping.notificationID)
        withAnimation(animation) {
            selectedPing = nil
        }
        load()
    }
}
