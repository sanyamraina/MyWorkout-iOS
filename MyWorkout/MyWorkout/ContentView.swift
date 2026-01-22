//
//  ContentView.swift
//  MyWorkout
//
//  Created by Sanyam Raina on 1/19/26.
//

import SwiftUI
import Combine
import Charts
import UniformTypeIdentifiers
import UIKit

enum ExerciseType: String, Codable, CaseIterable {
    case weights
    case cardio

    var label: String {
        switch self {
        case .weights:
            return "Weights"
        case .cardio:
            return "Cardio"
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable {
    case kg
    case lb

    var label: String {
        switch self {
        case .kg:
            return "kg"
        case .lb:
            return "lb"
        }
    }
}

enum MuscleGroup: String, CaseIterable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case cardio = "Cardio"
}

enum TemplateShareError: Error {
    case invalidPayload
}

enum SessionMergeWindowOption: String, CaseIterable, Codable {
    case oneMinute
    case fiveMinutes
    case tenMinutes
    case threeHours
    case sixHours
    case twelveHours
    case twentyFourHours
    case sameDay

    var label: String {
        switch self {
        case .oneMinute:
            return "1 minute (test)"
        case .fiveMinutes:
            return "5 minutes (test)"
        case .tenMinutes:
            return "10 minutes (test)"
        case .threeHours:
            return "3 hours (recommended)"
        case .sixHours:
            return "6 hours"
        case .twelveHours:
            return "12 hours"
        case .twentyFourHours:
            return "24 hours"
        case .sameDay:
            return "Same day"
        }
    }

    var windowSeconds: TimeInterval? {
        switch self {
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 5 * 60
        case .tenMinutes:
            return 10 * 60
        case .threeHours:
            return 3 * 60 * 60
        case .sixHours:
            return 6 * 60 * 60
        case .twelveHours:
            return 12 * 60 * 60
        case .twentyFourHours:
            return 24 * 60 * 60
        case .sameDay:
            return nil
        }
    }
}

struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let type: ExerciseType
    let sets: [WorkoutSet]
    let durationMinutes: Int?
    let calories: Int?
    let loggedAt: Date?

    init(
        id: UUID,
        name: String,
        type: ExerciseType = .weights,
        sets: [WorkoutSet],
        durationMinutes: Int? = nil,
        calories: Int? = nil,
        loggedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sets = sets
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.loggedAt = loggedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(ExerciseType.self, forKey: .type) ?? .weights
        if let decodedSets = try? container.decode([WorkoutSet].self, forKey: .sets) {
            sets = decodedSets
        } else {
            let legacyWeight = (try? container.decode(Double.self, forKey: .weightKg)) ?? 0
            let legacySets = (try? container.decode(Int.self, forKey: .sets)) ?? 0
            let legacyReps = (try? container.decode(Int.self, forKey: .repsPerSet)) ?? 0
            sets = (0..<max(legacySets, 0)).map { _ in
                WorkoutSet(id: UUID(), weightKg: legacyWeight, reps: legacyReps)
            }
        }
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        calories = try container.decodeIfPresent(Int.self, forKey: .calories)
        loggedAt = try container.decodeIfPresent(Date.self, forKey: .loggedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(sets, forKey: .sets)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(loggedAt, forKey: .loggedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case weightKg
        case sets
        case repsPerSet
        case durationMinutes
        case calories
        case loggedAt
    }
}

struct WorkoutSet: Identifiable, Codable, Equatable {
    let id: UUID
    let weightKg: Double
    let reps: Int
}

struct TemplateExercise: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let type: ExerciseType
    let weightKg: Double?
    let sets: Int?
    let repsPerSet: Int?

    init(
        id: UUID,
        name: String,
        type: ExerciseType = .weights,
        weightKg: Double? = nil,
        sets: Int? = nil,
        repsPerSet: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.weightKg = weightKg
        self.sets = sets
        self.repsPerSet = repsPerSet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(ExerciseType.self, forKey: .type) ?? .weights
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        sets = try container.decodeIfPresent(Int.self, forKey: .sets)
        repsPerSet = try container.decodeIfPresent(Int.self, forKey: .repsPerSet)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(weightKg, forKey: .weightKg)
        try container.encodeIfPresent(sets, forKey: .sets)
        try container.encodeIfPresent(repsPerSet, forKey: .repsPerSet)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case weightKg
        case sets
        case repsPerSet
    }
}

struct WorkoutSession: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let endDate: Date
    let exercises: [WorkoutExercise]

    init(id: UUID, date: Date, endDate: Date? = nil, exercises: [WorkoutExercise]) {
        self.id = id
        self.date = date
        self.endDate = endDate ?? date
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? date
        exercises = try container.decode([WorkoutExercise].self, forKey: .exercises)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(exercises, forKey: .exercises)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case endDate
        case exercises
    }
}

extension WorkoutSession {
    func mergedExercises() -> [WorkoutExercise] {
        var orderedKeys: [String] = []
        var mergedByKey: [String: WorkoutExercise] = [:]

        for exercise in exercises {
            let key = "\(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(exercise.type.rawValue)"
            if let existing = mergedByKey[key] {
                switch exercise.type {
                case .weights:
                    let combinedSets = existing.sets + exercise.sets
                    let mergedLoggedAt = [existing.loggedAt, exercise.loggedAt].compactMap { $0 }.min()
                    mergedByKey[key] = WorkoutExercise(
                        id: existing.id,
                        name: existing.name,
                        type: existing.type,
                        sets: combinedSets,
                        durationMinutes: nil,
                        calories: nil,
                        loggedAt: mergedLoggedAt
                    )
                case .cardio:
                    let currentMinutes = existing.durationMinutes ?? 0
                    let currentCalories = existing.calories ?? 0
                    let addMinutes = exercise.durationMinutes ?? 0
                    let addCalories = exercise.calories ?? 0
                    let totalMinutes = currentMinutes + addMinutes
                    let totalCalories = currentCalories + addCalories
                    let mergedLoggedAt = [existing.loggedAt, exercise.loggedAt].compactMap { $0 }.min()
                    mergedByKey[key] = WorkoutExercise(
                        id: existing.id,
                        name: existing.name,
                        type: existing.type,
                        sets: [],
                        durationMinutes: totalMinutes > 0 ? totalMinutes : nil,
                        calories: totalCalories > 0 ? totalCalories : nil,
                        loggedAt: mergedLoggedAt
                    )
                }
            } else {
                orderedKeys.append(key)
                mergedByKey[key] = exercise
            }
        }

        return orderedKeys.compactMap { mergedByKey[$0] }
    }
}

struct WorkoutTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let exercises: [TemplateExercise]
}

struct TemplateSharePayload: Codable {
    let version: Int
    let template: WorkoutTemplate
}

struct LibraryExercise: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let group: MuscleGroup
    let type: ExerciseType
}

struct WorkoutBackup: Codable {
    let version: Int
    let exportedAt: Date
    let sessions: [WorkoutSession]
    let templates: [WorkoutTemplate]
    let entries: [WorkoutExercise]?
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

final class WorkoutStore: ObservableObject {
    @Published private(set) var entries: [WorkoutExercise] = []
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var exerciseLibrary: [LibraryExercise] = WorkoutStore.defaultLibrary
    private var hasLoaded = false
    @Published private var exerciseTypeMap: [String: ExerciseType] = [:]
    @Published var defaultWeightUnit: WeightUnit = .kg {
        didSet { saveDefaultWeightUnit() }
    }
    @Published var sessionMergeWindowOption: SessionMergeWindowOption = .threeHours {
        didSet { saveSessionMergeWindowOption() }
    }

    init() {
        defaultWeightUnit = loadDefaultWeightUnit()
        sessionMergeWindowOption = loadSessionMergeWindowOption()
        load()
    }

    func addSession(date: Date, exercises: [WorkoutExercise]) {
        let newEntries = exercises.map { exercise in
            WorkoutExercise(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                sets: exercise.sets,
                durationMinutes: exercise.durationMinutes,
                calories: exercise.calories,
                loggedAt: exercise.loggedAt ?? date
            )
        }
        entries.append(contentsOf: newEntries)
        updateExerciseTypes(from: exercises)
        saveEntries()
        refreshSessions()
    }

    private func mergeExercises(existing: [WorkoutExercise], incoming: [WorkoutExercise]) -> [WorkoutExercise] {
        var merged = existing
        var indexByKey: [String: Int] = [:]

        for (idx, exercise) in merged.enumerated() {
            let key = exerciseMergeKey(for: exercise)
            indexByKey[key] = idx
        }

        for exercise in incoming {
            let key = exerciseMergeKey(for: exercise)
            if let idx = indexByKey[key] {
                let current = merged[idx]
                switch exercise.type {
                case .weights:
                    let combinedSets = current.sets + exercise.sets
                    merged[idx] = WorkoutExercise(
                        id: current.id,
                        name: current.name,
                        type: current.type,
                        sets: combinedSets,
                        durationMinutes: nil,
                        calories: nil,
                        loggedAt: mergedLoggedAt(current: current, incoming: exercise)
                    )
                case .cardio:
                    let currentMinutes = current.durationMinutes ?? 0
                    let currentCalories = current.calories ?? 0
                    let addMinutes = exercise.durationMinutes ?? 0
                    let addCalories = exercise.calories ?? 0
                    let totalMinutes = currentMinutes + addMinutes
                    let totalCalories = currentCalories + addCalories
                    merged[idx] = WorkoutExercise(
                        id: current.id,
                        name: current.name,
                        type: current.type,
                        sets: [],
                        durationMinutes: totalMinutes > 0 ? totalMinutes : nil,
                        calories: totalCalories > 0 ? totalCalories : nil,
                        loggedAt: mergedLoggedAt(current: current, incoming: exercise)
                    )
                }
            } else {
                indexByKey[key] = merged.count
                merged.append(exercise)
            }
        }

        return merged
    }

