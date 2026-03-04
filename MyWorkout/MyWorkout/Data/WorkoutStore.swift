import Foundation
import SwiftUI
import Combine

final class WorkoutStore: ObservableObject {
    @Published private(set) var entries: [WorkoutExercise] = []
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var exerciseLibrary: [LibraryExercise] = []
    private var customLibrary: [LibraryExercise] = []
    private var hasLoaded = false
    @Published var ioErrorMessage: String?
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
    @Published var isExerciseNotesEnabled: Bool = true {
        didSet { saveExerciseNotesEnabled() }
    }
    @Published var isTodaysNotesEnabled: Bool = true {
        didSet { saveTodaysNotesEnabled() }
    }
    @Published var isSpottingEnabled: Bool = true {
        didSet { saveSpottingEnabled() }
    }

    init() {
        defaultWeightUnit = loadDefaultWeightUnit()
        sessionMergeWindowOption = loadSessionMergeWindowOption()
        isDropSetsEnabled = loadDropSetsEnabled()
        isExerciseNotesEnabled = loadExerciseNotesEnabled()
        isTodaysNotesEnabled = loadTodaysNotesEnabled()
        isSpottingEnabled = loadSpottingEnabled()
        templateUsage = loadTemplateUsage()
        customLibrary = loadCustomLibrary()
        exerciseLibrary = mergedLibrary(defaults: Self.defaultLibrary, custom: customLibrary)
        loadAsync()
    }

    private func normalizedTitleCase(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return trimmed.lowercased().capitalized
    }

    private func normalizedExerciseName(_ name: String) -> String {
        normalizedTitleCase(name)
    }

    private func reportIOError(_ message: String) {
        DispatchQueue.main.async {
            self.ioErrorMessage = message
        }
    }

    private func reportLoadErrorIfNeeded(_ message: String, url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        reportIOError(message)
    }



    func addSession(date: Date, exercises: [WorkoutExercise]) {
        let newEntries = exercises.map { exercise in
            WorkoutExercise(
                id: exercise.id,
                name: normalizedExerciseName(exercise.name),
                type: exercise.type,
                sets: exercise.sets,
                durationSeconds: exercise.durationSeconds,
                calories: exercise.calories,
                isometricWeightKg: exercise.isometricWeightKg,
                isometricSets: exercise.isometricSets,
                loggedAt: exercise.loggedAt ?? date,
                todaysNotes: exercise.todaysNotes
            )
        }
        entries.append(contentsOf: newEntries)
        ensureLibraryEntries(for: newEntries)
        updateExerciseTypes(from: newEntries)
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
                        isometricWeightKg: nil,
                        isometricSets: [],
                        loggedAt: mergedLoggedAt(current: current, incoming: exercise),
                        todaysNotes: mergedTodaysNotes(current: current, incoming: exercise)
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
                        isometricWeightKg: nil,
                        isometricSets: [],
                        loggedAt: mergedLoggedAt(current: current, incoming: exercise),
                        todaysNotes: mergedTodaysNotes(current: current, incoming: exercise)
                    )
                case .isometric:
                    let combinedSets = current.isometricSets + exercise.isometricSets
                    let totalSeconds = combinedSets.reduce(0) { $0 + $1.durationSeconds }
                    let maxWeight = combinedSets.map(\.weightKg).max() ?? 0
                    merged[idx] = WorkoutExercise(
                        id: current.id,
                        name: current.name,
                        type: current.type,
                        sets: [],
                        durationSeconds: totalSeconds > 0 ? totalSeconds : nil,
                        calories: nil,
                        isometricWeightKg: maxWeight > 0 ? maxWeight : nil,
                        isometricSets: combinedSets,
                        loggedAt: mergedLoggedAt(current: current, incoming: exercise),
                        todaysNotes: mergedTodaysNotes(current: current, incoming: exercise)
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

    private func mergedTodaysNotes(current: WorkoutExercise, incoming: WorkoutExercise) -> String? {
        let currentEntry = current.todaysNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let incomingEntry = incoming.todaysNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if currentEntry.isEmpty && incomingEntry.isEmpty {
            return nil
        }
        if currentEntry.isEmpty {
            return incomingEntry
        }
        if incomingEntry.isEmpty || incomingEntry == currentEntry {
            return currentEntry
        }
        return "\(currentEntry)\n\(incomingEntry)"
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
            isometricWeightKg: exercise.isometricWeightKg,
            isometricSets: exercise.isometricSets,
            loggedAt: loggedAt,
            todaysNotes: exercise.todaysNotes
        )
    }

