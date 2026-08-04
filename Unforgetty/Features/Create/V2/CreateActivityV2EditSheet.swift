import SwiftUI
import Combine
import EventKit
import CoreLocation
import MapKit

struct CreateActivityV2EditSheet: View {
    @EnvironmentObject private var store: ActivityStore
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    @Binding var copiedEditions: ActivityEditionsClipboard?
    // Onboarding reuses this exact sheet for its "create your first activity" step rather than a
    // simplified mock — this is the one behavioral difference it needs: the first activity always
    // goes live immediately, scheduling ahead is a Pro feature introduced right after on the
    // paywall step, so the "Fecha" toggle is disabled (not hidden — still visible so it isn't a
    // surprise once unlocked) rather than functional here.
    var isOnboarding: Bool = false
    @State private var selectedTab = CreateActivityV2EditTab.personalization
    @State private var tabScrollPosition: ScrollPosition = .init()
    @State private var tabContainerSize: CGSize = .zero
    @State private var showingStrictInfo = false
    @State private var showingBlurInfo = false
    @State private var showingScheduleInfo = false
    @State private var showingAlarmInfo = false
    @State private var showingLocationPicker = false

    var body: some View {
        VStack(spacing: 0) {
            CustomTabBar(
                selection: $selectedTab,
                selectedTextColor: .white,
                normalTextColor: .white.opacity(0.58),
                selectedTintColor: .white.opacity(0.16)
            ) { tab in
                scrollToTab(tab)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .background(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 1)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    sheetPage {
                        StyleEditorView(viewModel: viewModel) {
                            viewModel.saveDraft(store: store)
                        }
                    }

                    sheetPage {
                        if viewModel.draft.kind == .check(.todoList) {
                            strictModeEditor
                            remindersEditor
                            hideCompletedEditor
                        }
                        blurContentEditor
                        dynamicIslandEditor
                        scheduleEditor(isOnboarding: isOnboarding)
                        autoEndEditor
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition($tabScrollPosition)
            .onScrollGeometryChange(for: Int.self) {
                let progress = ($0.contentOffset.x + $0.contentInsets.leading) / max($0.containerSize.width, 1)
                return max(0, min(CreateActivityV2EditTab.allCases.count - 1, Int(progress.rounded())))
            } action: { _, newValue in
                let tabs = CreateActivityV2EditTab.allCases
                guard tabs.indices.contains(newValue), selectedTab != tabs[newValue] else { return }
                selectedTab = tabs[newValue]
            }
            .onScrollGeometryChange(for: CGSize.self) {
                $0.containerSize
            } action: { _, newValue in
                tabContainerSize = newValue
            }
        }
        .foregroundStyle(.white)
        .tint(.yellow)
        .preferredColorScheme(.dark)
        .background {
            sheetGlassBackground
        }
        .alert("No se ha podido enviar", isPresented: errorBinding) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
//        .overlay(alignment: .bottomTrailing) {
//            copyEditionsButton
//                .padding(20)
//        }
    }

    private func sheetPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .containerRelativeFrame(.horizontal)
    }

    private func scrollToTab(_ tab: CreateActivityV2EditTab) {
        guard tabContainerSize.width > 0 else { return }
        let index = CreateActivityV2EditTab.allCases.firstIndex(of: tab) ?? 0
        withAnimation(.easeInOut(duration: 0.25)) {
            tabScrollPosition.scrollTo(x: CGFloat(index) * tabContainerSize.width)
        }
    }

    private var strictModeEditor: some View {
        settingsGroup {
            HStack(spacing: 10) {
                Text("Modo estricto")
                    .font(.body.weight(.medium))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                infoButton(isPresented: $showingStrictInfo) {
                    Text("Con el modo estricto activado no podrás borrar esta actividad deslizando desde la lista de creadas.")
                }

                Spacer(minLength: 12)

                Toggle("", isOn: Binding(
                    get: { viewModel.draft.isStrict },
                    set: {
                        viewModel.draft.isStrict = $0
                        viewModel.saveDraft(store: store)
                    }
                ))
                .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private var blurContentEditor: some View {
        settingsGroup {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("Blur content")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .textCase(.uppercase)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    infoButton(isPresented: $showingBlurInfo) {
                        Text("Blur content oculta el contenido sensible. En notas puedes alternarlo tocando la Live Activity, dejarlo siempre visible, o activarlo cuando la pantalla siempre activa esté apagada.")
                    }

                    Spacer(minLength: 0)
                }

                Picker("Blur content", selection: Binding(
                    get: {
                        availableBlurContentModes.contains(viewModel.draft.blurContentMode)
                            ? viewModel.draft.blurContentMode
                            : .never
                    },
                    set: {
                        viewModel.draft.blurContentMode = $0
                        viewModel.saveDraft(store: store)
                    }
                )) {
                    ForEach(availableBlurContentModes) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // Per-activity, not a device-wide Settings toggle — carried along in FriendActivitySnapshot
    // too, so it's respected the same way whether this ends up as your own Live Activity or a
    // friend's ping.
    private var dynamicIslandEditor: some View {
        settingsGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dynamic Island")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)

                Picker("Dynamic Island", selection: Binding(
                    get: { viewModel.draft.isDynamicIslandEnabled },
                    set: {
                        viewModel.draft.isDynamicIslandEnabled = $0
                        viewModel.saveDraft(store: store)
                    }
                )) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var availableBlurContentModes: [BlurContentMode] {
        viewModel.draft.kind.isCheck
            ? [.never, .whenLuminanceReduced]
            : BlurContentMode.allCases
    }

    private var hideCompletedEditor: some View {
        settingsGroup {
            HStack(spacing: 10) {
                Text("Ocultar completadas")
                    .font(.body.weight(.medium))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 12)

                Toggle("", isOn: Binding(
                    get: { viewModel.draft.hideCompletedChecklistItems },
                    set: {
                        viewModel.draft.hideCompletedChecklistItems = $0
                        viewModel.saveDraft(store: store)
                    }
                ))
                .labelsHidden()
            }
        }
    }

    private var remindersEditor: some View {
        settingsGroup {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Sincronizar con Reminders")
                        .font(.body.weight(.medium))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    Spacer(minLength: 12)

                    Toggle("", isOn: Binding(
                        get: { viewModel.draft.syncWithReminders },
                        set: { viewModel.setRemindersSync($0, store: store) }
                    ))
                    .labelsHidden()
                }

                if viewModel.draft.syncWithReminders {
                    Picker("Lista", selection: Binding(
                        get: { viewModel.draft.reminderListID ?? "" },
                        set: { viewModel.setReminderList($0.isEmpty ? nil : $0, store: store) }
                    )) {
                        Text("Selecciona una lista").tag("")
                        ForEach(viewModel.reminderLists, id: \.calendarIdentifier) { list in
                            Text(list.title).tag(list.calendarIdentifier)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var copyEditionsButton: some View {
        if copiedEditions == nil {
            Button {
                copyEditions()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("Copiar ediciones")
        } else {
            Menu {
                Button("Copiar", systemImage: "doc.on.doc") {
                    copyEditions()
                }

                Button("Pegar", systemImage: "doc.on.clipboard") {
                    pasteEditions()
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("Ediciones")
        }
    }

    private func scheduleEditor(isOnboarding: Bool) -> some View {
        settingsGroup {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text("Programar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .textCase(.uppercase)

                    infoButton(isPresented: $showingScheduleInfo) {
                        Text("Programa esta actividad para enviarla automáticamente a la hora y días seleccionados.")
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    Text("Fecha")
                        .font(.body.weight(.medium))

                    Spacer(minLength: 12)

                    Toggle("", isOn: Binding(
                        get: { viewModel.isScheduling },
                        set: {
                            viewModel.toggleScheduling($0)
                            if $0 {
                                viewModel.activity.locationTriggerEnabled = false
                            }
                            viewModel.saveDraft(store: store)
                        }
                    ))
                    .labelsHidden()
                    .disabled(isOnboarding)
                }

                if viewModel.isScheduling {
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("Inicio", selection: Binding(
                            get: { viewModel.scheduleTime },
                            set: {
                                viewModel.scheduleTime = $0
                                viewModel.saveDraft(store: store)
                            }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)

                        WeekdaySelectorView(selection: viewModel.selectedWeekdays) { weekday in
                            viewModel.toggleWeekday(weekday)
                            viewModel.saveDraft(store: store)
                        }

                        Text(viewModel.selectedWeekdays.isEmpty
                             ? "Se enviará una sola vez, en esa fecha y hora."
                             : "Se repite cada semana en los días marcados.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))

                        if !viewModel.selectedWeekdays.isEmpty {
                            HStack(spacing: 10) {
                                Text("Hasta")
                                    .font(.body.weight(.medium))

                                Spacer(minLength: 12)

                                Toggle("", isOn: Binding(
                                    get: { viewModel.scheduleEndDate != nil },
                                    set: { isOn in
                                        viewModel.setScheduleEndDate(isOn ? Calendar.current.date(byAdding: .month, value: 1, to: viewModel.scheduleTime) : nil)
                                        viewModel.saveDraft(store: store)
                                    }
                                ))
                                .labelsHidden()
                            }

                            if let endDate = viewModel.scheduleEndDate {
                                DatePicker("Fecha de fin", selection: Binding(
                                    get: { endDate },
                                    set: {
                                        viewModel.setScheduleEndDate($0)
                                        viewModel.saveDraft(store: store)
                                    }
                                ), displayedComponents: .date)
                                .datePickerStyle(.compact)
                            }
                        }

                        HStack(spacing: 10) {
                            Text("Alarma")
                                .font(.body.weight(.medium))
                                .foregroundStyle(viewModel.sendToFriendUsernames.isEmpty ? .primary : .secondary)

                            infoButton(isPresented: $showingAlarmInfo) {
                                Text("También sonará una alarma a la hora de inicio, para obligarte a mirar el móvil. Todavía no implementado — placeholder.")
                            }

                            Spacer(minLength: 12)

                            Toggle("", isOn: Binding(
                                get: { viewModel.activity.alarmEnabled },
                                set: {
                                    viewModel.activity.alarmEnabled = $0
                                    viewModel.saveDraft(store: store)
                                }
                            ))
                            .labelsHidden()
                            .disabled(!viewModel.sendToFriendUsernames.isEmpty)
                        }

                        if !viewModel.sendToFriendUsernames.isEmpty {
                            Text("La alarma no está disponible al enviar a un amigo.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Divider()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                locationEditor(isOnboarding: isOnboarding)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var autoEndEditor: some View {
        settingsGroup {
            VStack(alignment: .leading, spacing: 16) {
                Text("Autoeliminar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)

                HStack(spacing: 10) {
                    Text("Duración")
                        .font(.body.weight(.medium))

                    Spacer(minLength: 12)

                    Menu {
                        ForEach(CreateActivityV2EditViewModel.autoEndDurationOptions, id: \.seconds) { option in
                            Button(option.title) {
                                viewModel.activity.autoEndDuration = option.seconds
                                viewModel.saveDraft(store: store)
                            }
                        }
                    } label: {
                        Text(CreateActivityV2EditViewModel.autoEndDurationTitle(for: viewModel.activity.autoEndDuration))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }


    private func locationEditor(isOnboarding: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("Localización")
                    .font(.body.weight(.medium))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 12)

                Toggle("", isOn: Binding(
                    get: { viewModel.activity.locationTriggerEnabled },
                    set: {
                        viewModel.activity.locationTriggerEnabled = $0
                        if $0 {
                            viewModel.toggleScheduling(false)
                            LocationActivityMonitor.shared.requestAuthorization()
                        }
                        viewModel.saveDraft(store: store)
                    }
                ))
                .labelsHidden()
                .disabled(isOnboarding)
            }

            if viewModel.activity.locationTriggerEnabled {
                Button {
                    showingLocationPicker = true
                } label: {
                    HStack {
                        Text(hasSelectedLocation ? "Cambiar ubicación" : "Elegir ubicación")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                if hasSelectedLocation {
                    Text("Ubicación seleccionada")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            ActivityLocationPicker(
                latitude: Binding(
                    get: { viewModel.activity.locationLatitude },
                    set: {
                        viewModel.activity.locationLatitude = $0
                        viewModel.saveDraft(store: store)
                    }
                ),
                longitude: Binding(
                    get: { viewModel.activity.locationLongitude },
                    set: {
                        viewModel.activity.locationLongitude = $0
                        viewModel.saveDraft(store: store)
                    }
                )
            )
        }
    }

    private var hasSelectedLocation: Bool {
        viewModel.activity.locationLatitude != nil && viewModel.activity.locationLongitude != nil
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private func infoButton<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder message: @escaping () -> Content
    ) -> some View {
        Button {
            isPresented.wrappedValue = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 28, height: 28)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .popover(isPresented: isPresented) {
            message()
                .font(.footnote)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .frame(width: 300, alignment: .leading)
                .background(.black.opacity(0.86))
                .preferredColorScheme(.dark)
                .presentationCompactAdaptation(.popover)
        }
    }

    @ViewBuilder
    private var sheetGlassBackground: some View {
        if #available(iOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: .rect(cornerRadius: 30, style: .continuous))
                .ignoresSafeArea()
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }

    private func copyEditions() {
        copiedEditions = ActivityEditionsClipboard(viewModel: viewModel)
    }

    private func pasteEditions() {
        guard let copiedEditions else { return }
        copiedEditions.apply(to: viewModel)
        viewModel.saveDraft(store: store)
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.clearError()
            }
        }
    }

}

private struct ActivityLocationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @State private var position: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    init(latitude: Binding<Double?>, longitude: Binding<Double?>) {
        self._latitude = latitude
        self._longitude = longitude

        let coordinate = CLLocationCoordinate2D(
            latitude: latitude.wrappedValue ?? 40.4168,
            longitude: longitude.wrappedValue ?? -3.7038
        )
        self._selectedCoordinate = State(initialValue: latitude.wrappedValue != nil && longitude.wrappedValue != nil ? coordinate : nil)
        self._position = State(initialValue: .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        ))
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let selectedCoordinate {
                        MapCircle(center: selectedCoordinate, radius: 500)
                            .foregroundStyle(.yellow.opacity(0.12))
                            .stroke(.yellow.opacity(0.7), lineWidth: 1)

                        Marker("Inicio", coordinate: selectedCoordinate)
                            .tint(.yellow)
                    }
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    selectedCoordinate = coordinate
                    isSearchFocused = false
                }
                .overlay(alignment: .bottom) {
                    Text(selectedCoordinate == nil ? "Toca el mapa para elegir una ubicación" : "Ubicación seleccionada")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(.bottom, 18)
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.6))

                            TextField("Buscar dirección o lugar", text: $searchText)
                                .foregroundStyle(.white)
                                .focused($isSearchFocused)
                                .onChange(of: searchText) {
                                    searchCompleter.update(query: searchText)
                                }

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    searchCompleter.results = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: .capsule)

                        if isSearchFocused, !searchCompleter.results.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(searchCompleter.results, id: \.title) { result in
                                    Button {
                                        selectCompletion(result)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                                .foregroundStyle(.white)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.55))
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)

                                    if result.title != searchCompleter.results.last?.title {
                                        Divider().overlay(.white.opacity(0.12))
                                    }
                                }
                            }
                            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14, style: .continuous))
                            .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Localización")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let selectedCoordinate {
                            latitude = selectedCoordinate.latitude
                            longitude = selectedCoordinate.longitude
                        }
                        dismiss()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isSearchFocused = false
        searchText = completion.title
        let request = MKLocalSearch.Request(completion: completion)
        Task {
            guard let response = try? await MKLocalSearch(request: request).start(),
                  let coordinate = response.mapItems.first?.placemark.coordinate else { return }
            selectedCoordinate = coordinate
            searchCompleter.results = []
            withAnimation(.snappy) {
                position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
            }
        }
    }
}

@MainActor
private final class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

private enum CreateActivityV2EditTab: String, CustomTabBarItem {
    case personalization = "Personalization"
    case settings = "Settings"

    var title: String { rawValue }
}

struct ActivityEditionsClipboard: Hashable {
    var kind: ActivityKind
    var style: ActivityStyle
    var isStrict: Bool
    var blurContentMode: BlurContentMode
    var isScheduling: Bool
    var selectedWeekdays: Set<Weekday>
    var scheduleTime: Date

    init(viewModel: CreateActivityV2EditViewModel) {
        kind = viewModel.draft.kind
        style = viewModel.draft.style
        isStrict = viewModel.draft.isStrict
        blurContentMode = viewModel.draft.blurContentMode
        isScheduling = viewModel.isScheduling
        selectedWeekdays = viewModel.selectedWeekdays
        scheduleTime = viewModel.scheduleTime
    }

    /// Lets "Copiar" on a received friend ping feed the same clipboard used to paste style/editions
    /// between local activities — the received card has no `CreateActivityV2EditViewModel` of its
    /// own to build from.
    init(snapshot: FriendActivitySnapshot) {
        kind = snapshot.kind == "music" ? .music : .note
        style = ActivityStyle(snapshot: snapshot)
        isStrict = false
        blurContentMode = .never
        isScheduling = false
        selectedWeekdays = []
        scheduleTime = .now
    }

    @MainActor
    func apply(to viewModel: CreateActivityV2EditViewModel) {
        viewModel.setKind(kind)
        viewModel.draft.style = style
        viewModel.draft.isStrict = isStrict
        viewModel.draft.blurContentMode = blurContentMode
        viewModel.isScheduling = isScheduling
        viewModel.selectedWeekdays = selectedWeekdays
        viewModel.scheduleTime = scheduleTime
        viewModel.activity.recurrence = isScheduling ? selectedWeekdays : []
        viewModel.activity.startDate = scheduleTime
    }
}
