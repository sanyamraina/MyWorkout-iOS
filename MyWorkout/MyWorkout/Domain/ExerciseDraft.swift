import Foundation

struct LiveWorkoutDraft: Codable {
    let templateId: UUID?
    let workoutDate: Date
    let usesManualTimes: Bool
    let manualStartTime: Date
    let manualEndTime: Date
    let drafts: [ExerciseDraft]
    let newDraftIds: Set<UUID>
    let pendingTemplateDrafts: [ExerciseDraft]
    let selectedDraftId: UUID?
}

struct AddWorkoutDraft: Codable {
    let sessionId: UUID?
    let templateId: UUID?
    let workoutDate: Date
    let usesManualTimes: Bool
    let manualStartTime: Date
    let manualEndTime: Date
    let drafts: [ExerciseDraft]
    let showsTimeEditor: Bool
}

struct TemplateFlowDraft: Codable {
    let templateId: UUID
    let workoutDate: Date
    let usesManualTimes: Bool
    let manualStartTime: Date
    let manualEndTime: Date
    let drafts: [ExerciseDraft]
    let templateExercises: [TemplateExercise]
    let addToTemplateDraftIds: Set<UUID>
    let newDraftIds: Set<UUID>
    let hasStarted: Bool
    let showsTimeEditor: Bool
}

struct ExerciseDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var type: ExerciseType
    var sets: [WorkoutSetDraft]
    var isometricSets: [IsometricSetDraft]
    var weightUnit: WeightUnit
    var durationMinutes: String
    var calories: String
    var durationPlaceholder: String
    var caloriesPlaceholder: String
    var exerciseNote: String
    var isExerciseNoteExpanded: Bool
    var todaysNotes: String
    var isTodaysNotesExpanded: Bool
    var entryId: UUID?
    var loggedAt: Date?
    var isNameLocked: Bool
    var isTypeLocked: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        type: ExerciseType = .weights,
        sets: [WorkoutSetDraft] = [WorkoutSetDraft()],
        isometricSets: [IsometricSetDraft] = [IsometricSetDraft()],
        weightUnit: WeightUnit = .kg,
        durationMinutes: String = "",
        calories: String = "",
        durationPlaceholder: String = "",
        caloriesPlaceholder: String = "",
        exerciseNote: String = "",
        isExerciseNoteExpanded: Bool = false,
        todaysNotes: String = "",
        isTodaysNotesExpanded: Bool = false,
        entryId: UUID? = nil,
        loggedAt: Date? = nil,
        isNameLocked: Bool = false,
        isTypeLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sets = sets
        self.isometricSets = isometricSets
        self.weightUnit = weightUnit
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.durationPlaceholder = durationPlaceholder
        self.caloriesPlaceholder = caloriesPlaceholder
        self.exerciseNote = exerciseNote
        self.isExerciseNoteExpanded = isExerciseNoteExpanded
        self.todaysNotes = todaysNotes
        self.isTodaysNotesExpanded = isTodaysNotesExpanded
        self.entryId = entryId
        self.loggedAt = loggedAt
        self.isNameLocked = isNameLocked
        self.isTypeLocked = isTypeLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try container.decodeIfPresent(ExerciseType.self, forKey: .type) ?? .weights
        sets = try container.decodeIfPresent([WorkoutSetDraft].self, forKey: .sets) ?? [WorkoutSetDraft()]
        isometricSets = try container.decodeIfPresent([IsometricSetDraft].self, forKey: .isometricSets) ?? [IsometricSetDraft()]
        weightUnit = try container.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .kg
        durationMinutes = try container.decodeIfPresent(String.self, forKey: .durationMinutes) ?? ""
        calories = try container.decodeIfPresent(String.self, forKey: .calories) ?? ""
        durationPlaceholder = try container.decodeIfPresent(String.self, forKey: .durationPlaceholder) ?? ""
        caloriesPlaceholder = try container.decodeIfPresent(String.self, forKey: .caloriesPlaceholder) ?? ""
        exerciseNote = try container.decodeIfPresent(String.self, forKey: .exerciseNote) ?? ""
        isExerciseNoteExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExerciseNoteExpanded) ?? false
        todaysNotes = try container.decodeIfPresent(String.self, forKey: .todaysNotes) ?? ""
        isTodaysNotesExpanded = try container.decodeIfPresent(Bool.self, forKey: .isTodaysNotesExpanded) ?? false
        entryId = try container.decodeIfPresent(UUID.self, forKey: .entryId)
        loggedAt = try container.decodeIfPresent(Date.self, forKey: .loggedAt)
        isNameLocked = try container.decodeIfPresent(Bool.self, forKey: .isNameLocked) ?? false
        isTypeLocked = try container.decodeIfPresent(Bool.self, forKey: .isTypeLocked) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(sets, forKey: .sets)
        try container.encode(isometricSets, forKey: .isometricSets)
        try container.encode(weightUnit, forKey: .weightUnit)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(calories, forKey: .calories)
        try container.encode(durationPlaceholder, forKey: .durationPlaceholder)
        try container.encode(caloriesPlaceholder, forKey: .caloriesPlaceholder)
        try container.encode(exerciseNote, forKey: .exerciseNote)
        try container.encode(isExerciseNoteExpanded, forKey: .isExerciseNoteExpanded)
        try container.encode(todaysNotes, forKey: .todaysNotes)
        try container.encode(isTodaysNotesExpanded, forKey: .isTodaysNotesExpanded)
        try container.encodeIfPresent(entryId, forKey: .entryId)
        try container.encodeIfPresent(loggedAt, forKey: .loggedAt)
        try container.encode(isNameLocked, forKey: .isNameLocked)
        try container.encode(isTypeLocked, forKey: .isTypeLocked)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case sets
        case isometricSets
        case weightUnit
        case durationMinutes
        case calories
        case durationPlaceholder
        case caloriesPlaceholder
        case exerciseNote
        case isExerciseNoteExpanded
        case todaysNotes
        case isTodaysNotesExpanded
        case entryId
        case loggedAt
        case isNameLocked
        case isTypeLocked
    }
}

struct IsometricSetDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var duration: String
    var weight: String
    var durationPlaceholder: String
    var weightPlaceholder: String

    init(
        id: UUID = UUID(),
        duration: String = "",
        weight: String = "",
        durationPlaceholder: String = "",
        weightPlaceholder: String = ""
    ) {
        self.id = id
        self.duration = duration
        self.weight = weight
        self.durationPlaceholder = durationPlaceholder
        self.weightPlaceholder = weightPlaceholder
    }
}

struct WorkoutSetSegmentDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var weight: String
    var reps: String
    var weightPlaceholder: String
    var repsPlaceholder: String
    var isSpotted: Bool
    var isSpottedPlaceholder: Bool

    init(
        id: UUID = UUID(),
        weight: String = "",
        reps: String = "",
        weightPlaceholder: String = "",
        repsPlaceholder: String = "",
        isSpotted: Bool = false,
        isSpottedPlaceholder: Bool = false
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.weightPlaceholder = weightPlaceholder
        self.repsPlaceholder = repsPlaceholder
        self.isSpotted = isSpotted
        self.isSpottedPlaceholder = isSpottedPlaceholder
    }
}

struct WorkoutSetDraft: Identifiable, Equatable, Codable {
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
