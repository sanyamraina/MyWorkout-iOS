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
import PhotosUI
import AVFoundation
import CoreImage.CIFilterBuiltins

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

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case midnightSand
    case studioMinimal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .midnightSand:
            return "Dark"
        case .studioMinimal:
            return "Light"
        }
    }

    var nightAsset: String {
        switch self {
        case .midnightSand:
            return "MidnightSandNight"
        case .studioMinimal:
            return "StudioMinimalNight"
        }
    }

    var coalAsset: String {
        switch self {
        case .midnightSand:
            return "MidnightSandCoal"
        case .studioMinimal:
            return "StudioMinimalCoal"
        }
    }

    var sandAsset: String {
        switch self {
        case .midnightSand:
            return "MidnightSandSand"
        case .studioMinimal:
            return "StudioMinimalSand"
        }
    }

    var cardAsset: String {
        switch self {
        case .midnightSand:
            return "MidnightSandCard"
        case .studioMinimal:
            return "StudioMinimalCard"
        }
    }
}

enum ThemeColorKey {
    case night
    case coal
    case sand
    case card
}

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()
    @Published var selectedTheme: AppTheme = .midnightSand {
        didSet { saveTheme() }
    }

    private init() {
        selectedTheme = loadTheme()
    }

    private func loadTheme() -> AppTheme {
        let raw = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.midnightSand.rawValue
        return AppTheme(rawValue: raw) ?? .midnightSand
    }

    private func saveTheme() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
    }
}

private func themeColor(_ key: ThemeColorKey) -> Color {
    let theme = ThemeStore.shared.selectedTheme
    switch key {
    case .night:
        return Color(theme.nightAsset)
    case .coal:
        return Color(theme.coalAsset)
    case .sand:
        return Color(theme.sandAsset)
    case .card:
        return Color(theme.cardAsset)
    }
}

private func combineDate(_ date: Date, time: Date) -> Date {
    let calendar = Calendar.current
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
    return calendar.date(
        bySettingHour: timeComponents.hour ?? 0,
        minute: timeComponents.minute ?? 0,
        second: timeComponents.second ?? 0,
        of: date
    ) ?? date
}

private func isFutureDay(_ date: Date) -> Bool {
    let calendar = Calendar.current
    let selected = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: Date())
    return selected > today
}

private func distributedTimes(count: Int, start: Date, end: Date) -> [Date] {
    guard count > 1 else { return [start] }
    let interval = end.timeIntervalSince(start)
    guard interval > 0 else { return Array(repeating: start, count: count) }
    let step = interval / Double(count - 1)
    return (0..<count).map { index in
        start.addingTimeInterval(Double(index) * step)
    }
}

private func isNowTime(_ date: Date, within seconds: TimeInterval = 300) -> Bool {
    abs(date.timeIntervalSince(Date())) <= seconds
}

private func formattedDurationValue(_ seconds: Int?) -> String {
    guard let seconds, seconds > 0 else { return "" }
    let minutes = seconds / 60
    let remainder = seconds % 60
    return String(format: "%d:%02d", minutes, remainder)
}

private func durationLabel(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    if remainder == 0 {
        return "\(minutes) min"
    }
    return String(format: "%d:%02d", minutes, remainder)
}

private func formattedWeight(_ kg: Double, unit: WeightUnit) -> String {
    if kg == 0 { return "Bodyweight" }
    let value = unit == .lb ? kg * 2.20462262 : kg
    return String(format: "%.1f %@", value, unit.label)
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
    let durationSeconds: Int?
    let calories: Int?
    let loggedAt: Date?

    init(
        id: UUID,
        name: String,
        type: ExerciseType = .weights,
        sets: [WorkoutSet],
        durationSeconds: Int? = nil,
        calories: Int? = nil,
        loggedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sets = sets
        self.durationSeconds = durationSeconds
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
        if let durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            self.durationSeconds = durationSeconds
        } else if let durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) {
            self.durationSeconds = durationMinutes * 60
        } else {
            self.durationSeconds = nil
        }
        calories = try container.decodeIfPresent(Int.self, forKey: .calories)
        loggedAt = try container.decodeIfPresent(Date.self, forKey: .loggedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(sets, forKey: .sets)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
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
        case durationSeconds
        case calories
        case loggedAt
    }
}

struct WorkoutSetSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let weightKg: Double
    let reps: Int
}

struct WorkoutSet: Identifiable, Codable, Equatable {
    let id: UUID
    let segments: [WorkoutSetSegment]

    init(id: UUID, segments: [WorkoutSetSegment]) {
        self.id = id
        self.segments = segments
    }

