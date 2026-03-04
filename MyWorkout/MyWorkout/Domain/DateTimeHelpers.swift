import Foundation

func combineDate(_ date: Date, time: Date) -> Date {
    let calendar = Calendar.current
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
    return calendar.date(
        bySettingHour: timeComponents.hour ?? 0,
        minute: timeComponents.minute ?? 0,
        second: timeComponents.second ?? 0,
        of: date
    ) ?? date
}

func isFutureDay(_ date: Date) -> Bool {
    let calendar = Calendar.current
    let selected = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: Date())
    return selected > today
}

func distributedTimes(count: Int, start: Date, end: Date) -> [Date] {
    guard count > 1 else { return [start] }
    let interval = end.timeIntervalSince(start)
    guard interval > 0 else { return Array(repeating: start, count: count) }
    let step = interval / Double(count - 1)
    return (0..<count).map { index in
        start.addingTimeInterval(Double(index) * step)
    }
}

func isNowTime(_ date: Date, within seconds: TimeInterval = 300) -> Bool {
    abs(date.timeIntervalSince(Date())) <= seconds
}

func formattedTime(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
}

func sessionTimeRangeLabel(start: Date, end: Date) -> String {
    if start == end {
        return formattedTime(start)
    }
    return "\(formattedTime(start)) – \(formattedTime(end))"
}

func relativeLabel(for date: Date) -> String {
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
