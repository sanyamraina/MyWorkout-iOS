import Foundation

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
        func mergedEntryNote(_ existing: String?, _ incoming: String?) -> String? {
            let trimmedExisting = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let trimmedIncoming = incoming?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedExisting.isEmpty && trimmedIncoming.isEmpty {
                return nil
            }
            if trimmedExisting.isEmpty {
                return trimmedIncoming
            }
            if trimmedIncoming.isEmpty || trimmedIncoming == trimmedExisting {
                return trimmedExisting
            }
            return "\(trimmedExisting)\n\(trimmedIncoming)"
        }

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
                        isometricWeightKg: nil,
                        isometricSets: [],
                        loggedAt: mergedLoggedAt,
                        todaysNotes: mergedEntryNote(existing.todaysNotes, exercise.todaysNotes)
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
                        isometricWeightKg: nil,
                        isometricSets: [],
                        loggedAt: mergedLoggedAt,
                        todaysNotes: mergedEntryNote(existing.todaysNotes, exercise.todaysNotes)
                    )
                case .isometric:
                    let combinedSets = existing.isometricSets + exercise.isometricSets
                    let totalSeconds = combinedSets.reduce(0) { $0 + $1.durationSeconds }
                    let maxWeight = combinedSets.map(\.weightKg).max() ?? 0
                    let mergedLoggedAt = [existing.loggedAt, exercise.loggedAt].compactMap { $0 }.min()
                    mergedByKey[key] = WorkoutExercise(
                        id: existing.id,
                        name: existing.name,
                        type: existing.type,
                        sets: [],
                        durationSeconds: totalSeconds > 0 ? totalSeconds : nil,
                        calories: nil,
                        isometricWeightKg: maxWeight > 0 ? maxWeight : nil,
                        isometricSets: combinedSets,
                        loggedAt: mergedLoggedAt,
                        todaysNotes: mergedEntryNote(existing.todaysNotes, exercise.todaysNotes)
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