    init(id: UUID, weightKg: Double, reps: Int) {
        self.id = id
        self.segments = [WorkoutSetSegment(id: UUID(), weightKg: weightKg, reps: reps)]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let segments = try? container.decode([WorkoutSetSegment].self, forKey: .segments) {
            self.segments = segments
        } else {
            let weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg) ?? 0
            let reps = try container.decodeIfPresent(Int.self, forKey: .reps) ?? 0
            self.segments = [WorkoutSetSegment(id: UUID(), weightKg: weightKg, reps: reps)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(segments, forKey: .segments)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case segments
        case weightKg
        case reps
    }
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

extension WorkoutExercise {
    var allSegments: [WorkoutSetSegment] {
        sets.flatMap(\.segments)
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
                        durationSeconds: nil,
                        calories: nil,
                        loggedAt: mergedLoggedAt
                    )
                case .cardio:
                    let currentSeconds = existing.durationSeconds ?? 0
                    let currentCalories = existing.calories ?? 0
                    let addSeconds = exercise.durationSeconds ?? 0
                    let addCalories = exercise.calories ?? 0
                    let totalSeconds = currentSeconds + addSeconds
                    let totalCalories = currentCalories + addCalories
                    let mergedLoggedAt = [existing.loggedAt, exercise.loggedAt].compactMap { $0 }.min()
                    mergedByKey[key] = WorkoutExercise(
                        id: existing.id,
                        name: existing.name,
                        type: existing.type,
                        sets: [],
                        durationSeconds: totalSeconds > 0 ? totalSeconds : nil,
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

final class WorkoutStore: ObservableObject {
    @Published private(set) var entries: [WorkoutExercise] = []
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var exerciseLibrary: [LibraryExercise] = WorkoutStore.defaultLibrary
    private var hasLoaded = false
    @Published private var exerciseTypeMap: [String: ExerciseType] = [:]
    @Published private var exerciseNotes: [String: String] = [:]
    @Published private var templateUsage: [String: Int] = [:]
    @Published var defaultWeightUnit: WeightUnit = .kg {
        didSet { saveDefaultWeightUnit() }
    }
    @Published var sessionMergeWindowOption: SessionMergeWindowOption = .threeHours {
        didSet { saveSessionMergeWindowOption() }
    }
    @Published var isDropSetsEnabled: Bool = true {
        didSet { saveDropSetsEnabled() }
    }
    @Published var isNotesEnabled: Bool = true {
        didSet { saveNotesEnabled() }
    }

    init() {
        defaultWeightUnit = loadDefaultWeightUnit()
        sessionMergeWindowOption = loadSessionMergeWindowOption()
        isDropSetsEnabled = loadDropSetsEnabled()
        isNotesEnabled = loadNotesEnabled()
        templateUsage = loadTemplateUsage()
        load()
    }

    func addSession(date: Date, exercises: [WorkoutExercise]) {
        let newEntries = exercises.map { exercise in
            WorkoutExercise(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                sets: exercise.sets,
                durationSeconds: exercise.durationSeconds,
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
                        durationSeconds: nil,
                        calories: nil,
                        loggedAt: mergedLoggedAt(current: current, incoming: exercise)
                    )
                case .cardio:
                    let currentSeconds = current.durationSeconds ?? 0
                    let currentCalories = current.calories ?? 0
                    let addSeconds = exercise.durationSeconds ?? 0
                    let addCalories = exercise.calories ?? 0
                    let totalSeconds = currentSeconds + addSeconds
                    let totalCalories = currentCalories + addCalories
                    merged[idx] = WorkoutExercise(
                        id: current.id,
                        name: current.name,
                        type: current.type,
                        sets: [],
                        durationSeconds: totalSeconds > 0 ? totalSeconds : nil,
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
                // Duration can be 0 minutes for single-exercise sessions (start == end).
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
            durationSeconds: exercise.durationSeconds,
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
                durationSeconds: exercise.durationSeconds,
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
        saveTemplateUsage()
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
        templateUsage.removeValue(forKey: template.id.uuidString)
        saveTemplates()
        saveTemplateUsage()
    }

    func templateUsageCount(for template: WorkoutTemplate) -> Int {
        templateUsage[template.id.uuidString] ?? 0
    }

    func incrementTemplateUsage(for template: WorkoutTemplate) {
        let key = template.id.uuidString
        templateUsage[key, default: 0] += 1
        saveTemplateUsage()
    }

    func resolvedDrafts(for template: WorkoutTemplate) -> [ExerciseDraft] {
        template.exercises.map { exercise in
            let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let latest = latestExerciseRecord(named: trimmedName) {
                switch exercise.type {
                case .cardio:
                    let duration = latest.exercise.type == .cardio
                        ? formattedDurationValue(latest.exercise.durationSeconds)
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
                        caloriesPlaceholder: calories,
                        note: note(for: trimmedName)
                    )
                case .weights:
                    if latest.exercise.type == .weights {
                        let setDrafts = latest.exercise.sets.map { set in
                            let segmentDrafts = set.segments.map { segment in
                                WorkoutSetSegmentDraft(
                                    weight: "",
                                    reps: "",
                                    weightPlaceholder: segment.weightKg == 0
                                        ? "0"
                                        : String(format: "%.1f", weightValue(segment.weightKg, unit: defaultWeightUnit)),
                                    repsPlaceholder: "\(segment.reps)"
                                )
                            }
                            return WorkoutSetDraft(segments: segmentDrafts.isEmpty ? [WorkoutSetSegmentDraft()] : segmentDrafts)
                        }
                        return ExerciseDraft(
                            name: latest.exercise.name,
                            type: .weights,
                            sets: setDrafts.isEmpty ? [WorkoutSetDraft()] : setDrafts,
                            weightUnit: defaultWeightUnit,
                            note: note(for: latest.exercise.name)
                        )
                    }
                }
            }
            return ExerciseDraft(
                name: trimmedName,
                type: exercise.type,
                sets: exercise.type == .weights ? [WorkoutSetDraft()] : [],
                weightUnit: defaultWeightUnit,
                note: note(for: trimmedName)
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

    func muscleGroupLabel(for name: String) -> String? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if let match = exerciseLibrary.first(where: { $0.name.lowercased() == key }) {
            return match.group.rawValue
        }
        return nil
    }

    func exportBackup() -> WorkoutBackup {
        WorkoutBackup(
            version: 3,
            exportedAt: Date(),
            sessions: sessions,
            templates: templates,
            entries: entries,
            notes: exerciseNotes
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
                        durationSeconds: exercise.durationSeconds,
                        calories: exercise.calories,
                        loggedAt: exercise.loggedAt ?? session.date
                    )
                }
            }
        }
        templates = backup.templates
        exerciseNotes = backup.notes ?? [:]
        exerciseTypeMap = [:]
        updateExerciseTypes(from: self.entries)
        updateExerciseTypes(from: templates.flatMap { $0.exercises })
        saveEntries()
        saveTemplates()
        saveExerciseNotes()
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
        exerciseNotes = [:]
        saveEntries()
        saveTemplates()
        saveExerciseTypes()
        saveExerciseNotes()

        let urls = [sessionsFileURL(), entriesFileURL(), templatesFileURL(), exerciseTypesFileURL(), exerciseNotesFileURL()]
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
                        durationSeconds: exercise.durationSeconds,
                        calories: exercise.calories,
                        loggedAt: exercise.loggedAt ?? session.date
                    )
                }
            }
        }
        templates = loadTemplates()
        exerciseTypeMap = loadExerciseTypes()
        exerciseNotes = loadExerciseNotes()
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

    func note(for name: String) -> String {
        let key = normalizedExerciseKey(name)
        guard !key.isEmpty else { return "" }
        return exerciseNotes[key] ?? ""
    }

    func exerciseNotesList() -> [(name: String, note: String)] {
        exerciseNotes
            .map { (name: $0.key, note: $0.value) }
            .filter { !$0.name.isEmpty && !$0.note.isEmpty }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setNote(_ note: String, for name: String) {
        let key = normalizedExerciseKey(name)
        guard !key.isEmpty else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if exerciseNotes.removeValue(forKey: key) != nil {
                saveExerciseNotes()
            }
            return
        }
        if exerciseNotes[key] != trimmed {
            exerciseNotes[key] = trimmed
            saveExerciseNotes()
        }
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

    private func loadExerciseNotes() -> [String: String] {
        do {
            let data = try Data(contentsOf: exerciseNotesFileURL())
            return try JSONDecoder().decode([String: String].self, from: data)
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

    private func saveExerciseNotes() {
        guard hasLoaded else { return }
        do {
            let data = try JSONEncoder().encode(exerciseNotes)
            let url = exerciseNotesFileURL()
            try FileManager.default
                .createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Ignore write failures; user can continue without persistence.
        }
    }

    private func loadTemplateUsage() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: "templateUsageCounts"),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveTemplateUsage() {
        guard hasLoaded else { return }
        guard let data = try? JSONEncoder().encode(templateUsage) else { return }
        UserDefaults.standard.set(data, forKey: "templateUsageCounts")
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

    private func loadDropSetsEnabled() -> Bool {
        let value = UserDefaults.standard.object(forKey: "dropSetsEnabled") as? Bool
        return value ?? true
    }

    private func saveDropSetsEnabled() {
        UserDefaults.standard.set(isDropSetsEnabled, forKey: "dropSetsEnabled")
    }

    private func loadNotesEnabled() -> Bool {
        let value = UserDefaults.standard.object(forKey: "notesEnabled") as? Bool
        return value ?? true
    }

    private func saveNotesEnabled() {
        UserDefaults.standard.set(isNotesEnabled, forKey: "notesEnabled")
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
                                durationSeconds: nil,
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

    private func exerciseNotesFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/exercise-notes.json")
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
    @State private var templateFlow: WorkoutTemplate?
    @State private var showTemplateImport = false
    @State private var templateImportText = ""
    @State private var showTemplateImportError = false
    @State private var templateImportErrorMessage = ""
    @State private var showTemplateShareNotice = false
    @State private var showTemplateImportSuccess = false
    @State private var templateSharePayload: TemplateShareSheetPayload?
    @State private var showTemplateScanner = false
    @State private var showTemplatePhotoPicker = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
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
        .sheet(item: $templateFlow) { template in
            TemplateFlowView(store: store, template: template)
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
        .sheet(item: $templateSharePayload) { payload in
            TemplateShareSheet(
                code: payload.code,
                onCopy: {
                    UIPasteboard.general.string = payload.code
                    showTemplateShareNotice = true
                }
            )
        }
        .sheet(isPresented: $showTemplateScanner) {
            TemplateQRScanner(
                onScan: { code in
                    showTemplateScanner = false
                    do {
                        try store.importTemplate(from: code)
                        showTemplateImportSuccess = true
                    } catch {
                        templateImportErrorMessage = "Invalid template code."
                        showTemplateImportError = true
                    }
                },
                onImportPhoto: {
                    showTemplateScanner = false
                    showTemplatePhotoPicker = true
                }
            )
        }
        .sheet(isPresented: $showTemplatePhotoPicker) {
            PhotoPicker(
                onImage: { image in
                    showTemplatePhotoPicker = false
                    handleTemplateImageImport(image)
                },
                onError: { message in
                    showTemplatePhotoPicker = false
                    templateImportErrorMessage = message
                    showTemplateImportError = true
                }
            )
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

    private func handleTemplateImageImport(_ image: UIImage) {
        guard let code = extractQRCode(from: image) else {
            templateImportErrorMessage = "No QR code found in that image."
            showTemplateImportError = true
            return
        }
        do {
            try store.importTemplate(from: code)
            showTemplateImportSuccess = true
        } catch {
            templateImportErrorMessage = "Invalid template code."
            showTemplateImportError = true
        }
    }

    private func extractQRCode(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) ?? []
        return features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
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
                    .foregroundStyle(themeColor(.sand))
                Spacer()
            }
            Text("Track what you lift, keep it simple.")
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themeColor(.sand).opacity(0.7))
        }
    }

    private var stats: some View {
        let currentStreak = currentWorkoutStreak()
        let maxStreak = maxWorkoutStreak()
        let totalSets = store.sessions.reduce(0) { total, session in
            total + session.mergedExercises().filter { $0.type == .weights }.reduce(0) { $0 + $1.sets.count }
        }
        let todaySets = store.sessions
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { total, session in
                total + session.mergedExercises().filter { $0.type == .weights }.reduce(0) { $0 + $1.sets.count }
            }
        return HStack(spacing: 12) {
            StatPager(
                pages: [
                    StatPage(title: "Current Streak", value: "\(currentStreak)"),
                    StatPage(title: "Max Streak", value: "\(maxStreak)")
                ]
            )
            StatPager(
                pages: [
                    StatPage(title: "Today's Sets", value: "\(todaySets)"),
                    StatPage(title: "Total Sets", value: "\(totalSets)")
                ]
            )
        }
    }

    private func workoutDays() -> [Date] {
        let calendar = Calendar.current
        let unique = Set(store.sessions.map { calendar.startOfDay(for: $0.date) })
        return unique.sorted()
    }

    private func currentWorkoutStreak() -> Int {
        let calendar = Calendar.current
        let days = Set(workoutDays())
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let startDay: Date
        if days.contains(today) {
            startDay = today
        } else if let yesterday, days.contains(yesterday) {
            startDay = yesterday
        } else {
            return 0
        }
        var count = 0
        var cursor = startDay
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private func maxWorkoutStreak() -> Int {
        let calendar = Calendar.current
        let days = workoutDays()
        guard let first = days.first else { return 0 }
        var maxStreak = 1
        var currentStreak = 1
        var previous = first
        for day in days.dropFirst() {
            let diff = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            if diff == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            if currentStreak > maxStreak {
                maxStreak = currentStreak
            }
            previous = day
        }
        return maxStreak
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Templates")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColor(.sand))
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
                    Button {
                        showTemplateScanner = true
                    } label: {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themeColor(.sand))
                }
            }

            if store.templates.isEmpty {
                Text("Create a template to reuse your go-to workouts.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.templates) { template in
                            TemplateCard(
                                template: template,
                                onUse: {
                                    templateFlow = template
                                },
                                onShare: {
                                    do {
                                        let code = try store.shareString(for: template)
                                        templateSharePayload = TemplateShareSheetPayload(code: code)
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
                .foregroundStyle(themeColor(.sand))

            let recentExercises = recentWorkoutExercises(limit: 8)
            if recentExercises.isEmpty {
                Text("No exercises yet. Add a workout to start your log.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))
            } else {
                ForEach(recentExercises, id: \.self) { name in
                    Button {
                        startQuickWorkout(for: name)
                    } label: {
                        ExerciseHistoryCard(
                            name: name,
                            record: store.latestExerciseRecord(named: name),
                            weightUnit: store.defaultWeightUnit
                        )
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
            .foregroundStyle(themeColor(.night))
            .background(themeColor(.sand))
            .clipShape(Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(themeColor(.night).opacity(0.001))
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
                    colors: [themeColor(.night), themeColor(.coal)],
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
                                    onEdit: { editingSession = session },
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
                                    .tint(themeColor(.sand))
                                }
                            }
                        }
                    } header: {
                        Text("History")
                            .font(.custom("Avenir Next", size: 28))
                            .fontWeight(.semibold)
                            .foregroundStyle(themeColor(.sand))
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
                    SessionDetailView(session: session, weightUnit: store.defaultWeightUnit) {
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
    @ObservedObject private var themeStore = ThemeStore.shared
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
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.custom("Avenir Next", size: 30))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))

                    preferencesCard
                    featureControlsCard
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
                .foregroundStyle(themeColor(.sand).opacity(0.7))

            VStack(alignment: .leading, spacing: 10) {
                Text("Session Window")
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(themeColor(.sand))
                Text("Workouts logged within this window merge into the same session.")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))
                Picker("Session Window", selection: $sessionWindowSelection) {
                    ForEach(SessionMergeWindowOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(themeColor(.sand))
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
                .overlay(themeColor(.sand).opacity(0.12))

            VStack(alignment: .leading, spacing: 8) {
                Text("Default Weight Unit")
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(themeColor(.sand))
                Picker("Default Weight Unit", selection: $store.defaultWeightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()
                .overlay(themeColor(.sand).opacity(0.12))

            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(themeColor(.sand))
                Picker("Theme", selection: $themeStore.selectedTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card).opacity(0.9))
        )
    }

    private var featureControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Controls")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themeColor(.sand).opacity(0.7))

            Toggle(isOn: $store.isDropSetsEnabled) {
                Text("Drop Sets")
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(themeColor(.sand))
            }
            .tint(themeColor(.sand))

            Toggle(isOn: $store.isNotesEnabled) {
                Text("Notes")
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(themeColor(.sand))
            }
            .tint(themeColor(.sand))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card).opacity(0.9))
        )
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themeColor(.sand).opacity(0.7))

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
                .fill(themeColor(.card).opacity(0.9))
        )
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themeColor(.sand).opacity(0.7))
            Text("MyWorkout")
                .font(.custom("Avenir Next", size: 18))
                .foregroundStyle(themeColor(.sand))
            Text("Track what you lift, keep it simple.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(themeColor(.sand).opacity(0.7))
            Text("Data stays on device unless you export a backup.")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themeColor(.sand).opacity(0.6))
            Text("License: MIT")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themeColor(.sand).opacity(0.6))
            Text("Version \(appVersion)")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themeColor(.sand).opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card).opacity(0.9))
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
                .foregroundStyle(isDestructive ? Color.red.opacity(0.8) : themeColor(.sand))
            Text(title)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(isDestructive ? Color.red.opacity(0.8) : themeColor(.sand))
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
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Progress")
                        .font(.custom("Avenir Next", size: 30))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))

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
                    .foregroundStyle(themeColor(.sand))
                Spacer()
                if !recentExerciseNames.isEmpty {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(recentExerciseNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeColor(.sand))
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
                        .foregroundStyle(themeColor(.sand))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(themeColor(.sand))
                    }
                }
                .frame(height: 220)
                .chartYAxisLabel("Kg")
                .chartXAxisLabel("Date")
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(themeColor(.card).opacity(0.9))
                )
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume Trend")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))

            if volumePoints.isEmpty {
                emptyCard(text: "No volume data yet.")
            } else {
                Chart {
                    ForEach(volumePoints) { point in
                        BarMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(themeColor(.sand).opacity(0.7))
                    }
                }
                .frame(height: 220)
                .chartYAxisLabel("Total Volume")
                .chartXAxisLabel("Date")
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(themeColor(.card).opacity(0.9))
                )
            }
        }
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Consistency")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))

            if weeklyWorkouts.isEmpty {
                emptyCard(text: "No workouts yet.")
            } else {
                Chart {
                    ForEach(weeklyWorkouts) { point in
                        BarMark(
                            x: .value("Week", point.weekStart),
                            y: .value("Workouts", point.value)
                        )
                        .foregroundStyle(themeColor(.sand))
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel("Sessions")
                .chartXAxisLabel("Week")
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(themeColor(.card).opacity(0.9))
                )
            }
        }
    }

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cardio Trend")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))

            if weeklyCardio.isEmpty {
                emptyCard(text: "No cardio yet.")
            } else {
                Chart {
                    ForEach(weeklyCardio) { point in
                        BarMark(
                            x: .value("Week", point.weekStart),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(themeColor(.sand).opacity(0.7))

                        LineMark(
                            x: .value("Week", point.weekStart),
                            y: .value("Calories", point.calories)
                        )
                        .foregroundStyle(themeColor(.sand))
                    }
                }
                .frame(height: 200)
                .chartYAxisLabel("Minutes / Calories")
                .chartXAxisLabel("Week")
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(themeColor(.card).opacity(0.9))
                )
            }
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent PRs")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))

            if prItems.isEmpty {
                emptyCard(text: "No PRs yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(prItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.custom("Avenir Next", size: 16))
                                    .foregroundStyle(themeColor(.sand))
                                Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.custom("Avenir Next", size: 12))
                                    .foregroundStyle(themeColor(.sand).opacity(0.6))
                            }
                            Spacer()
                            Text("\(formattedWeight(item.weight, unit: store.defaultWeightUnit)) x \(item.reps)")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themeColor(.sand))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(themeColor(.card).opacity(0.9))
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
                .foregroundStyle(themeColor(.sand))

            if focusItems.isEmpty {
                emptyCard(text: "No exercise focus yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(focusItems) { item in
                        HStack {
                            Text(item.name)
                                .font(.custom("Avenir Next", size: 16))
                                .foregroundStyle(themeColor(.sand))
                            Spacer()
                            Text("\(item.count) sets")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themeColor(.sand).opacity(0.8))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(themeColor(.card).opacity(0.9))
                        )
                    }
                }
            }
        }
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.custom("Avenir Next", size: 14))
            .foregroundStyle(themeColor(.sand).opacity(0.6))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeColor(.card).opacity(0.85))
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
            let bestSegment = exercise.allSegments.max { $0.weightKg < $1.weightKg }
            guard let bestSegment else { continue }
            points.append(StrengthPoint(date: session.date, weight: bestSegment.weightKg, reps: bestSegment.reps))
        }
        return points
    }

    private var volumePoints: [VolumePoint] {
        filteredSessions.map { session in
            let volume = session.mergedExercises().filter { $0.type == .weights }.reduce(0.0) { total, exercise in
                total + exercise.allSegments.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
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
            let totals = sessions.reduce(into: (seconds: 0, calories: 0)) { result, session in
                for exercise in session.mergedExercises() where exercise.type == .cardio {
                    result.seconds += exercise.durationSeconds ?? 0
                    result.calories += exercise.calories ?? 0
                }
            }
            let minutes = totals.seconds / 60
            return WeekPoint(weekStart: weekStart, value: 0, calories: totals.calories, minutes: minutes)
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
                let bestSegment = exercise.allSegments.max { $0.weightKg < $1.weightKg }
                guard let bestSegment else { continue }
                let currentBest = bestByName[name] ?? 0
                if bestSegment.weightKg > currentBest {
                    bestByName[name] = bestSegment.weightKg
                    items.append(PRItem(name: name, date: session.date, weight: bestSegment.weightKg, reps: bestSegment.reps))
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
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))

            if let record {
                Text("Last used \(record.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))

                HStack(spacing: 12) {
                    ForEach(tags(for: record.exercise), id: \.self) { tag in
                        TagView(text: tag)
                    }
                }
            } else {
                Text("No logged workout yet")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeColor(.card).opacity(0.9))
        )
    }

    private func tags(for exercise: WorkoutExercise) -> [String] {
        switch exercise.type {
        case .weights:
            let setCount = exercise.sets.count
            let maxWeight = exercise.allSegments.map(\.weightKg).max() ?? 0
            let maxReps = exercise.allSegments.map(\.reps).max() ?? 0
            let isBodyweight = !exercise.sets.isEmpty && exercise.allSegments.allSatisfy { $0.weightKg == 0 }
            var tags = ["\(setCount) sets"]
            if setCount > 0 {
                if isBodyweight {
                    tags.append("Bodyweight")
                } else {
                    tags.append("Max \(formattedWeight(maxWeight, unit: weightUnit))")
                }
                tags.append("Max \(maxReps) reps")
            }
            return tags
        case .cardio:
            var tags: [String] = []
            if let duration = exercise.durationSeconds, duration > 0 {
                tags.append(durationLabel(duration))
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
    var weightUnit: WeightUnit
    var durationMinutes: String
    var calories: String
    var durationPlaceholder: String
    var caloriesPlaceholder: String
    var note: String
    var isNoteExpanded: Bool
    var entryId: UUID?
    var loggedAt: Date?

    init(
        id: UUID = UUID(),
        name: String = "",
        type: ExerciseType = .weights,
        sets: [WorkoutSetDraft] = [WorkoutSetDraft()],
        weightUnit: WeightUnit = .kg,
        durationMinutes: String = "",
        calories: String = "",
        durationPlaceholder: String = "",
        caloriesPlaceholder: String = "",
        note: String = "",
        isNoteExpanded: Bool = false,
        entryId: UUID? = nil,
        loggedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sets = sets
        self.weightUnit = weightUnit
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.durationPlaceholder = durationPlaceholder
        self.caloriesPlaceholder = caloriesPlaceholder
        self.note = note
        self.isNoteExpanded = isNoteExpanded
        self.entryId = entryId
        self.loggedAt = loggedAt
    }
}

struct WorkoutSetSegmentDraft: Identifiable, Equatable {
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

struct WorkoutSetDraft: Identifiable, Equatable {
    let id: UUID
    var segments: [WorkoutSetSegmentDraft]

    init(
        id: UUID = UUID(),
        segments: [WorkoutSetSegmentDraft] = [WorkoutSetSegmentDraft()]
    ) {
        self.id = id
        self.segments = segments
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
    @State private var isKeyboardVisible = false

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
                    var segmentModels: [WorkoutSetSegment] = []
                    var hasPartialSegment = false

                    for segment in setDraft.segments {
                        let weightText = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                        let repsText = segment.reps.trimmingCharacters(in: .whitespacesAndNewlines)

                        if weightText.isEmpty && repsText.isEmpty {
                            continue
                        }

                        if weightText.isEmpty || repsText.isEmpty {
                            hasPartialSegment = true
                            continue
                        }

                        guard let inputValue = Double(weightText),
                              let repsValue = Int(repsText) else {
                            hasPartialSegment = true
                            continue
                        }

                        let weightValue = draft.weightUnit == .lb ? inputValue * 0.45359237 : inputValue
                        guard repsValue > 0, weightValue >= 0 else {
                            hasPartialSegment = true
                            continue
                        }

                        segmentModels.append(WorkoutSetSegment(id: UUID(), weightKg: weightValue, reps: repsValue))
                    }

                    if hasPartialSegment {
                        hasPartialSet = true
                        continue
                    }

                    guard !segmentModels.isEmpty else {
                        continue
                    }

                    setModels.append(WorkoutSet(id: UUID(), segments: segmentModels))
                }

                let hasAnySetInput = draft.sets.contains { set in
                    set.segments.contains {
                        !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
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
                        id: draft.entryId ?? UUID(),
                        name: name,
                        type: .weights,
                        sets: setModels,
                        durationSeconds: nil,
                        calories: nil,
                        loggedAt: draft.loggedAt
                    )
                )
            case .cardio:
                let durationTrimmed = draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
                let caloriesTrimmed = draft.calories.trimmingCharacters(in: .whitespacesAndNewlines)
                let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
                let caloriesValue = caloriesTrimmed.isEmpty ? nil : Int(caloriesTrimmed)
                let hasMetrics = durationValue != nil || caloriesValue != nil

                if name.isEmpty && (!durationTrimmed.isEmpty || !caloriesTrimmed.isEmpty) {
                    hasInvalid = true
                    continue
                }

                if !durationTrimmed.isEmpty && durationValue == nil {
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
                        id: draft.entryId ?? UUID(),
                        name: name,
                        type: .cardio,
                        sets: [],
                        durationSeconds: durationValue,
                        calories: caloriesValue,
                        loggedAt: draft.loggedAt
                    )
                )
            }
        }

        return (validExercises, hasInvalid)
    }

    private var validExercises: [WorkoutExercise] {
        validation.validExercises
    }

    private func parseDurationSeconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { return nil }
        if cleaned.contains(":") {
            let parts = cleaned.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]),
                  minutes >= 0,
                  seconds >= 0,
                  seconds < 60 else {
                return nil
            }
            return minutes * 60 + seconds
        }
        guard let minutes = Int(cleaned), minutes >= 0 else { return nil }
        return minutes * 60
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
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(titleText)
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))

                    datePickerCard

                    exerciseEditors

                    Button {
                        drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Exercise")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themeColor(.sand))
                    }
                }
                .padding(24)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                VStack(spacing: 10) {
                    Button {
                    let finalExercises = session == nil
                        ? stampTimes(validExercises)
                        : fillMissingTimes(validExercises)
                    if let session {
                        store.updateSession(session, date: sessionDate(from: finalExercises), exercises: finalExercises)
                    } else {
                        store.addSession(date: sessionDate(from: finalExercises), exercises: finalExercises)
                        if let template {
                            store.incrementTemplateUsage(for: template)
                        }
                    }
                    if store.isNotesEnabled {
                        for draft in drafts {
                            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { continue }
                            store.setNote(draft.note, for: name)
                        }
                    }
                    dismiss()
                } label: {
                        Text(saveLabel)
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night))
                            .background(themeColor(.sand))
                            .clipShape(Capsule())
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.sand))
                            .background(
                                Capsule()
                                    .stroke(themeColor(.sand).opacity(0.6), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [
                            themeColor(.night).opacity(0.0),
                            themeColor(.night).opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    private func drafts(for session: WorkoutSession) -> [ExerciseDraft] {
        session.exercises.map { exercise in
            switch exercise.type {
            case .weights:
                let setDrafts = exercise.sets.map { set in
                    let segmentDrafts = set.segments.map { segment in
                        WorkoutSetSegmentDraft(
                            weight: segment.weightKg == 0
                                ? "0"
                                : String(format: "%.1f", weightValue(segment.weightKg, unit: store.defaultWeightUnit)),
                            reps: "\(segment.reps)"
                        )
                    }
                    return WorkoutSetDraft(segments: segmentDrafts.isEmpty ? [WorkoutSetSegmentDraft()] : segmentDrafts)
                }
                return ExerciseDraft(
                    name: exercise.name,
                    type: .weights,
                    sets: setDrafts.isEmpty ? [WorkoutSetDraft()] : setDrafts,
                    weightUnit: store.defaultWeightUnit,
                    note: store.note(for: exercise.name),
                    entryId: exercise.id,
                    loggedAt: exercise.loggedAt
                )
            case .cardio:
                return ExerciseDraft(
                    name: exercise.name,
                    type: .cardio,
                    sets: [],
                    weightUnit: store.defaultWeightUnit,
                    durationMinutes: formattedDurationValue(exercise.durationSeconds),
                    calories: formattedOptionalInt(exercise.calories),
                    note: store.note(for: exercise.name),
                    entryId: exercise.id,
                    loggedAt: exercise.loggedAt
                )
            }
        }
    }

    private var exerciseEditors: some View {
        let suggestions = store.exerciseNameCatalog()
        return ForEach($drafts) { $draft in
            ExerciseEditorRow(
                draft: $draft,
                suggestions: suggestions,
                suggestionDetail: store.muscleGroupLabel(for:),
                showsMetrics: true,
                knownType: store.exerciseType(for: draft.name),
                isDropSetsEnabled: store.isDropSetsEnabled,
                isNotesEnabled: store.isNotesEnabled,
                noteForName: store.note(for:),
                onDelete: {
                    drafts.removeAll { $0.id == draft.id }
                },
                onMoveUp: nil,
                onMoveDown: nil
            )
        }
    }

    private var datePickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themeColor(.sand).opacity(0.6))
            HStack {
                Text(relativeLabel(for: workoutDate))
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(themeColor(.sand))
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
                    .fill(themeColor(.card))
            )
            if isFutureDay(workoutDate) {
                Text("Future date")
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(themeColor(.sand).opacity(0.55))
            }
        }
    }

    private func relativeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func formattedOptionalInt(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private func sessionDate(from exercises: [WorkoutExercise]) -> Date {
        exercises.map(\.loggedAt).compactMap { $0 }.min() ?? workoutDate
    }

    private func fillMissingTimes(_ exercises: [WorkoutExercise]) -> [WorkoutExercise] {
        let fallback = combineDate(workoutDate, time: Date())
        return exercises.map { exercise in
            if exercise.loggedAt != nil {
                return exercise
            }
            return WorkoutExercise(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                sets: exercise.sets,
                durationSeconds: exercise.durationSeconds,
                calories: exercise.calories,
                loggedAt: fallback
            )
        }
    }

    private func stampTimes(_ exercises: [WorkoutExercise]) -> [WorkoutExercise] {
        let timestamp = combineDate(workoutDate, time: Date())
        return exercises.map { exercise in
            if exercise.loggedAt != nil {
                return exercise
            }
            return WorkoutExercise(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                sets: exercise.sets,
                durationSeconds: exercise.durationSeconds,
                calories: exercise.calories,
                loggedAt: timestamp
            )
        }
    }

    private func weightValue(_ kg: Double, unit: WeightUnit) -> Double {
        if unit == .lb {
            return kg * 2.20462262
        }
        return kg
    }
}

