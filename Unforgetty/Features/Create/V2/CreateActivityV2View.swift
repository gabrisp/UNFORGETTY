import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CreateActivityV2View: View {
    @Binding var progress: CGFloat
    @EnvironmentObject private var store: ActivityStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var editViewModel = CreateActivityV2EditViewModel()
    @State private var selectedActivity: ScheduledActivity?
    @State private var presentedSheetActivity: ScheduledActivity?
    @State private var isKeyboardVisible = false
    @State private var cardHeights: [UUID: CGFloat] = [:]
    @State private var info = Info()
    @State private var isShowingPremium = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(store.liveActivityCards) { activity in
                        SavedLiveActivityCardView(activity: activity)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(15)
            .scrollDisabled(isActivitySelected)
            .navigationTitle(isNavigationTitleHidden ? "" : "Unforgetty")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isActivitySelected {
                        Button("Close", systemImage: "xmark") {
                            closeSelectedActivity()
                        }
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isActivitySelected {
                        Button {
                            Task {
                                let didSend = await editViewModel.send(store: store)
                                guard didSend else { return }
                                await MainActor.run {
                                    closeSelectedActivity()
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.yellow)
                        .disabled(!editViewModel.draft.isValid || (editViewModel.isScheduling && editViewModel.selectedWeekdays.isEmpty))
                    } else {
                        Button("Add", systemImage: "plus") {
                            withAnimation(animation) {
                                select(store.createLiveActivityDraft())
                            }
                        }

                        Button("Upgrade", systemImage: "crown.fill") {
                            isShowingPremium = true
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .tint(.yellow)
                    }
                }

            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { _, newValue in
                info.scrollOffset = newValue
            }
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).minY
            } action: { newValue in
                info.minY = newValue - info.safeArea.top
            }
            .background(Color.secondarybg)
            .task {
                store.ensureInitialLiveActivityDraft()
            }
        }
        .sheet(isPresented: $isShowingPremium) {
            PremiumView()
        }
        .sheet(item: $presentedSheetActivity) { activity in
            let spacing: CGFloat = 20
            let isSafeAreaiPhone = info.safeArea.bottom > 0
            let minSheetHeight = info.containerSize.height - info.minY - (selectedActivitySlotHeight + spacing)
            let maxSheetHeight = info.containerSize.height - info.minY + (isSafeAreaiPhone ? 15 : 10)

            CreateActivityV2EditSheet(viewModel: editViewModel)
                .presentationDetents([.height(minSheetHeight), .height(maxSheetHeight)])
                .presentationBackgroundInteraction(.enabled(upThrough: .height(maxSheetHeight)))
                .interactiveDismissDisabled()
                .presentationBackground(schemeBackground)
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
        .onChange(of: editViewModel.activity) {
            guard selectedActivityID == editViewModel.activity.id else { return }
            selectedActivity = editViewModel.activity
            if presentedSheetActivity != nil {
                presentedSheetActivity = editViewModel.activity
            }
            editViewModel.saveDraft(store: store)
        }
        .trackKeyboardVisibility(
            isKeyboardVisible: $isKeyboardVisible,
            presentedSheetActivity: $presentedSheetActivity,
            selectedActivity: $selectedActivity
        )
    }

    @ViewBuilder
    private func SavedLiveActivityCardView(activity: ScheduledActivity) -> some View {
        let isCurrent = activity.id == selectedActivityID
        let currentIndex = store.liveActivityCards.firstIndex(where: { $0.id == activity.id }) ?? 0
        let selectedActivityIndex = store.liveActivityCards.firstIndex(where: { $0.id == selectedActivityID }) ?? 0

        cardContent(activity: activity, isCurrent: isCurrent)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: { newValue in
                cardHeights[activity.id] = newValue
            }
            .contentShape(.rect)
            .onTapGesture {
                withAnimation(animation) {
                    select(activity)
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    deleteActivity(activity)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .visualEffect { [info, isActivitySelected] content, proxy in
                let rect = proxy.frame(in: .scrollView)
                let bounds = info.containerSize
                let centeredSelectedOffset = selectedActivityTopOffset - rect.minY
                let hiddenCardOffset = bounds.height - rect.minY
                let pushOffset = isCurrent ? centeredSelectedOffset : hiddenCardOffset

                return content
                    .scaleEffect(isActivitySelected && !isCurrent ? 0.95 : 1, anchor: .top)
                    .offset(y: isActivitySelected ? pushOffset : 0)
                    .opacity(isActivitySelected && !isCurrent ? 0 : 1)
            }
            .allowsHitTesting(isActivitySelected ? isCurrent : true)
            .disabled(isActivitySelected && !isCurrent)
            .padding(.top, cardTopPadding(activity: activity, index: currentIndex))
    }

    @ViewBuilder
    private func cardContent(activity: ScheduledActivity, isCurrent: Bool) -> some View {
        if isCurrent {
            LivePreviewView(viewModel: editViewModel)
        } else {
            ActivityPreviewView(draft: activity.draft)
        }
    }

    private func select(_ activity: ScheduledActivity) {
        editViewModel.load(activity)
        selectedActivity = activity
        if !isKeyboardVisible {
            presentedSheetActivity = activity
        }
    }

    private func closeSelectedActivity() {
        store.discardEmptyLiveActivityDraft(editViewModel.activity)
        withAnimation(animation) {
            selectedActivity = nil
            presentedSheetActivity = nil
        }
    }

    private func deleteActivity(_ activity: ScheduledActivity) {
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
                    cardHeights.removeValue(forKey: activity.id)
                }
            }
        }
    }

    private var isNavigationTitleHidden: Bool {
        info.scrollOffset > 1 || isActivitySelected
    }

    private var isActivitySelected: Bool {
        selectedActivityID != nil
    }

    private var selectedActivityID: UUID? {
        selectedActivity?.id
    }

    private var selectedActivityHeight: CGFloat {
        guard let selectedActivityID else { return 220 }
        return cardHeights[selectedActivityID] ?? 220
    }

    private var selectedActivitySlotHeight: CGFloat {
        max(220, selectedActivityHeight)
    }

    private var selectedActivityTopOffset: CGFloat {
        max(0, (selectedActivitySlotHeight - selectedActivityHeight) / 2)
    }

    private func cardTopPadding(activity: ScheduledActivity, index: Int) -> CGFloat {
        guard index > 0, !isActivitySelected else { return 0 }
        let height = cardHeights[activity.id] ?? 220
        return -(height * 0.4)
    }

    private var schemeBackground: Color {
        colorScheme == .dark ? .black : .white
    }

    private var animation: Animation {
        .interactiveSpring(response: 0.55, dampingFraction: 0.8)
    }

    private struct Info {
        var scrollOffset: CGFloat = 0
        var containerSize: CGSize = .zero
        var safeArea: EdgeInsets = .init()
        var minY: CGFloat = 0
    }
}

private extension View {
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
                    presentedSheetActivity.wrappedValue = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.snappy) {
                    isKeyboardVisible.wrappedValue = false
                    presentedSheetActivity.wrappedValue = selectedActivity.wrappedValue
                }
            }
        #else
        self
        #endif
    }
}