    private func exerciseMergeKey(for exercise: WorkoutExercise) -> String {
        let normalized = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalized)|\(exercise.type.rawValue)"
    }

    private func mergedLoggedAt(current: WorkoutExercise, incoming: WorkoutExercise) -> Date? {
        [current.loggedAt, incoming.loggedAt].compactMap { $0 }.min()
    }

    private func closestSessionIndex(
        for startDate: Date,
        end endDate: Date,
        option: SessionMergeWindowOption
    ) -> Int? {
        closestSessionIndex(in: sessions, for: startDate, end: endDate, option: option)
    }

    private func closestSessionIndex(
        in sessions: [WorkoutSession],
        for startDate: Date,
        end endDate: Date,
        option: SessionMergeWindowOption
    ) -> Int? {
        var closest: (index: Int, distance: TimeInterval)?
        let maxWindow = option.windowSeconds
        for (index, session) in sessions.enumerated() {
            if option == .sameDay,
               !Calendar.current.isDate(session.date, inSameDayAs: startDate),
               !Calendar.current.isDate(session.date, inSameDayAs: endDate) {
                continue
            }
            let distance: TimeInterval
            if startDate > session.endDate {
                distance = startDate.timeIntervalSince(session.endDate)
            } else if endDate < session.date {
                distance = session.date.timeIntervalSince(endDate)
            } else {
                distance = 0
            }
            if let maxWindow, distance > maxWindow {
                continue
            }
            if let current = closest {
                if distance < current.distance {
                    closest = (index, distance)
                }
            } else {
                closest = (index, distance)
            }
        }
        return closest?.index
    }

    func needsRebuild(for option: SessionMergeWindowOption) -> Bool {
        sessionSignatures(rebuiltSessions(using: option, entries: entries)) != sessionSignatures(sessions)
    }

    func rebuildSessions(using option: SessionMergeWindowOption? = nil) {
        let option = option ?? sessionMergeWindowOption
        sessions = rebuiltSessions(using: option, entries: entries)
        sessions.sort { $0.date > $1.date }
        updateExerciseTypes(from: sessions.flatMap { $0.exercises })
    }

    private func rebuiltSessions(using option: SessionMergeWindowOption, entries: [WorkoutExercise]) -> [WorkoutSession] {
        var rebuilt: [WorkoutSession] = []
        let orderedExercises = entries
            .map { exercise in
                let loggedAt = exercise.loggedAt ?? Date.distantPast
                return (loggedAt, exercise)
            }
            .sorted { $0.0 < $1.0 }
        for (loggedAt, exercise) in orderedExercises {
            let normalized = normalizedExercise(exercise, loggedAt: loggedAt)
            if let index = closestSessionIndex(in: rebuilt, for: loggedAt, end: loggedAt, option: option) {
                let existing = rebuilt[index]
                let mergedExercises = existing.exercises + [normalized]
                let startDate = min(existing.date, loggedAt)
                let endDate = max(existing.endDate, loggedAt)
                rebuilt[index] = WorkoutSession(
                    id: existing.id,
                    date: startDate,
                    endDate: endDate,
                    exercises: mergedExercises
                )
            } else {
                rebuilt.append(
                    WorkoutSession(
                        id: UUID(),
                        date: loggedAt,
                        endDate: loggedAt,
                        exercises: [normalized]
                    )
                )
            }
        }
        return rebuilt
    }

    private struct SessionSignature: Equatable {
        let startDate: Date
        let endDate: Date
        let exerciseIds: [UUID]
    }

