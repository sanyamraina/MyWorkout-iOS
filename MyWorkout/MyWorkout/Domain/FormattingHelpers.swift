import Foundation

func formattedDurationValue(_ seconds: Int?) -> String {
    guard let seconds, seconds > 0 else { return "" }
    let minutes = seconds / 60
    let remainder = seconds % 60
    return String(format: "%d:%02d", minutes, remainder)
}

func durationLabel(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    if remainder == 0 {
        return "\(minutes) min"
    }
    return String(format: "%d:%02d", minutes, remainder)
}

func formattedWeight(_ kg: Double, unit: WeightUnit) -> String {
    if kg == 0 { return "Bodyweight" }
    let value = unit == .lb ? kg * 2.20462262 : kg
    return String(format: "%.1f %@", value, unit.label)
}
