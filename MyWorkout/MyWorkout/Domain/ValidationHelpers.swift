import Foundation

func minimumWorkoutEndTime(start: Date, minimumMinutes: Int = 5) -> Date {
    Calendar.current.date(byAdding: .minute, value: minimumMinutes, to: start) ?? start
}

func isValidWorkoutTimeRange(start: Date, end: Date, minimumMinutes: Int = 5) -> Bool {
    end >= minimumWorkoutEndTime(start: start, minimumMinutes: minimumMinutes)
}