    private func sessionSignatures(_ sessions: [WorkoutSession]) -> [SessionSignature] {
        sessions
            .map { session in
                let ids = session.exercises.map(\.id).sorted { $0.uuidString < $1.uuidString }
                return SessionSignature(startDate: session.date, endDate: session.endDate, exerciseIds: ids)
            }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                if $0.endDate != $1.endDate { return $0.endDate < $1.endDate }
                let left = $0.exerciseIds.first?.uuidString ?? ""
                let right = $1.exerciseIds.first?.uuidString ?? ""
                return left < right
            }
    }

    private func normalizedExercise(_ exercise: WorkoutExercise, loggedAt: Date) -> WorkoutExercise {
        WorkoutExercise(
            id: exercise.id,
            name: exercise.name,
            type: exercise.type,
            sets: exercise.sets,
            durationMinutes: exercise.durationMinutes,
            calories: exercise.calories,
            loggedAt: loggedAt
        )
    }

    func updateSession(_ session: WorkoutSession, date: Date, exercises: [WorkoutExercise]) {
        let removeIds = Set(session.exercises.map(\.id))
        entries.removeAll { removeIds.contains($0.id) }
        let newEntries = exercises.map { exercise in
            WorkoutExercise(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                sets: exercise.sets,
                durationMinutes: exercise.durationMinutes,
                calories: exercise.calories,
                loggedAt: exercise.loggedAt ?? date
            )
        }
        entries.append(contentsOf: newEntries)
        updateExerciseTypes(from: exercises)
        saveEntries()
        refreshSessions()
    }

    func removeSession(_ session: WorkoutSession) {
        let removeIds = Set(session.exercises.map(\.id))
        entries.removeAll { removeIds.contains($0.id) }
        saveEntries()
        refreshSessions()
    }

    func addTemplate(title: String, exercises: [TemplateExercise]) {
        let template = WorkoutTemplate(
            id: UUID(),
            title: title,
            exercises: exercises
        )
        templates.insert(template, at: 0)
        updateExerciseTypes(from: exercises)
        saveTemplates()
    }

    func shareString(for template: WorkoutTemplate) throws -> String {
        let payload = TemplateSharePayload(version: 1, template: template)
        let data = try JSONEncoder().encode(payload)
        return data.base64EncodedString()
    }

    func importTemplate(from shareString: String) throws {
        let cleaned = shareString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: cleaned) else {
            throw TemplateShareError.invalidPayload
        }
        let payload = try JSONDecoder().decode(TemplateSharePayload.self, from: data)
        let exercises = payload.template.exercises.map {
            TemplateExercise(id: UUID(), name: $0.name, type: $0.type, weightKg: nil, sets: nil, repsPerSet: nil)
        }
        addTemplate(title: payload.template.title, exercises: exercises)
    }

    func updateTemplate(id: UUID, title: String, exercises: [TemplateExercise]) {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[index] = WorkoutTemplate(id: id, title: title, exercises: exercises)
        updateExerciseTypes(from: exercises)
        saveTemplates()
    }

    func addTemplate(from session: WorkoutSession) {
        let title = "Template \(templates.count + 1)"
        let exercises = session.mergedExercises().map { exercise in
            TemplateExercise(
                id: UUID(),
                name: exercise.name,
                type: exercise.type,
                weightKg: nil,
                sets: nil,
                repsPerSet: nil
            )
        }
        addTemplate(title: title, exercises: exercises)
    }

    func removeTemplate(_ template: WorkoutTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }

    func resolvedDrafts(for template: WorkoutTemplate) -> [ExerciseDraft] {
        template.exercises.map { exercise in
            let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let latest = latestExerciseRecord(named: trimmedName) {
                switch exercise.type {
                case .cardio:
                    let duration = latest.exercise.type == .cardio
                        ? formattedOptionalInt(latest.exercise.durationMinutes)
                        : ""
                    let calories = latest.exercise.type == .cardio
                        ? formattedOptionalInt(latest.exercise.calories)
                        : ""
                    return ExerciseDraft(
                        name: trimmedName,
                        type: .cardio,
                        sets: [],
                        weightUnit: defaultWeightUnit,
                        durationMinutes: "",
                        calories: "",
                        durationPlaceholder: duration,
                        caloriesPlaceholder: calories
                    )
                case .weights:
                    if latest.exercise.type == .weights {
                        let setDrafts = latest.exercise.sets.map { set in
                            WorkoutSetDraft(
                                weight: "",
                                reps: "",
                                weightPlaceholder: set.weightKg == 0
                                    ? ""
                                    : String(format: "%.1f", weightValue(set.weightKg, unit: defaultWeightUnit)),
                                repsPlaceholder: "\(set.reps)"
                            )
                        }
                        let isBodyweight = latest.exercise.sets.allSatisfy { $0.weightKg == 0 }
                        return ExerciseDraft(
                            name: latest.exercise.name,
                            type: .weights,
                            sets: setDrafts.isEmpty ? [WorkoutSetDraft()] : setDrafts,
                            isBodyweight: isBodyweight,
                            weightUnit: defaultWeightUnit
                        )
                    }
                }
            }
            return ExerciseDraft(
                name: trimmedName,
                type: exercise.type,
                sets: exercise.type == .weights ? [WorkoutSetDraft()] : [],
                isBodyweight: false,
                weightUnit: defaultWeightUnit
            )
        }
    }

    func latestExerciseRecord(named name: String) -> (exercise: WorkoutExercise, date: Date)? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }

        var latest: (date: Date, exercise: WorkoutExercise)?
        for session in sessions {
            for exercise in session.exercises {
                let exerciseKey = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard exerciseKey == key else { continue }
                if let current = latest {
                    let exerciseDate = exercise.loggedAt ?? session.date
                    if exerciseDate >= current.date {
                        latest = (exerciseDate, exercise)
                    }
                } else {
                    let exerciseDate = exercise.loggedAt ?? session.date
                    latest = (exerciseDate, exercise)
                }
            }
        }
        return latest.map { (exercise: $0.exercise, date: $0.date) }
    }

    func exerciseNameCatalog() -> [String] {
        let sessionNames = sessions.flatMap { $0.exercises.map { $0.name } }
        let templateNames = templates.flatMap { $0.exercises.map { $0.name } }
        let libraryNames = exerciseLibrary.map { $0.name }
        let combined = sessionNames + templateNames + libraryNames
        let unique = Dictionary(grouping: combined, by: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            .compactMap { $0.value.first }
        return unique
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    func exportBackup() -> WorkoutBackup {
        WorkoutBackup(
            version: 2,
            exportedAt: Date(),
            sessions: sessions,
            templates: templates,
            entries: entries
        )
    }

    func importBackup(_ backup: WorkoutBackup) {
        if let entries = backup.entries {
            self.entries = entries
        } else {
            self.entries = backup.sessions.flatMap { session in
                session.exercises.map { exercise in
                    WorkoutExercise(
                        id: exercise.id,
                        name: exercise.name,
                        type: exercise.type,
                        sets: exercise.sets,
                        durationMinutes: exercise.durationMinutes,
                        calories: exercise.calories,
                        loggedAt: exercise.loggedAt ?? session.date
                    )
                }
            }
        }
        templates = backup.templates
        exerciseTypeMap = [:]
        updateExerciseTypes(from: self.entries)
        updateExerciseTypes(from: templates.flatMap { $0.exercises })
        saveEntries()
        saveTemplates()
        refreshSessions()
    }

    func exportBackupData() throws -> Data {
        let backup = exportBackup()
        return try JSONEncoder().encode(backup)
    }

    func importBackupData(_ data: Data) throws {
        let backup = try JSONDecoder().decode(WorkoutBackup.self, from: data)
        importBackup(backup)
    }

    func resetAllData() {
        entries = []
        sessions = []
        templates = []
        exerciseTypeMap = [:]
        saveEntries()
        saveTemplates()
        saveExerciseTypes()

        let urls = [sessionsFileURL(), entriesFileURL(), templatesFileURL(), exerciseTypesFileURL()]
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func formattedOptionalInt(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private func weightValue(_ kg: Double, unit: WeightUnit) -> Double {
        if unit == .lb {
            return kg * 2.20462262
        }
        return kg
    }

    private func load() {
        entries = loadEntries()
        let needsEntryMigration = entries.isEmpty
        if needsEntryMigration {
            let legacySessions = loadSessions()
            entries = legacySessions.flatMap { session in
                session.exercises.map { exercise in
                    WorkoutExercise(
                        id: exercise.id,
                        name: exercise.name,
                        type: exercise.type,
                        sets: exercise.sets,
                        durationMinutes: exercise.durationMinutes,
                        calories: exercise.calories,
                        loggedAt: exercise.loggedAt ?? session.date
                    )
                }
            }
        }
        templates = loadTemplates()
        exerciseTypeMap = loadExerciseTypes()
        hasLoaded = true
        updateExerciseTypes(from: entries)
        let templateExercises = templates.flatMap { $0.exercises }
        updateExerciseTypes(from: templateExercises)
        updateExerciseTypes(from: exerciseLibrary)
        refreshSessions()
        if needsEntryMigration {
            saveEntries()
        }
    }

    func exerciseType(for name: String) -> ExerciseType? {
        let key = normalizedExerciseKey(name)
        guard !key.isEmpty else { return nil }
        return exerciseTypeMap[key]
    }

    private func updateExerciseTypes(from exercises: [WorkoutExercise]) {
        var changed = false
        for exercise in exercises {
            let key = normalizedExerciseKey(exercise.name)
            guard !key.isEmpty else { continue }
            if exerciseTypeMap[key] != exercise.type {
                exerciseTypeMap[key] = exercise.type
                changed = true
            }
        }
        if changed {
            saveExerciseTypes()
        }
    }

    private func updateExerciseTypes(from templates: [TemplateExercise]) {
        var changed = false
        for exercise in templates {
            let key = normalizedExerciseKey(exercise.name)
            guard !key.isEmpty else { continue }
            if exerciseTypeMap[key] != exercise.type {
                exerciseTypeMap[key] = exercise.type
                changed = true
            }
        }
        if changed {
            saveExerciseTypes()
        }
    }

    private func updateExerciseTypes(from library: [LibraryExercise]) {
        var changed = false
        for exercise in library {
            let key = normalizedExerciseKey(exercise.name)
            guard !key.isEmpty else { continue }
            if exerciseTypeMap[key] != exercise.type {
                exerciseTypeMap[key] = exercise.type
                changed = true
            }
        }
        if changed {
            saveExerciseTypes()
        }
    }

    private func normalizedExerciseKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func loadExerciseTypes() -> [String: ExerciseType] {
        do {
            let data = try Data(contentsOf: exerciseTypesFileURL())
            return try JSONDecoder().decode([String: ExerciseType].self, from: data)
        } catch {
            return [:]
        }
    }

    private func saveExerciseTypes() {
        guard hasLoaded else { return }
        do {
            let data = try JSONEncoder().encode(exerciseTypeMap)
            let url = exerciseTypesFileURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            // Ignore write failures; user can continue without persistence.
        }
    }

    private func loadDefaultWeightUnit() -> WeightUnit {
        let raw = UserDefaults.standard.string(forKey: "defaultWeightUnit") ?? WeightUnit.kg.rawValue
        return WeightUnit(rawValue: raw) ?? .kg
    }

    private func saveDefaultWeightUnit() {
        UserDefaults.standard.set(defaultWeightUnit.rawValue, forKey: "defaultWeightUnit")
    }

    private func loadSessionMergeWindowOption() -> SessionMergeWindowOption {
        let raw = UserDefaults.standard.string(forKey: "sessionMergeWindowOption")
        return SessionMergeWindowOption(rawValue: raw ?? "") ?? .threeHours
    }

    private func saveSessionMergeWindowOption() {
        UserDefaults.standard.set(sessionMergeWindowOption.rawValue, forKey: "sessionMergeWindowOption")
    }

    private static let defaultLibrary: [LibraryExercise] = [
        LibraryExercise(id: UUID(), name: "Bench Press (Barbell)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Bench Press (Dumbbell)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Bench Press (Smith)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Push Ups", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Incline Press (Barbell)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Incline Press (Dumbbell)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Incline Press (Smith)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Chest Fly (Cable)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Chest Fly (Dumbbell)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Chest Fly (Pec Deck)", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Dips", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Cable Crossover", group: .chest, type: .weights),
        LibraryExercise(id: UUID(), name: "Lat Pulldown (Wide Grip)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Lat Pulldown (Close Grip)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Lat Pulldown (Neutral Grip)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Row (Barbell)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Row (Dumbbell)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Row (Seated Cable)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Row (Chest-Supported)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Deadlift (Conventional)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Deadlift (Romanian)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Deadlift (Sumo)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Pull Ups (Wide Grip)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Pull Ups (Neutral Grip)", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Chin Ups", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Straight Arm Pulldown", group: .back, type: .weights),
        LibraryExercise(id: UUID(), name: "Overhead Press (Barbell)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Overhead Press (Dumbbell)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Overhead Press (Smith)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Shoulder Press", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Shoulder Press (Machine)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Lateral Raise (Dumbbell)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Lateral Raise (Cable)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Lateral Raise (Machine)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Face Pulls", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Front Raises", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Rear Delt Fly (Dumbbell)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Rear Delt Fly (Cable)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Rear Delt Fly (Reverse Pec Deck)", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Arnold Press", group: .shoulders, type: .weights),
        LibraryExercise(id: UUID(), name: "Curl (Barbell)", group: .biceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Curl (Dumbbell)", group: .biceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Curl (Preacher)", group: .biceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Curl (Cable)", group: .biceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Hammer Curl (Dumbbell)", group: .biceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Hammer Curl (Cable)", group: .biceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Concentration Curls", group: .biceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Pushdown (Rope)", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Pushdown (Bar)", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Pushdown (Straight)", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Skull Crushers", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Overhead Extension (Dumbbell)", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Overhead Extension (Cable)", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Dips (Bench)", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Dips (Parallel Bars)", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Close Grip Bench Press", group: .triceps, type: .weights),
        LibraryExercise(id: UUID(), name: "Squat (Back)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Squat (Front)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Squat (Smith)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Leg Press", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Deadlift (Romanian)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Deadlift (Sumo)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Lunge (Walking)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Lunge (Reverse)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Bulgarian Split Squat", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Leg Extensions", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Leg Curls", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Calf Raises", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Plank (Standard)", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Plank (Side)", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Plank (Weighted)", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Crunch (Cable)", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Crunch (Machine)", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Hanging Leg Raises", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Russian Twists", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Bicycle Crunches", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Dead Bug", group: .core, type: .weights),
        LibraryExercise(id: UUID(), name: "Treadmill", group: .cardio, type: .cardio),
        LibraryExercise(id: UUID(), name: "Cycling", group: .cardio, type: .cardio),
        LibraryExercise(id: UUID(), name: "Rowing", group: .cardio, type: .cardio),
        LibraryExercise(id: UUID(), name: "Jump Rope", group: .cardio, type: .cardio),
        LibraryExercise(id: UUID(), name: "Stair Climber", group: .cardio, type: .cardio),
        LibraryExercise(id: UUID(), name: "Elliptical", group: .cardio, type: .cardio),
        LibraryExercise(id: UUID(), name: "Running (Outdoor)", group: .cardio, type: .cardio),
        LibraryExercise(id: UUID(), name: "Walking", group: .cardio, type: .cardio),
        LibraryExercise(id: UUID(), name: "Swimming", group: .cardio, type: .cardio)
    ]

    private func loadSessions() -> [WorkoutSession] {
        do {
            let data = try Data(contentsOf: sessionsFileURL())
            return try JSONDecoder().decode([WorkoutSession].self, from: data)
        } catch {
            do {
                let data = try Data(contentsOf: sessionsFileURL())
                let legacy = try JSONDecoder().decode([LegacyWorkoutEntry].self, from: data)
                return legacy.map { entry in
                    WorkoutSession(
                        id: entry.id,
                        date: entry.date,
                        exercises: [
                            WorkoutExercise(
                                id: UUID(),
                                name: entry.name,
                                type: .weights,
                                sets: (0..<max(entry.sets, 0)).map { _ in
                                    WorkoutSet(id: UUID(), weightKg: entry.weightKg, reps: entry.repsPerSet)
                                },
                                durationMinutes: nil,
                                calories: nil,
                                loggedAt: entry.date
                            )
                        ]
                    )
                }
            } catch {
                return []
            }
        }
    }

    private func loadEntries() -> [WorkoutExercise] {
        do {
            let data = try Data(contentsOf: entriesFileURL())
            return try JSONDecoder().decode([WorkoutExercise].self, from: data)
        } catch {
            return []
        }
    }

    private func refreshSessions() {
        sessions = rebuiltSessions(using: sessionMergeWindowOption, entries: entries)
        sessions.sort { $0.date > $1.date }
    }

    private func loadTemplates() -> [WorkoutTemplate] {
        do {
            let data = try Data(contentsOf: templatesFileURL())
            return try JSONDecoder().decode([WorkoutTemplate].self, from: data)
        } catch {
            do {
                let data = try Data(contentsOf: templatesFileURL())
                let legacy = try JSONDecoder().decode([LegacyWorkoutTemplate].self, from: data)
                return legacy.map { template in
                    WorkoutTemplate(
                        id: template.id,
                        title: template.name,
                        exercises: [
                            TemplateExercise(
                                id: UUID(),
                                name: template.name,
                                type: .weights,
                                weightKg: nil,
                                sets: nil,
                                repsPerSet: nil
                            )
                        ]
                    )
                }
            } catch {
                return []
            }
        }
    }

    private func saveEntries() {
        guard hasLoaded else { return }
        do {
            let data = try JSONEncoder().encode(entries)
            let url = entriesFileURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            // Ignore write failures; user can continue without persistence.
        }
    }

    private func saveTemplates() {
        guard hasLoaded else { return }
        do {
            let data = try JSONEncoder().encode(templates)
            let url = templatesFileURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            // Ignore write failures; user can continue without persistence.
        }
    }

    private func sessionsFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/workouts.json")
    }

    private func entriesFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/entries.json")
    }

    private func templatesFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/templates.json")
    }

    private func exerciseTypesFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/exercise-types.json")
    }

    private struct LegacyWorkoutEntry: Codable {
        let id: UUID
        let name: String
        let weightKg: Double
        let sets: Int
        let repsPerSet: Int
        let date: Date
    }

    private struct LegacyWorkoutTemplate: Codable {
        let id: UUID
        let name: String
        let weightKg: Double
        let sets: Int
        let repsPerSet: Int
    }
}

struct ContentView: View {
    @StateObject private var store = WorkoutStore()

    var body: some View {
        TabView {
            HomeView(store: store)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HistoryView(store: store)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            ExerciseLibraryView(store: store)
                .tabItem {
                    Label("Explore", systemImage: "square.grid.2x2.fill")
                }

            ProgressTabView(store: store)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView(store: store)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

struct HomeView: View {
    @ObservedObject var store: WorkoutStore
    @State private var showingAdd = false
    @State private var showingTemplateAdd = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var editingSession: WorkoutSession?
    @State private var draftFromTemplate: WorkoutTemplate?
    @State private var showTemplateImport = false
    @State private var templateImportText = ""
    @State private var showTemplateImportError = false
    @State private var templateImportErrorMessage = ""
    @State private var showTemplateShareNotice = false
    @State private var showTemplateImportSuccess = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            List {
                header
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 28, leading: 22, bottom: 8, trailing: 22))

                stats
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 18, trailing: 22))

                templatesSection
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 18, trailing: 22))

                exercisesSection
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 24, trailing: 22))

            }
            .listStyle(.plain)
            .listRowSeparator(.hidden)
            .scrollContentBackground(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            addButton
        }
        .sheet(isPresented: $showingAdd) {
            AddWorkoutView(store: store, template: nil, session: nil)
        }
        .sheet(item: $draftFromTemplate) { template in
            AddWorkoutView(store: store, template: template, session: nil)
        }
        .sheet(item: $editingSession) { session in
            AddWorkoutView(store: store, template: nil, session: session)
        }
        .sheet(isPresented: $showingTemplateAdd) {
            AddTemplateView(store: store)
        }
        .sheet(item: $editingTemplate) { template in
            EditTemplateView(store: store, template: template)
        }
        .alert("Import Template", isPresented: $showTemplateImport) {
            TextField("Paste template code", text: $templateImportText)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {}
            Button("Import") {
                do {
                    try store.importTemplate(from: templateImportText)
                    templateImportText = ""
                    showTemplateImportSuccess = true
                } catch {
                    templateImportErrorMessage = "Invalid template code."
                    showTemplateImportError = true
                }
            }
        } message: {
            Text("Paste a template code to import it.")
        }
        .alert("Import Failed", isPresented: $showTemplateImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(templateImportErrorMessage)
        }
        .alert("Template Ready to Share", isPresented: $showTemplateShareNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Template code copied to the clipboard.")
        }
        .alert("Template Imported", isPresented: $showTemplateImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Template added to your list.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("MyWorkout")
                    .font(.custom("Avenir Next", size: 34))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Spacer()
            }
            Text("Track what you lift, keep it simple.")
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(Color("Sand").opacity(0.7))
        }
    }

    private var stats: some View {
        let totalSets = store.sessions.reduce(0) { total, session in
            total + session.mergedExercises().filter { $0.type == .weights }.reduce(0) { $0 + $1.sets.count }
        }
        return HStack(spacing: 16) {
            StatCard(title: "Workouts", value: "\(store.sessions.count)")
            StatCard(title: "Total Sets", value: "\(totalSets)")
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Templates")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Spacer()
                Menu {
                    Button {
                        showingTemplateAdd = true
                    } label: {
                        Label("New Template", systemImage: "plus")
                    }
                    Button {
                        templateImportText = ""
                        showTemplateImport = true
                    } label: {
                        Label("Import Template", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(Color("Sand"))
                }
            }

            if store.templates.isEmpty {
                Text("Create a template to reuse your go-to workouts.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.templates) { template in
                            TemplateCard(
                                template: template,
                                onUse: {
                                    draftFromTemplate = template
                                },
                                onShare: {
                                    do {
                                        let code = try store.shareString(for: template)
                                        UIPasteboard.general.string = code
                                        showTemplateShareNotice = true
                                    } catch {
                                        templateImportErrorMessage = "Unable to share template."
                                        showTemplateImportError = true
                                    }
                                },
                                onEdit: {
                                    editingTemplate = template
                                },
                                onDelete: {
                                    store.removeTemplate(template)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Start")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))

            let recentExercises = recentWorkoutExercises(limit: 8)
            if recentExercises.isEmpty {
                Text("No exercises yet. Add a workout to start your log.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            } else {
                ForEach(recentExercises, id: \.self) { name in
                    Button {
                        startQuickWorkout(for: name)
                    } label: {
                        ExerciseHistoryCard(name: name, record: store.latestExerciseRecord(named: name))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func startQuickWorkout(for name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let type = store.latestExerciseRecord(named: trimmedName)?.exercise.type ?? .weights
        draftFromTemplate = WorkoutTemplate(
            id: UUID(),
            title: "Quick Start",
            exercises: [
                TemplateExercise(
                    id: UUID(),
                    name: trimmedName,
                    type: type,
                    weightKg: nil,
                    sets: nil,
                    repsPerSet: nil
                )
            ]
        )
    }

    private func recentWorkoutExercises(limit: Int) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for session in store.sessions.sorted(by: { $0.date > $1.date }) {
            for exercise in session.mergedExercises() {
                let trimmed = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = trimmed.lowercased()
                guard !trimmed.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                ordered.append(trimmed)
                if ordered.count >= limit {
                    return ordered
                }
            }
        }
        return ordered
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Workout")
            }
            .font(.custom("Avenir Next", size: 18))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color("Night"))
            .background(Color("Sand"))
            .clipShape(Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Color("Night").opacity(0.001))
    }
}

struct HistoryView: View {
    @ObservedObject var store: WorkoutStore
    @State private var editingSession: WorkoutSession?
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [Color("Night"), Color("Coal")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    Section {
                        if store.sessions.isEmpty {
                            EmptyStateView()
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))
                    } else {
                        ForEach(store.sessions) { session in
                            Button {
                                path.append(session.id)
                            } label: {
                                WorkoutSessionCard(
                                    session: session,
                                    sessionNumber: sessionNumbers[session.id] ?? 1,
                                    onDelete: { store.removeSession(session) },
                                    onSaveTemplate: { store.addTemplate(from: session) }
                                )
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.removeSession(session)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        editingSession = session
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(Color("Sand"))
                                }
                            }
                        }
                    } header: {
                        Text("History")
                            .font(.custom("Avenir Next", size: 28))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("Sand"))
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 0, trailing: 20))
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                                if let session = store.sessions.first(where: { $0.id == id }) {
                                    SessionDetailView(session: session) {
                                        editingSession = session
                                    }
                                }
            }
        }
        .onChange(of: store.sessions) { _, newSessions in
            let validIds = Set(newSessions.map { $0.id })
            if path.contains(where: { !validIds.contains($0) }) {
                path = path.filter { validIds.contains($0) }
            }
        }
        .sheet(item: $editingSession) { session in
            AddWorkoutView(store: store, template: nil, session: session)
        }
    }

    private var sessionNumbers: [UUID: Int] {
        let grouped = Dictionary(grouping: store.sessions) { session in
            Calendar.current.startOfDay(for: session.date)
        }
        var mapping: [UUID: Int] = [:]
        for (_, sessions) in grouped {
            let ordered = sessions.sorted { $0.date < $1.date }
            for (idx, session) in ordered.enumerated() {
                mapping[session.id] = idx + 1
            }
        }
        return mapping
    }
}

struct SettingsView: View {
    @ObservedObject var store: WorkoutStore
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument: BackupDocument?
    @State private var importErrorMessage: String?
    @State private var showImportError = false
    @State private var showResetConfirm = false
    @State private var showRebuildConfirm = false
    @State private var sessionWindowSelection: SessionMergeWindowOption = .threeHours
    @State private var pendingSessionWindow: SessionMergeWindowOption?
    @State private var isSettingUp = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.custom("Avenir Next", size: 30))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("Sand"))

                    preferencesCard
                    dataCard
                    aboutCard
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "myworkout-backup"
        ) { _ in }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                handleImport(from: url)
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showImportError = true
            }
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Unable to import backup.")
        }
        .alert("Reset All Data?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetAllData()
            }
        } message: {
            Text("This will permanently delete all workouts, templates, and exercise types on this device.")
        }
        .alert("Update History Sessions?", isPresented: $showRebuildConfirm) {
            Button("Keep Current", role: .cancel) {
                sessionWindowSelection = store.sessionMergeWindowOption
                pendingSessionWindow = nil
            }
            Button("Rebuild History", role: .destructive) {
                if let pendingSessionWindow {
                    store.sessionMergeWindowOption = pendingSessionWindow
                    store.rebuildSessions()
                }
                pendingSessionWindow = nil
            }
        } message: {
            Text("Changing the session window can regroup past workouts. Rebuild history to apply the new window?")
        }
        .onAppear {
            sessionWindowSelection = store.sessionMergeWindowOption
            DispatchQueue.main.async {
                isSettingUp = false
            }
        }
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(Color("Sand").opacity(0.7))

            VStack(alignment: .leading, spacing: 10) {
                Text("Session Window")
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(Color("Sand"))
                Text("Workouts logged within this window merge into the same session.")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))
                Picker("Session Window", selection: $sessionWindowSelection) {
                    ForEach(SessionMergeWindowOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color("Sand"))
                .onChange(of: sessionWindowSelection) { _, newValue in
                    guard !isSettingUp else { return }
                    guard newValue != store.sessionMergeWindowOption else { return }
                    if store.needsRebuild(for: newValue) {
                        pendingSessionWindow = newValue
                        showRebuildConfirm = true
                    } else {
                        store.sessionMergeWindowOption = newValue
                    }
                }
            }

            Divider()
                .overlay(Color("Sand").opacity(0.12))

            VStack(alignment: .leading, spacing: 8) {
                Text("Default Weight Unit")
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(Color("Sand"))
                Picker("Default Weight Unit", selection: $store.defaultWeightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card").opacity(0.9))
        )
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(Color("Sand").opacity(0.7))

            Button {
                do {
                    exportDocument = BackupDocument(data: try store.exportBackupData())
                    isExporting = true
                } catch {
                    importErrorMessage = error.localizedDescription
                    showImportError = true
                }
            } label: {
                settingsRow(title: "Export Backup", systemImage: "square.and.arrow.up")
            }

            Button {
                isImporting = true
            } label: {
                settingsRow(title: "Import Backup", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                settingsRow(title: "Reset All Data", systemImage: "trash", isDestructive: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card").opacity(0.9))
        )
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(Color("Sand").opacity(0.7))
            Text("MyWorkout")
                .font(.custom("Avenir Next", size: 18))
                .foregroundStyle(Color("Sand"))
            Text("Track what you lift, keep it simple.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(Color("Sand").opacity(0.7))
            Text("Version \(appVersion)")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color("Sand").opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card").opacity(0.9))
        )
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func settingsRow(title: String, systemImage: String, isDestructive: Bool = false) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(isDestructive ? Color.red.opacity(0.8) : Color("Sand"))
            Text(title)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(isDestructive ? Color.red.opacity(0.8) : Color("Sand"))
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func handleImport(from url: URL) {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            try store.importBackupData(data)
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
}

enum ProgressRange: String, CaseIterable {
    case week
    case month
    case all

    var label: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .all:
            return "All"
        }
    }
}

struct StrengthPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let reps: Int
}

