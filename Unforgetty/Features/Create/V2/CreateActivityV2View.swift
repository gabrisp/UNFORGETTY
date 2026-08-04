import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CreateActivityV2View: View {
    @Binding var progress: CGFloat
    @EnvironmentObject private var store: ActivityStore
    @EnvironmentObject private var flow: AppFlowViewModel
    @Environment(\.colorScheme) private var colorScheme
    // The one and only view model for this screen — CardSource/EditSubSheet/ScreenGeometry and all
    // the selection/sheet/keyboard/geometry state that used to be loose @State directly on this
    // view now live here too (see CreateActivityV2EditViewModel.swift), alongside the
    // activity-being-edited state it already owned.
    @StateObject private var editViewModel: CreateActivityV2EditViewModel
    // Onboarding's "create your first activity" step reuses this exact screen — same toolbar
    // machinery, same background, same sheet — instead of a lookalike, per explicit instruction.
    // `isOnboarding` is false and `onboardingSendCompleted` is nil at the app's own real call site
    // (CreateActivityView.swift), so every branch gated on them below is dead code there; nothing
    // about the real screen's behavior changes unless a caller opts in.
    private let isOnboarding: Bool
    private let onboardingSendCompleted: (() -> Void)?

    init(
        progress: Binding<CGFloat>,
        editViewModel: CreateActivityV2EditViewModel? = nil,
        isOnboarding: Bool = false,
        onboardingSendCompleted: (() -> Void)? = nil
    ) {
        self._progress = progress
        self._editViewModel = StateObject(wrappedValue: editViewModel ?? CreateActivityV2EditViewModel())
        self.isOnboarding = isOnboarding
        self.onboardingSendCompleted = onboardingSendCompleted
    }

    var body: some View {
        // Native tabs instead of a toolbar Menu toggling one shared grid — bound to `cardSource`
        // itself (already `Hashable`), so nothing else that reads `cardSource` elsewhere (onReedit,
        // isBrowsingGridToolbar, etc.) needed to change: switching tabs IS switching cardSource.
        TabView(selection: $editViewModel.cardSource) {
            Tab("Stack", systemImage: "square.stack.fill", value: CardSource.own) {
                stackTabContent
            }
            Tab("Friends", systemImage: "person.2.fill", value: CardSource.friends) {
                friendsTabContent
            }
        }
    }

    private var stackTabContent: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(store.liveActivityCards) { activity in
                        SavedLiveActivityCardView(activity: activity)
                            .colorScheme(.dark)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(15)
            .scrollDisabled(isActivitySelected)
            // .safeAreaBar (not used here) minimizes/reveals on scroll like a system tab bar —
            // .safeAreaInset just reserves the space and pins the content, no scroll reactivity.
            .safeAreaInset(edge: .bottom) {
                if !isActivitySelected && !isOnboarding {
                    upgradeBar
                }
            }
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
                    if editViewModel.isKeyboardVisible {
                        Button {
                            Haptics.light()
                            dismissKeyboard()
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                    } else if showsEditingToolbarButtons {
                        // No kind-switcher in onboarding — the kind was already chosen on the
                        // previous step — replaced with the one thing this context actually
                        // needs: a button that sends the activity for real.
                        if isOnboarding {
                            onboardingSendButton
                        } else {
                            activityKindMenu
                        }
                    }
                }

                // Separate spaced groups (not one ToolbarItemGroup) so ToolbarSpacer can actually
                // sit between them. The Stack/Friend switcher itself is gone — the TabView's own
                // tab bar does that now.
                if isBrowsingGridToolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Add", systemImage: "plus") {
                            Haptics.light()
                            withAnimation(animation) {
                                select(store.createLiveActivityDraft())
                            }
                        }
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") {
                            Haptics.light()
                            editViewModel.presentedGridSheet = .settings
                        }
                    }
                }
            }
            // `onScrollGeometryChange`'s `action` only fires when the *transformed* value changes —
            // transforming straight to the boolean this is actually used for (instead of the raw
            // offset) means it fires once per threshold crossing instead of on every scroll frame,
            // which otherwise reassigned the whole `geometry` struct — and therefore invalidated
            // this entire view — continuously while scrolling.
            .onScrollGeometryChange(for: Bool.self) {
                ($0.contentOffset.y + $0.contentInsets.top) > 1
            } action: { _, newValue in
                editViewModel.geometry.isScrolledPastTop = newValue
            }
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).minY
            } action: { newValue in
                editViewModel.geometry.minY = newValue - editViewModel.geometry.safeArea.top
            }
            .background {
                screenBackground
            }
            .task {
                if !isOnboarding {
                    store.ensureInitialLiveActivityDraft()
                }
            }
            .task {
                guard isOnboarding else { return }
                // select() (the normal tap path) always persists first via store.update inside
                // saveDraft — this activity has never been saved before reaching this step, so
                // without this the ForEach below has no matching entry and nothing renders as
                // "current." Mirrors select()'s effect otherwise too: opens straight into the
                // editing surface instead of requiring a tap on a grid onboarding never shows.
                editViewModel.saveDraft(store: store)
                editViewModel.selectedActivity = editViewModel.activity
                editViewModel.presentedSheetActivity = editViewModel.activity
            }
            // Settings is a navigation route, not a sheet — pushed onto this NavigationStack, so
            // this has to live inside it (a .navigationDestination outside the stack it targets
            // does nothing). Duplicated in the Friends tab's own stack below for the same reason —
            // whichever tab's Settings button was tapped needs to push in *that* tab's visible
            // stack, not an invisible one. Since TabView keeps both stacks mounted, triggering it
            // from one tab can in principle also push (invisibly) in the other if it's still
            // mounted — harmless in practice since the user only ever sees the tab they tapped
            // from, but worth knowing if Settings is ever found "already open" after switching tabs.
            .navigationDestination(isPresented: isShowingSettingsBinding) {
                SettingsView()
            }
        }
        .statusBarHidden(true)
        .overlay(alignment: .top) {
            if showsEditingToolbarButtons && !isOnboarding {
                CutoutAccessoryView(
                    padding: .auto,
                    leadingContent: {
                        cutoutCancelButton
                    },
                    trailingContent: {
                        cutoutSendButton
                    }
                )
                .frame(height: max(84, editViewModel.geometry.safeArea.top + 36), alignment: .top)
            }
        }
        // Fills the same lower region the edit sheet occupies (same height math as its
        // presentationDetents below) so the success confirmation reads as "the sheet became this",
        // not as a banner popping in somewhere unrelated.
        .overlay(alignment: .bottom) {
            if let successMessage = editViewModel.successMessage {
                successBottomBanner(successMessage)
                    .frame(maxWidth: .infinity)
                    .frame(height: successZoneHeight, alignment: .center)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .sheet(item: $editViewModel.presentedSheetActivity) { activity in
            let spacing: CGFloat = 20
            let isSafeAreaiPhone = editViewModel.geometry.safeArea.bottom > 0
            let minSheetHeight = editViewModel.geometry.containerSize.height - editViewModel.geometry.minY - (selectedActivityHeight + spacing)
            let maxSheetHeight = editViewModel.geometry.containerSize.height - editViewModel.geometry.minY + (isSafeAreaiPhone ? 15 : 10)

            Group {
                if case .liveAction(let actionID) = editViewModel.editSubSheet {
                    LiveActionItemEditSheet(viewModel: editViewModel, actionID: actionID) {
                        withAnimation(.snappy) {
                            editViewModel.editSubSheet = nil
                        }
                    }
                    .environmentObject(store)
                    .transition(.blurReplace.combined(with: .opacity))
                } else if editViewModel.editSubSheet == .friendPicker {
                    FriendPickerSheet(viewModel: editViewModel) {
                        withAnimation(.snappy) {
                            editViewModel.editSubSheet = nil
                        }
                    }
                    .transition(.blurReplace.combined(with: .opacity))
                } else if editViewModel.editSubSheet == .friendMessage {
                    FriendMessageComposeSheet(viewModel: editViewModel) {
                        withAnimation(.snappy) {
                            editViewModel.editSubSheet = nil
                        }
                    }
                    .transition(.blurReplace.combined(with: .opacity))
                } else if editViewModel.editSubSheet == .songPicker {
                    MusicPickerSheet(viewModel: editViewModel) {
                        withAnimation(.snappy) {
                            editViewModel.editSubSheet = nil
                        }
                    }
                    .environmentObject(store)
                    .transition(.blurReplace.combined(with: .opacity))
                } else {
                    CreateActivityV2EditSheet(viewModel: editViewModel, copiedEditions: $store.copiedEditions, isOnboarding: isOnboarding)
                        .transition(.blurReplace.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: editViewModel.editSubSheet)
            .presentationDetents([.height(minSheetHeight), .height(maxSheetHeight)])
            .presentationBackgroundInteraction(.enabled(upThrough: .height(maxSheetHeight)))
            .interactiveDismissDisabled()
            .presentationBackground(.clear)
            .colorScheme(.dark)
        }
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: { newValue in
            editViewModel.geometry.containerSize = newValue
        }
        .onGeometryChange(for: EdgeInsets.self) {
            $0.safeAreaInsets
        } action: { newValue in
            editViewModel.geometry.safeArea = newValue
        }
        .onChange(of: editViewModel.activity) { oldValue, newValue in
            guard editViewModel.selectedActivityID == newValue.id else { return }
            if editViewModel.isApplyingHistory {
                editViewModel.selectedActivity = newValue
                if editViewModel.presentedSheetActivity != nil {
                    editViewModel.presentedSheetActivity = newValue
                }
                editViewModel.saveDraft(store: store)
                editViewModel.isApplyingHistory = false
                return
            }

            // `editViewModel.load(activity)` (fresh selection, nothing edited) fires this same
            // onChange — same trap as normalizeActivityTitle above. Only persist (the expensive
            // full-store rewrite) when this is a genuine edit to the activity already open, not
            // whenever `.activity` merely changes for any reason including just switching selection.
            editViewModel.recordEditIfNeeded(oldActivity: oldValue, newActivity: newValue)
            if oldValue.id == newValue.id, oldValue != newValue {
                editViewModel.saveDraft(store: store)
            }
            editViewModel.selectedActivity = newValue
            if editViewModel.presentedSheetActivity != nil && editViewModel.editSubSheet == nil {
                editViewModel.presentedSheetActivity = newValue
            }
        }
        .background {
            KeyboardVisibilityReader(isVisible: $editViewModel.isKeyboardVisible)
        }
        // "Reeditar" on a received friend ping (Friends tab) saves the new draft into `store`,
        // switches cardSource back to .own (which also switches the visible tab, see body's
        // TabView(selection:)), then flags it here rather than reaching into this view's local
        // state directly — the two tabs share no view hierarchy, only `store`/`flow`.
        .onChange(of: flow.pendingSelectedActivityID) { _, newValue in
            guard let newValue, let activity = store.liveActivityCards.first(where: { $0.id == newValue }) else { return }
            withAnimation(animation) {
                select(activity)
            }
            flow.pendingSelectedActivityID = nil
        }
    }

    private var friendsTabContent: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    FriendCardsSection(
                        containerSize: editViewModel.geometry.containerSize,
                        animation: animation,
                        isSelected: $editViewModel.isFriendPingSelected,
                        onReedit: { activity in
                            editViewModel.cardSource = .own
                            withAnimation(animation) {
                                select(activity)
                            }
                        }
                    )
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(15)
            .scrollDisabled(editViewModel.isFriendPingSelected)
            .navigationTitle(isNavigationTitleHidden ? "" : "Unforgetty")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if isBrowsingGridToolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Friend Requests", systemImage: "person.2.badge.plus") {
                            Haptics.light()
                            editViewModel.presentedGridSheet = .friendRequests
                        }
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gearshape") {
                            Haptics.light()
                            editViewModel.presentedGridSheet = .settings
                        }
                    }
                }
            }
            .background {
                screenBackground
            }
            .navigationDestination(isPresented: isShowingSettingsBinding) {
                SettingsView()
            }
        }
        .statusBarHidden(true)
        .sheet(item: friendRequestsSheetBinding) { _ in
            FriendRequestsSheet()
        }
    }

    @ViewBuilder
    private func SavedLiveActivityCardView(activity: ScheduledActivity) -> some View {
        let isCurrent = activity.id == editViewModel.selectedActivityID

        CardAnimationSlot(
            isCurrent: isCurrent,
            isAnySelected: isActivitySelected,
            containerSize: editViewModel.geometry.containerSize,
            animation: animation,
            onSelect: { height in select(activity, height: height) },
            onCurrentHeightChange: { height in editViewModel.selectedCardHeight = height }
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
            // Interactive (text input, live-action buttons) — must stay real SwiftUI views, not a
            // rasterized layer, or touch/keyboard input on the card being edited would break.
            SelectedActivityPreview(
                viewModel: editViewModel,
                selectedLiveActionID: editedLiveActionID,
                onEditLiveAction: presentLiveActionEditor,
                onPickSong: {
                    Haptics.light()
                    editViewModel.editSubSheet = .songPicker
                },
                isPickingSong: editViewModel.editSubSheet == .songPicker,
                isLiveActivity: isSelectedActivityLive,
                onEndLiveActivity: endSelectedLiveActivity,
                showsStatusPill: !isEditingSubsheet
            )
        } else {
            // NOT flattened with .drawingGroup(): Liquid Glass's .glassEffect() (used for
            // .plain-background cards, the most common case, via liquidGlassCard) is a live
            // compositor effect that samples the real backdrop behind it — rasterizing into an
            // isolated offscreen texture left it with nothing to sample, rendering as transparent
            // instead of tinted glass. Correctness over the animation-recompositing optimization
            // this used to buy.
            ActivityPreviewView(draft: activity.draft)
        }
    }

    private func select(_ activity: ScheduledActivity, height: CGFloat = 160) {
        editViewModel.clearHistory()
        editViewModel.load(activity)
        normalizeActivityTitle()
        editViewModel.selectedActivity = editViewModel.activity
        editViewModel.selectedCardHeight = height
        if !editViewModel.isKeyboardVisible {
            editViewModel.presentedSheetActivity = editViewModel.activity
        }
    }

    private func closeSelectedActivity() {
        dismissKeyboard()
        normalizeActivityTitle()
        store.discardEmptyLiveActivityDraft(editViewModel.activity)
        editViewModel.clearHistory()
        withAnimation(animation) {
            editViewModel.selectedActivity = nil
            editViewModel.presentedSheetActivity = nil
        }
    }

    private var showsEditingToolbarButtons: Bool {
        isActivitySelected && editViewModel.editSubSheet == nil && !editViewModel.isKeyboardVisible && editViewModel.successMessage == nil
    }

    private var isBrowsingGridToolbar: Bool {
        !editViewModel.isKeyboardVisible && !isActivitySelected && !editViewModel.isFriendPingSelected
    }

    private var isEditingSubsheet: Bool {
        editViewModel.editSubSheet != nil
    }

    private var editedLiveActionID: UUID? {
        if case .liveAction(let id) = editViewModel.editSubSheet { return id }
        return nil
    }

    private var undoToolbarButton: some View {
        Button {
            Haptics.light()
            undoActivityChange()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .disabled(!editViewModel.canUndo)
        .accessibilityLabel("Undo")
    }

    private var redoToolbarButton: some View {
        Button {
            Haptics.light()
            redoActivityChange()
        } label: {
            Image(systemName: "arrow.uturn.forward")
        }
        .disabled(!editViewModel.canRedo)
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
        } else if !isOnboarding && (editViewModel.draft.kind == .note || editViewModel.draft.kind == .music || editViewModel.draft.kind == .image) {
            // Actions and checklists don't sync cross-device (device-local shortcuts / no
            // cross-device store). Note, music, and image content can all reach a friend's device —
            // image uploads its background photo to the "images" Storage bucket right before
            // sending (raw bytes don't fit the ~4KB push payload) instead of embedding it inline,
            // same idea as music's Spotify CDN URL. Music/image's own picker opens by tapping the
            // art in the preview, not this toolbar button. Excluded entirely in onboarding — no
            // friend-sharing option for the first activity being created there.
            friendPickerButton
                .task { await editViewModel.loadFriends() }
        }
    }

    private var friendPickerButton: some View {
        Button {
            Haptics.light()
            editViewModel.editSubSheet = .friendPicker
        } label: {
            if editViewModel.sendToFriendUsernames.isEmpty {
                Image(systemName: "person")
            } else {
                // Replaces the icon entirely once someone's selected, rather than a small badge
                // stacked on top of it — the count is the more useful thing to see at a glance here.
                Text("\(editViewModel.sendToFriendUsernames.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Circle().fill(.red))
            }
        }
    }

    // Replaces the old inline toolbar "Upgrade" crown button — a persistent, always-visible bar
    // reads as a stronger, harder-to-miss upsell than a small toolbar item that scrolled past
    // whenever the title collapsed.
    private var upgradeBar: some View {
        Button {
            Haptics.medium()
            flow.showPaywall()
        } label: {
            HStack {
                Text("Unforgetty PRO")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 12)
                Text("Upgrade")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .liquidGlassCard(tint: .yellow, cornerRadius: 20, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
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

    // editViewModel.undo()/redo() pop their own stacks and call load() internally, which fires
    // .onChange(of: editViewModel.activity) above — its isApplyingHistory branch is what actually
    // syncs selectedActivity/presentedSheetActivity to the replayed value.
    private func undoActivityChange() {
        editViewModel.undo()
    }

    private func redoActivityChange() {
        editViewModel.redo()
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
        .tint(!editViewModel.sendToFriendUsernames.isEmpty ? Color(hex: editViewModel.draft.style.friendSendButtonColorHex) : .yellow)
        .controlSize(.small)
        .disabled(isSendDisabled)
    }

    private var successZoneHeight: CGFloat {
        let spacing: CGFloat = 20
        return max(160, editViewModel.geometry.containerSize.height - editViewModel.geometry.minY - (selectedActivityHeight + spacing))
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

    // Both bridge editViewModel.presentedGridSheet (one enum, not a bool per sheet) to the
    // Binding shapes .navigationDestination(isPresented:)/.sheet(item:) each require.
    private var isShowingSettingsBinding: Binding<Bool> {
        Binding(
            get: { editViewModel.presentedGridSheet == .settings },
            set: { editViewModel.presentedGridSheet = $0 ? .settings : nil }
        )
    }

    private var friendRequestsSheetBinding: Binding<GridSheet?> {
        Binding(
            get: { editViewModel.presentedGridSheet == .friendRequests ? .friendRequests : nil },
            set: { editViewModel.presentedGridSheet = $0 }
        )
    }

    private var isSendDisabled: Bool {
        // A message is optional — picking at least one friend is enough to send.
        if !editViewModel.sendToFriendUsernames.isEmpty {
            return false
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

            if isOnboarding {
                // No 5-second auto-timeout back to a grid onboarding never shows — the success
                // state stays up, and the caller (onboardingSendCompleted) brings back the shared
                // onboarding footer's Continue button in its place.
                await MainActor.run {
                    withAnimation(.snappy) {
                        editViewModel.presentedSheetActivity = nil
                        editViewModel.successMessage = "It's live! Swipe up!!!"
                    }
                    onboardingSendCompleted?()
                }
                return
            }

            let message = sendSuccessMessage()
            // Close only the sheet and show the success state in place of the toolbar buttons —
            // still on the editing screen at this point, not back in the list yet.
            await MainActor.run {
                withAnimation(.snappy) {
                    editViewModel.presentedSheetActivity = nil
                    editViewModel.successMessage = message
                }
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.snappy) {
                    editViewModel.successMessage = nil
                }
                closeSelectedActivity()
            }
        }
    }

    private var onboardingSendButton: some View {
        Button {
            Haptics.medium()
            sendSelectedActivity()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                Text("Send")
            }
            .fontWeight(.semibold)
            .foregroundStyle(.black)
        }
        .buttonStyle(.glassProminent)
        .tint(.yellow)
        .controlSize(.small)
        .disabled(isSendDisabled)
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
        if editViewModel.selectedActivityID == activity.id {
            withAnimation(animation) {
                editViewModel.selectedActivity = nil
                editViewModel.presentedSheetActivity = nil
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
            editViewModel.editSubSheet = .liveAction(actionID)
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private var isNavigationTitleHidden: Bool {
        editViewModel.geometry.isScrolledPastTop || isActivitySelected || editViewModel.isFriendPingSelected
    }

    private var isActivitySelected: Bool {
        editViewModel.isActivitySelected
    }

    private var activityTitleBinding: Binding<String> {
        Binding {
            editViewModel.draft.title
        } set: { newValue in
            editViewModel.draft.title = newValue
            editViewModel.saveDraft(store: store)
        }
    }

    // Called on every select()/close/send — including just tapping a card open to look at it, with
    // nothing edited. `saveDraft` is expensive (ActivityStore.activities' didSet does a full
    // Core Data delete-and-reinsert-everything plus rewrites every activity's images to disk), so
    // this must stay a genuine no-op when the title didn't actually need normalizing — it was
    // previously calling saveDraft unconditionally, turning "tap to open" into a full-store
    // rewrite on the main thread during the card's own opening animation.
    private func normalizeActivityTitle() {
        let trimmedTitle = editViewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, trimmedTitle != editViewModel.draft.title else { return }
        editViewModel.draft.title = trimmedTitle
        editViewModel.saveDraft(store: store)
    }

    private func defaultActivityTitle(for activity: ScheduledActivity) -> String {
        let oldestFirstCards = store.liveActivityCards.sorted { $0.createdAt < $1.createdAt }
        let activityNumber = (oldestFirstCards.firstIndex(where: { $0.id == activity.id }) ?? oldestFirstCards.count) + 1
        return "Activity #\(activityNumber)"
    }

    private var selectedActivityHeight: CGFloat {
        editViewModel.selectedCardHeight
    }

    @ViewBuilder
    private var screenBackground: some View {
        if isActivitySelected || editViewModel.isFriendPingSelected {
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
        isActivitySelected || editViewModel.isFriendPingSelected ? .black : schemeBackground
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
        max(700, editViewModel.geometry.containerSize.width * 1.72)
    }

    private var editingBottomBackgroundGlowSize: CGFloat {
        max(640, editViewModel.geometry.containerSize.width * 1.58)
    }

    private var animation: Animation {
        .interactiveSpring(response: 0.55, dampingFraction: 0.8)
    }
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
struct CardAnimationSlot<Content: View>: View {
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
                            Image(systemName: "ckeyboard.chevron.compact.down")
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

/// Isolates the NotificationCenter subscription for keyboard visibility into its own tiny view
/// (meant to be dropped into a `.background { }`) instead of chaining `.onReceive` directly onto
/// a large view's modifier list — keeps the subscription's own lifecycle self-contained, separate
/// from whatever big view happens to need the resulting value.
private struct KeyboardVisibilityReader: View {
    @Binding var isVisible: Bool

    var body: some View {
        #if canImport(UIKit)
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.snappy) {
                    isVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.snappy) {
                    isVisible = false
                }
            }
        #else
        Color.clear
        #endif
    }
}
