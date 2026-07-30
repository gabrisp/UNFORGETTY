import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

nonisolated struct UnforgettyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var phase: String; var notificationID: String }
    var notificationID: String
}

struct WidgetChecklistItem: Codable, Identifiable { var id: UUID; var text: String; var isCompleted: Bool }
struct WidgetTag: Codable, Identifiable { var id: UUID; var name: String }
struct WidgetStyle: Codable { var backgroundHex: String; var textHex: String; var backgroundMode: String?; var font: String; var textSize: Double; var alignment: String }
struct WidgetDraft: Codable { var id: UUID?; var kind: String; var title: String; var body: String; var noteIsCompleted: Bool; var checklistItems: [WidgetChecklistItem]; var tags: [WidgetTag]?; var isStrict: Bool; var style: WidgetStyle }
struct WidgetActivity: Codable { var id: UUID; var notificationID: String; var surface: String?; var draft: WidgetDraft; var startDate: Date?; var endDate: Date?; var recurrence: Set<Int>?; var status: String?; var liveActivityID: String?; var createdAt: Date? }

nonisolated enum WidgetContentStore {
    static let defaults = UserDefaults(suiteName: "group.com.gabrisp.Unforgetty") ?? .standard
    static func draft(for notificationID: String) -> WidgetDraft? {
        guard let data = defaults.data(forKey: "activities.v1"), let values = try? JSONDecoder().decode([WidgetActivity].self, from: data) else { return nil }
        return values.first(where: { $0.notificationID == notificationID })?.draft
    }
    static func toggle(itemID: UUID, notificationID: String) {
        guard let data = defaults.data(forKey: "activities.v1"), var values = try? JSONDecoder().decode([WidgetActivity].self, from: data), let activity = values.firstIndex(where: { $0.notificationID == notificationID }), let item = values[activity].draft.checklistItems.firstIndex(where: { $0.id == itemID }) else { return }
        values[activity].draft.checklistItems[item].isCompleted.toggle()
        defaults.set(try? JSONEncoder().encode(values), forKey: "activities.v1")
    }
    static func remove(itemID: UUID, notificationID: String) {
        guard let data = defaults.data(forKey: "activities.v1"), var values = try? JSONDecoder().decode([WidgetActivity].self, from: data), let activity = values.firstIndex(where: { $0.notificationID == notificationID }) else { return }
        guard values[activity].draft.checklistItems.count > 1 else { return }
        values[activity].draft.checklistItems.removeAll { $0.id == itemID }
        defaults.set(try? JSONEncoder().encode(values), forKey: "activities.v1")
    }
    static func completeNote(notificationID: String) {
        guard let data = defaults.data(forKey: "activities.v1"), var values = try? JSONDecoder().decode([WidgetActivity].self, from: data), let index = values.firstIndex(where: { $0.notificationID == notificationID }) else { return }
        values[index].draft.noteIsCompleted = true
        defaults.set(try? JSONEncoder().encode(values), forKey: "activities.v1")
    }
}

nonisolated enum WidgetLiveActivityRefresher {
    static func refresh(notificationID: String) async {
        for activity in Activity<UnforgettyActivityAttributes>.activities where activity.attributes.notificationID == notificationID {
            await activity.update(ActivityContent(state: .init(phase: UUID().uuidString, notificationID: notificationID), staleDate: nil))
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

nonisolated struct ToggleChecklistItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Completar tarea"
    static var openAppWhenRun = false
    @Parameter(title: "Actividad") var notificationID: String
    @Parameter(title: "Tarea") var itemID: String
    init() { notificationID = ""; itemID = "" }
    init(notificationID: String, itemID: UUID) { self.notificationID = notificationID; self.itemID = itemID.uuidString }
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: itemID) else { return .result() }
        WidgetContentStore.toggle(itemID: id, notificationID: notificationID)
        await WidgetLiveActivityRefresher.refresh(notificationID: notificationID)
        return .result()
    }
}

nonisolated struct RemoveChecklistItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Eliminar tarea"
    static var openAppWhenRun = false
    @Parameter(title: "Actividad") var notificationID: String
    @Parameter(title: "Tarea") var itemID: String
    init() { notificationID = ""; itemID = "" }
    init(notificationID: String, itemID: UUID) { self.notificationID = notificationID; self.itemID = itemID.uuidString }
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: itemID) else { return .result() }
        WidgetContentStore.remove(itemID: id, notificationID: notificationID)
        await WidgetLiveActivityRefresher.refresh(notificationID: notificationID)
        return .result()
    }
}

nonisolated struct CompleteNoteIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Marcar nota como hecha"
    static var openAppWhenRun = false
    @Parameter(title: "Actividad") var notificationID: String
    init() { notificationID = "" }
    init(notificationID: String) { self.notificationID = notificationID }
    func perform() async throws -> some IntentResult {
        WidgetContentStore.completeNote(notificationID: notificationID)
        await WidgetLiveActivityRefresher.refresh(notificationID: notificationID)
        return .result()
    }
}