private struct TemplateExerciseSelection: Identifiable {
    let index: Int
    var id: Int { index }
}

struct TemplateFlowView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var workoutDate = Date()
    @State private var drafts: [ExerciseDraft] = []
    @State private var hasLoadedDrafts = false
    @State private var templateExercises: [TemplateExercise] = []
    @State private var addToTemplateDraftIds: Set<UUID> = []
    @State private var newDraftIds: Set<UUID> = []
    @State private var selectedExercise: TemplateExerciseSelection?
    @State private var showFinishConfirm = false
    @State private var hasStarted = false
    @State private var showsTimeEditor = false
    @State private var usesManualTimes = false
    @State private var manualStartTime = Date()
    @State private var manualEndTime = Date()
    @State private var showAddExercisePrompt = false
    @State private var pendingDeleteIndex: Int?
    @State private var showDeleteTemplateConfirm = false

    private var completion: (exercises: [WorkoutExercise], hasInvalid: Bool) {
        var exercises: [WorkoutExercise] = []
        var hasInvalid = false
        for draft in drafts {
            let result = workoutExercise(from: draft)
            if result.hasInvalid {
                hasInvalid = true
            }
            if let exercise = result.exercise {
                exercises.append(exercise)
            }
        }
        return (exercises, hasInvalid)
    }

    private var canFinish: Bool {
        !completion.exercises.isEmpty && !completion.hasInvalid
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if hasStarted {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.title)
                                .font(.custom("Avenir Next", size: 28))
                                .fontWeight(.semibold)
                                .foregroundStyle(themeColor(.sand))
                            Text("\(completion.exercises.count) of \(drafts.count) completed")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                        }
                        .padding(.top, 8)
                        ProgressView(value: Double(completion.exercises.count), total: Double(max(drafts.count, 1)))
                            .tint(themeColor(.sand))
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    let pendingIndices = drafts.indices.filter { !isComplete(index: $0) }
                    let completedIndices = drafts.indices.filter { isComplete(index: $0) }

                    if !pendingIndices.isEmpty {
                        Section {
                            ForEach(pendingIndices, id: \.self) { index in
                                exerciseRow(for: index, isComplete: false)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text("Up Next")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                                .textCase(nil)
                        }
                    }

                    if !completedIndices.isEmpty {
                        Section {
                            ForEach(completedIndices, id: \.self) { index in
                                exerciseRow(for: index, isComplete: true)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text("Completed")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                                .textCase(nil)
                        }
                    }

                    Button {
                        showAddExercisePrompt = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Exercise")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themeColor(.sand))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 24, trailing: 0))
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            } else {
                startScreen
            }
        }
        .onChange(of: manualStartTime) { _, newValue in
            let minimumEnd = Calendar.current.date(byAdding: .minute, value: 5, to: newValue) ?? newValue
            if manualEndTime < minimumEnd {
                manualEndTime = minimumEnd
            }
        }
        .onChange(of: manualEndTime) { _, newValue in
            let minimumEnd = Calendar.current.date(byAdding: .minute, value: 5, to: manualStartTime) ?? manualStartTime
            if newValue < minimumEnd {
                manualEndTime = minimumEnd
            }
        }
        .safeAreaInset(edge: .bottom) {
            if hasStarted {
                VStack(spacing: 10) {
                    if completion.hasInvalid {
                        Text("Finish requires fixing incomplete exercise entries.")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(themeColor(.sand).opacity(0.7))
                    }
                    Button {
                        showFinishConfirm = true
                    } label: {
                        Text("Finish Template")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night))
                            .background(themeColor(.sand))
                            .clipShape(Capsule())
                    }
                    .disabled(!canFinish)
                    .opacity(canFinish ? 1 : 0.4)

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.sand))
                            .background(
                                Capsule()
                                    .stroke(themeColor(.sand).opacity(0.6), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [
                            themeColor(.night).opacity(0.0),
                            themeColor(.night).opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .sheet(item: $selectedExercise) { selection in
            if drafts.indices.contains(selection.index) {
                TemplateExerciseEntryView(
                    store: store,
                    workoutDate: workoutDate,
                    usesManualTimes: usesManualTimes,
                    draft: $drafts[selection.index],
                    onSave: handleTemplateSave,
                    onCancel: {
                        handleTemplateCancel(draftId: drafts[selection.index].id)
                    }
                )
            }
        }
        .confirmationDialog("Add Exercise", isPresented: $showAddExercisePrompt) {
            Button("Just this workout") {
                addExercise(addToTemplate: false)
            }
            Button("Add to template") {
                addExercise(addToTemplate: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Should this exercise live only in this workout, or be saved back to the template?")
        }
        .alert("Remove from Template?", isPresented: $showDeleteTemplateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                removeDraftFromTemplate()
            }
        } message: {
            Text("This will remove the exercise from the template and the current workout.")
        }
        .alert("Finish Template?", isPresented: $showFinishConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Finish") {
                let exercises = applyTimes(to: completion.exercises)
                store.addSession(date: sessionDate(from: exercises), exercises: exercises)
                store.incrementTemplateUsage(for: template)
                if store.isNotesEnabled {
                    for draft in drafts {
                        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { continue }
                        store.setNote(draft.note, for: name)
                    }
                }
                dismiss()
            }
        } message: {
            Text("This will save the completed exercises as one workout session.")
        }
        .onAppear {
            guard !hasLoadedDrafts else { return }
            hasLoadedDrafts = true
            templateExercises = template.exercises
            drafts = store.resolvedDrafts(for: template)
            if drafts.isEmpty || drafts.count != templateExercises.count {
                drafts = templateExercises.map {
                    ExerciseDraft(
                        name: $0.name,
                        type: $0.type,
                        sets: $0.type == .weights ? [WorkoutSetDraft()] : [],
                        weightUnit: store.defaultWeightUnit
                    )
                }
            }
            manualStartTime = Date()
            manualEndTime = Date()
        }
    }

    private var startScreen: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(template.title)
                .font(.custom("Avenir Next", size: 28))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))

            Text("\(drafts.count) exercises")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themeColor(.sand).opacity(0.6))

            VStack(alignment: .leading, spacing: 10) {
                Text("Schedule")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))

                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        if showsTimeEditor {
                            usesManualTimes = !shouldUseLiveSchedule()
                            showsTimeEditor = false
                        } else {
                            usesManualTimes = true
                            showsTimeEditor = true
                        }
                    } label: {
                        HStack {
                            Text(scheduleSummary)
                                .font(.custom("Avenir Next", size: 16))
                                .foregroundStyle(themeColor(.sand))
                            Spacer()
                            Image(systemName: showsTimeEditor ? "chevron.up" : "chevron.down")
                                .font(.custom("Avenir Next", size: 12))
                                .foregroundStyle(themeColor(.sand).opacity(0.5))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(themeColor(.card))
                        )
                    }
                    .buttonStyle(.plain)

                    if showsTimeEditor {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Date")
                                .font(.custom("Avenir Next", size: 11))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                            HStack {
                                Text(relativeLabel(for: workoutDate))
                                    .font(.custom("Avenir Next", size: 16))
                                    .foregroundStyle(themeColor(.sand))
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: $workoutDate,
                                    displayedComponents: [.date]
                                )
                                .labelsHidden()
                                .colorScheme(.dark)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(themeColor(.card))
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Time")
                                .font(.custom("Avenir Next", size: 11))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                            HStack {
                                Text("Start")
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(themeColor(.sand).opacity(0.75))
                                Spacer()
                                if isNowTime(manualStartTime) {
                                    Text("Now")
                                        .font(.custom("Avenir Next", size: 13))
                                        .foregroundStyle(themeColor(.sand).opacity(0.75))
                                }
                                DatePicker(
                                    "",
                                    selection: $manualStartTime,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                                .colorScheme(.dark)
                            }

                            HStack {
                                Text("End")
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(themeColor(.sand).opacity(0.75))
                                Spacer()
                                if isNowTime(manualEndTime) {
                                    Text("Now")
                                        .font(.custom("Avenir Next", size: 13))
                                        .foregroundStyle(themeColor(.sand).opacity(0.75))
                                }
                                DatePicker(
                                    "",
                                    selection: $manualEndTime,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .labelsHidden()
                                .colorScheme(.dark)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(themeColor(.card))
                        )

                        if isFutureDay(workoutDate) {
                            Text("Future date")
                                .font(.custom("Avenir Next", size: 11))
                                .foregroundStyle(themeColor(.sand).opacity(0.55))
                        }

                    }
                }

            }

            Button {
                if usesManualTimes == false {
                    workoutDate = Date()
                }
                hasStarted = true
            } label: {
                Text("Start Workout")
                    .font(.custom("Avenir Next", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(themeColor(.night))
                    .background(themeColor(.sand))
                    .clipShape(Capsule())
            }

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.custom("Avenir Next", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(themeColor(.sand))
                    .background(
                        Capsule()
                            .stroke(themeColor(.sand).opacity(0.6), lineWidth: 1)
                    )
            }
        }
        .padding(24)
    }

    private func relativeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func workoutExercise(from draft: ExerciseDraft) -> (exercise: WorkoutExercise?, hasInvalid: Bool) {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch draft.type {
        case .weights:
            var setModels: [WorkoutSet] = []
            var hasPartialSet = false

            for setDraft in draft.sets {
                var segmentModels: [WorkoutSetSegment] = []
                var hasPartialSegment = false

                for segment in setDraft.segments {
                    let weightText = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsText = segment.reps.trimmingCharacters(in: .whitespacesAndNewlines)

                    if weightText.isEmpty && repsText.isEmpty {
                        continue
                    }

                    if weightText.isEmpty || repsText.isEmpty {
                        hasPartialSegment = true
                        continue
                    }

                    guard let inputValue = Double(weightText),
                          let repsValue = Int(repsText) else {
                        hasPartialSegment = true
                        continue
                    }

                    let weightValue = draft.weightUnit == .lb ? inputValue * 0.45359237 : inputValue
                    guard repsValue > 0, weightValue >= 0 else {
                        hasPartialSegment = true
                        continue
                    }

                    segmentModels.append(WorkoutSetSegment(id: UUID(), weightKg: weightValue, reps: repsValue))
                }

                if hasPartialSegment {
                    hasPartialSet = true
                    continue
                }

                guard !segmentModels.isEmpty else {
                    continue
                }

                setModels.append(WorkoutSet(id: UUID(), segments: segmentModels))
            }

            let hasAnySetInput = draft.sets.contains { set in
                set.segments.contains {
                    !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }

            if hasPartialSet {
                return (nil, true)
            }

            if name.isEmpty && hasAnySetInput {
                return (nil, true)
            }

            guard !setModels.isEmpty else {
                return (nil, false)
            }

            guard !name.isEmpty else {
                return (nil, true)
            }

            return (
                WorkoutExercise(
                    id: draft.entryId ?? UUID(),
                    name: name,
                    type: .weights,
                    sets: setModels,
                    durationSeconds: nil,
                    calories: nil,
                    loggedAt: draft.loggedAt
                ),
                false
            )
        case .cardio:
            let durationTrimmed = draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            let caloriesTrimmed = draft.calories.trimmingCharacters(in: .whitespacesAndNewlines)
            let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
            let caloriesValue = caloriesTrimmed.isEmpty ? nil : Int(caloriesTrimmed)
            let hasMetrics = durationValue != nil || caloriesValue != nil

            if name.isEmpty && (!durationTrimmed.isEmpty || !caloriesTrimmed.isEmpty) {
                return (nil, true)
            }

            if !durationTrimmed.isEmpty && durationValue == nil {
                return (nil, true)
            }
            if let durationValue, durationValue <= 0 { return (nil, true) }
            if let caloriesValue, caloriesValue <= 0 { return (nil, true) }

            if name.isEmpty && !hasMetrics {
                return (nil, false)
            }

            guard hasMetrics, !name.isEmpty else {
                return (nil, true)
            }

            return (
                WorkoutExercise(
                    id: draft.entryId ?? UUID(),
                    name: name,
                    type: .cardio,
                    sets: [],
                    durationSeconds: durationValue,
                    calories: caloriesValue,
                    loggedAt: draft.loggedAt
                ),
                false
            )
        }
    }

    private func parseDurationSeconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { return nil }
        if cleaned.contains(":") {
            let parts = cleaned.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]),
                  minutes >= 0,
                  seconds >= 0,
                  seconds < 60 else {
                return nil
            }
            return minutes * 60 + seconds
        }
        guard let minutes = Int(cleaned), minutes >= 0 else { return nil }
        return minutes * 60
    }

    private func sessionDate(from exercises: [WorkoutExercise]) -> Date {
        exercises.map(\.loggedAt).compactMap { $0 }.min() ?? workoutDate
    }

    private func applyTimes(to exercises: [WorkoutExercise]) -> [WorkoutExercise] {
        if usesManualTimes == false {
            let now = Date()
            return exercises.map { exercise in
                if exercise.loggedAt != nil {
                    return exercise
                }
                return WorkoutExercise(
                    id: exercise.id,
                    name: exercise.name,
                    type: exercise.type,
                    sets: exercise.sets,
                    durationSeconds: exercise.durationSeconds,
                    calories: exercise.calories,
                    loggedAt: combineDate(workoutDate, time: now)
                )
            }
        }
        let start = combineDate(workoutDate, time: manualStartTime)
        let end = combineDate(workoutDate, time: manualEndTime)
        let times = distributedTimes(count: exercises.count, start: start, end: end)
        return exercises.enumerated().map { index, exercise in
            WorkoutExercise(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                sets: exercise.sets,
                durationSeconds: exercise.durationSeconds,
                calories: exercise.calories,
                loggedAt: times[index]
            )
        }
    }

    private var scheduleSummary: String {
        if usesManualTimes == false || shouldUseLiveSchedule() {
            return "\(relativeLabel(for: Date())) · Now"
        }
        let dateLabel = relativeLabel(for: workoutDate)
        let startLabel = manualStartTime.formatted(date: .omitted, time: .shortened)
        let endLabel = manualEndTime.formatted(date: .omitted, time: .shortened)
        return "\(dateLabel) · \(startLabel) – \(endLabel)"
    }

    private func shouldUseLiveSchedule() -> Bool {
        Calendar.current.isDateInToday(workoutDate)
            && isNowTime(manualStartTime)
            && isNowTime(manualEndTime)
    }

    private func isComplete(index: Int) -> Bool {
        guard drafts.indices.contains(index) else { return false }
        return workoutExercise(from: drafts[index]).exercise != nil
    }

    private func exerciseRow(for index: Int, isComplete: Bool) -> some View {
        let draft = drafts[index]
        let templateExercise = templateExercises.indices.contains(index)
            ? templateExercises[index]
            : nil
        return Button {
            selectedExercise = TemplateExerciseSelection(index: index)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.name.isEmpty ? (templateExercise?.name ?? "Exercise") : draft.name)
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themeColor(.sand))
                    Text((templateExercise?.type ?? draft.type).label)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                }
                Spacer()
                Text(isComplete ? "Done" : "Start")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(themeColor(.sand))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeColor(.card).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeleteIndex = index
                showDeleteTemplateConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                pendingDeleteIndex = index
                removeDraftFromFlow()
            } label: {
                Label("Skip", systemImage: "forward.fill")
            }
            .tint(Color("Sand"))
        }
    }

    private func removeDraftFromFlow() {
        guard let index = pendingDeleteIndex, drafts.indices.contains(index) else { return }
        let draftId = drafts[index].id
        drafts.remove(at: index)
        newDraftIds.remove(draftId)
        addToTemplateDraftIds.remove(draftId)
        pendingDeleteIndex = nil
    }

    private func removeDraftFromTemplate() {
        guard let index = pendingDeleteIndex, drafts.indices.contains(index) else { return }
        let draftId = drafts[index].id
        drafts.remove(at: index)
        newDraftIds.remove(draftId)
        addToTemplateDraftIds.remove(draftId)
        if templateExercises.indices.contains(index) {
            templateExercises.remove(at: index)
            store.updateTemplate(id: template.id, title: template.title, exercises: templateExercises)
        }
        pendingDeleteIndex = nil
    }

    private func addExercise(addToTemplate: Bool) {
        let newDraft = ExerciseDraft(
            type: .weights,
            sets: [WorkoutSetDraft()],
            weightUnit: store.defaultWeightUnit
        )
        drafts.append(newDraft)
        newDraftIds.insert(newDraft.id)
        if addToTemplate {
            addToTemplateDraftIds.insert(newDraft.id)
        }
        selectedExercise = TemplateExerciseSelection(index: drafts.count - 1)
    }

    private func handleTemplateSave(_ draft: ExerciseDraft) {
        newDraftIds.remove(draft.id)
        guard addToTemplateDraftIds.contains(draft.id) else { return }
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let newExercise = TemplateExercise(
            id: UUID(),
            name: trimmedName,
            type: draft.type,
            weightKg: nil,
            sets: nil,
            repsPerSet: nil
        )
        templateExercises.append(newExercise)
        store.updateTemplate(id: template.id, title: template.title, exercises: templateExercises)
        addToTemplateDraftIds.remove(draft.id)
    }

    private func handleTemplateCancel(draftId: UUID) {
        guard newDraftIds.contains(draftId) else { return }
        guard let index = drafts.firstIndex(where: { $0.id == draftId }) else { return }
        if isDraftEmpty(drafts[index]) {
            drafts.remove(at: index)
        }
        newDraftIds.remove(draftId)
        addToTemplateDraftIds.remove(draftId)
    }

    private func isDraftEmpty(_ draft: ExerciseDraft) -> Bool {
        if !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if !draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if !draft.calories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        for set in draft.sets {
            for segment in set.segments {
                if !segment.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !segment.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return false
                }
            }
        }
        return true
    }
}

