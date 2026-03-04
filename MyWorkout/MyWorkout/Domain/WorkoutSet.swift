import Foundation

struct IsometricSet: Identifiable, Codable, Equatable {
    let id: UUID
    let durationSeconds: Int
    let weightKg: Double
}

struct WorkoutSetSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let weightKg: Double
    let reps: Int
    let isSpotted: Bool

    init(id: UUID, weightKg: Double, reps: Int, isSpotted: Bool = false) {
        self.id = id
        self.weightKg = weightKg
        self.reps = reps
        self.isSpotted = isSpotted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        reps = try container.decode(Int.self, forKey: .reps)
        isSpotted = try container.decodeIfPresent(Bool.self, forKey: .isSpotted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encode(reps, forKey: .reps)
        try container.encode(isSpotted, forKey: .isSpotted)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case weightKg
        case reps
        case isSpotted
    }
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
