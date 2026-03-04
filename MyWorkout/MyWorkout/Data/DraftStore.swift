import Foundation

struct DraftStore {
    static func load<T: Codable>(_ kind: DraftKind, as type: T.Type) -> T? {
        do {
            let data = try Data(contentsOf: fileURL(for: kind))
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    static func save<T: Codable>(_ payload: T, kind: DraftKind) {
        do {
            let data = try JSONEncoder().encode(payload)
            let url = fileURL(for: kind)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            // Ignore write failures; drafts are best-effort.
        }
    }

    static func clear(_ kind: DraftKind) {
        let url = fileURL(for: kind)
        try? FileManager.default.removeItem(at: url)
    }

    private static func fileURL(for kind: DraftKind) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/\(kind.fileName)")
    }
}