struct VolumePoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}

struct WeekPoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let value: Int
    let calories: Int
    let minutes: Int
}

struct PRItem: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
    let weight: Double
    let reps: Int
}

struct FocusItem: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct ProgressTabView: View {
    @ObservedObject var store: WorkoutStore
    @State private var range: ProgressRange = .month
    @State private var selectedExercise = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Progress")
                        .font(.custom("Avenir Next", size: 30))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("Sand"))

                    Picker("Range", selection: $range) {
                        ForEach(ProgressRange.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    strengthSection
                    volumeSection
                    consistencySection
                    cardioSection
                    prSection
                    focusSection
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
        }
        .onAppear {
            if selectedExercise.isEmpty {
                selectedExercise = recentExerciseNames.first ?? ""
            }
        }
        .onChange(of: store.sessions.count) { _, _ in
            if selectedExercise.isEmpty {
                selectedExercise = recentExerciseNames.first ?? ""
            }
        }
    }

    private var filteredSessions: [WorkoutSession] {
        let cutoff = rangeStartDate()
        return store.sessions.filter { session in
            guard let cutoff else { return true }
            return session.date >= cutoff
        }
        .sorted { $0.date < $1.date }
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Strength Trend")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Spacer()
                if !recentExerciseNames.isEmpty {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(recentExerciseNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color("Sand"))
                }
            }

            if strengthPoints.isEmpty {
                emptyCard(text: "No strength data yet.")
            } else {
                Chart {
                    ForEach(strengthPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(Color("Sand"))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(Color("Sand"))
                    }
                }
                .frame(height: 220)
                .chartYAxisLabel("Kg")
                .chartXAxisLabel("Date")
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color("Card").opacity(0.9))
                )
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume Trend")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))

            if volumePoints.isEmpty {
                emptyCard(text: "No volume data yet.")
            } else {
                Chart {
                    ForEach(volumePoints) { point in
                        BarMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(Color("Sand").opacity(0.7))
                    }
                }
                .frame(height: 220)
                .chartYAxisLabel("Total Volume")
                .chartXAxisLabel("Date")
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color("Card").opacity(0.9))
                )
            }
        }
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Consistency")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))

            if weeklyWorkouts.isEmpty {
                emptyCard(text: "No workouts yet.")
            } else {
                Chart {
                    ForEach(weeklyWorkouts) { point in
                        BarMark(
                            x: .value("Week", point.weekStart),
                            y: .value("Workouts", point.value)
                        )
                        .foregroundStyle(Color("Sand"))
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel("Sessions")
                .chartXAxisLabel("Week")
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color("Card").opacity(0.9))
                )
            }
        }
    }

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cardio Trend")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))

            if weeklyCardio.isEmpty {
                emptyCard(text: "No cardio yet.")
            } else {
                Chart {
                    ForEach(weeklyCardio) { point in
                        BarMark(
                            x: .value("Week", point.weekStart),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(Color("Sand").opacity(0.7))

                        LineMark(
                            x: .value("Week", point.weekStart),
                            y: .value("Calories", point.calories)
                        )
                        .foregroundStyle(Color("Sand"))
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel("Minutes / Calories")
                .chartXAxisLabel("Week")
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color("Card").opacity(0.9))
                )
            }
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent PRs")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))

            if prItems.isEmpty {
                emptyCard(text: "No PRs yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(prItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.custom("Avenir Next", size: 16))
                                    .foregroundStyle(Color("Sand"))
                                Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.custom("Avenir Next", size: 12))
                                    .foregroundStyle(Color("Sand").opacity(0.6))
                            }
                            Spacer()
                            Text(String(format: "%.1f kg x %d", item.weight, item.reps))
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(Color("Sand"))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color("Card").opacity(0.9))
                        )
                    }
                }
            }
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Focus")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))

            if focusItems.isEmpty {
                emptyCard(text: "No exercise focus yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(focusItems) { item in
                        HStack {
                            Text(item.name)
                                .font(.custom("Avenir Next", size: 16))
                                .foregroundStyle(Color("Sand"))
                            Spacer()
                            Text("\(item.count) sets")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(Color("Sand").opacity(0.8))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color("Card").opacity(0.9))
                        )
                    }
                }
            }
        }
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.custom("Avenir Next", size: 14))
            .foregroundStyle(Color("Sand").opacity(0.6))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("Card").opacity(0.85))
            )
    }

    private func rangeStartDate() -> Date? {
        switch range {
        case .week:
            return Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .month:
            return Calendar.current.date(byAdding: .month, value: -1, to: Date())
        case .all:
            return nil
        }
    }

    private var recentExerciseNames: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for session in store.sessions.sorted(by: { $0.date > $1.date }) {
            for exercise in session.mergedExercises() where exercise.type == .weights {
                let trimmed = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = trimmed.lowercased()
                guard !trimmed.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                ordered.append(trimmed)
            }
        }
        return ordered
    }

    private var strengthPoints: [StrengthPoint] {
        let name = selectedExercise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return [] }
        var points: [StrengthPoint] = []
        for session in filteredSessions {
            guard let exercise = session.mergedExercises().first(where: {
                $0.type == .weights && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name.lowercased()
            }) else { continue }
            let bestSet = exercise.sets.max { $0.weightKg < $1.weightKg }
            guard let bestSet else { continue }
            points.append(StrengthPoint(date: session.date, weight: bestSet.weightKg, reps: bestSet.reps))
        }
        return points
    }

    private var volumePoints: [VolumePoint] {
        filteredSessions.map { session in
            let volume = session.mergedExercises().filter { $0.type == .weights }.reduce(0.0) { total, exercise in
                total + exercise.sets.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
            }
            return VolumePoint(date: session.date, volume: volume)
        }
    }

    private var weeklyWorkouts: [WeekPoint] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)) ?? session.date
        }
        return grouped.map { weekStart, sessions in
            WeekPoint(weekStart: weekStart, value: sessions.count, calories: 0, minutes: 0)
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    private var weeklyCardio: [WeekPoint] {
        let cardioSessions = filteredSessions.filter { session in
            session.mergedExercises().contains { $0.type == .cardio }
        }
        let grouped = Dictionary(grouping: cardioSessions) { session in
            Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)) ?? session.date
        }
        return grouped.map { weekStart, sessions in
            let totals = sessions.reduce(into: (minutes: 0, calories: 0)) { result, session in
                for exercise in session.mergedExercises() where exercise.type == .cardio {
                    result.minutes += exercise.durationMinutes ?? 0
                    result.calories += exercise.calories ?? 0
                }
            }
            return WeekPoint(weekStart: weekStart, value: 0, calories: totals.calories, minutes: totals.minutes)
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    private var prItems: [PRItem] {
        var bestByName: [String: Double] = [:]
        var items: [PRItem] = []
        let sessions = filteredSessions.sorted { $0.date < $1.date }
        for session in sessions {
            for exercise in session.mergedExercises() where exercise.type == .weights {
                let name = exercise.name
                let bestSet = exercise.sets.max { $0.weightKg < $1.weightKg }
                guard let bestSet else { continue }
                let currentBest = bestByName[name] ?? 0
                if bestSet.weightKg > currentBest {
                    bestByName[name] = bestSet.weightKg
                    items.append(PRItem(name: name, date: session.date, weight: bestSet.weightKg, reps: bestSet.reps))
                }
            }
        }
        return Array(items.suffix(5).reversed())
    }

    private var focusItems: [FocusItem] {
        var counts: [String: Int] = [:]
        for session in filteredSessions {
            for exercise in session.mergedExercises() where exercise.type == .weights {
                counts[exercise.name, default: 0] += exercise.sets.count
            }
        }
        return counts
            .map { FocusItem(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
}

struct ExerciseHistoryCard: View {
    let name: String
    let record: (exercise: WorkoutExercise, date: Date)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))

            if let record {
                Text("Last used \(record.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))

                HStack(spacing: 12) {
                    ForEach(tags(for: record.exercise), id: \.self) { tag in
                        TagView(text: tag)
                    }
                }
            } else {
                Text("No logged workout yet")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("Card").opacity(0.9))
        )
    }

    private func tags(for exercise: WorkoutExercise) -> [String] {
        switch exercise.type {
        case .weights:
            let setCount = exercise.sets.count
            let maxWeight = exercise.sets.map(\.weightKg).max() ?? 0
            let maxReps = exercise.sets.map(\.reps).max() ?? 0
            let isBodyweight = !exercise.sets.isEmpty && exercise.sets.allSatisfy { $0.weightKg == 0 }
            var tags = ["\(setCount) sets"]
            if setCount > 0 {
                if isBodyweight {
                    tags.append("Bodyweight")
                } else {
                    tags.append(String(format: "Max %.1f kg", maxWeight))
                }
                tags.append("Max \(maxReps) reps")
            }
            return tags
        case .cardio:
            var tags: [String] = []
            if let duration = exercise.durationMinutes, duration > 0 {
                tags.append("\(duration) min")
            }
            if let calories = exercise.calories, calories > 0 {
                tags.append("\(calories) cal")
            }
            return tags.isEmpty ? ["Cardio"] : tags
        }
    }
}

