import Foundation

struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let type: ExerciseType
    let sets: [WorkoutSet]
    let durationSeconds: Int?
    let calories: Int?
    let isometricWeightKg: Double?
    let isometricSets: [IsometricSet]
    let loggedAt: Date?
    let todaysNotes: String?

    init(
        id: UUID,
        name: String,
        type: ExerciseType = .weights,
        sets: [WorkoutSet],
        durationSeconds: Int? = nil,
        calories: Int? = nil,
        isometricWeightKg: Double? = nil,
        isometricSets: [IsometricSet] = [],
        loggedAt: Date? = nil,
        todaysNotes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sets = sets
        self.durationSeconds = durationSeconds
        self.calories = calories
        self.isometricWeightKg = isometricWeightKg
        self.isometricSets = isometricSets
        self.loggedAt = loggedAt
        self.todaysNotes = todaysNotes
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
        isometricWeightKg = try container.decodeIfPresent(Double.self, forKey: .isometricWeightKg)
        if let decodedSets = try container.decodeIfPresent([IsometricSet].self, forKey: .isometricSets) {
            isometricSets = decodedSets
        } else {
            isometricSets = []
        }
        loggedAt = try container.decodeIfPresent(Date.self, forKey: .loggedAt)
        todaysNotes = try container.decodeIfPresent(String.self, forKey: .todaysNotes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(sets, forKey: .sets)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(isometricWeightKg, forKey: .isometricWeightKg)
        try container.encode(isometricSets, forKey: .isometricSets)
        try container.encodeIfPresent(loggedAt, forKey: .loggedAt)
        try container.encodeIfPresent(todaysNotes, forKey: .todaysNotes)
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
        case isometricWeightKg
        case isometricSets
        case loggedAt
        case todaysNotes
    }
}

extension WorkoutExercise {
    var allSegments: [WorkoutSetSegment] {
        sets.flatMap(\.segments)
    }
}
