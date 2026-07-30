import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CreateActivityView: View {
    @StateObject private var viewModel = CreateActivityViewModel()
    @Binding var progress: CGFloat
    @EnvironmentObject private var store: ActivityStore
    @State private var currentPage: CreatePage? = .liveActivity
    @State private var editingPage: CreatePage?
//    @State private var showingSchedulePopover = false
    @State private var isKeyboardVisible = false
    @State private var editDrawerHeight: CGFloat = 0
    @State private var visibleContentHeight: CGFloat = 0
    private let actionBarSlotHeight: CGFloat = 44

    var body: some View {
        CreateActivityV2View(progress: $progress)
    }

    @ViewBuilder
    private var legacyBody: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    NewActivityPageView(
                        viewModel: viewModel,
                        progress: $progress,
                        bottomInset: bottomReservedHeight,
                        isEditing: editingPage != nil,
                        isVisible: visiblePage == .liveActivity,
                        visibleContentHeight: $visibleContentHeight
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(CreatePage.liveActivity)

                    NotificationPageView(
                        viewModel: viewModel,
                        bottomInset: bottomReservedHeight,
                        isEditing: editingPage != nil,
                        isVisible: visiblePage == .notification,
                        visibleContentHeight: $visibleContentHeight
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(CreatePage.notification)

//                    CreatePlaceholderPage(
//                        page: .widget,
//                        bottomInset: bottomReservedHeight,
//                        isVisible: visiblePage == .widget,
//                        visibleContentHeight: $visibleContentHeight
//                    )
//                    .containerRelativeFrame(.horizontal)
//                    .id(CreatePage.widget)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $currentPage)
            .scrollDisabled(editingPage != nil)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isKeyboardVisible {
                        Button {
                            withAnimation(.snappy) {
                                toggleEditingForCurrentPage()
                            }
                        } label: {
                            Image(systemName: editingPage == nil ? "clock" : "xmark")
                        }
                        .editingButtonStyle(editingPage != nil)
                        .editingActiveTint(editingPage != nil)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button {
                        dismissKeyboard()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .padding(.vertical, 8)
                }
            }
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    normalControlsOverlay
                        .opacity(areActionControlsVisible ? 1 : 0)
                        .blur(radius: areActionControlsVisible ? 0 : 10)
                        .allowsHitTesting(areActionControlsVisible)
                        .animation(.snappy, value: areActionControlsVisible)

                    if editingPage == nil {
                        pageIndicator
                            .padding(.bottom, 8)
                    }

                }
            }
            .overlay(alignment: .bottom) {
                if let editingPage {
                    GeometryReader { proxy in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)

                            editModeDrawer(for: editingPage)
                                .readMeasuredHeight($editDrawerHeight)
                                .transition(.move(edge: .bottom))
                                .padding(.bottom, -proxy.safeAreaInsets.bottom)
                        }
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .trackKeyboardVisibility(
                isKeyboardVisible: $isKeyboardVisible,
                editingPage: $editingPage
            )
        }
    }

    private var areActionControlsVisible: Bool {
        editingPage == nil && !isKeyboardVisible
    }

    private var bottomReservedHeight: CGFloat {
        editingPage == nil ? normalControlsHeight : max(editDrawerHeight, 400)
    }

    private var normalControlsHeight: CGFloat {
        actionBarSlotHeight
    }

    private var normalControlsOverlay: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Color.clear
                .frame(maxWidth: .infinity)
                .frame(minHeight: visibleContentHeight == 0 ? 44 : visibleContentHeight)
                .frame(height: visibleContentHeight == 0 ? 44 : visibleContentHeight)
                .accessibilityHidden(true)

            Color.clear
                .frame(height: 18)
                .accessibilityHidden(true)

            actionBar
                .padding(.horizontal, 18)
                .frame(height: actionBarSlotHeight)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy, value: visiblePage)
        .animation(.snappy, value: visibleContentHeight)
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(CreatePage.visibleCases) { page in
                Button {
                    withAnimation(.snappy) {
                        currentPage = page
                    }
                } label: {
                    Capsule()
                        .fill(page == visiblePage ? Color.primary : Color.secondary.opacity(0.28))
                        .frame(width: page == visiblePage ? 18 : 6, height: 6)
                }
                .buttonStyle(.plain)
                .disabled(editingPage != nil)
                .accessibilityLabel(page.title)
                .accessibilityAddTraits(page == visiblePage ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: .capsule)
        .animation(.snappy, value: visiblePage)
    }

    private var visiblePage: CreatePage {
        currentPage ?? .liveActivity
    }

    private var actionBar: some View {
        DraftActionBarView(viewModel: viewModel, showsChecklistMenu: visiblePage != .notification) {
            HStack(spacing: 10) {
//                Button {
//                    viewModel.toggleScheduling(!viewModel.isScheduling)
//                    showingSchedulePopover = true
//                } label: {
//                    Image(systemName: "clock")
//                        .font(.body.weight(.semibold))
//                        .foregroundStyle(viewModel.isScheduling ? Color.accentColor : .primary)
//                        .padding(13)
//                        .circularLiquidGlass(viewModel.isScheduling ? Color.accentColor.opacity(0.32) : Color.white.opacity(0.18))
//                }
//                .contentShape(.circle)
//                .popover(isPresented: $showingSchedulePopover) {
//                    VStack(spacing: 14) {
//                        WeekdaySelectorView(selection: viewModel.selectedWeekdays, onToggle: viewModel.toggleWeekday)
//                        DatePicker("Hora", selection: $viewModel.scheduleTime, displayedComponents: .hourAndMinute)
//                    }
//                    .padding()
//                    .frame(width: 280)
//                    .presentationCompactAdaptation(.popover)
//                }

                BubbleActionButton.send {
                    Task { await viewModel.send(store: store, surface: visiblePage.activitySurface) }
                }
                .disabled(!viewModel.draft.isValid || (viewModel.isScheduling && viewModel.selectedWeekdays.isEmpty))
            }
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func toggleEditingForCurrentPage() {
        if editingPage != nil {
            editingPage = nil
        } else {
            editingPage = currentPage ?? .liveActivity
        }
    }

    private func editModeDrawer(for page: CreatePage) -> some View {
        ScrollView(.vertical) {
            editModeContent(for: page)
                .padding(.horizontal, 24)
                .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400, alignment: .top)
        .editModeDrawerGlass()
    }

    @ViewBuilder
    private func editModeContent(for page: CreatePage) -> some View {
        switch page {
        case .liveActivity:
            VStack(spacing: 16) {
                StyleEditorView(viewModel: viewModel)
                scheduleEditor
            }
        case .notification:
            VStack(spacing: 16) {
                scheduleEditor

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        case .widget:
            VStack(spacing: 16) {
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        }
    }

    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Programar", isOn: Binding(
                get: { viewModel.isScheduling },
                set: { viewModel.toggleScheduling($0) }
            ))

            if viewModel.isScheduling {
                WeekdaySelectorView(selection: viewModel.selectedWeekdays, onToggle: viewModel.toggleWeekday)

                DatePicker("Hora", selection: $viewModel.scheduleTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    @ViewBuilder
    func editModeDrawerGlass() -> some View {
        let shape = UnevenRoundedRectangle(cornerRadii: .init(topLeading: 28, topTrailing: 28))

        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(Color.white.opacity(0.16)), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    func readMeasuredHeight(_ height: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: MeasuredHeightPreferenceKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(MeasuredHeightPreferenceKey.self) { height.wrappedValue = $0 }
    }

    func readActiveMeasuredHeight(isActive: Bool, height: Binding<CGFloat>) -> some View {
        modifier(ActiveMeasuredHeightModifier(isActive: isActive, height: height))
    }

    @ViewBuilder
    func editingButtonStyle(_ isEditing: Bool) -> some View {
        if isEditing {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.glass)
        }
    }

    @ViewBuilder
    func editingActiveTint(_ isEditing: Bool) -> some View {
        if isEditing {
            self.tint(.red)
        } else {
            self
                
        }
    }

    @ViewBuilder
    func trackKeyboardVisibility(isKeyboardVisible: Binding<Bool>, editingPage: Binding<CreatePage?>) -> some View {
        #if canImport(UIKit)
        self
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.snappy) {
                    isKeyboardVisible.wrappedValue = true
                    editingPage.wrappedValue = nil
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

private struct ActiveMeasuredHeightModifier: ViewModifier {
    let isActive: Bool
    @Binding var height: CGFloat
    @State private var measuredHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: MeasuredHeightPreferenceKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(MeasuredHeightPreferenceKey.self) { newValue in
                measuredHeight = newValue
                updateHeightIfActive(newValue)
            }
            .onChange(of: isActive) {
                updateHeightIfActive(measuredHeight)
            }
    }

    private func updateHeightIfActive(_ newValue: CGFloat) {
        guard isActive else { return }
        withAnimation(.snappy) {
            height = newValue
        }
    }
}

private struct MeasuredHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum CreatePage: CaseIterable, Identifiable {
    case liveActivity
    case notification
    case widget

    var id: Self { self }

    static var visibleCases: [Self] {
        [.liveActivity, .notification]
    }

    var title: String {
        switch self {
        case .liveActivity: "Live Activity"
        case .notification: "Notification"
        case .widget: "Widget"
        }
    }

    var activitySurface: ActivitySurface {
        switch self {
        case .liveActivity: .liveActivity
        case .notification: .notification
        case .widget: .widget
        }
    }
}

private struct CreatePlaceholderPage: View {
    let page: CreatePage
    let bottomInset: CGFloat
    let isVisible: Bool
    @Binding var visibleContentHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(page.title)
                .font(.title2.weight(.semibold))
                .readActiveMeasuredHeight(isActive: isVisible, height: $visibleContentHeight)

            Spacer(minLength: 0)

            Color.clear
                .frame(height: bottomInset)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NotificationPageView<VM: DraftEditingViewModel>: View {
    @ObservedObject var viewModel: VM
    let bottomInset: CGFloat
    let isEditing: Bool
    let isVisible: Bool
    @Binding var visibleContentHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            NotificationPreviewCard(draft: viewModel.draft)
                .readActiveMeasuredHeight(isActive: isVisible, height: $visibleContentHeight)

            if isEditing {
                Spacer(minLength: 0)
            } else {
                Color.clear
                    .frame(height: 18)
                    .accessibilityHidden(true)
            }

            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .accessibilityHidden(true)

            if isEditing {
                Color.clear
                    .frame(height: max(0, bottomInset - 44))
                    .accessibilityHidden(true)
            }

            if !isEditing {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NotificationPreviewCard: View {
    let draft: LiveActivityDraft

    var body: some View {
        HStack(spacing: 0) {
            Text(notificationText)
                .font(.system(size: notificationTextSize, weight: .medium, design: draft.style.fontDesign))
                .foregroundStyle(Color(hex: draft.style.textHex))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: contentAlignment)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .liquidGlassCard(tint: Color(hex: draft.style.backgroundHex), cornerRadius: 20)
        .overlay(alignment: .topTrailing) {
            notificationBadge
                .offset(x: 8, y: -10)
        }
    }

    private var notificationText: String {
        if draft.kind == .note {
            let trimmed = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Don't forget passport" : trimmed
        }

        return draft.checklistItems
            .map(\.text)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? "Tarea"
    }

    private var notificationTextSize: CGFloat {
        max(15, CGFloat(draft.style.textSize) * 0.52)
    }

    private var contentAlignment: Alignment {
        Alignment(horizontal: draft.style.horizontalAlignment, vertical: .center)
    }

    private var notificationBadge: some View {
        ZStack {
            Circle()
                .fill(.red.opacity(0.45))
                .frame(width: 52, height: 52)
                .blur(radius: 14)

            Text("1")
                .font(.callout.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.red, in: .circle)
        }
    }
}
