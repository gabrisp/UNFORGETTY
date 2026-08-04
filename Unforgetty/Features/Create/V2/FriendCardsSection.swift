import SwiftUI

/// Friend-ping browsing, extracted out of CreateActivityV2View so its own selection/reload/copy/
/// delete interactions only invalidate this smaller view instead of the entire ~1000-line parent
/// (own-card grid, toolbar, sheet content, etc.) on every friend-card tap. Still contributes its
/// card content directly into the parent's existing ScrollView/LazyVStack (no ScrollView of its
/// own) and its own `.toolbar` merges into the same NavigationStack — the screen itself doesn't
/// change, only which cards populate it, per the original design constraint for this feature.
/// `isSelected` is the one piece of state that has to flow back up: the parent's ScrollView/
/// background/title all need to know "is anything centered" regardless of which grid is showing,
/// but that's a single Bool write per actual select/deselect, not a whole object.
struct FriendCardsSection: View {
    @EnvironmentObject private var store: ActivityStore
    let containerSize: CGSize
    let animation: Animation
    @Binding var isSelected: Bool
    let onReedit: (ScheduledActivity) -> Void

    @StateObject private var viewModel = FriendCardsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ForEach(viewModel.receivedPings) { ping in
            receivedPingCardView(ping)
        }
        .task {
            viewModel.load()
        }
        // `.task` only fires once per mount (i.e. once per switch to Friends browsing) — a ping
        // that arrives while this section is already visible (app foregrounded on this tab, or
        // just sitting here when the push comes in) wouldn't otherwise show up until the user
        // switched away and back. Re-load whenever the app becomes active while mounted instead.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            viewModel.load()
        }
        .onChange(of: viewModel.selectedFriendPing?.notificationID) { _, newValue in
            isSelected = newValue != nil
        }
        .toolbar {
            if let selectedFriendPing = viewModel.selectedFriendPing {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.light()
                        withAnimation(animation) {
                            viewModel.close()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("@\(selectedFriendPing.fromUsername)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    ToolbarIconButton(systemImage: "arrow.clockwise") {
                        Haptics.light()
                        viewModel.reload(selectedFriendPing)
                    }
                    .frame(width: 32, height: 32)
                    .accessibilityLabel("Reload")

                    ToolbarIconMenu(systemImage: "ellipsis", items: [
                        ToolbarMenuItem(title: "Copiar", systemImage: "doc.on.doc") {
                            Haptics.light()
                            viewModel.copy(selectedFriendPing, store: store)
                        },
                        ToolbarMenuItem(title: "Reeditar", systemImage: "pencil") {
                            Haptics.light()
                            let activity = viewModel.reedit(selectedFriendPing, store: store)
                            onReedit(activity)
                        },
                        ToolbarMenuItem(title: "Eliminar", systemImage: "trash", isDestructive: true) {
                            Haptics.light()
                            withAnimation(animation) {
                                viewModel.delete(selectedFriendPing)
                            }
                        }
                    ])
                    .frame(width: 32, height: 32)
                }
            }
        }
    }

    @ViewBuilder
    private func receivedPingCardView(_ ping: ReceivedFriendPing) -> some View {
        let isCurrent = ping.notificationID == viewModel.selectedFriendPing?.notificationID

        CardAnimationSlot(
            isCurrent: isCurrent,
            isAnySelected: isSelected,
            containerSize: containerSize,
            animation: animation,
            onSelect: { height in
                viewModel.select(ping, height: height)
            },
            onCurrentHeightChange: { height in viewModel.updateCurrentHeight(height) }
        ) {
            friendCardContent(ping: ping, isCurrent: isCurrent)
        }
        .contextMenu {
            if viewModel.selectedFriendPing == nil {
                Button(role: .destructive) {
                    Haptics.light()
                    viewModel.delete(ping)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func friendCardContent(ping: ReceivedFriendPing, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if isCurrent {
                Text("From @\(ping.fromUsername)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ReceivedActivityPreviewView(snapshot: ping.snapshot)
                .overlay(alignment: .topTrailing) {
                    if !isCurrent {
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
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
}