struct UnforgettyWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UnforgettyActivityAttributes.self) { context in
            let draft = WidgetContentStore.draft(for: context.attributes.notificationID)
            LockScreenActivityView(notificationID: context.attributes.notificationID)
                .activityBackgroundTint(Color(hex: draft?.style.backgroundHex ?? "172033").opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { _ in
            // v1 deliberately has no Dynamic Island presentation.
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { EmptyView() }
            } compactLeading: { EmptyView() } compactTrailing: { EmptyView() } minimal: { EmptyView() }
        }
    }
}

private struct UnforgettyHomeWidgetEntry: TimelineEntry {
    let date: Date
}

private struct UnforgettyHomeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> UnforgettyHomeWidgetEntry {
        UnforgettyHomeWidgetEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (UnforgettyHomeWidgetEntry) -> Void) {
        completion(UnforgettyHomeWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UnforgettyHomeWidgetEntry>) -> Void) {
        let entry = UnforgettyHomeWidgetEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private struct UnforgettyHomeWidget: Widget {
    private let kind = "com.gabrisp.Unforgetty.Widget.home"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UnforgettyHomeWidgetProvider()) { entry in
            UnforgettyHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("Unforgetty")
        .description("Acceso rapido a tus actividades.")
        .supportedFamilies([.systemSmall])
    }
}

private struct UnforgettyHomeWidgetView: View {
    let entry: UnforgettyHomeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checklist.checked")
                .font(.title2.weight(.semibold))

            Text("Unforgetty")
                .font(.headline)

            Text("Crea una actividad para verla en directo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct LockScreenActivityView: View {
    let notificationID: String
    private var draft: WidgetDraft? { WidgetContentStore.draft(for: notificationID) }
    var body: some View {
        if let draft {
            VStack(alignment: draft.style.horizontalAlignment, spacing: 14) {
                if draft.kind == "note" {
                    Text(noteText(for: draft))
                        .font(.system(size: draft.style.textSize))
                        .multilineTextAlignment(draft.style.textAlignment)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                        .opacity(isNotePlaceholder(draft) ? 0.45 : 1)
                }
                else {
                    if displayedChecklistItems(for: draft).count == 6 {
                        HStack(alignment: .top, spacing: 18) {
                            checklistColumn(Array(displayedChecklistItems(for: draft).prefix(3)), draft: draft)
                            checklistColumn(Array(displayedChecklistItems(for: draft).suffix(3)), draft: draft)
                        }
                        .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                    } else {
                        checklistColumn(displayedChecklistItems(for: draft), draft: draft)
                            .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                    }
                }
            }
            .foregroundStyle(Color(hex: draft.style.textHex))
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: 300, alignment: .topLeading)
            .clipped()
        } else { Text("Abre Unforgetty para recuperar esta actividad.").padding() }
    }

    private func checkbox(isCompleted: Bool, color: Color, textSize: Double) -> some View {
        let rowHeight = max(32, CGFloat(textSize) * 1.22)
        let size = min(rowHeight, max(24, CGFloat(textSize) * 1.08))

        return ZStack {
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: size, height: size)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.66, weight: .bold))
            }
        }
    }

    private func noteText(for draft: WidgetDraft) -> String {
        isNotePlaceholder(draft) ? "Note" : draft.body
    }

    private func isNotePlaceholder(_ draft: WidgetDraft) -> Bool {
        draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func checklistText(for item: WidgetChecklistItem) -> String {
        isChecklistPlaceholder(item) ? "To Do" : item.text
    }

    private func isChecklistPlaceholder(_ item: WidgetChecklistItem) -> Bool {
        item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func displayedChecklistItems(for draft: WidgetDraft) -> [WidgetChecklistItem] {
        Array(draft.checklistItems.prefix(6))
    }

    private func checklistColumn(_ items: [WidgetChecklistItem], draft: WidgetDraft) -> some View {
        VStack(alignment: draft.style.horizontalAlignment, spacing: 14) {
            ForEach(items) { item in
                checklistRow(item, draft: draft)
            }
        }
    }

    private func checklistRow(_ item: WidgetChecklistItem, draft: WidgetDraft) -> some View {
        Button(intent: ToggleChecklistItemIntent(notificationID: notificationID, itemID: item.id)) {
            HStack(spacing: 12) {
                checkbox(isCompleted: item.isCompleted, color: Color(hex: draft.style.textHex), textSize: draft.style.textSize)
                Text(checklistText(for: item))
                    .font(.system(size: draft.style.textSize))
                    .strikethrough(item.isCompleted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .opacity(isChecklistPlaceholder(item) ? 0.45 : 1)
            }
            .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private extension WidgetStyle {
    var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
    }

    var textAlignment: TextAlignment {
        switch alignment {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
    }

    var contentAlignment: Alignment {
        Alignment(horizontal: horizontalAlignment, vertical: .center)
    }
}

private extension Color {
    init(hex: String) { let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0; self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255) }
}

@main struct UnforgettyWidgetBundle: WidgetBundle {
    var body: some Widget {
        UnforgettyHomeWidget()
        UnforgettyWidget()
    }
}