struct TemplateExerciseEntryView: View {
    @ObservedObject var store: WorkoutStore
    let workoutDate: Date
    let usesManualTimes: Bool
    @Binding var draft: ExerciseDraft
    let onSave: (ExerciseDraft) -> Void
    let onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var isKeyboardVisible = false
    @State private var didSave = false

    init(
        store: WorkoutStore,
        workoutDate: Date,
        usesManualTimes: Bool,
        draft: Binding<ExerciseDraft>,
        onSave: @escaping (ExerciseDraft) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.store = store
        self.workoutDate = workoutDate
        self.usesManualTimes = usesManualTimes
        self._draft = draft
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var validation: (exercise: WorkoutExercise?, hasInvalid: Bool) {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch draft.type {
        case .weights:
            var setModels: [WorkoutSet] = []
            var hasPartialSet = false

            for setDraft in draft.sets {
                var segmentModels: [WorkoutSetSegment] = []
                var hasPartialSegment = false

                for segment in setDraft.segments {
                    let weightText = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsText = segment.reps.trimmingCharacters(in: .whitespacesAndNewlines)

                    if weightText.isEmpty && repsText.isEmpty {
                        continue
                    }

                    if weightText.isEmpty || repsText.isEmpty {
                        hasPartialSegment = true
                        continue
                    }

                    guard let inputValue = Double(weightText),
                          let repsValue = Int(repsText) else {
                        hasPartialSegment = true
                        continue
                    }

                    let weightValue = draft.weightUnit == .lb ? inputValue * 0.45359237 : inputValue
                    guard repsValue > 0, weightValue >= 0 else {
                        hasPartialSegment = true
                        continue
                    }

                    segmentModels.append(WorkoutSetSegment(id: UUID(), weightKg: weightValue, reps: repsValue))
                }

                if hasPartialSegment {
                    hasPartialSet = true
                    continue
                }

                guard !segmentModels.isEmpty else {
                    continue
                }

                setModels.append(WorkoutSet(id: UUID(), segments: segmentModels))
            }

            let hasAnySetInput = draft.sets.contains { set in
                set.segments.contains {
                    !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }

            if hasPartialSet {
                return (nil, true)
            }

            if name.isEmpty && hasAnySetInput {
                return (nil, true)
            }

            guard !setModels.isEmpty else {
                return (nil, false)
            }

            guard !name.isEmpty else {
                return (nil, true)
            }

            return (
                WorkoutExercise(
                    id: draft.entryId ?? UUID(),
                    name: name,
                    type: .weights,
                    sets: setModels,
                    durationSeconds: nil,
                    calories: nil,
                    loggedAt: draft.loggedAt
                ),
                false
            )
        case .cardio:
            let durationTrimmed = draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            let caloriesTrimmed = draft.calories.trimmingCharacters(in: .whitespacesAndNewlines)
            let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
            let caloriesValue = caloriesTrimmed.isEmpty ? nil : Int(caloriesTrimmed)
            let hasMetrics = durationValue != nil || caloriesValue != nil

            if name.isEmpty && (!durationTrimmed.isEmpty || !caloriesTrimmed.isEmpty) {
                return (nil, true)
            }

            if !durationTrimmed.isEmpty && durationValue == nil {
                return (nil, true)
            }
            if let durationValue, durationValue <= 0 { return (nil, true) }
            if let caloriesValue, caloriesValue <= 0 { return (nil, true) }

            if name.isEmpty && !hasMetrics {
                return (nil, false)
            }

            guard hasMetrics, !name.isEmpty else {
                return (nil, true)
            }

            return (
                WorkoutExercise(
                    id: draft.entryId ?? UUID(),
                    name: name,
                    type: .cardio,
                    sets: [],
                    durationSeconds: durationValue,
                    calories: caloriesValue,
                    loggedAt: draft.loggedAt
                ),
                false
            )
        }
    }

    private var canSave: Bool {
        validation.exercise != nil && !validation.hasInvalid
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(draft.name.isEmpty ? "Exercise" : draft.name)
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))

                    ExerciseEditorRow(
                        draft: $draft,
                        suggestions: store.exerciseNameCatalog(),
                        suggestionDetail: store.muscleGroupLabel(for:),
                        showsMetrics: true,
                        knownType: store.exerciseType(for: draft.name),
                        isDropSetsEnabled: store.isDropSetsEnabled,
                        isNotesEnabled: store.isNotesEnabled,
                        noteForName: store.note(for:),
                        onDelete: nil,
                        onMoveUp: nil,
                        onMoveDown: nil
                    )
                }
                .padding(24)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                VStack(spacing: 10) {
                    Button {
                        if usesManualTimes == false {
                            draft.loggedAt = combineDate(workoutDate, time: Date())
                        }
                        didSave = true
                        onSave(draft)
                        dismiss()
                    } label: {
                        Text("Save Exercise")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night))
                            .background(themeColor(.sand))
                            .clipShape(Capsule())
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)

                    Button {
                        onCancel?()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.sand))
                            .background(
                                Capsule()
                                    .stroke(themeColor(.sand).opacity(0.6), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [
                            themeColor(.night).opacity(0.0),
                            themeColor(.night).opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onDisappear {
            if !didSave {
                onCancel?()
            }
        }
    }

    private func parseDurationSeconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { return nil }
        if cleaned.contains(":") {
            let parts = cleaned.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]),
                  minutes >= 0,
                  seconds >= 0,
                  seconds < 60 else {
                return nil
            }
            return minutes * 60 + seconds
        }
        guard let minutes = Int(cleaned), minutes >= 0 else { return nil }
        return minutes * 60
    }
}