    func updateSession(_ session: WorkoutSession, date: Date, exercises: [WorkoutExercise]) {
        let removeIds = Set(session.exercises.map(\.id))
        entries.removeAll { removeIds.contains($0.id) }
        let newEntries = exercises.map { exercise in
            WorkoutExercise(
                id: exercise.id,
                name: normalizedExerciseName(exercise.name),
                type: exercise.type,
                sets: exercise.sets,
                durationSeconds: exercise.durationSeconds,
                calories: exercise.calories,
                isometricWeightKg: exercise.isometricWeightKg,
                isometricSets: exercise.isometricSets,
                loggedAt: exercise.loggedAt ?? date,
                todaysNotes: exercise.todaysNotes
            )
        }
        entries.append(contentsOf: newEntries)
        ensureLibraryEntries(for: newEntries)
        updateExerciseTypes(from: newEntries)
        saveEntries()
        refreshSessions()
    }

    func removeSession(_ session: WorkoutSession) {
        let removeIds = Set(session.exercises.map(\.id))
        entries.removeAll { removeIds.contains($0.id) }
        saveEntries()
        refreshSessions()
    }

    func removeExercise(_ exercise: WorkoutExercise, from session: WorkoutSession) {
        let targetKey = exerciseMergeKey(for: exercise)
        let removeIds = session.exercises
            .filter { exerciseMergeKey(for: $0) == targetKey }
            .map(\.id)
        let removeSet = Set(removeIds)
        guard !removeSet.isEmpty else { return }
        entries.removeAll { removeSet.contains($0.id) }
        saveEntries()
        refreshSessions()
    }

    func addTemplate(title: String, exercises: [TemplateExercise]) {
        let normalizedTitle = normalizedTitleCase(title)
        let normalizedExercises = exercises.map { exercise in
            TemplateExercise(
                id: exercise.id,
                name: normalizedExerciseName(exercise.name),
                type: exercise.type,
                weightKg: exercise.weightKg,
                sets: exercise.sets,
                repsPerSet: exercise.repsPerSet
            )
        }
        let template = WorkoutTemplate(
            id: UUID(),
            title: normalizedTitle,
            exercises: normalizedExercises
        )
        templates.insert(template, at: 0)
        ensureLibraryEntries(for: normalizedExercises)
        updateExerciseTypes(from: normalizedExercises)
        saveTemplates()
        saveTemplateUsage()
    }

    func shareString(for template: WorkoutTemplate) throws -> String {
        let liteExercises = template.exercises.map {
            TemplateShareLiteExercise(name: $0.name, type: $0.type)
        }
        let payload = TemplateShareLitePayload(version: 2, title: template.title, exercises: liteExercises)
        let data = try JSONEncoder().encode(payload)
        return data.base64EncodedString()
    }