struct ExerciseDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: ExerciseType
    var sets: [WorkoutSetDraft]
    var isBodyweight: Bool
    var weightUnit: WeightUnit
    var durationMinutes: String
    var calories: String
    var durationPlaceholder: String
    var caloriesPlaceholder: String

    init(
        id: UUID = UUID(),
        name: String = "",
        type: ExerciseType = .weights,
        sets: [WorkoutSetDraft] = [WorkoutSetDraft()],
        isBodyweight: Bool = false,
        weightUnit: WeightUnit = .kg,
        durationMinutes: String = "",
        calories: String = "",
        durationPlaceholder: String = "",
        caloriesPlaceholder: String = ""
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sets = sets
        self.isBodyweight = isBodyweight
        self.weightUnit = weightUnit
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.durationPlaceholder = durationPlaceholder
        self.caloriesPlaceholder = caloriesPlaceholder
    }
}

struct WorkoutSetDraft: Identifiable, Equatable {
    let id: UUID
    var weight: String
    var reps: String
    var weightPlaceholder: String
    var repsPlaceholder: String

    init(
        id: UUID = UUID(),
        weight: String = "",
        reps: String = "",
        weightPlaceholder: String = "",
        repsPlaceholder: String = ""
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.weightPlaceholder = weightPlaceholder
        self.repsPlaceholder = repsPlaceholder
    }
}