struct ExerciseEditorRow: View {
    @Binding var draft: ExerciseDraft
    let suggestions: [String]
    let suggestionDetail: ((String) -> String?)?
    let showsMetrics: Bool
    let knownType: ExerciseType?
    let isDropSetsEnabled: Bool
    let isNotesEnabled: Bool
    let noteForName: ((String) -> String)?
    let onDelete: (() -> Void)?
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onNameFocusChange: ((Bool) -> Void)?
    @State private var lastUnit: WeightUnit = .kg
    @State private var isNameFocused = false

    init(
        draft: Binding<ExerciseDraft>,
        suggestions: [String],
        suggestionDetail: ((String) -> String?)? = nil,
        showsMetrics: Bool,
        knownType: ExerciseType?,
        isDropSetsEnabled: Bool,
        isNotesEnabled: Bool,
        noteForName: ((String) -> String)?,
        onDelete: (() -> Void)?,
        onMoveUp: (() -> Void)?,
        onMoveDown: (() -> Void)?,
        onNameFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._draft = draft
        self.suggestions = suggestions
        self.suggestionDetail = suggestionDetail
        self.showsMetrics = showsMetrics
        self.knownType = knownType
        self.isDropSetsEnabled = isDropSetsEnabled
        self.isNotesEnabled = isNotesEnabled
        self.noteForName = noteForName
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onNameFocusChange = onNameFocusChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            nameField
            metricsSection
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColor(.card))
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
        .onChange(of: knownType) { _, newValue in
            if let newValue {
                draft.type = newValue
            }
        }
        .onChange(of: draft.name) { _, _ in
            if let knownType {
                draft.type = knownType
            }
            if isNotesEnabled, let noteForName,
               draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let note = noteForName(draft.name)
                if !note.isEmpty {
                    draft.note = note
                }
            }
        }
        .onChange(of: draft.type) { _, newValue in
            if newValue == .cardio {
                draft.sets = []
            } else if draft.sets.isEmpty {
                draft.sets = [WorkoutSetDraft()]
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Exercise")
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(themeColor(.sand).opacity(0.6))
            if let knownType {
                typeBadge(for: knownType)
            } else {
                typePicker
            }
            Spacer()
            if let onMoveUp {
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(themeColor(.sand).opacity(0.7))
                }
            }
            if let onMoveDown {
                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(themeColor(.sand).opacity(0.7))
                }
            }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(themeColor(.sand).opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nameField: some View {
        ExerciseNameField(
            title: "Exercise",
            showsTitle: false,
            text: $draft.name,
            suggestions: suggestions,
            suggestionDetail: suggestionDetail,
            onFocusChange: { isFocused in
                isNameFocused = isFocused
                onNameFocusChange?(isFocused)
            }
        )
        .zIndex(2)
    }

    @ViewBuilder
    private var metricsSection: some View {
        if showsMetrics {
            VStack(alignment: .leading, spacing: 12) {
                if draft.type == .weights {
                    weightsSection
                } else {
                    cardioSection
                }
                if isNotesEnabled {
                    notesSection
                }
            }
        }
    }

    private var weightsSection: some View {
        VStack(spacing: 10) {
            ForEach($draft.sets) { $set in
                let setId = $set.wrappedValue.id
                SetCardView(
                    set: $set,
                    weightUnit: $draft.weightUnit,
                    isCompact: draft.sets.count > 1,
                    canRemoveSet: draft.sets.count > 1,
                    allowDropSets: isDropSetsEnabled,
                    isBodyweightSegment: isBodyweightSegment,
                    onRemoveSet: {
                        draft.sets.removeAll { $0.id == setId }
                    }
                )
            }
            .animation(.easeInOut(duration: 0.2), value: draft.sets.count)

            Divider()
                .overlay(themeColor(.sand).opacity(0.12))

            Button {
                draft.sets.append(WorkoutSetDraft())
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Set")
                }
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themeColor(.sand))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardioSection: some View {
        HStack(spacing: 12) {
            InputCard(
                title: "Time (mm:ss)",
                text: $draft.durationMinutes,
                placeholder: draft.durationPlaceholder.isEmpty ? "20:00" : draft.durationPlaceholder,
                keyboard: .numbersAndPunctuation
            )
            InputCard(
                title: "Calories",
                text: $draft.calories,
                placeholder: draft.caloriesPlaceholder.isEmpty ? "150" : draft.caloriesPlaceholder,
                keyboard: .numberPad
            )
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 8) {
            if draft.isNoteExpanded {
                Text("Note")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))
                ZStack(alignment: .topLeading) {
                    if trimmedNote.isEmpty {
                        Text("Add a note for next time…")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themeColor(.sand).opacity(0.4))
                            .padding(.top, 19)
                            .padding(.leading, 19)
                    }
                    TextEditor(text: $draft.note)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themeColor(.sand))
                        .scrollContentBackground(.hidden)
                        .padding(.top, 10)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
                .frame(minHeight: 80)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeColor(.card).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeColor(.sand).opacity(0.12), lineWidth: 1)
                        )
                )

                Button {
                    draft.isNoteExpanded = false
                } label: {
                    Text(trimmedNote.isEmpty ? "Hide Note" : "Done")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(themeColor(.sand))
                }
                .buttonStyle(.plain)
            } else if trimmedNote.isEmpty {
                Button {
                    draft.isNoteExpanded = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Note")
                    }
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(themeColor(.sand))
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                    Text(trimmedNote)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themeColor(.sand))
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeColor(.card).opacity(0.6))
                )

                Button {
                    draft.isNoteExpanded = true
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Note")
                    }
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.sand))
                }
                .buttonStyle(.plain)
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

    private func convertWeights(from: WeightUnit, to: WeightUnit) {
        guard from != to else { return }
        let multiplier: Double
        if from == .kg && to == .lb {
            multiplier = 2.20462262
        } else {
            multiplier = 0.45359237
        }
        draft.sets = draft.sets.map { set in
            let segments = set.segments.map { segment in
                let trimmedWeight = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = Double(trimmedWeight) ?? 0
                let converted = roundToHalf(value * multiplier)
                let placeholderValue = Double(segment.weightPlaceholder) ?? 0
                let convertedPlaceholder = roundToHalf(placeholderValue * multiplier)
                return WorkoutSetSegmentDraft(
                    id: segment.id,
                    weight: trimmedWeight.isEmpty ? "" : (value == 0 ? "0" : String(format: "%.1f", converted)),
                    reps: segment.reps,
                    weightPlaceholder: placeholderValue == 0 ? segment.weightPlaceholder : String(format: "%.1f", convertedPlaceholder),
                    repsPlaceholder: segment.repsPlaceholder
                )
            }
            return WorkoutSetDraft(id: set.id, segments: segments)
        }
    }

    private func isBodyweightSegment(_ segment: WorkoutSetSegmentDraft) -> Bool {
        let weight = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(weight) else { return false }
        return value == 0
    }



    private func roundToHalf(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }

    private func typeBadge(for type: ExerciseType) -> some View {
        Text(type.label)
            .font(.custom("Avenir Next", size: 12))
            .foregroundStyle(themeColor(.sand))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(themeColor(.sand).opacity(0.12))
            )
    }

    private var typePlaceholder: some View {
        Text("Type")
            .font(.custom("Avenir Next", size: 12))
            .foregroundStyle(themeColor(.sand).opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(themeColor(.sand).opacity(0.08))
            )
    }
}

