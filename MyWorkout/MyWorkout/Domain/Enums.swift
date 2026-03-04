import Foundation

enum ExerciseType: String, Codable, CaseIterable {
    case weights
    case cardio
    case isometric

    var label: String {
        switch self {
        case .weights:
            return "Weights"
        case .cardio:
            return "Cardio"
        case .isometric:
            return "Isometric"
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
    case custom = "Custom"
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

enum DraftKind: String, Codable {
    case live
    case add
    case templateFlow

    var fileName: String {
        "draft-\(rawValue).json"
    }
}