struct AddWorkoutView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate?
    let session: WorkoutSession?
    @Environment(\.dismiss) private var dismiss

    @State private var workoutDate = Date()
    @State private var drafts: [ExerciseDraft] = []
    @State private var hasLoadedDrafts = false

    private var validation: (validExercises: [WorkoutExercise], hasInvalid: Bool) {
        var validExercises: [WorkoutExercise] = []
        var hasInvalid = false

        for draft in drafts {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            switch draft.type {
            case .weights:
                var setModels: [WorkoutSet] = []
                var hasPartialSet = false

                for setDraft in draft.sets {
                    let weightText = setDraft.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsText = setDraft.reps.trimmingCharacters(in: .whitespacesAndNewlines)

                    if draft.isBodyweight {
                        if repsText.isEmpty {
                            continue
                        }

                        guard let repsValue = Int(repsText), repsValue > 0 else {
                            hasPartialSet = true
                            continue
                        }

                        setModels.append(WorkoutSet(id: UUID(), weightKg: 0, reps: repsValue))
                        continue
                    }

                    if weightText.isEmpty && repsText.isEmpty {
                        continue
                    }

                    if weightText.isEmpty || repsText.isEmpty {
                        hasPartialSet = true
                        continue
                    }

                    guard let inputValue = Double(weightText),
                          let repsValue = Int(repsText) else {
                        hasPartialSet = true
                        continue
                    }

                    let weightValue = draft.weightUnit == .lb ? inputValue * 0.45359237 : inputValue
                    guard repsValue > 0, weightValue > 0 else {
                        hasPartialSet = true
                        continue
                    }

                    setModels.append(WorkoutSet(id: UUID(), weightKg: weightValue, reps: repsValue))
                }

                let hasAnySetInput = draft.isBodyweight
                    ? draft.sets.contains { !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    : draft.sets.contains {
                        !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }

                if hasPartialSet {
                    hasInvalid = true
                    continue
                }

                if name.isEmpty && hasAnySetInput {
                    hasInvalid = true
                    continue
                }

                guard !setModels.isEmpty else {
                    continue
                }

                guard !name.isEmpty else {
                    hasInvalid = true
                    continue
                }

                validExercises.append(
                    WorkoutExercise(
                        id: UUID(),
                        name: name,
                        type: .weights,
                        sets: setModels,
                        durationMinutes: nil,
                        calories: nil,
                        loggedAt: workoutDate
                    )
                )
            case .cardio:
                let durationTrimmed = draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
                let caloriesTrimmed = draft.calories.trimmingCharacters(in: .whitespacesAndNewlines)
                let durationValue = durationTrimmed.isEmpty ? nil : Int(durationTrimmed)
                let caloriesValue = caloriesTrimmed.isEmpty ? nil : Int(caloriesTrimmed)
                let hasMetrics = durationValue != nil || caloriesValue != nil

                if name.isEmpty && (!durationTrimmed.isEmpty || !caloriesTrimmed.isEmpty) {
                    hasInvalid = true
                    continue
                }

                if let durationValue, durationValue <= 0 { hasInvalid = true; continue }
                if let caloriesValue, caloriesValue <= 0 { hasInvalid = true; continue }

                if name.isEmpty && !hasMetrics {
                    continue
                }

                guard hasMetrics, !name.isEmpty else {
                    hasInvalid = true
                    continue
                }

                validExercises.append(
                    WorkoutExercise(
                        id: UUID(),
                        name: name,
                        type: .cardio,
                        sets: [],
                        durationMinutes: durationValue,
                        calories: caloriesValue,
                        loggedAt: workoutDate
                    )
                )
            }
        }

        return (validExercises, hasInvalid)
    }

    private var validExercises: [WorkoutExercise] {
        validation.validExercises
    }

    private var canSave: Bool {
        !drafts.isEmpty && !validExercises.isEmpty && !validation.hasInvalid
    }

    private var titleText: String {
        session == nil ? "New Workout" : "Edit Workout"
    }

    private var saveLabel: String {
        session == nil ? "Save Workout" : "Update Workout"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(titleText)
                            .font(.custom("Avenir Next", size: 28))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("Sand"))

                        datePickerCard

                        ForEach($drafts) { $draft in
                            ExerciseEditorRow(
                                draft: $draft,
                                suggestions: store.exerciseNameCatalog(),
                                showsMetrics: true,
                                knownType: store.exerciseType(for: draft.name),
                                onDelete: {
                                    drafts.removeAll { $0.id == draft.id }
                                },
                                onMoveUp: nil,
                                onMoveDown: nil
                            )
                        }

                        Button {
                            drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Exercise")
                            }
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(Color("Sand"))
                        }
                    }
                    .padding(24)
                }

                Button {
                    if let session {
                        store.updateSession(session, date: workoutDate, exercises: validExercises)
                    } else {
                        store.addSession(date: workoutDate, exercises: validExercises)
                    }
                    dismiss()
                } label: {
                    Text(saveLabel)
                        .font(.custom("Avenir Next", size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color("Night"))
                        .background(Color("Sand"))
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
            }
        }
        .onAppear {
            guard !hasLoadedDrafts else { return }
            hasLoadedDrafts = true
            if let session {
                workoutDate = session.date
                drafts = drafts(for: session)
                return
            }
            if let template {
                drafts = store.resolvedDrafts(for: template)
            } else {
                drafts = [ExerciseDraft(weightUnit: store.defaultWeightUnit)]
            }
        }
    }

    private func drafts(for session: WorkoutSession) -> [ExerciseDraft] {
        session.mergedExercises().map { exercise in
            switch exercise.type {
            case .weights:
                let setDrafts = exercise.sets.map {
                    WorkoutSetDraft(
                        weight: $0.weightKg == 0 ? "" : String(format: "%.1f", weightValue($0.weightKg, unit: store.defaultWeightUnit)),
                        reps: "\($0.reps)"
                    )
                }
                let isBodyweight = exercise.sets.allSatisfy { $0.weightKg == 0 }
                return ExerciseDraft(
                    name: exercise.name,
                    type: .weights,
                    sets: setDrafts.isEmpty ? [WorkoutSetDraft()] : setDrafts,
                    isBodyweight: isBodyweight,
                    weightUnit: store.defaultWeightUnit
                )
            case .cardio:
                return ExerciseDraft(
                    name: exercise.name,
                    type: .cardio,
                    sets: [],
                    weightUnit: store.defaultWeightUnit,
                    durationMinutes: formattedOptionalInt(exercise.durationMinutes),
                    calories: formattedOptionalInt(exercise.calories)
                )
            }
        }
    }

    private var datePickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color("Sand").opacity(0.6))
            HStack {
                Text(relativeLabel(for: workoutDate))
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(Color("Sand"))
                Spacer()
                DatePicker(
                    "",
                    selection: $workoutDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .colorScheme(.dark)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("Card"))
            )
        }
    }

    private func relativeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func formattedOptionalInt(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private func weightValue(_ kg: Double, unit: WeightUnit) -> Double {
        if unit == .lb {
            return kg * 2.20462262
        }
        return kg
    }
}