struct WorkoutSessionCard: View {
    let session: WorkoutSession
    let sessionNumber: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSaveTemplate: (() -> Void)?

    init(
        session: WorkoutSession,
        sessionNumber: Int,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onSaveTemplate: (() -> Void)? = nil
    ) {
        self.session = session
        self.sessionNumber = sessionNumber
        self.onEdit = onEdit
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
                    .foregroundStyle(themeColor(.sand))
                Spacer()
                Text("\(mergedExercises.count) exercises")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))
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
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
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

    private func sessionLine(for exercise: WorkoutExercise) -> String {
        switch exercise.type {
        case .weights:
            return "\(exercise.name) - \(exercise.sets.count) sets"
        case .cardio:
            var details: [String] = []
            if let duration = exercise.durationSeconds, duration > 0 {
                details.append(durationLabel(duration))
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
    let weightUnit: WeightUnit
    let onEdit: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))

                    ForEach(session.mergedExercises()) { exercise in
                        ExerciseDetailCard(exercise: exercise, weightUnit: weightUnit)
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
                .foregroundStyle(themeColor(.sand))
            }
        }
    }
}

struct ExerciseDetailCard: View {
    let exercise: WorkoutExercise
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exercise.name)
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColor(.sand))
                Spacer()
                Text(exercise.type.label)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))
            }

            switch exercise.type {
            case .weights:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        Text("Set \(index + 1): \(segmentLine(for: set.segments))")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themeColor(.sand).opacity(0.7))
                    }
                }
            case .cardio:
                VStack(alignment: .leading, spacing: 6) {
                    if let duration = exercise.durationSeconds, duration > 0 {
                        Text("Duration: \(durationLabel(duration))")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themeColor(.sand).opacity(0.7))
                    }
                    if let calories = exercise.calories, calories > 0 {
                        Text("Calories: \(calories) cal")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themeColor(.sand).opacity(0.7))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func weightLabel(for kg: Double) -> String {
        formattedWeight(kg, unit: weightUnit)
    }

    private func segmentLine(for segments: [WorkoutSetSegment]) -> String {
        segments.map { segment in
            "\(weightLabel(for: segment.weightKg)) x \(segment.reps)"
        }
        .joined(separator: " → ")
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themeColor(.sand).opacity(0.6))
            Text(value)
                .font(.custom("Avenir Next", size: 22))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card).opacity(0.8))
        )
    }
}

