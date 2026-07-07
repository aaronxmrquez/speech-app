import Foundation
import Combine

struct DictationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let date: Date
    let appName: String?
}

/// Historial local de dictados (JSON en Application Support, máx. 100).
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [DictationRecord] = []

    private var persist = true
    private static let maxRecords = 100

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dicta/history.json")
    }

    init() {
        load()
    }

    /// Para el modo --render-previews: datos de muestra sin tocar el disco.
    static func preview() -> HistoryStore {
        let store = HistoryStore()
        store.persist = false
        store.records = [
            DictationRecord(id: UUID(),
                            text: "Hola equipo, acabo de terminar la revisión del sistema de diseño y todo se ve muy bien.",
                            date: Date().addingTimeInterval(-300), appName: "Slack"),
            DictationRecord(id: UUID(),
                            text: "Hello team, I just finished reviewing the design system and everything looks great.",
                            date: Date().addingTimeInterval(-3900), appName: "Notas"),
        ]
        return store
    }

    func add(text: String, appName: String?) {
        records.insert(DictationRecord(id: UUID(), text: text, date: Date(), appName: appName), at: 0)
        if records.count > Self.maxRecords {
            records.removeLast(records.count - Self.maxRecords)
        }
        save()
    }

    func delete(_ record: DictationRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode([DictationRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        guard persist else { return }
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
