import Foundation
import SwiftUI

enum ActivityKind: Codable, CaseIterable, Identifiable, Hashable {
    case note
    case check(CheckKind)

    enum CheckKind: String, Codable, CaseIterable, Identifiable {
        case buttons
        case todoList

        var id: Self { self }
        var title: String {
            switch self {
            case .buttons: "Buttons"
            case .todoList: "To Do"
            }
        }
    }

    static var checklist: Self { .check(.todoList) }
    static var allCases: [Self] { [.note, .check(.buttons), .check(.todoList)] }

    var id: String {
        switch self {
        case .note: "note"
        case .check(let checkKind): "check.\(checkKind.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .note: "Nota"
        case .check(let checkKind): checkKind.title
        }
    }

    var isNote: Bool { self == .note }
    var isCheck: Bool {
        if case .check = self { return true }
        return false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "note":
            self = .note
        case "check.buttons", "buttons":
            self = .check(.buttons)
        case "check.todoList", "todoList", "checklist":
            self = .check(.todoList)
        default:
            self = .check(.todoList)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .note:
            try container.encode("note")
        case .check(.buttons):
            try container.encode("check.buttons")
        case .check(.todoList):
            try container.encode("checklist")
        }
    }
}

enum ActivityStatus: String, Codable, CaseIterable, Identifiable {
    case draft, active, scheduled, completed
    var id: Self { self }
    var title: String {
        switch self {
        case .draft: "Borrador"
        case .active: "Activas"
        case .scheduled: "Programadas"
        case .completed: "Completadas"
        }
    }
}

enum ActivitySurface: String, Codable, CaseIterable, Identifiable {
    case liveActivity, notification, widget
    var id: Self { self }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: Self { self }
    var shortLabel: String {
        switch self {
        case .monday: "L"
        case .tuesday: "M"
        case .wednesday: "X"
        case .thursday: "J"
        case .friday: "V"
        case .saturday: "S"
        case .sunday: "D"
        }
    }

    /// `Calendar.component(.weekday, from:)` returns 1 = Sunday ... 7 = Saturday.
    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}

struct Tag: Codable, Identifiable, Hashable { var id = UUID(); var name: String }
struct ChecklistItem: Codable, Identifiable, Hashable { var id = UUID(); var text: String; var isCompleted = false }

struct ActivityStyle: Codable, Hashable {
    static let minimumTextSize: Double = 33
    static let maximumTextSize: Double = 44
    static let defaultTextSize: Double = 33

    var backgroundHex = "F6F6F7"
    var textHex = "111111"
    var backgroundMode = BackgroundMode.plain
    var font = FontChoice.rounded
    var textSize: Double = Self.defaultTextSize
    var alignment = TextAlignmentChoice.leading
    enum BackgroundMode: String, Codable, CaseIterable, Identifiable { case plain, gradient; var id: Self { self }; var title: String { rawValue.capitalized } }
    enum FontChoice: String, Codable, CaseIterable, Identifiable { case rounded, serif, monospaced; var id: Self { self }; var title: String { rawValue.capitalized } }
    enum TextAlignmentChoice: String, Codable, CaseIterable, Identifiable { case leading, center, trailing; var id: Self { self }; var title: String { rawValue.capitalized } }

    private enum CodingKeys: String, CodingKey { case backgroundHex, textHex, backgroundMode, font, textSize, alignment }

    var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var fontDesign: Font.Design {
        switch font {
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backgroundHex = try container.decodeIfPresent(String.self, forKey: .backgroundHex) ?? "F6F6F7"
        textHex = try container.decodeIfPresent(String.self, forKey: .textHex) ?? "111111"
        backgroundMode = try container.decodeIfPresent(BackgroundMode.self, forKey: .backgroundMode) ?? .plain
        font = try container.decodeIfPresent(FontChoice.self, forKey: .font) ?? .rounded
        let decodedTextSize = try container.decodeIfPresent(Double.self, forKey: .textSize) ?? Self.defaultTextSize
        textSize = min(Self.maximumTextSize, max(Self.minimumTextSize, decodedTextSize))
        alignment = try container.decodeIfPresent(TextAlignmentChoice.self, forKey: .alignment) ?? .leading
    }
}

struct LiveActivityDraft: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: ActivityKind = .note
    var title = ""
    var body = ""
    var noteIsCompleted = false
    var checklistItems: [ChecklistItem] = [ChecklistItem(text: "")]
    var tags: [Tag] = []
    var isStrict = false
    var style = ActivityStyle()
    var isValid: Bool {
        kind == .note
            ? !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : checklistItems.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct ScheduledActivity: Codable, Identifiable, Hashable {
    var id: UUID
    var notificationID: String
    var surface: ActivitySurface
    var draft: LiveActivityDraft
    var startDate: Date
    var endDate: Date?
    var recurrence: Set<Weekday>
    var status: ActivityStatus
    var liveActivityID: String?
    var createdAt: Date = .now

    init(draft: LiveActivityDraft, surface: ActivitySurface = .liveActivity, startDate: Date, endDate: Date? = nil, recurrence: Set<Weekday> = [], status: ActivityStatus) {
        self.id = draft.id; self.notificationID = draft.id.uuidString; self.surface = surface; self.draft = draft; self.startDate = startDate; self.endDate = endDate; self.recurrence = recurrence; self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, notificationID, surface, draft, startDate, endDate, recurrence, status, liveActivityID, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        notificationID = try container.decode(String.self, forKey: .notificationID)
        surface = try container.decodeIfPresent(ActivitySurface.self, forKey: .surface) ?? .liveActivity
        draft = try container.decode(LiveActivityDraft.self, forKey: .draft)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        recurrence = try container.decodeIfPresent(Set<Weekday>.self, forKey: .recurrence) ?? []
        status = try container.decode(ActivityStatus.self, forKey: .status)
        liveActivityID = try container.decodeIfPresent(String.self, forKey: .liveActivityID)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(notificationID, forKey: .notificationID)
        try container.encode(surface, forKey: .surface)
        try container.encode(draft, forKey: .draft)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(recurrence, forKey: .recurrence)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(liveActivityID, forKey: .liveActivityID)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }
}
