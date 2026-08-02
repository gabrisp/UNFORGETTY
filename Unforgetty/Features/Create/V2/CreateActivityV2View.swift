import SwiftUI
import ActivityKit
#if canImport(UIKit)
import UIKit
#endif

private enum CardSource { case own, friends }

struct CreateActivityV2View: View {
    @Binding var progress: CGFloat
    @EnvironmentObject private var store: ActivityStore
    @EnvironmentObject private var flow: AppFlowViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var editViewModel = CreateActivityV2EditViewModel()
    @State private var selectedActivity: ScheduledActivity?
    @State private var presentedSheetActivity: ScheduledActivity?
    @State private var isKeyboardVisible = false
    // Only the currently-selected card's height is ever needed (for the edit sheet's
    // presentationDetents) — a single scalar set once at selection time, not a dictionary written
    // continuously by every card's geometry reads. See CardAnimationSlot.
    @State private var selectedCardHeight: CGFloat = 160
    @State private var info = Info()
    @State private var editedLiveAction: LiveActionSelection?
    @State private var isPickingFriends = false
    @State private var isPickingSong = false
    @State private var undoStack: [ScheduledActivity] = []
    @State private var redoStack: [ScheduledActivity] = []
    @State private var isApplyingHistory = false
    @State private var isShowingSettings = false
    @State private var successMessage: String?
    // Friend pings are browsed in this SAME screen/NavigationStack — only the grid's data source
    // switches, via the toolbar's Stack/Friend menu — rather than navigating to a separate screen,
    // so the card-open animation (built around this view's own `info`/height-tracking state) never
    // has to be reproduced or reconciled across two different view hierarchies.
    @State private var cardSource: CardSource = .own
    @State private var receivedPings: [ReceivedFriendPing] = []
    @State private var selectedFriendPing: ReceivedFriendPing?
    @State private var selectedFriendCardHeight: CGFloat = 160

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    if cardSource == .own {
                        ForEach(store.liveActivityCards) { activity in
                            SavedLiveActivityCardView(activity: activity)
                        }
                    } else {
                        ForEach(receivedPings) { ping in
                            ReceivedPingCardView(ping: ping)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(15)
            .scrollDisabled(isActivitySelected || isFriendPingSelected)
            .navigationTitle(isNavigationTitleHidden ? "" : "Unforgetty")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if showsEditingToolbarButtons {
                        undoToolbarButton
                        redoToolbarButton
                    }

                    if isFriendPingSelected {
                        Button {
                            Haptics.light()
                            closeSelectedFriendPing()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }

//                    if isActivitySelected && editedLiveAction == nil {
//                        Button("Close", systemImage: "xmark") {
//                            dismissKeyboard()
//                            closeSelectedActivity()
//                        }
//                    }
                }

                ToolbarItem(placement: .principal) {
                    if isActivitySelected {
                        // Placeholder disabled for now along with the "Activity #N" auto-fill — see normalizeActivityTitle().
                        TextField("", text: activityTitleBinding)
                            .font(.headline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .frame(width: 180)
                            .submitLabel(.done)
                            .onSubmit {
                                normalizeActivityTitle()
                            }
                            .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                            .opacity(isEditingSubsheet ? 0 : 1)
                            .disabled(isEditingSubsheet)
                    } else if let selectedFriendPing {
                        Text("@\(selectedFriendPing.fromUsername)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if showsEditingToolbarButtons {
                        addContentButton
                    }
                }

                if showsEditingToolbarButtons {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isKeyboardVisible {
                        Button {
                            Haptics.light()
                            dismissKeyboard()
                        } label: {
                            Image(systemName: "chevron.compact.down.fill")
                        }
                    } else if showsEditingToolbarButtons {
                        activityKindMenu
                    } else if isFriendPingSelected {
                        ToolbarIconButton(systemImage: "arrow.clockwise") {
                            reloadSelectedFriendPing()
                        }
                        .frame(width: 32, height: 32)
                        .accessibilityLabel("Reload")

                        ToolbarIconMenu(systemImage: "ellipsis", items: [
                            ToolbarMenuItem(title: "Copiar", systemImage: "doc.on.doc") { copySelectedFriendPing() },
                            ToolbarMenuItem(title: "Reeditar", systemImage: "pencil") { reeditSelectedFriendPing() },
                            ToolbarMenuItem(title: "Eliminar", systemImage: "trash", isDestructive: true) { deleteSelectedFriendPing() }
                        ])
                        .frame(width: 32, height: 32)
                    } else if !isActivitySelected {
                        cardSourceMenu

                        Button("Add", systemImage: "plus") {
                            Haptics.light()
                            withAnimation(animation) {
                                select(store.createLiveActivityDraft())
                            }
                        }
                        .disabled(cardSource != .own)

                        Button("Upgrade", systemImage: "crown.fill") {
                            Haptics.medium()
                            flow.showPaywall()
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .tint(.yellow)

                        Button("Settings", systemImage: "gearshape") {
                            Haptics.light()
                            isShowingSettings = true
                        }
                    }

//                    if isActivitySelected {
//                        if editedLiveAction == nil {
//                            Button {
//                                sendSelectedActivity()
//                            } label: {
//                                Image(systemName: "arrow.up")
//                            }
//                            .buttonStyle(.glassProminent)
//                            .tint(.yellow)
//                            .disabled(isSendDisabled)
//                        }
//                    } else {
//                        Button("Add", systemImage: "plus") {
//                            withAnimation(animation) {
//                                select(store.createLiveActivityDraft())
//                            }
//                        }
//
//                        Button("Upgrade", systemImage: "crown.fill") {
//                            isShowingPremium = true
//                        }
//                        .labelStyle(.titleAndIcon)
//                        .buttonStyle(.glassProminent)
//                        .controlSize(.large)
//                        .tint(.yellow)
//                    }
                }
            }
            // `onScrollGeometryChange`'s `action` only fires when the *transformed* value changes —
            // transforming straight to the boolean this is actually used for (instead of the raw
            // offset) means it fires once per threshold crossing instead of on every scroll frame,
            // which otherwise reassigned the whole `info` struct — and therefore invalidated this
            // entire view — continuously while scrolling.
            .onScrollGeometryChange(for: Bool.self) {
                ($0.contentOffset.y + $0.contentInsets.top) > 1
            } action: { _, newValue in
                info.isScrolledPastTop = newValue
            }
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).minY
            } action: { newValue in
                info.minY = newValue - info.safeArea.top
            }
            .background {
                screenBackground
            }
            .task {
                store.ensureInitialLiveActivityDraft()
            }
        }
        .statusBarHidden(true)
        .overlay(alignment: .top) {
            if showsEditingToolbarButtons {
                CutoutAccessoryView(
                    padding: .auto,
                    leadingContent: {
                        cutoutCancelButton
                    },
                    trailingContent: {
                        cutoutSendButton
                    }
                )
                .frame(height: max(84, info.safeArea.top + 36), alignment: .top)
            }
        }
        // Fills the same lower region the edit sheet occupies (same height math as its
        // presentationDetents below) so the success confirmation reads as "the sheet became this",
        // not as a banner popping in somewhere unrelated.
        .overlay(alignment: .bottom) {
            if let successMessage {
                successBottomBanner(successMessage)
                    .frame(maxWidth: .infinity)
                    .frame(height: successZoneHeight, alignment: .center)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(item: $presentedSheetActivity) { activity in
            let spacing: CGFloat = 20
            let isSafeAreaiPhone = info.safeArea.bottom > 0
            let minSheetHeight = info.containerSize.height - info.minY - (selectedActivityHeight + spacing)
            let maxSheetHeight = info.containerSize.height - info.minY + (isSafeAreaiPhone ? 15 : 10)

            Group {
                if let editedLiveAction {
                    LiveActionItemEditSheet(viewModel: editViewModel, actionID: editedLiveAction.id) {
                        withAnimation(.snappy) {
                            self.editedLiveAction = nil
                        }
                    }
                    .environmentObject(store)
                    .transition(.blurReplace.combined(with: .opacity))
                } else if isPickingFriends {
                    FriendPickerSheet(viewModel: editViewModel) {
                        withAnimation(.snappy) {
                            isPickingFriends = false
                        }
                    }
                    .transition(.blurReplace.combined(with: .opacity))
                } else if isPickingSong {
                    MusicPickerSheet(viewModel: editViewModel) {
                        withAnimation(.snappy) {
                            isPickingSong = false
                        }
                    }
                    .environmentObject(store)
                    .transition(.blurReplace.combined(with: .opacity))
                } else {
                    CreateActivityV2EditSheet(viewModel: editViewModel, copiedEditions: $store.copiedEditions)
                        .transition(.blurReplace.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: editedLiveAction?.id)
            .animation(.snappy, value: isPickingFriends)
            .animation(.snappy, value: isPickingSong)
            .presentationDetents([.height(minSheetHeight), .height(maxSheetHeight)])
            .presentationBackgroundInteraction(.enabled(upThrough: .height(maxSheetHeight)))
            .interactiveDismissDisabled()
            .presentationBackground(.clear)
        }
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: { newValue in
            info.containerSize = newValue
        }
        .onGeometryChange(for: EdgeInsets.self) {
            $0.safeAreaInsets
        } action: { newValue in
            info.safeArea = newValue
        }
        .onChange(of: editViewModel.activity) { oldValue, newValue in
            guard selectedActivityID == newValue.id else { return }
            if isApplyingHistory {
                selectedActivity = newValue
                if presentedSheetActivity != nil {
                    presentedSheetActivity = newValue
                }
                editViewModel.saveDraft(store: store)
                isApplyingHistory = false
                return
            }

            if oldValue.id == newValue.id, oldValue != newValue {
                undoStack.append(oldValue)
                redoStack.removeAll()
            }
            selectedActivity = newValue
            if presentedSheetActivity != nil && editedLiveAction == nil {
                presentedSheetActivity = newValue
            }
            editViewModel.saveDraft(store: store)
        }
        .trackKeyboardVisibility(
            isKeyboardVisible: $isKeyboardVisible,
            presentedSheetActivity: $presentedSheetActivity,
            selectedActivity: $selectedActivity
        )
        // "Reeditar" on a received friend ping (a separate tab) saves the new draft into `store`
        // then flags it here rather than reaching into this view's local state directly — the two
        // tabs share no view hierarchy, only `store`/`flow`.
        .onChange(of: flow.pendingSelectedActivityID) { _, newValue in
            guard let newValue, let activity = store.liveActivityCards.first(where: { $0.id == newValue }) else { return }
            withAnimation(animation) {
                select(activity)
            }
            flow.pendingSelectedActivityID = nil
        }
    }

    @ViewBuilder
    private func SavedLiveActivityCardView(activity: ScheduledActivity) -> some View {
        let isCurrent = activity.id == selectedActivityID

        CardAnimationSlot(
            isCurrent: isCurrent,
            isAnySelected: isActivitySelected,
            containerSize: info.containerSize,
            animation: animation,
            onSelect: { height in select(activity, height: height) },
            onCurrentHeightChange: { height in selectedCardHeight = height }
        ) {
            cardContent(activity: activity, isCurrent: isCurrent)
        }
        .contextMenu {
            if !isActivitySelected {
                Button(role: .destructive) {
                    deleteActivity(activity)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(!canDelete(activity))
            }
        }
    }

    @ViewBuilder
    private func cardContent(activity: ScheduledActivity, isCurrent: Bool) -> some View {
        if isCurrent {
            SelectedActivityPreview(
                viewModel: editViewModel,
                selectedLiveActionID: editedLiveAction?.id,
                onEditLiveAction: presentLiveActionEditor,
                onPickSong: {
                    Haptics.light()
                    isPickingSong = true
                },
                isPickingSong: isPickingSong,
                isLiveActivity: isSelectedActivityLive,
                onEndLiveActivity: endSelectedLiveActivity,
                showsStatusPill: !isEditingSubsheet
            )
        } else {
            ActivityPreviewView(draft: activity.draft)
        }
    }

    private func select(_ activity: ScheduledActivity, height: CGFloat = 160) {
        undoStack.removeAll()
        redoStack.removeAll()
        editViewModel.load(activity)
        normalizeActivityTitle()
        selectedActivity = editViewModel.activity
        selectedCardHeight = height
        if !isKeyboardVisible {
            presentedSheetActivity = editViewModel.activity
        }
    }

    private func closeSelectedActivity() {
        dismissKeyboard()
        normalizeActivityTitle()
        store.discardEmptyLiveActivityDraft(editViewModel.activity)
        undoStack.removeAll()
        redoStack.removeAll()
        withAnimation(animation) {
            selectedActivity = nil
            presentedSheetActivity = nil
        }
    }

    private var showsEditingToolbarButtons: Bool {
        isActivitySelected && editedLiveAction == nil && !isPickingFriends && !isPickingSong && !isKeyboardVisible && successMessage == nil
    }

    @ViewBuilder
    private func ReceivedPingCardView(ping: ReceivedFriendPing) -> some View {
        let isCurrent = ping.notificationID == selectedFriendPing?.notificationID

        CardAnimationSlot(
            isCurrent: isCurrent,
            isAnySelected: isFriendPingSelected,
            containerSize: info.containerSize,
            animation: animation,
            onSelect: { height in
                selectedFriendPing = ping
                selectedFriendCardHeight = height
            },
            onCurrentHeightChange: { height in selectedFriendCardHeight = height }
        ) {
            friendCardContent(ping: ping, isCurrent: isCurrent)
        }
        .contextMenu {
            if !isFriendPingSelected {
                Button(role: .destructive) {
                    deleteFriendPing(ping)
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
                        Text("Received from @\(ping.fromUsername) on \(Self.friendDateFormatter.string(from: ping.receivedAt))")
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

    private static let friendDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private func switchCardSource(_ source: CardSource) {
        guard cardSource != source else { return }
        withAnimation(animation) {
            cardSource = source
        }
        if source == .friends {
            loadReceivedPings()
        }
    }

    private func loadReceivedPings() {
        receivedPings = WidgetContentStore.receivedFriendPings()
        if let selectedFriendPing {
            self.selectedFriendPing = receivedPings.first { $0.notificationID == selectedFriendPing.notificationID }
        }
    }

    private func closeSelectedFriendPing() {
        withAnimation(animation) {
            selectedFriendPing = nil
        }
    }

    /// `saveReceivedFriendPing` only ever writes once (idempotent against the widget's repeated
    /// `.onAppear`), so a later `.update` push's changed content never lands here on its own —
    /// this pulls the latest state from whatever Live Activity is actually still running.
    private func reloadSelectedFriendPing() {
        guard let selectedFriendPing else { return }
        Haptics.light()
        if
            let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.attributes.notificationID == selectedFriendPing.notificationID }),
            let fromUsername = activity.content.state.fromUsername,
            let snapshot = activity.content.state.friendSnapshot
        {
            WidgetContentStore.updateReceivedFriendPing(notificationID: selectedFriendPing.notificationID, fromUsername: fromUsername, message: activity.content.state.message, snapshot: snapshot)
        }
        loadReceivedPings()
    }

    private func copySelectedFriendPing() {
        guard let selectedFriendPing else { return }
        Haptics.light()
        store.copiedEditions = ActivityEditionsClipboard(snapshot: selectedFriendPing.snapshot)
    }

    private func reeditSelectedFriendPing() {
        guard let selectedFriendPing else { return }
        Haptics.light()
        let activity = ScheduledActivity(draft: LiveActivityDraft(snapshot: selectedFriendPing.snapshot), surface: .liveActivity, startDate: .now, status: .draft)
        store.save(activity)
        self.selectedFriendPing = nil
        cardSource = .own
        withAnimation(animation) {
            select(activity)
        }
    }

    private func deleteSelectedFriendPing() {
        guard let selectedFriendPing else { return }
        deleteFriendPing(selectedFriendPing)
    }

    private func deleteFriendPing(_ ping: ReceivedFriendPing) {
        Haptics.light()
        if selectedFriendPing?.notificationID == ping.notificationID {
            withAnimation(animation) {
                selectedFriendPing = nil
            }
        }
        WidgetContentStore.deleteReceivedFriendPing(notificationID: ping.notificationID)
        loadReceivedPings()
    }

    private var isFriendPingSelected: Bool {
        selectedFriendPing != nil
    }

    private var isEditingSubsheet: Bool {
        editedLiveAction != nil || isPickingFriends || isPickingSong
    }

    private var undoToolbarButton: some View {
        Button {
            Haptics.light()
            undoActivityChange()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .disabled(undoStack.isEmpty)
        .accessibilityLabel("Undo")
    }

    private var redoToolbarButton: some View {
        Button {
            Haptics.light()
            redoActivityChange()
        } label: {
            Image(systemName: "arrow.uturn.forward")
        }
        .disabled(redoStack.isEmpty)
        .accessibilityLabel("Redo")
    }

    @ViewBuilder
    private var addContentButton: some View {
        if editViewModel.draft.kind == .check(.todoList) {
            Button("Add item", systemImage: "plus") {
                Haptics.light()
                editViewModel.addChecklistItem()
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .opacity(editViewModel.draft.checklistItems.count < 6 ? 1 : 0)
            .disabled(editViewModel.draft.checklistItems.count >= 6)
            .animation(.snappy, value: editViewModel.draft.checklistItems.count)
        } else if editViewModel.draft.kind == .check(.buttons) {
            Button("Add action", systemImage: "plus") {
                Haptics.light()
                editViewModel.addLiveActionItem()
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .opacity(editViewModel.draft.liveActionItems.count < 8 ? 1 : 0)
            .disabled(editViewModel.draft.liveActionItems.count >= 8)
            .animation(.snappy, value: editViewModel.draft.liveActionItems.count)
        } else if editViewModel.draft.kind == .note || editViewModel.draft.kind == .music {
            // Actions and checklists don't sync cross-device, and images can't be pushed (the raw
            // bytes blow the ~4KB APNs content-state limit) — only note and music content can
            // reach a friend's device, so this only shows for those kinds. Music's own picker
            // opens by tapping the album art in the preview (like image does), not a toolbar button.
            friendPickerButton
                .task { await editViewModel.loadFriends() }
        }
    }

    private var friendPickerButton: some View {
        Button {
            Haptics.light()
            isPickingFriends = true
        } label: {
            Image(systemName: "person")
        }
        .overlay(alignment: .topTrailing) {
            if !editViewModel.sendToFriendUsernames.isEmpty {
                Text("\(editViewModel.sendToFriendUsernames.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Circle().fill(.red))
                    .offset(x: 6, y: -6)
            }
        }
    }

    private var cardSourceMenu: some View {
        Menu {
            Button {
                Haptics.selection()
                switchCardSource(.own)
            } label: {
                Label("Stack", systemImage: "square.stack.fill")
            }

            Button {
                Haptics.selection()
                switchCardSource(.friends)
            } label: {
                Label("Friend", systemImage: "person.2")
            }
        } label: {
            Image(systemName: cardSource == .own ? "square.stack.fill" : "person.2")
        }
        .accessibilityLabel("Stack or Friend")
    }

    private var activityKindMenu: some View {
        Menu {
            Button("Text", systemImage: "text.alignleft") {
                Haptics.selection()
                setActivityKind(.note)
            }

            Button("Image", systemImage: "photo") {
                Haptics.selection()
                setActivityKind(.image)
            }

            Button("Music", systemImage: "music.note") {
                Haptics.selection()
                setActivityKind(.music)
            }

            Button("Checklist", systemImage: "checklist.checked") {
                Haptics.selection()
                setActivityKind(.check(.todoList))
            }

            Button("Actions", systemImage: "square.grid.2x2") {
                Haptics.selection()
                setActivityKind(.check(.buttons))
            }
        } label: {
            Image(systemName: activityKindMenuIcon)
        }
        .accessibilityLabel("Tipo de actividad")
    }

    private var activityKindMenuIcon: String {
        switch editViewModel.draft.kind {
        case .note:
            "text.alignleft"
        case .image:
            "photo"
        case .music:
            "music.note"
        case .check(.todoList):
            "checklist.checked"
        case .check(.buttons):
            "square.grid.2x2"
        }
    }

    private func setActivityKind(_ kind: ActivityKind) {
        editViewModel.setKind(kind)
        editViewModel.saveDraft(store: store)
    }

    private func undoActivityChange() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(editViewModel.activity)
        applyHistoryActivity(previous)
    }

    private func redoActivityChange() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(editViewModel.activity)
        applyHistoryActivity(next)
    }

    private func applyHistoryActivity(_ activity: ScheduledActivity) {
        isApplyingHistory = true
        editViewModel.load(activity)
        selectedActivity = activity
        if presentedSheetActivity != nil {
            presentedSheetActivity = activity
        }
    }

    private var cutoutSendButton: some View {
        Button {
            Haptics.medium()
            sendSelectedActivity()
        } label: {
            Text(!editViewModel.sendToFriendUsernames.isEmpty ? "Enviar" : (editViewModel.isScheduling || editViewModel.activity.locationTriggerEnabled ? "Schedule" : "Send"))
                .fontWeight(.semibold)
                .foregroundStyle(.black)
        }
        .buttonStyle(.glassProminent)
        .tint(.yellow)
        .controlSize(.small)
        .disabled(isSendDisabled)
    }

    private var successZoneHeight: CGFloat {
        let spacing: CGFloat = 20
        return max(160, info.containerSize.height - info.minY - (selectedActivityHeight + spacing))
    }

    private func successBottomBanner(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: message)
            Text(message)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private var cutoutCancelButton: some View {
        Button {
            Haptics.light()
            closeSelectedActivity()
        } label: {
            Text("Cancel")
                .fontWeight(.semibold)
        }
        .buttonStyle(.glass)
        .controlSize(.small)
    }

    private var isSendDisabled: Bool {
        if !editViewModel.sendToFriendUsernames.isEmpty {
            return editViewModel.friendMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // No selected weekday is valid while scheduling: it means "just this once", not "nothing
        // set" — see CreateActivityV2EditViewModel.effectiveRecurrence.
        return !editViewModel.draft.isValid
            || (editViewModel.activity.locationTriggerEnabled && !hasSelectedLocation)
    }

    private var hasSelectedLocation: Bool {
        editViewModel.activity.locationLatitude != nil && editViewModel.activity.locationLongitude != nil
    }

    private var isSelectedActivityLive: Bool {
        isActivitySelected && editViewModel.activity.liveActivityID != nil
    }

    private func sendSelectedActivity() {
        normalizeActivityTitle()
        Task {
            let didSend = await editViewModel.send(store: store)
            guard didSend else { return }
            let message = sendSuccessMessage()
            // Close only the sheet and show the success state in place of the toolbar buttons —
            // still on the editing screen at this point, not back in the list yet.
            await MainActor.run {
                withAnimation(.snappy) {
                    presentedSheetActivity = nil
                    successMessage = message
                }
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.snappy) {
                    successMessage = nil
                }
                closeSelectedActivity()
            }
        }
    }

    private func sendSuccessMessage() -> String {
        if !editViewModel.sendToFriendUsernames.isEmpty {
            let names = editViewModel.sendToFriendUsernames.map { "@\($0)" }.joined(separator: ", ")
            return "Enviado a \(names)"
        }
        if editViewModel.activity.locationTriggerEnabled {
            return "Programado por ubicación"
        }
        if editViewModel.isScheduling {
            return editViewModel.selectedWeekdays.isEmpty ? "Programado correctamente" : "Programado: se repite cada semana"
        }
        return "Live Activity enviada"
    }

    private func endSelectedLiveActivity() {
        guard let liveActivityID = editViewModel.activity.liveActivityID else { return }

        Task {
            await LiveActivityController.end(id: liveActivityID)
            await MainActor.run {
                withAnimation(animation) {
                    editViewModel.activity.liveActivityID = nil
                    editViewModel.activity.status = .completed
                    editViewModel.saveDraft(store: store)
                }
            }
        }
    }

    private func deleteActivity(_ activity: ScheduledActivity) {
        guard canDelete(activity) else { return }
        if selectedActivityID == activity.id {
            withAnimation(animation) {
                selectedActivity = nil
                presentedSheetActivity = nil
            }
        }

        Task {
            if let liveActivityID = activity.liveActivityID {
                await LiveActivityController.end(id: liveActivityID)
            }
            await MainActor.run {
                withAnimation(animation) {
                    store.deleteLiveActivityCard(id: activity.id)
                }
            }
        }
    }

    private func canDelete(_ activity: ScheduledActivity) -> Bool {
        guard activity.draft.isStrict, activity.draft.kind == .check(.todoList) else { return true }
        return !activity.draft.checklistItems.isEmpty && activity.draft.checklistItems.allSatisfy(\.isCompleted)
    }

    private func presentLiveActionEditor(_ actionID: UUID) {
        withAnimation(.snappy) {
            editedLiveAction = LiveActionSelection(id: actionID)
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private var isNavigationTitleHidden: Bool {
        info.isScrolledPastTop || isActivitySelected || isFriendPingSelected
    }

    private var isActivitySelected: Bool {
        selectedActivityID != nil
    }

    private var selectedActivityID: UUID? {
        selectedActivity?.id
    }

    private var activityTitleBinding: Binding<String> {
        Binding {
            editViewModel.draft.title
        } set: { newValue in
            editViewModel.draft.title = newValue
            editViewModel.saveDraft(store: store)
        }
    }

    private func normalizeActivityTitle() {
        let trimmedTitle = editViewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            // Disabled for now — don't auto-fill an empty title with "Activity #N".
            // editViewModel.draft.title = defaultActivityTitle(for: editViewModel.activity)
        } else if trimmedTitle != editViewModel.draft.title {
            editViewModel.draft.title = trimmedTitle
        }
        editViewModel.saveDraft(store: store)
    }

    private func defaultActivityTitle(for activity: ScheduledActivity) -> String {
        let oldestFirstCards = store.liveActivityCards.sorted { $0.createdAt < $1.createdAt }
        let activityNumber = (oldestFirstCards.firstIndex(where: { $0.id == activity.id }) ?? oldestFirstCards.count) + 1
        return "Activity #\(activityNumber)"
    }

    private var selectedActivityHeight: CGFloat {
        selectedCardHeight
    }

    @ViewBuilder
    private var screenBackground: some View {
        if isActivitySelected || isFriendPingSelected {
            editingSurfaceBackground
                .overlay(alignment: .topTrailing) {
                    editingBackgroundGlow
                }
                .overlay(alignment: .bottomLeading) {
                    editingBottomBackgroundGlow
                }
                .ignoresSafeArea()
        } else {
            Color.secondarybg
                .ignoresSafeArea()
        }
    }

    private var editingSurfaceBackground: Color {
        isActivitySelected || isFriendPingSelected ? .black : schemeBackground
    }

    private var schemeBackground: Color {
        colorScheme == .dark ? .black : .white
    }

    private var editingBackgroundGlow: some View {
        Circle()
            .fill(editingBackgroundGlowGradient)
            .frame(width: editingBackgroundGlowSize, height: editingBackgroundGlowSize)
            .blur(radius: 132)
            .opacity(0.82)
            .offset(x: editingBackgroundGlowSize * 0.36, y: -editingBackgroundGlowSize * 0.46)
            .allowsHitTesting(false)
            .animation(.snappy, value: editViewModel.draft.style.backgroundHex)
            .animation(.snappy, value: editViewModel.draft.style.gradientStartHex)
            .animation(.snappy, value: editViewModel.draft.style.gradientEndHex)
    }

    private var editingBottomBackgroundGlow: some View {
        Circle()
            .fill(editingBottomBackgroundGlowGradient)
            .frame(width: editingBottomBackgroundGlowSize, height: editingBottomBackgroundGlowSize)
            .blur(radius: 150)
            .opacity(0.46)
            .offset(x: -editingBottomBackgroundGlowSize * 0.3, y: editingBottomBackgroundGlowSize * 0.34)
            .allowsHitTesting(false)
            .animation(.snappy, value: editViewModel.draft.style.backgroundHex)
            .animation(.snappy, value: editViewModel.draft.style.gradientStartHex)
            .animation(.snappy, value: editViewModel.draft.style.gradientEndHex)
            .animation(.snappy, value: editViewModel.draft.style.textHex)
    }

    private var editingBackgroundGlowGradient: RadialGradient {
        RadialGradient(
            colors: [
                editingBackgroundGlowColor.opacity(0.95),
                editingBackgroundGlowColor.opacity(0.42),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: editingBackgroundGlowSize * 0.5
        )
    }

    private var editingBottomBackgroundGlowGradient: RadialGradient {
        RadialGradient(
            colors: [
                editingBottomBackgroundGlowColor.opacity(0.9),
                editingBottomBackgroundGlowColor.opacity(0.34),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: editingBottomBackgroundGlowSize * 0.5
        )
    }

    private var editingBackgroundGlowColor: Color {
        let style = editViewModel.draft.style

        switch style.backgroundMode {
        case .plain, .image:
            return Color(hex: style.backgroundHex)
        case .gradient:
            return Color(hex: style.gradientStartHex)
        }
    }

    private var editingBottomBackgroundGlowColor: Color {
        let style = editViewModel.draft.style

        switch style.backgroundMode {
        case .gradient:
            return Color(hex: style.gradientEndHex)
        case .plain, .image:
            return Color(hex: style.textHex)
        }
    }

    private var editingBackgroundGlowSize: CGFloat {
        max(700, info.containerSize.width * 1.72)
    }

    private var editingBottomBackgroundGlowSize: CGFloat {
        max(640, info.containerSize.width * 1.58)
    }

    private var animation: Animation {
        .interactiveSpring(response: 0.55, dampingFraction: 0.8)
    }

    private struct Info {
        var isScrolledPastTop = false
        var containerSize: CGSize = .zero
        var safeArea: EdgeInsets = .init()
        var minY: CGFloat = 0
    }
}

private struct LiveActionSelection: Identifiable, Hashable {
    let id: UUID
}

/// Wraps a card's tap-to-center animation + hit-testing/visibility math as a genuinely separate
/// `View` identity per card (SwiftUI gives each `ForEach` row its own instance) — its own measured
/// height lives in LOCAL `@State` here instead of a `[ID: CGFloat]` dictionary on the parent.
/// Previously every card wrote into that shared dictionary on every scroll/layout pass, and because
/// `CreateActivityV2View`'s cards were plain functions (no view-identity boundary), each write
/// invalidated and re-diffed the *entire* parent body — every other card, the whole toolbar, on
/// every frame. Only the currently-selected card's height is ever actually needed by the parent
/// (for the edit sheet's `presentationDetents`), so that's handed up once, at selection time, via
/// `onSelect`, rather than continuously.
private struct CardAnimationSlot<Content: View>: View {
    let isCurrent: Bool
    let isAnySelected: Bool
    let containerSize: CGSize
    let animation: Animation
    let onSelect: (CGFloat) -> Void
    // The selected card's content (e.g. a note's text) can keep changing height while it's open —
    // typing more text, adding checklist items — and the presenting sheet needs to track that
    // reactively, same as before this was split out. Only wired up while `isCurrent`, so the other
    // N-1 cards in the grid still never write anything up to the parent on every layout pass.
    let onCurrentHeightChange: (CGFloat) -> Void
    @ViewBuilder let content: () -> Content
    @State private var measuredHeight: CGFloat = 160

    var body: some View {
        content()
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: { newValue in
                measuredHeight = newValue
                if isCurrent {
                    onCurrentHeightChange(newValue)
                }
            }
            .contentShape(.rect)
            .onTapGesture {
                withAnimation(animation) {
                    onSelect(measuredHeight)
                }
            }
            .visualEffect { [isCurrent, isAnySelected, containerSize] content, proxy in
                let rect = proxy.frame(in: .scrollView)
                let centeredOffset = -rect.minY
                let hiddenOffset = containerSize.height - rect.minY
                let pushOffset = isCurrent ? centeredOffset : hiddenOffset

                return content
                    .scaleEffect(isAnySelected && !isCurrent ? 0.95 : 1, anchor: .top)
                    .offset(y: isAnySelected ? pushOffset : 0)
                    .opacity(isAnySelected && !isCurrent ? 0 : 1)
            }
            .allowsHitTesting(isAnySelected ? isCurrent : true)
            .disabled(isAnySelected && !isCurrent)
    }
}

private enum ActivityStatusPillKind {
    case live
    case scheduled

    var title: String {
        switch self {
        case .live: "Live"
        case .scheduled: "Scheduled"
        }
    }

    var dotColor: Color {
        switch self {
        case .live: .green
        case .scheduled: .yellow
        }
    }
}

private struct SelectedActivityPreview: View {
    @EnvironmentObject private var store: ActivityStore
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    let selectedLiveActionID: UUID?
    var onEditLiveAction: (UUID) -> Void
    var onPickSong: () -> Void
    var isPickingSong: Bool
    var isLiveActivity: Bool
    var onEndLiveActivity: () -> Void
    var showsStatusPill: Bool
    @State private var isLiveIndicatorPulsing = false
    @State private var isShowingEndLiveActivityPopover = false

    var body: some View {
        VStack(spacing: 12) {
            LivePreviewView(
                viewModel: viewModel,
                selectedLiveActionID: selectedLiveActionID,
                onEditLiveAction: onEditLiveAction,
                onPickSong: onPickSong,
                isEditingMusic: isPickingSong
            )

            if showsStatusPill, let statusPillKind {
                statusPill(statusPillKind)
            }

//            ActivityKindCircleSelector(viewModel: viewModel)
//                .environmentObject(store)
        }
        .overlay(alignment: .bottom) {
            if isShowingEndLiveActivityPopover {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Live Activity")
                        .font(.headline)

                    Text("Finalizar esta actividad activa.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Finalizar", role: .destructive) {
                        isShowingEndLiveActivityPopover = false
                        onEndLiveActivity()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
                .frame(width: 220)
                .background(.regularMaterial, in: .rect(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
                .offset(y: -52)
                .zIndex(10)
            }
        }
    }

    private var statusPillKind: ActivityStatusPillKind? {
        if isLiveActivity { return .live }
        if viewModel.activity.status == .scheduled { return .scheduled }
        return nil
    }

    @ViewBuilder
    private func statusPill(_ kind: ActivityStatusPillKind) -> some View {
        let content = HStack(spacing: 7) {
            Circle()
                .fill(kind.dotColor)
                .frame(width: 8, height: 8)
                .scaleEffect(kind == .live && isLiveIndicatorPulsing ? 1.3 : 0.85)
                .shadow(color: kind.dotColor.opacity(0.75), radius: kind == .live && isLiveIndicatorPulsing ? 6 : 3)

            Text(kind.title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.1), in: .capsule)

        if kind == .live {
            Button {
                isShowingEndLiveActivityPopover = true
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Live Activity activa. Finalizar")
            .onAppear {
                isLiveIndicatorPulsing = true
            }
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLiveIndicatorPulsing)
        } else {
            content
        }
    }
}

private struct ActivityKindCircleSelector: View {
    @EnvironmentObject private var store: ActivityStore
    @ObservedObject var viewModel: CreateActivityV2EditViewModel

	    var body: some View {
	        HStack(spacing: 14) {
            kindButton(
                systemImage: "note.text",
                isSelected: viewModel.draft.kind == .note,
                label: "Note"
            ) {
                setKind(.note)
            }

            kindButton(
                systemImage: viewModel.draft.kind == .check(.todoList) ? "checklist.checked" : "checklist.unchecked",
                isSelected: viewModel.draft.kind == .check(.todoList),
                label: "To Do"
            ) {
                setKind(.check(.todoList))
            }

            kindButton(
                systemImage: viewModel.draft.kind == .check(.buttons) ? "square.grid.2x2.fill" : "square.grid.2x2",
                isSelected: viewModel.draft.kind == .check(.buttons),
                label: "LiveActions"
            ) {
                setKind(.check(.buttons))
	            }
	        }
            .sensoryFeedback(.selection, trigger: viewModel.draft.kind)
	    }

    private func kindButton(systemImage: String, isSelected: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(13)
                .circularLiquidGlass(Color.white.opacity(isSelected ? 0.3 : 0.16))
        }
        .buttonStyle(.plain)
        .contentShape(.circle)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func setKind(_ kind: ActivityKind) {
        viewModel.setKind(kind)
        viewModel.saveDraft(store: store)
    }
}

private struct LiveActionItemEditSheet: View {
    @EnvironmentObject private var store: ActivityStore
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    let actionID: UUID
    var onDone: () -> Void
    @FocusState private var focusedField: Field?
    @State private var feedbackTrigger = 0

    private let iconChoices = [
        "bolt.fill", "app.fill", "link", "play.fill",
        "paperplane.fill", "music.note", "timer", "bell.fill",
        "heart.fill", "star.fill", "bookmark.fill", "calendar",
        "message.fill", "phone.fill", "safari.fill", "sparkles"
    ]

    var body: some View {
        NavigationStack {
            if currentAction != nil {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 18) {
                        editorSection("Action") {
                            actionTextField(
                                "Display name",
                                text: actionBinding(\.title, default: "Action"),
                                field: .title
                            )

                            Picker("Action", selection: actionBinding(\.kind, default: .openLink)) {
                                ForEach(LiveActionKind.allCases) { kind in
                                    Text(kind.title).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        editorSection(destinationSectionTitle) {
                            destinationFields

	                            Button {
                                    triggerFeedback()
	                                runCurrentAction()
	                            } label: {
	                                Label("Run", systemImage: "play.fill")
	                                    .frame(maxWidth: .infinity)
                                        .frame(height: 44)
	                            }
	                            .buttonStyle(.glassProminent)
                            .disabled(currentAction.flatMap(liveActionURL(for:)) == nil)
                        }

                        editorSection("Appearance") {
                            HStack(spacing: 14) {
                                ColorPicker("Background", selection: hexBinding(\.backgroundHex))
                                ColorPicker("Text", selection: hexBinding(\.textHex))
                            }
                        }

	                        editorSection("Icon") {
                                actionTextField(
                                    "Custom emoji",
                                    text: optionalActionBinding(\.customIcon),
                                    field: .customIcon
                                )

	                            iconPicker
	                        }

                    }
                    .padding(20)
                }
                .navigationTitle("Live Action")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
	                    ToolbarItem(placement: .topBarLeading) {
	                        Button(role: .destructive) {
                                triggerFeedback()
	                            viewModel.removeLiveActionItem(id: actionID)
	                            viewModel.saveDraft(store: store)
	                            onDone()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }

	                    ToolbarItem(placement: .topBarTrailing) {
	                        Button {
                                triggerFeedback()
	                            viewModel.saveDraft(store: store)
	                            onDone()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.glassProminent)
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()

	                        Button {
                            triggerFeedback()
	                            focusedField = nil
	                        } label: {
                            Image(systemName: "chevron.compact.down.fill")
                        }
                        .padding(.vertical, 8)
                    }
                }
	            } else {
	                ContentUnavailableView("Action not found", systemImage: "square.grid.2x2")
	            }
	        }
            .foregroundStyle(.white)
            .tint(.yellow)
            .preferredColorScheme(.dark)
            .toolbarBackground(.clear, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: feedbackTrigger)
            .sensoryFeedback(.selection, trigger: currentAction?.kind)
            .sensoryFeedback(.selection, trigger: currentAction?.icon)
            .sensoryFeedback(.selection, trigger: currentAction?.customIcon)
	    }

    @ViewBuilder
    private var destinationFields: some View {
        switch currentAction?.kind {
        case .shortcut:
            actionTextField(
                "Shortcut name",
                text: actionBinding(\.target, default: ""),
                field: .target,
                capitalization: .words
            )

            actionTextField(
                "Input (optional)",
                text: optionalActionBinding(\.shortcutInput),
                field: .shortcutInput
            )
        case .openApp:
            actionTextField(
                "App URL scheme, e.g. shortcuts://",
                text: actionBinding(\.target, default: ""),
                field: .target,
                keyboardType: .URL
            )
        case .openLink, nil:
            actionTextField(
                "https://example.com",
                text: actionBinding(\.target, default: ""),
                field: .target,
                keyboardType: .URL
            )
        }
    }

    private func actionTextField(
        _ placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .never
    ) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .focused($focusedField, equals: field)
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(.white.opacity(0.1), in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
    }

    private func editorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .textCase(.uppercase)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private var iconPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
	            ForEach(iconChoices, id: \.self) { icon in
	                Button {
                        triggerFeedback()
	                    actionBinding(\.icon, default: "bolt.fill").wrappedValue = icon
	                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(icon == currentAction?.icon ? Color.white.opacity(0.18) : Color.white.opacity(0.08), in: .rect(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var currentAction: LiveActionItem? {
        viewModel.draft.liveActionItems.first { $0.id == actionID }
    }

    private var destinationSectionTitle: String {
        switch currentAction?.kind {
        case .shortcut:
            "Shortcut"
        case .openApp:
            "App"
        case .openLink, nil:
            "Link"
        }
    }

    private func actionBinding<Value>(_ keyPath: WritableKeyPath<LiveActionItem, Value>, default defaultValue: Value) -> Binding<Value> {
        Binding {
            currentAction?[keyPath: keyPath] ?? defaultValue
        } set: { newValue in
            guard let index = viewModel.draft.liveActionItems.firstIndex(where: { $0.id == actionID }) else { return }
            viewModel.draft.liveActionItems[index][keyPath: keyPath] = newValue
        }
    }

    private func optionalActionBinding(_ keyPath: WritableKeyPath<LiveActionItem, String?>) -> Binding<String> {
        Binding {
            currentAction?[keyPath: keyPath] ?? ""
        } set: { newValue in
            guard let index = viewModel.draft.liveActionItems.firstIndex(where: { $0.id == actionID }) else { return }
            let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            viewModel.draft.liveActionItems[index][keyPath: keyPath] = trimmedValue.isEmpty ? nil : newValue
        }
    }

    private func hexBinding(_ keyPath: WritableKeyPath<LiveActionItem, String>) -> Binding<Color> {
        Binding {
            Color(hex: currentAction?[keyPath: keyPath] ?? "FFFFFF")
        } set: { color in
            guard let components = UIColor(color).cgColor.components else { return }
            let red = Int((components.count > 2 ? components[0] : components[0]) * 255)
            let green = Int((components.count > 2 ? components[1] : components[0]) * 255)
            let blue = Int((components.count > 2 ? components[2] : components[0]) * 255)
            actionBinding(keyPath, default: "FFFFFF").wrappedValue = String(format: "%02X%02X%02X", red, green, blue)
        }
    }

	    private func runCurrentAction() {
	        guard let action = currentAction, let url = liveActionURL(for: action) else { return }
	        openURL(url)
	    }

    private func triggerFeedback() {
        feedbackTrigger += 1
    }

    private func liveActionURL(for action: LiveActionItem) -> URL? {
        LiveActionURLBuilder.url(kind: action.kind.rawValue, target: action.target, shortcutInput: action.shortcutInput)
    }

    private enum Field: Hashable {
        case title
        case target
        case shortcutInput
        case customIcon
    }
}

private extension View {
    // Dismissing presentedSheetActivity on keyboardWillShow used to close the ONLY sheet
    // presentation (the edit sheet itself) the instant any TextField inside it became first
    // responder — typing was structurally impossible in any text field the sheet contains.
    @ViewBuilder
    func trackKeyboardVisibility(
        isKeyboardVisible: Binding<Bool>,
        presentedSheetActivity: Binding<ScheduledActivity?>,
        selectedActivity: Binding<ScheduledActivity?>
    ) -> some View {
        #if canImport(UIKit)
        self
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.snappy) {
                    isKeyboardVisible.wrappedValue = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.snappy) {
                    isKeyboardVisible.wrappedValue = false
                }
            }
        #else
        self
        #endif
    }
}
