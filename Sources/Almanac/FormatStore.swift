import Combine
import Foundation

@MainActor
final class FormatStore: ObservableObject {
    @Published var data: StoreData {
        didSet {
            save()
            onChange?()
        }
    }

    /// Called after any mutation (used to re-register hotkeys).
    var onChange: (() -> Void)?

    private let fileURL: URL

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Almanac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("store.json")

        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(StoreData.self, from: raw),
           !decoded.formats.isEmpty {
            data = decoded
        } else {
            data = .defaults
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }

    // MARK: Mutations

    func add(_ preset: FormatPreset) {
        data.formats.append(preset)
    }

    func update(_ preset: FormatPreset) {
        guard let i = data.formats.firstIndex(where: { $0.id == preset.id }) else { return }
        data.formats[i] = preset
    }

    func remove(id: UUID) {
        data.formats.removeAll { $0.id == id }
    }

    func moveFormats(from source: IndexSet, to destination: Int) {
        data.formats.move(fromOffsets: source, toOffset: destination)
    }
}
