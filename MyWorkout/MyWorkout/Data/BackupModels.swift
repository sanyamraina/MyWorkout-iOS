import SwiftUI
import UniformTypeIdentifiers

struct WorkoutBackup: Codable {
    let version: Int
    let exportedAt: Date
    let sessions: [WorkoutSession]
    let templates: [WorkoutTemplate]
    let entries: [WorkoutExercise]?
    let notes: [String: String]?
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