    func importTemplate(from shareString: String) throws {
        let cleaned = shareString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: cleaned) else {
            throw TemplateShareError.invalidPayload
        }
        if let payload = try? JSONDecoder().decode(TemplateShareLitePayload.self, from: data) {
            let exercises = payload.exercises.map {
                TemplateExercise(id: UUID(), name: $0.name, type: $0.type, weightKg: nil, sets: nil, repsPerSet: nil)
            }
            addTemplate(title: payload.title, exercises: exercises)
            return
        }
        let payload = try JSONDecoder().decode(TemplateSharePayload.self, from: data)
        let exercises = payload.template.exercises.map {
            TemplateExercise(id: UUID(), name: $0.name, type: $0.type, weightKg: nil, sets: nil, repsPerSet: nil)
        }
        addTemplate(title: payload.template.title, exercises: exercises)
    }

    func updateTemplate(id: UUID, title: String, exercises: [TemplateExercise]) {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return }
        let normalizedTitle = normalizedTitleCase(title)
        let normalizedExercises = exercises.map { exercise in
            TemplateExercise(
                id: exercise.id,
                name: normalizedExerciseName(exercise.name),
                type: exercise.type,
                weightKg: exercise.weightKg,
                sets: exercise.sets,
                repsPerSet: exercise.repsPerSet
            )
        }
        templates[index] = WorkoutTemplate(id: id, title: normalizedTitle, exercises: normalizedExercises)
        ensureLibraryEntries(for: normalizedExercises)
        updateExerciseTypes(from: normalizedExercises)
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
                        exerciseNote: exerciseNote(for: trimmedName)
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
                                    repsPlaceholder: "\(segment.reps)",
                                    isSpotted: false,
                                    isSpottedPlaceholder: segment.isSpotted
                                )
                            }
                            return WorkoutSetDraft(segments: segmentDrafts.isEmpty ? [WorkoutSetSegmentDraft()] : segmentDrafts)
                        }
                        return ExerciseDraft(
                            name: latest.exercise.name,
                            type: .weights,
                            sets: setDrafts.isEmpty ? [WorkoutSetDraft()] : setDrafts,
                            weightUnit: defaultWeightUnit,
                            exerciseNote: exerciseNote(for: latest.exercise.name)
                        )
                    }
                case .isometric:
                    if latest.exercise.type == .isometric {
                        let latestSets = latest.exercise.isometricSets
                        let setDrafts = latestSets.isEmpty
                            ? [IsometricSetDraft(durationPlaceholder: formattedDurationValue(latest.exercise.durationSeconds))]
                            : latestSets.map { set in
                                let weightPlaceholder = set.weightKg > 0
                                    ? String(format: "%.1f", weightValue(set.weightKg, unit: defaultWeightUnit))
                                    : "0"
                                return IsometricSetDraft(
                                    duration: "",
                                    weight: "",
                                    durationPlaceholder: formattedDurationValue(set.durationSeconds),
                                    weightPlaceholder: weightPlaceholder
                                )
                            }
                        return ExerciseDraft(
                            name: trimmedName,
                            type: .isometric,
                            sets: [],
                            isometricSets: setDrafts,
                            weightUnit: defaultWeightUnit,
                            exerciseNote: exerciseNote(for: trimmedName)
                        )
                    }
                }
            }
            return ExerciseDraft(
                name: trimmedName,
                type: exercise.type,
                sets: exercise.type == .weights ? [WorkoutSetDraft()] : [],
                isometricSets: exercise.type == .isometric ? [IsometricSetDraft()] : [IsometricSetDraft()],
                weightUnit: defaultWeightUnit,
                exerciseNote: exerciseNote(for: trimmedName)
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
            let legacyEntries = backup.sessions.flatMap { session in
                session.exercises.map { exercise in
                    WorkoutExercise(
                        id: exercise.id,
                        name: exercise.name,
                        type: exercise.type,
                        sets: exercise.sets,
                        durationSeconds: exercise.durationSeconds,
                        calories: exercise.calories,
                        isometricWeightKg: exercise.isometricWeightKg,
                        isometricSets: exercise.isometricSets,
                        loggedAt: exercise.loggedAt ?? session.date,
                        todaysNotes: exercise.todaysNotes
                    )
                }
            }
            self.entries = legacyEntries
        }
        templates = backup.templates
        exerciseNotes = backup.notes ?? [:]
        exerciseTypeMap = [:]
        ensureLibraryEntries(for: self.entries)
        updateExerciseTypes(from: self.entries)
        updateExerciseTypes(from: templates.flatMap { $0.exercises })
        saveEntries()
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
        templateUsage = [:]
        exerciseTypeMap = [:]
        exerciseNotes = [:]
        customLibrary = []
        exerciseLibrary = Self.defaultLibrary
        saveEntries()
        saveTemplates()
        saveTemplateUsage()
        saveExerciseTypes()
        saveExerciseNotes()
        saveCustomLibrary()
        UserDefaults.standard.removeObject(forKey: "templateUsageCounts")

        let urls = [
            sessionsFileURL(),
            entriesFileURL(),
            templatesFileURL(),
            exerciseTypesFileURL(),
            exerciseNotesFileURL(),
            exerciseLibraryFileURL()
        ]
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

    private struct LoadedData {
        let entries: [WorkoutExercise]
        let templates: [WorkoutTemplate]
        let exerciseTypeMap: [String: ExerciseType]
        let exerciseNotes: [String: String]
        let needsEntryMigration: Bool
    }

    private func loadSnapshot() -> LoadedData {
        var loadedEntries = loadEntries()
        let needsEntryMigration = loadedEntries.isEmpty
        if needsEntryMigration {
            let legacySessions = loadSessions()
            let legacyEntries = legacySessions.flatMap { session in
                session.exercises.map { exercise in
                    WorkoutExercise(
                        id: exercise.id,
                        name: exercise.name,
                        type: exercise.type,
                        sets: exercise.sets,
                        durationSeconds: exercise.durationSeconds,
                        calories: exercise.calories,
                        isometricWeightKg: exercise.isometricWeightKg,
                        isometricSets: exercise.isometricSets,
                        loggedAt: exercise.loggedAt ?? session.date,
                        todaysNotes: exercise.todaysNotes
                    )
                }
            }
            loadedEntries = legacyEntries
        }
        let loadedTemplates = loadTemplates()
        let loadedExerciseTypeMap = loadExerciseTypes()
        let loadedExerciseNotes = loadExerciseNotes()
        return LoadedData(
            entries: loadedEntries,
            templates: loadedTemplates,
            exerciseTypeMap: loadedExerciseTypeMap,
            exerciseNotes: loadedExerciseNotes,
            needsEntryMigration: needsEntryMigration
        )
    }

    private func loadAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let snapshot = self.loadSnapshot()
            DispatchQueue.main.async {
                self.entries = snapshot.entries
                self.templates = snapshot.templates
                self.exerciseTypeMap = snapshot.exerciseTypeMap
                self.exerciseNotes = snapshot.exerciseNotes
                self.hasLoaded = true
                self.updateExerciseTypes(from: self.entries)
                let templateExercises = self.templates.flatMap { $0.exercises }
                self.updateExerciseTypes(from: templateExercises)
                self.updateExerciseTypes(from: self.exerciseLibrary)
                self.refreshSessions()
                if snapshot.needsEntryMigration {
                    self.saveEntries()
                }
            }
        }
    }

    func exerciseType(for name: String) -> ExerciseType? {
        let key = normalizedExerciseKey(name)
        guard !key.isEmpty else { return nil }
        return exerciseTypeMap[key]
    }

    func exerciseNote(for name: String) -> String {
        let key = normalizedExerciseKey(name)
        guard !key.isEmpty else { return "" }
        return exerciseNotes[key] ?? ""
    }

    func exerciseNotesList() -> [(name: String, exerciseNote: String)] {
        exerciseNotes
            .map { (name: $0.key, exerciseNote: $0.value) }
            .filter { !$0.name.isEmpty && !$0.exerciseNote.isEmpty }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setExerciseNote(_ exerciseNote: String, for name: String) {
        let key = normalizedExerciseKey(name)
        guard !key.isEmpty else { return }
        let trimmed = exerciseNote.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func ensureLibraryEntries(for exercises: [WorkoutExercise]) {
        var didChange = false
        for exercise in exercises {
            let trimmed = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if addToLibraryIfNeeded(name: trimmed, type: exercise.type) {
                didChange = true
            }
        }
        if didChange {
            saveCustomLibrary()
            updateExerciseTypes(from: exerciseLibrary)
        }
    }

    private func ensureLibraryEntries(for exercises: [TemplateExercise]) {
        var didChange = false
        for exercise in exercises {
            let trimmed = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if addToLibraryIfNeeded(name: trimmed, type: exercise.type) {
                didChange = true
            }
        }
        if didChange {
            saveCustomLibrary()
            updateExerciseTypes(from: exerciseLibrary)
        }
    }

    private func addToLibraryIfNeeded(name: String, type: ExerciseType) -> Bool {
        let key = normalizedExerciseKey(name)
        guard !key.isEmpty else { return false }
        let exists = exerciseLibrary.contains { normalizedExerciseKey($0.name) == key }
        guard !exists else { return false }
        let group: MuscleGroup = type == .cardio ? .cardio : .custom
        let newExercise = LibraryExercise(id: UUID(), name: normalizedTitleCase(name), group: group, type: type)
        customLibrary.append(newExercise)
        exerciseLibrary = mergedLibrary(defaults: Self.defaultLibrary, custom: customLibrary)
        return true
    }

    private func normalizedExerciseKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func loadExerciseTypes() -> [String: ExerciseType] {
        do {
            let data = try Data(contentsOf: exerciseTypesFileURL())
            return try JSONDecoder().decode([String: ExerciseType].self, from: data)
        } catch {
            reportLoadErrorIfNeeded("Failed to load exercise types.", url: exerciseTypesFileURL())
            return [:]
        }
    }

    private func loadExerciseNotes() -> [String: String] {
        do {
            let data = try Data(contentsOf: exerciseNotesFileURL())
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            reportLoadErrorIfNeeded("Failed to load exercise notes.", url: exerciseNotesFileURL())
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
            reportIOError("Failed to save exercise types.")
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
            reportIOError("Failed to save exercise notes.")
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

    private func loadExerciseNotesEnabled() -> Bool {
        let value = UserDefaults.standard.object(forKey: "notesEnabled") as? Bool
        return value ?? true
    }

    private func saveExerciseNotesEnabled() {
        UserDefaults.standard.set(isExerciseNotesEnabled, forKey: "notesEnabled")
    }

    private func loadTodaysNotesEnabled() -> Bool {
        let value = UserDefaults.standard.object(forKey: "todaysNotesEnabled") as? Bool
        return value ?? true
    }

    private func saveTodaysNotesEnabled() {
        UserDefaults.standard.set(isTodaysNotesEnabled, forKey: "todaysNotesEnabled")
    }

    private func loadSpottingEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: "spottingEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "spottingEnabled")
    }

    private func saveSpottingEnabled() {
        UserDefaults.standard.set(isSpottingEnabled, forKey: "spottingEnabled")
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
        LibraryExercise(id: UUID(), name: "Deadlift (Sumo)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Lunge (Walking)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Lunge (Reverse)", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Bulgarian Split Squat", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Leg Extensions", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Leg Curls", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Calf Raises", group: .legs, type: .weights),
        LibraryExercise(id: UUID(), name: "Plank (Standard)", group: .core, type: .isometric),
        LibraryExercise(id: UUID(), name: "Plank (Side)", group: .core, type: .isometric),
        LibraryExercise(id: UUID(), name: "Plank (Weighted)", group: .core, type: .isometric),
        LibraryExercise(id: UUID(), name: "Farmer Carry", group: .core, type: .isometric),
        LibraryExercise(id: UUID(), name: "Suitcase Carry", group: .core, type: .isometric),
        LibraryExercise(id: UUID(), name: "Overhead Carry", group: .core, type: .isometric),
        LibraryExercise(id: UUID(), name: "Front Rack Carry", group: .core, type: .isometric),
        LibraryExercise(id: UUID(), name: "Waiter Carry", group: .core, type: .isometric),
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

    private func mergedLibrary(defaults: [LibraryExercise], custom: [LibraryExercise]) -> [LibraryExercise] {
        var seen = Set<String>()
        var merged: [LibraryExercise] = []
        for exercise in defaults {
            let key = normalizedExerciseKey(exercise.name)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(exercise)
        }
        for exercise in custom {
            let key = normalizedExerciseKey(exercise.name)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(exercise)
        }
        return merged
    }

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
                                isometricWeightKg: nil,
                                loggedAt: entry.date
                            )
                        ]
                    )
                }
            } catch {
                reportLoadErrorIfNeeded("Failed to load sessions.", url: sessionsFileURL())
                return []
            }
        }
    }

    private func loadEntries() -> [WorkoutExercise] {
        do {
            let data = try Data(contentsOf: entriesFileURL())
            return try JSONDecoder().decode([WorkoutExercise].self, from: data)
        } catch {
            reportLoadErrorIfNeeded("Failed to load entries.", url: entriesFileURL())
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
                reportLoadErrorIfNeeded("Failed to load templates.", url: templatesFileURL())
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
            reportIOError("Failed to save entries.")
        }
    }

    private func loadCustomLibrary() -> [LibraryExercise] {
        do {
            let data = try Data(contentsOf: exerciseLibraryFileURL())
            return try JSONDecoder().decode([LibraryExercise].self, from: data)
        } catch {
            reportLoadErrorIfNeeded("Failed to load custom exercises.", url: exerciseLibraryFileURL())
            return []
        }
    }

    private func saveCustomLibrary() {
        guard hasLoaded else { return }
        do {
            let data = try JSONEncoder().encode(customLibrary)
            let url = exerciseLibraryFileURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            reportIOError("Failed to save custom exercises.")
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
            reportIOError("Failed to save templates.")
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

    private func exerciseLibraryFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/exercise-library.json")
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