struct StatPage: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct StatPager: View {
    let pages: [StatPage]
    @State private var selection = 0

    private var displayIndex: Int {
        max(0, min(selection, pages.count - 1))
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(themeColor(.card).opacity(0.8))
                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        StatPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .frame(height: 104)

            PageDots(count: pages.count, currentIndex: displayIndex)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatPageView: View {
    let page: StatPage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(page.title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themeColor(.sand).opacity(0.6))
            Text(page.value)
                .font(.custom("Avenir Next", size: 22))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PageDots: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(themeColor(.sand).opacity(index == currentIndex ? 0.9 : 0.35))
                    .frame(width: index == currentIndex ? 6 : 4, height: index == currentIndex ? 6 : 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
                    .fill(themeColor(.sand).opacity(0.12))
            )
            .foregroundStyle(themeColor(.sand))
    }
}

struct ExerciseNameField: View {
    let title: String
    let showsTitle: Bool
    @Binding var text: String
    let suggestions: [String]
    let suggestionDetail: ((String) -> String?)?
    let onFocusChange: ((Bool) -> Void)?
    @FocusState private var isFocused: Bool

    init(
        title: String,
        showsTitle: Bool,
        text: Binding<String>,
        suggestions: [String],
        suggestionDetail: ((String) -> String?)? = nil,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.showsTitle = showsTitle
        self._text = text
        self.suggestions = suggestions
        self.suggestionDetail = suggestionDetail
        self.onFocusChange = onFocusChange
    }

    private var matches: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return suggestions
            .filter { name in
                let nameMatch = name.lowercased().contains(query)
                if nameMatch { return true }
                guard let detail = suggestionDetail?(name)?.lowercased() else { return false }
                return detail.contains(query)
            }
            .prefix(6)
            .map { $0 }
    }

    private var groupedMatches: [(group: String, items: [String])] {
        var groups: [String: [String]] = [:]
        for name in matches {
            let group = suggestionDetail?(name) ?? "Other"
            groups[group, default: []].append(name)
        }
        let ordered = groups.keys.sorted()
        return ordered.map { ($0, groups[$0] ?? []) }
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text(title)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))
            }
            VStack(spacing: 6) {
                TextField("Bicep Curls", text: $text)
                    .font(.custom("Avenir Next", size: 18))
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(themeColor(.sand))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeColor(.card).opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isFocused ? themeColor(.sand).opacity(0.35) : themeColor(.sand).opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .focused($isFocused)

                if isFocused && !matches.isEmpty {
                    suggestionList
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeColor(.card).opacity(0.98))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(themeColor(.sand).opacity(0.12), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
                }
            }
        }
        .onChange(of: isFocused) { _, newValue in
            onFocusChange?(newValue)
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(groupedMatches, id: \.group) { group, items in
                HStack(spacing: 8) {
                    Capsule()
                        .fill(themeColor(.sand).opacity(0.18))
                        .frame(width: 18, height: 6)
                    Text(group.uppercased())
                        .font(.custom("Avenir Next", size: 11))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand).opacity(0.75))
                }
                .padding(.top, 6)
                .padding(.horizontal, 8)

                ForEach(items, id: \.self) { name in
                    Text(name)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themeColor(.sand))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                text = name
                                isFocused = false
                            }
                        )
                }
            }
        }
        .contentShape(Rectangle())
        .zIndex(10)
    }
}

struct ExerciseLibraryView: View {
    @ObservedObject var store: WorkoutStore
    @State private var searchText = ""
    @State private var draftTemplate: WorkoutTemplate?

    struct ExerciseNoteEntry: Identifiable {
        let id = UUID()
        let name: String
        let note: String
    }

    private var noteEntries: [ExerciseNoteEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let entries = store.exerciseNotesList().map { entry in
            ExerciseNoteEntry(name: displayName(for: entry.name), note: entry.note)
        }
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            entry.name.lowercased().contains(query) || entry.note.lowercased().contains(query)
        }
    }

    private func displayName(for key: String) -> String {
        if let match = store.exerciseLibrary.first(where: { $0.name.lowercased() == key.lowercased() }) {
            return match.name
        }
        if let record = store.latestExerciseRecord(named: key) {
            return record.exercise.name
        }
        return key
    }

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
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(themeColor(.sand).opacity(0.6))
                        TextField("Search exercises", text: $searchText)
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(themeColor(.sand))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(themeColor(.card))
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Explore")
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 6, trailing: 20))

                if store.isNotesEnabled, !noteEntries.isEmpty {
                    Section {
                        ForEach(noteEntries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.name)
                                    .font(.custom("Avenir Next", size: 16))
                                    .foregroundStyle(themeColor(.sand))
                                Text(entry.note)
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(themeColor(.sand).opacity(0.7))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(themeColor(.card).opacity(0.9))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        }
                    } header: {
                        HStack(spacing: 10) {
                            Capsule()
                                .fill(themeColor(.sand).opacity(0.18))
                                .frame(width: 18, height: 6)
                            Text("NOTES")
                                .font(.custom("Avenir Next", size: 13))
                                .fontWeight(.semibold)
                                .foregroundStyle(themeColor(.sand).opacity(0.75))
                        }
                        .padding(.top, 8)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                }

                ForEach(orderedGroups, id: \.self) { group in
                    Section {
                        ForEach(groupedExercises[group] ?? []) { exercise in
                            Button {
                                startQuickWorkout(for: exercise.name)
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .font(.custom("Avenir Next", size: 16))
                                        .foregroundStyle(themeColor(.sand))
                                    Spacer()
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.custom("Avenir Next", size: 14))
                                        .foregroundStyle(themeColor(.sand).opacity(0.35))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(themeColor(.card).opacity(0.9))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
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
                                .fill(themeColor(.sand).opacity(0.18))
                                .frame(width: 18, height: 6)
                            Text(group.rawValue.uppercased())
                                .font(.custom("Avenir Next", size: 13))
                                .fontWeight(.semibold)
                                .foregroundStyle(themeColor(.sand).opacity(0.75))
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
    var showsTitle: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text(title)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.75))
            }
            TextField(placeholder, text: $text)
                .font(.custom("Avenir Next", size: 14))
                .keyboardType(keyboard)
                .foregroundStyle(themeColor(.sand))
                // .padding(10)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeColor(.card).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isFocused ? themeColor(.sand).opacity(0.35) : themeColor(.sand).opacity(0.12),
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
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text("Unit")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(.clear)
            }
            unitPill
        }
    }

    private var unitPill: some View {
        Menu {
            Button("kg") { unit = .kg }
            Button("lb") { unit = .lb }
        } label: {
            Text(unit.label)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(themeColor(.sand))
                .frame(width: 44, height: 32)
                .background(
                    Capsule()
                        .fill(themeColor(.sand).opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(themeColor(.sand).opacity(0.18), lineWidth: 1)
                        )
                )
        }
    }
}

struct SetRemoveButtonAligned: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Unit")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(.clear)
            Button(role: .destructive, action: action) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(themeColor(.sand).opacity(0.7))
            }
            .frame(width: 32, height: 32)
        }
        .padding(.top, 2)
    }
}

struct SegmentRemoveButton: View {
    let showsTitle: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(themeColor(.sand).opacity(0.7))
        }
        .frame(width: 24, height: 24)
        .padding(.top, showsTitle ? 16 : 0)
    }
}

struct SetDeleteAnchor: View {
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .foregroundStyle(themeColor(.sand).opacity(0.7))
        }
        .frame(width: 24, height: 24)
    }
}