struct ExerciseEditorRow: View {
    @Binding var draft: ExerciseDraft
    let suggestions: [String]
    let showsMetrics: Bool
    let knownType: ExerciseType?
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    @State private var lastUnit: WeightUnit = .kg
    @State private var isNameFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Exercise")
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(Color("Sand").opacity(0.6))
                let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if let knownType {
                    typeBadge(for: knownType)
                } else if trimmedName.isEmpty {
                    typePlaceholder
                } else {
                    typePicker
                }
                if showsMetrics && draft.type == .weights {
                    bodyweightToggle
                }
                Spacer()
                if let onMoveUp {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(Color("Sand").opacity(0.7))
                    }
                }
                if let onMoveDown {
                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(Color("Sand").opacity(0.7))
                    }
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color("Sand").opacity(0.8))
                }
            }

            ExerciseNameField(
                title: "Exercise",
                showsTitle: false,
                text: $draft.name,
                suggestions: suggestions,
                onFocusChange: { isNameFocused = $0 }
            )
            .zIndex(2)

            if showsMetrics {
                if draft.type == .weights {
                    ForEach($draft.sets) { $set in
                        let setId = $set.wrappedValue.id
                        HStack(alignment: .center, spacing: 12) {
                            InputCard(
                                title: "Reps",
                                text: $set.reps,
                                placeholder: set.repsPlaceholder.isEmpty ? "10" : set.repsPlaceholder,
                                keyboard: .numberPad
                            )
                            if !draft.isBodyweight {
                                InputCard(
                                    title: "Weight",
                                    text: $set.weight,
                                    placeholder: set.weightPlaceholder.isEmpty ? "10" : set.weightPlaceholder,
                                    keyboard: .decimalPad
                                )
                                UnitPillAligned(unit: $draft.weightUnit)
                            }
                            if draft.sets.count > 1 {
                                Button(role: .destructive) {
                                    draft.sets.removeAll { $0.id == setId }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(Color("Sand").opacity(0.7))
                                }
                                .frame(width: 32, height: 32)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color("Card").opacity(0.6))
                        )
                    }
                    .animation(.easeInOut(duration: 0.2), value: draft.sets.count)

                    Divider()
                        .overlay(Color("Sand").opacity(0.12))

                    Button {
                        draft.sets.append(WorkoutSetDraft())
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Set")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(Color("Sand"))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 12) {
                        InputCard(
                            title: "Time (min)",
                            text: $draft.durationMinutes,
                            placeholder: draft.durationPlaceholder.isEmpty ? "20" : draft.durationPlaceholder,
                            keyboard: .numberPad
                        )
                        InputCard(
                            title: "Calories",
                            text: $draft.calories,
                            placeholder: draft.caloriesPlaceholder.isEmpty ? "150" : draft.caloriesPlaceholder,
                            keyboard: .numberPad
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("Card"))
        )
        .zIndex(isNameFocused ? 5 : 1)
        .onAppear {
            lastUnit = draft.weightUnit
            if let knownType {
                draft.type = knownType
            }
        }
        .onChange(of: draft.weightUnit) { _, newValue in
            guard lastUnit != newValue else { return }
            convertWeights(from: lastUnit, to: newValue)
            lastUnit = newValue
        }
        .onChange(of: draft.isBodyweight) { _, isBodyweight in
            if isBodyweight {
                draft.sets = draft.sets.map { set in
                    WorkoutSetDraft(
                        id: set.id,
                        weight: "",
                        reps: set.reps,
                        weightPlaceholder: "",
                        repsPlaceholder: set.repsPlaceholder
                    )
                }
            }
        }
        .onChange(of: knownType) { _, newValue in
            if let newValue {
                draft.type = newValue
            }
        }
        .onChange(of: draft.name) { _, _ in
            if let knownType {
                draft.type = knownType
            }
        }
        .onChange(of: draft.type) { _, newValue in
            if newValue == .cardio {
                draft.isBodyweight = false
            }
        }
    }

    private var typePicker: some View {
        Picker("Type", selection: $draft.type) {
            ForEach(ExerciseType.allCases, id: \.self) { type in
                Text(type.label).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.mini)
        .scaleEffect(0.9)
    }

    private var bodyweightToggle: some View {
        Button {
            draft.isBodyweight.toggle()
        } label: {
            Text("Bodyweight")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(draft.isBodyweight ? Color("Night") : Color("Sand"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(draft.isBodyweight ? Color("Sand") : Color("Sand").opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func convertWeights(from: WeightUnit, to: WeightUnit) {
        guard from != to, !draft.isBodyweight else { return }
        let multiplier: Double
        if from == .kg && to == .lb {
            multiplier = 2.20462262
        } else {
            multiplier = 0.45359237
        }
        draft.sets = draft.sets.map { set in
            let value = Double(set.weight) ?? 0
            let converted = roundToHalf(value * multiplier)
            let placeholderValue = Double(set.weightPlaceholder) ?? 0
            let convertedPlaceholder = roundToHalf(placeholderValue * multiplier)
            return WorkoutSetDraft(
                id: set.id,
                weight: value == 0 ? "" : String(format: "%.1f", converted),
                reps: set.reps,
                weightPlaceholder: placeholderValue == 0 ? set.weightPlaceholder : String(format: "%.1f", convertedPlaceholder),
                repsPlaceholder: set.repsPlaceholder
            )
        }
    }

    private func roundToHalf(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }

    private func typeBadge(for type: ExerciseType) -> some View {
        Text(type.label)
            .font(.custom("Avenir Next", size: 12))
            .foregroundStyle(Color("Sand"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color("Sand").opacity(0.12))
            )
    }

    private var typePlaceholder: some View {
        Text("Type")
            .font(.custom("Avenir Next", size: 12))
            .foregroundStyle(Color("Sand").opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color("Sand").opacity(0.08))
            )
    }
}

struct WorkoutSessionCard: View {
    let session: WorkoutSession
    let sessionNumber: Int
    let onDelete: () -> Void
    let onSaveTemplate: (() -> Void)?

    init(
        session: WorkoutSession,
        sessionNumber: Int,
        onDelete: @escaping () -> Void,
        onSaveTemplate: (() -> Void)? = nil
    ) {
        self.session = session
        self.sessionNumber = sessionNumber
        self.onDelete = onDelete
        self.onSaveTemplate = onSaveTemplate
    }

    var body: some View {
        let mergedExercises = session.mergedExercises()
        let weightExercises = mergedExercises.filter { $0.type == .weights }
        let cardioExercises = mergedExercises.filter { $0.type == .cardio }
        let totalSets = weightExercises.reduce(0) { $0 + $1.sets.count }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(session.date.formatted(date: .abbreviated, time: .omitted)) • Session \(sessionNumber)")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Spacer()
                Text("\(mergedExercises.count) exercises")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            }

            HStack(spacing: 12) {
                if totalSets > 0 {
                    TagView(text: "\(totalSets) sets")
                }
                if !cardioExercises.isEmpty {
                    TagView(text: "\(cardioExercises.count) cardio")
                }
                if let first = mergedExercises.first {
                    TagView(text: first.name)
                }
                if mergedExercises.count > 1 {
                    TagView(text: "+\(mergedExercises.count - 1) more")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(mergedExercises.prefix(3)) { exercise in
                    Text(sessionLine(for: exercise))
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Color("Sand").opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("Sand").opacity(0.08), lineWidth: 1)
                )
        )
        .contextMenu {
            if let onSaveTemplate {
                Button {
                    onSaveTemplate()
                } label: {
                    Label("Save as Template", systemImage: "square.and.arrow.down")
                }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func sessionLine(for exercise: WorkoutExercise) -> String {
        switch exercise.type {
        case .weights:
            return "\(exercise.name) - \(exercise.sets.count) sets"
        case .cardio:
            var details: [String] = []
            if let duration = exercise.durationMinutes, duration > 0 {
                details.append("\(duration) min")
            }
            if let calories = exercise.calories, calories > 0 {
                details.append("\(calories) cal")
            }
            if details.isEmpty {
                details.append("Cardio")
            }
            return "\(exercise.name) - \(details.joined(separator: ", "))"
        }
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession
    let onEdit: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("Sand"))

                    ForEach(session.mergedExercises()) { exercise in
                        ExerciseDetailCard(exercise: exercise)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    onEdit()
                }
                .foregroundStyle(Color("Sand"))
            }
        }
    }
}

struct ExerciseDetailCard: View {
    let exercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exercise.name)
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Spacer()
                Text(exercise.type.label)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            }

            switch exercise.type {
            case .weights:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        Text("Set \(index + 1): \(weightLabel(for: set.weightKg)) x \(set.reps)")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(Color("Sand").opacity(0.7))
                    }
                }
            case .cardio:
                VStack(alignment: .leading, spacing: 6) {
                    if let minutes = exercise.durationMinutes, minutes > 0 {
                        Text("Duration: \(minutes) min")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(Color("Sand").opacity(0.7))
                    }
                    if let calories = exercise.calories, calories > 0 {
                        Text("Calories: \(calories) cal")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(Color("Sand").opacity(0.7))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("Sand").opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func weightLabel(for kg: Double) -> String {
        if kg == 0 { return "Bodyweight" }
        return String(format: "%.1f kg", kg)
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color("Sand").opacity(0.6))
            Text(value)
                .font(.custom("Avenir Next", size: 22))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card").opacity(0.8))
        )
    }
}

struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("Avenir Next", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color("Sand").opacity(0.12))
            )
            .foregroundStyle(Color("Sand"))
    }
}

