import Foundation

// MARK: - Format kind

enum FormatKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case pattern
    case iso8601
    case unix

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pattern: "Date pattern"
        case .iso8601: "ISO 8601 (with offset)"
        case .unix: "Unix timestamp"
        }
    }
}

// MARK: - Time zone

enum TimeZoneSpec: Codable, Equatable, Hashable, Sendable {
    case system
    case utc
    case named(String)

    var resolved: TimeZone {
        switch self {
        case .system: .current
        case .utc: TimeZone(identifier: "UTC") ?? .current
        case .named(let id): TimeZone(identifier: id) ?? .current
        }
    }

    var label: String {
        switch self {
        case .system: "System (\(TimeZone.current.identifier))"
        case .utc: "UTC"
        case .named(let id): id.replacingOccurrences(of: "_", with: " ")
        }
    }

    var shortLabel: String {
        switch self {
        case .system: "System"
        case .utc: "UTC"
        case .named(let id):
            id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id
        }
    }
}

// MARK: - Insert mode

enum InsertMode: String, Codable, Sendable {
    case paste
    case copyOnly
}

// MARK: - Format preset

struct FormatPreset: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: FormatKind
    var pattern: String
    var timeZone: TimeZoneSpec
    var dayOffset: Int
    var hotKey: KeyCombo?

    init(id: UUID = UUID(),
         name: String,
         kind: FormatKind = .pattern,
         pattern: String = "yyyy-MM-dd",
         timeZone: TimeZoneSpec = .system,
         dayOffset: Int = 0,
         hotKey: KeyCombo? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.pattern = pattern
        self.timeZone = timeZone
        self.dayOffset = dayOffset
        self.hotKey = hotKey
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, pattern, timeZone, dayOffset, hotKey
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Format"
        kind = try c.decodeIfPresent(FormatKind.self, forKey: .kind) ?? .pattern
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern) ?? "yyyy-MM-dd"
        timeZone = try c.decodeIfPresent(TimeZoneSpec.self, forKey: .timeZone) ?? .system
        dayOffset = try c.decodeIfPresent(Int.self, forKey: .dayOffset) ?? 0
        hotKey = try c.decodeIfPresent(KeyCombo.self, forKey: .hotKey)
    }

    var offsetDescription: String {
        switch dayOffset {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        case let n where n > 0: "In \(n) days"
        case let n: "\(-n) days ago"
        }
    }
}

// MARK: - Store data

struct StoreData: Codable, Sendable {
    var formats: [FormatPreset]
    var insertMode: InsertMode
    var primaryHotKey: KeyCombo?

    init(formats: [FormatPreset], insertMode: InsertMode = .paste, primaryHotKey: KeyCombo? = .defaultPrimary) {
        self.formats = formats
        self.insertMode = insertMode
        self.primaryHotKey = primaryHotKey
    }

    enum CodingKeys: String, CodingKey { case formats, insertMode, primaryHotKey }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formats = try c.decodeIfPresent([FormatPreset].self, forKey: .formats) ?? []
        insertMode = try c.decodeIfPresent(InsertMode.self, forKey: .insertMode) ?? .paste
        primaryHotKey = try c.decodeIfPresent(KeyCombo.self, forKey: .primaryHotKey)
    }

    static var defaults: StoreData {
        StoreData(formats: [
            FormatPreset(name: "ISO date", pattern: "yyyy-MM-dd"),
            FormatPreset(name: "Long date", pattern: "MMMM d, yyyy"),
            FormatPreset(name: "Short day", pattern: "EEE, MMM d"),
            FormatPreset(name: "Date & time", pattern: "yyyy-MM-dd HH:mm zzz"),
            FormatPreset(name: "ISO 8601", kind: .iso8601),
            FormatPreset(name: "Unix timestamp", kind: .unix),
        ])
    }
}

// MARK: - Rendering

enum Renderer {
    /// Renders a preset at a given base date, applying the preset's day offset
    /// and time zone.
    static func render(_ preset: FormatPreset, at base: Date) -> String {
        let tz = preset.timeZone.resolved
        var date = base
        if preset.dayOffset != 0 {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            date = cal.date(byAdding: .day, value: preset.dayOffset, to: base) ?? base
        }
        switch preset.kind {
        case .pattern:
            let df = DateFormatter()
            df.locale = .autoupdatingCurrent
            df.timeZone = tz
            df.dateFormat = preset.pattern
            return df.string(from: date)
        case .iso8601:
            let f = ISO8601DateFormatter()
            f.timeZone = tz
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: date)
        case .unix:
            return String(Int(date.timeIntervalSince1970))
        }
    }
}