struct SetCardView: View {
    @Binding var set: WorkoutSetDraft
    @Binding var weightUnit: WeightUnit
    let isCompact: Bool
    let canRemoveSet: Bool
    let allowDropSets: Bool
    let isBodyweightSegment: (WorkoutSetSegmentDraft) -> Bool
    let onRemoveSet: () -> Void
    @State private var segmentMidYs: [UUID: CGFloat] = [:]

    private var deleteAnchorY: CGFloat? {
        let ids = set.segments.map(\.id)
        guard !ids.isEmpty else { return nil }
        let count = ids.count
        if count % 2 == 1 {
            let midIndex = (count - 1) / 2
            return segmentMidYs[ids[midIndex]]
        }
        let upperIndex = count / 2
        let lowerIndex = upperIndex - 1
        guard let lower = segmentMidYs[ids[lowerIndex]],
              let upper = segmentMidYs[ids[upperIndex]] else {
            return nil
        }
        return (lower + upper) / 2
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                ForEach(Array($set.segments.enumerated()), id: \.element.id) { index, $segment in
                    let segmentId = $segment.wrappedValue.id
                    let showsTitle = index == 0
                    HStack(alignment: .center, spacing: 12) {
                        if allowDropSets && set.segments.count > 1 {
                            SegmentRemoveButton(showsTitle: showsTitle) {
                                set.segments.removeAll { $0.id == segmentId }
                            }
                        }
                        InputCard(
                            title: "Reps",
                            text: $segment.reps,
                            placeholder: segment.repsPlaceholder.isEmpty ? "10" : segment.repsPlaceholder,
                            keyboard: .numberPad,
                            showsTitle: showsTitle
                        )
                        InputCard(
                            title: "Weight",
                            text: $segment.weight,
                            placeholder: segment.weightPlaceholder.isEmpty ? "10" : segment.weightPlaceholder,
                            keyboard: .decimalPad,
                            showsTitle: showsTitle
                        )
                                if isBodyweightSegment(segment) {
                                    BodyweightPillAligned(isCompact: isCompact, showsTitle: showsTitle)
                                } else {
                                    UnitPillAligned(unit: $weightUnit, showsTitle: showsTitle)
                                }
                        if canRemoveSet {
                            SetDeleteAnchorSpacer()
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: SegmentMidYPreferenceKey.self,
                                value: [segmentId: proxy.frame(in: .named("setCard")).midY]
                            )
                        }
                    )
                }
            }
            .onPreferenceChange(SegmentMidYPreferenceKey.self) { value in
                segmentMidYs = value
            }

            if allowDropSets {
                Button {
                    set.segments.append(WorkoutSetSegmentDraft())
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Drop")
                    }
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.sand))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColor(.card).opacity(0.6))
        )
        .coordinateSpace(name: "setCard")
        .overlay(alignment: .topTrailing) {
            if canRemoveSet, let anchorY = deleteAnchorY {
                SetDeleteAnchor(action: onRemoveSet)
                    .offset(y: anchorY - 3)
                    .padding(.trailing, 0)
            }
        }
    }
}

struct SegmentMidYPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct SetDeleteAnchorSpacer: View {
    var body: some View {
        Color.clear
            .frame(width: 24, height: 24)
    }
}

struct BodyweightPillAligned: View {
    let isCompact: Bool
    var showsTitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTitle {
                Text("Unit")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(.clear)
            }
            Group {
                if isCompact {
                    Text("BW")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themeColor(.sand))
                        .frame(width: 44, height: 32)
                        .background(
                            Capsule()
                                .fill(themeColor(.sand).opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(themeColor(.sand).opacity(0.18), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Text("Bodyweight")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(themeColor(.sand))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(minWidth: 88, minHeight: 32)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(themeColor(.sand).opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(themeColor(.sand).opacity(0.18), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isCompact)
        }
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(themeColor(.night))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(themeColor(.sand))
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
                .foregroundStyle(themeColor(.sand))
            Text("Add a workout or create a template to get started.")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themeColor(.sand).opacity(0.6))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card).opacity(0.8))
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
                    .foregroundStyle(themeColor(.sand))
                if let first = template.exercises.first {
                    Text("Starts with \(first.name)")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(16)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(themeColor(.card).opacity(0.9))
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

struct TemplateShareSheet: View {
    let code: String
    let onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Share Template")
                        .font(.custom("Avenir Next", size: 26))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))

                    QRCodeView(text: code)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Code")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(themeColor(.sand).opacity(0.7))
                        Text("Use the button below to copy the code.")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(themeColor(.sand).opacity(0.6))
                    }

                    Button {
                        onCopy()
                    } label: {
                        Text("Copy Code")
                            .font(.custom("Avenir Next", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night))
                            .background(themeColor(.sand))
                            .clipShape(Capsule())
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.custom("Avenir Next", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.sand))
                            .background(
                                Capsule()
                                    .stroke(themeColor(.sand).opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .padding(24)
            }
        }
    }
}

struct TemplateShareSheetPayload: Identifiable {
    let id = UUID()
    let code: String
}

struct QRCodeView: View {
    let text: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        Group {
            if let image = generateImage() {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(themeColor(.card).opacity(0.9))
                    )
            } else {
                Text("Unable to generate QR code.")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.7))
            }
        }
    }

    private func generateImage() -> UIImage? {
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onError: onError)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onImage: (UIImage) -> Void
        private let onError: (String) -> Void

        init(onImage: @escaping (UIImage) -> Void, onError: @escaping (String) -> Void) {
            self.onImage = onImage
            self.onError = onError
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onError("No image selected.")
                return
            }
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                onError("Unable to load image.")
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self.onImage(image)
                    } else if let error {
                        self.onError(error.localizedDescription)
                    } else {
                        self.onError("Unable to load image.")
                    }
                }
            }
        }
    }
}

struct TemplateQRScanner: View {
    let onScan: (String) -> Void
    let onImportPhoto: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if AVCaptureDevice.default(for: .video) == nil {
                Text("Camera unavailable on this device.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.sand))
            } else {
                QRScannerView { code in
                    onScan(code)
                }
                .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.sand))
                    Spacer()
                    Text("Scan QR")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(themeColor(.sand).opacity(0.7))
                    Spacer()
                    Button {
                        dismiss()
                        onImportPhoto()
                    } label: {
                        Image(systemName: "photo")
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(themeColor(.sand))
                    }
                    .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                Spacer()
            }
        }
        .background(themeColor(.night).ignoresSafeArea())
    }
}

struct QRScannerView: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        let session = AVCaptureSession()
        session.sessionPreset = .high
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return view
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        if let preview = view.layer as? AVCaptureVideoPreviewLayer {
            preview.session = session
            preview.videoGravity = .resizeAspectFill
            context.coordinator.previewLayer = preview
        }

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let preview = uiView.layer as? AVCaptureVideoPreviewLayer,
           let connection = preview.connection {
            let angle = currentRotationAngle()
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }

    private func currentRotationAngle() -> CGFloat {
        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .interfaceOrientation ?? .portrait
        switch orientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        default:
            return 90
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        var session: AVCaptureSession?
        weak var previewLayer: AVCaptureVideoPreviewLayer?

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue else { return }
            session?.stopRunning()
            onScan(value)
        }
    }
}

struct AddTemplateView: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var drafts: [ExerciseDraft] = [ExerciseDraft()]
    @State private var editMode: EditMode = .inactive
    @State private var isNameFocused = false
    @State private var isKeyboardVisible = false

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
        return !trimmedTitle.isEmpty && validExercises.count == drafts.count && validExercises.count >= 2
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Template")
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    InputCard(title: "Template Name", text: $title, placeholder: "Push Day", keyboard: .default)
                        .padding(.leading, 24)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                }

                templateList

                if validExercises.count < 2 {
                    Text("Templates need at least 2 exercises.")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                if !isKeyboardVisible {
                    VStack(spacing: 10) {
                        Button {
                            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            store.addTemplate(title: trimmedTitle, exercises: validExercises)
                            dismiss()
                        } label: {
                            Text("Save Template")
                                .font(.custom("Avenir Next", size: 18))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(themeColor(.night))
                                .background(themeColor(.sand))
                                .clipShape(Capsule())
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.custom("Avenir Next", size: 18))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(themeColor(.sand))
                                .background(
                                    Capsule()
                                        .stroke(themeColor(.sand).opacity(0.6), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    private var templateList: some View {
        List {
            ForEach($drafts) { $draft in
                ExerciseEditorRow(
                    draft: $draft,
                    suggestions: store.exerciseNameCatalog(),
                    suggestionDetail: store.muscleGroupLabel(for:),
                    showsMetrics: false,
                    knownType: store.exerciseType(for: draft.name),
                    isDropSetsEnabled: store.isDropSetsEnabled,
                    isNotesEnabled: store.isNotesEnabled,
                    noteForName: nil,
                    onDelete: {
                        removeDraft(with: draft.id)
                    },
                    onMoveUp: nil,
                    onMoveDown: nil,
                    onNameFocusChange: { isNameFocused = $0 }
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
                .foregroundStyle(themeColor(.sand))
            }
            .allowsHitTesting(!isNameFocused)
            .disabled(isNameFocused)
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
        .scrollDisabled(isNameFocused)
        .environment(\.editMode, $editMode)
    }

    private func removeDraft(with id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            drafts.removeAll { $0.id == id }
            if drafts.isEmpty {
                drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
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
    @State private var isNameFocused = false
    @State private var isKeyboardVisible = false

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
        return !trimmedTitle.isEmpty && validExercises.count == drafts.count && validExercises.count >= 2
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
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
                            .foregroundStyle(themeColor(.sand))
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
                            suggestionDetail: store.muscleGroupLabel(for:),
                            showsMetrics: false,
                            knownType: store.exerciseType(for: draft.name),
                            isDropSetsEnabled: store.isDropSetsEnabled,
                    isNotesEnabled: store.isNotesEnabled,
                    noteForName: nil,
                    onDelete: {
                                removeDraft(with: draft.id)
                            },
                    onMoveUp: nil,
                    onMoveDown: nil,
                    onNameFocusChange: { isNameFocused = $0 }
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
                        .foregroundStyle(themeColor(.sand))
                    }
                    .allowsHitTesting(!isNameFocused)
                    .disabled(isNameFocused)
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
                .scrollDisabled(isNameFocused)
                .environment(\.editMode, $editMode)

                if validExercises.count < 2 {
                    Text("Templates need at least 2 exercises.")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                if !isKeyboardVisible {
                    VStack(spacing: 10) {
                        Button {
                            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            store.updateTemplate(id: template.id, title: trimmedTitle, exercises: validExercises)
                            dismiss()
                        } label: {
                            Text("Save Changes")
                                .font(.custom("Avenir Next", size: 18))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(themeColor(.night))
                                .background(themeColor(.sand))
                                .clipShape(Capsule())
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.custom("Avenir Next", size: 18))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(themeColor(.sand))
                                .background(
                                    Capsule()
                                        .stroke(themeColor(.sand).opacity(0.6), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    private func removeDraft(with id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            drafts.removeAll { $0.id == id }
            if drafts.isEmpty {
                drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
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
                .foregroundStyle(themeColor(.sand).opacity(0.6))
            TextField(placeholder, text: $text)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themeColor(.sand))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColor(.card))
        )
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
 