struct ExerciseNameField: View {
    let title: String
    let showsTitle: Bool
    @Binding var text: String
    let suggestions: [String]
    let onFocusChange: ((Bool) -> Void)?
    @FocusState private var isFocused: Bool

    private var matches: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return suggestions
            .filter { $0.lowercased().contains(query) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text(title)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            }
            ZStack(alignment: .topLeading) {
                TextField("Bicep Curls", text: $text)
                    .font(.custom("Avenir Next", size: 18))
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(Color("Sand"))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("Card").opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isFocused ? Color("Sand").opacity(0.35) : Color("Sand").opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .focused($isFocused)

                if isFocused && !matches.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(matches, id: \.self) { name in
                                Button {
                                    text = name
                                    isFocused = false
                                } label: {
                                    Text(name)
                                        .font(.custom("Avenir Next", size: 13))
                                        .foregroundStyle(Color("Sand"))
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                    }
                    .frame(maxHeight: 160)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("Card").opacity(0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("Sand").opacity(0.12), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
                    .offset(y: 54)
                    .zIndex(3)
                }
            }
            .zIndex(3)
        }
        .onChange(of: isFocused) { _, newValue in
            onFocusChange?(newValue)
        }
    }
}

struct ExerciseLibraryView: View {
    @ObservedObject var store: WorkoutStore
    @State private var searchText = ""
    @State private var draftTemplate: WorkoutTemplate?

    private var groupedExercises: [MuscleGroup: [LibraryExercise]] {
        let filtered = store.exerciseLibrary.filter { exercise in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return exercise.name.lowercased().contains(query.lowercased())
        }
        return Dictionary(grouping: filtered, by: \.group)
    }

    private var orderedGroups: [MuscleGroup] {
        MuscleGroup.allCases.filter { group in
            (groupedExercises[group] ?? []).isEmpty == false
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color("Sand").opacity(0.6))
                        TextField("Search exercises", text: $searchText)
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(Color("Sand"))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color("Card"))
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Explore")
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("Sand"))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 6, trailing: 20))

                ForEach(orderedGroups, id: \.self) { group in
                    Section {
                        ForEach(groupedExercises[group] ?? []) { exercise in
                            Button {
                                startQuickWorkout(for: exercise.name)
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .font(.custom("Avenir Next", size: 16))
                                        .foregroundStyle(Color("Sand"))
                                    Spacer()
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.custom("Avenir Next", size: 14))
                                        .foregroundStyle(Color("Sand").opacity(0.35))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color("Card").opacity(0.9))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color("Sand").opacity(0.08), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        }
                    } header: {
                        HStack(spacing: 10) {
                            Capsule()
                                .fill(Color("Sand").opacity(0.18))
                                .frame(width: 18, height: 6)
                            Text(group.rawValue.uppercased())
                                .font(.custom("Avenir Next", size: 13))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("Sand").opacity(0.75))
                        }
                        .padding(.top, 8)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                }
            }
            .listStyle(.plain)
            .listRowSeparator(.hidden)
            .scrollContentBackground(.hidden)
        }
        .sheet(item: $draftTemplate) { template in
            AddWorkoutView(store: store, template: template, session: nil)
        }
    }

    private func startQuickWorkout(for name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let type = store.exerciseType(for: trimmedName) ?? .weights
        draftTemplate = WorkoutTemplate(
            id: UUID(),
            title: "Explore",
            exercises: [
                TemplateExercise(
                    id: UUID(),
                    name: trimmedName,
                    type: type,
                    weightKg: nil,
                    sets: nil,
                    repsPerSet: nil
                )
            ]
        )
    }
}

struct InputCard: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let keyboard: UIKeyboardType
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color("Sand").opacity(0.75))
            TextField(placeholder, text: $text)
                .font(.custom("Avenir Next", size: 14))
                .keyboardType(keyboard)
                .foregroundStyle(Color("Sand"))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("Card").opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isFocused ? Color("Sand").opacity(0.35) : Color("Sand").opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                )
                .focused($isFocused)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UnitPillAligned: View {
    @Binding var unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Unit")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(.clear)
            unitPill
        }
        .padding(.top, 2)
    }

    private var unitPill: some View {
        Menu {
            Button("kg") { unit = .kg }
            Button("lb") { unit = .lb }
        } label: {
            Text(unit.label)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(Color("Sand"))
                .frame(width: 44, height: 32)
                .background(
                    Capsule()
                        .fill(Color("Sand").opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(Color("Sand").opacity(0.18), lineWidth: 1)
                        )
                )
        }
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color("Night"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color("Sand"))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No workouts yet")
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))
            Text("Add a workout or create a template to get started.")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(Color("Sand").opacity(0.6))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card").opacity(0.8))
        )
    }
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onUse: () -> Void
    let onShare: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onUse) {
            VStack(alignment: .leading, spacing: 8) {
                Text(template.title)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Text("\(template.exercises.count) exercises")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.7))
                if let first = template.exercises.first {
                    Text("Starts with \(first.name)")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Color("Sand").opacity(0.6))
                }
            }
            .padding(16)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color("Card").opacity(0.9))
            )
        }
        .contextMenu {
            Button {
                onShare()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddTemplateView: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var drafts: [ExerciseDraft] = [ExerciseDraft()]
    @State private var editMode: EditMode = .inactive

    private var validExercises: [TemplateExercise] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            return TemplateExercise(
                id: UUID(),
                name: name,
                type: draft.type,
                weightKg: nil,
                sets: nil,
                repsPerSet: nil
            )
        }
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && validExercises.count == drafts.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Template")
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("Sand"))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    InputCard(title: "Template Name", text: $title, placeholder: "Push Day", keyboard: .default)
                        .padding(.leading, 24)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                }

                List {
                    ForEach($drafts) { $draft in
                        ExerciseEditorRow(
                            draft: $draft,
                            suggestions: store.exerciseNameCatalog(),
                            showsMetrics: false,
                            knownType: store.exerciseType(for: draft.name),
                            onDelete: {
                                drafts.removeAll { $0.id == draft.id }
                                if drafts.isEmpty {
                                    drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
                                }
                            },
                            onMoveUp: nil,
                            onMoveDown: nil
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            editMode = .active
                        }
                    }
                    .onMove { source, destination in
                        drafts.move(fromOffsets: source, toOffset: destination)
                        editMode = .inactive
                    }

                    Button {
                        drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Exercise")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(Color("Sand"))
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 16, trailing: 16))
                    .buttonStyle(.plain)

                    Color.clear
                        .frame(height: 120)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)

                Button {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.addTemplate(title: trimmedTitle, exercises: validExercises)
                    dismiss()
                } label: {
                    Text("Save Template")
                        .font(.custom("Avenir Next", size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color("Night"))
                        .background(Color("Sand"))
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
            }
        }
    }
}

struct EditTemplateView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var drafts: [ExerciseDraft]
    @State private var editMode: EditMode = .inactive

    init(store: WorkoutStore, template: WorkoutTemplate) {
        self.store = store
        self.template = template
        _title = State(initialValue: template.title)
        _drafts = State(initialValue: template.exercises.map {
            ExerciseDraft(
                name: $0.name,
                type: $0.type,
                weightUnit: store.defaultWeightUnit
            )
        })
    }

    private var validExercises: [TemplateExercise] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return TemplateExercise(id: UUID(), name: name, type: draft.type, weightKg: nil, sets: nil, repsPerSet: nil)
        }
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && validExercises.count == drafts.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Edit Template")
                            .font(.custom("Avenir Next", size: 28))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("Sand"))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    InputCard(title: "Template Name", text: $title, placeholder: "Push Day", keyboard: .default)
                        .padding(.leading, 24)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                }

                List {
                    ForEach($drafts) { $draft in
                        ExerciseEditorRow(
                            draft: $draft,
                            suggestions: store.exerciseNameCatalog(),
                            showsMetrics: false,
                            knownType: store.exerciseType(for: draft.name),
                            onDelete: {
                                drafts.removeAll { $0.id == draft.id }
                                if drafts.isEmpty {
                                    drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
                                }
                            },
                            onMoveUp: nil,
                            onMoveDown: nil
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            editMode = .active
                        }
                    }
                    .onMove { source, destination in
                        drafts.move(fromOffsets: source, toOffset: destination)
                        editMode = .inactive
                    }

                    Button {
                        drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Exercise")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(Color("Sand"))
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 16, trailing: 16))
                    .buttonStyle(.plain)

                    Color.clear
                        .frame(height: 120)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)

                Button {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.updateTemplate(id: template.id, title: trimmedTitle, exercises: validExercises)
                    dismiss()
                } label: {
                    Text("Save Changes")
                        .font(.custom("Avenir Next", size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color("Night"))
                        .background(Color("Sand"))
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("Sand").opacity(0.6))
            TextField(placeholder, text: $text)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(Color("Sand"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("Card"))
        )
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
 
