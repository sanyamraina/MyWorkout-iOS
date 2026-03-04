import SwiftUI
import Charts

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
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    Text("Progress")
                        .font(.custom("Avenir Next", size: DesignSystem.FontSize.title2))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedPrimaryText())

                    Picker("Range", selection: $range) {
                        ForEach(ProgressRange.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .themedSegmentedPicker()

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
            syncSelectedExercise()
        }
        .onChange(of: store.sessions) { _, _ in
            syncSelectedExercise()
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Strength Trend")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                    .fontWeight(.semibold)
                    .foregroundStyle(themedPrimaryText())
                Spacer()
                if !recentExerciseNames.isEmpty {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(recentExerciseNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themedAccent())
                }
            }

            if strengthPoints.isEmpty {
                emptyCard(text: "No strength data yet.")
            } else {
                Chart {
                    ForEach(strengthPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(strengthWeightAxisLabel, displayWeightForChart(point.weight))
                        )
                        .foregroundStyle(themedAccent())

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(strengthWeightAxisLabel, displayWeightForChart(point.weight))
                        )
                        .foregroundStyle(themedAccent())
                    }
                }
                .frame(height: DesignSystem.FrameSize.chartHeight)
                .chartYAxisLabel(alignment: .leading) {
                    Text(store.defaultWeightUnit.label)
                        .foregroundStyle(themedSecondaryText())
                }
                .chartXAxisLabel(alignment: .center) {
                    Text("Date")
                        .foregroundStyle(themedSecondaryText())
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(themedSecondaryText())
                        AxisGridLine()
                            .foregroundStyle(themedSecondaryText().opacity(0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel()
                            .foregroundStyle(themedSecondaryText())
                        AxisGridLine()
                            .foregroundStyle(themedSecondaryText().opacity(0.3))
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .cardBackground()
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Volume Trend")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())

            if volumePoints.isEmpty {
                emptyCard(text: "No volume data yet.")
            } else {
                Chart {
                    ForEach(volumePoints) { point in
                        BarMark(
                            x: .value("Date", point.date),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(themedAccentMuted())
                    }
                }
                .frame(height: DesignSystem.FrameSize.chartHeight)
                .chartYAxisLabel(alignment: .leading) {
                    Text("Total Volume")
                        .foregroundStyle(themedSecondaryText())
                }
                .chartXAxisLabel(alignment: .center) {
                    Text("Date")
                        .foregroundStyle(themedSecondaryText())
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(themedSecondaryText())
                        AxisGridLine()
                            .foregroundStyle(themedSecondaryText().opacity(0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel()
                            .foregroundStyle(themedSecondaryText())
                        AxisGridLine()
                            .foregroundStyle(themedSecondaryText().opacity(0.3))
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .cardBackground()
            }
        }
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Workout Consistency")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())

            if weeklyWorkouts.isEmpty {
                emptyCard(text: "No workouts yet.")
            } else {
                Chart {
                    ForEach(weeklyWorkouts) { point in
                        BarMark(
                            x: .value("Week", point.weekStart),
                            y: .value("Workouts", point.value)
                        )
                        .foregroundStyle(themedAccent())
                    }
                }
                .frame(height: DesignSystem.FrameSize.consistencyChartHeight)
                .chartYAxisLabel(alignment: .leading) {
                    Text("Sessions")
                        .foregroundStyle(themedSecondaryText())
                }
                .chartXAxisLabel(alignment: .center) {
                    Text("Week")
                        .foregroundStyle(themedSecondaryText())
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(themedSecondaryText())
                        AxisGridLine()
                            .foregroundStyle(themedSecondaryText().opacity(0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel()
                            .foregroundStyle(themedSecondaryText())
                        AxisGridLine()
                            .foregroundStyle(themedSecondaryText().opacity(0.3))
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .cardBackground()
            }
        }
    }

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Cardio Trend")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())

            if weeklyCardio.isEmpty {
                emptyCard(text: "No cardio yet.")
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Minutes")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themedSecondaryText())
                        Chart {
                            ForEach(weeklyCardio) { point in
                                BarMark(
                                    x: .value("Week", point.weekStart),
                                    y: .value("Minutes", point.minutes)
                                )
                                .foregroundStyle(themedAccentMuted())
                            }
                        }
                        .frame(height: 130)
                        .chartYAxisLabel(alignment: .leading) {
                            Text("Minutes")
                                .foregroundStyle(themedSecondaryText())
                        }
                        .chartXAxisLabel(alignment: .center) {
                            Text("Week")
                                .foregroundStyle(themedSecondaryText())
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisValueLabel()
                                    .foregroundStyle(themedSecondaryText())
                                AxisGridLine()
                                    .foregroundStyle(themedSecondaryText().opacity(0.3))
                            }
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { _ in
                                AxisValueLabel()
                                    .foregroundStyle(themedSecondaryText())
                                AxisGridLine()
                                    .foregroundStyle(themedSecondaryText().opacity(0.3))
                            }
                        }
                    }

                    Divider()
                        .overlay(themedSecondaryText().opacity(0.18))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Calories")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themedSecondaryText())
                        Chart {
                            ForEach(weeklyCardio) { point in
                                LineMark(
                                    x: .value("Week", point.weekStart),
                                    y: .value("Calories", point.calories)
                                )
                                .foregroundStyle(themedAccent())

                                PointMark(
                                    x: .value("Week", point.weekStart),
                                    y: .value("Calories", point.calories)
                                )
                                .foregroundStyle(themedAccent())
                            }
                        }
                        .frame(height: 130)
                        .chartYAxisLabel(alignment: .leading) {
                            Text("Calories")
                                .foregroundStyle(themedSecondaryText())
                        }
                        .chartXAxisLabel(alignment: .center) {
                            Text("Week")
                                .foregroundStyle(themedSecondaryText())
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisValueLabel()
                                    .foregroundStyle(themedSecondaryText())
                                AxisGridLine()
                                    .foregroundStyle(themedSecondaryText().opacity(0.3))
                            }
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { _ in
                                AxisValueLabel()
                                    .foregroundStyle(themedSecondaryText())
                                AxisGridLine()
                                    .foregroundStyle(themedSecondaryText().opacity(0.3))
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .cardBackground()
            }
        }
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent PRs")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())

            if prItems.isEmpty {
                emptyCard(text: "No PRs yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(prItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.custom("Avenir Next", size: 16))
                                    .foregroundStyle(themedPrimaryText())
                                Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.custom("Avenir Next", size: 12))
                                    .foregroundStyle(themedSecondaryText())
                            }
                            Spacer()
                            Text("\(formattedWeight(item.weight, unit: store.defaultWeightUnit)) x \(item.reps)")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themedPrimaryText())
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(themeColor(.card).opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                                )
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
                .foregroundStyle(themedPrimaryText())

            if focusItems.isEmpty {
                emptyCard(text: "No exercise focus yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(focusItems) { item in
                        HStack {
                            Text(item.name)
                                .font(.custom("Avenir Next", size: 16))
                                .foregroundStyle(themedPrimaryText())
                            Spacer()
                            Text("\(item.count) sets")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themedSecondaryText())
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(themeColor(.card).opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.custom("Avenir Next", size: DesignSystem.FontSize.body))
            .foregroundStyle(themedSecondaryText())
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground(cornerRadius: DesignSystem.CornerRadius.lg, opacity: 1.0)
    }

    private func rangeStartDate() -> Date? {
        let calendar = Calendar.current
        switch range {
        case .week:
            guard let rawCutoff = calendar.date(byAdding: .day, value: -7, to: Date()) else { return nil }
            return calendar.startOfDay(for: rawCutoff)
        case .month:
            guard let rawCutoff = calendar.date(byAdding: .month, value: -1, to: Date()) else { return nil }
            return calendar.startOfDay(for: rawCutoff)
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

    private func syncSelectedExercise() {
        let names = recentExerciseNames
        guard !names.isEmpty else {
            selectedExercise = ""
            return
        }

        let selected = selectedExercise.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if selected.isEmpty || !names.contains(where: { $0.lowercased() == selected }) {
            selectedExercise = names[0]
        }
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

    private var strengthWeightAxisLabel: String {
        "Weight (\(store.defaultWeightUnit.label))"
    }

    private func displayWeightForChart(_ kg: Double) -> Double {
        store.defaultWeightUnit == .lb ? kg * 2.20462262 : kg
    }

    private var volumePoints: [VolumePoint] {
        filteredSessions.compactMap { session in
            let weightExercises = session.mergedExercises().filter { $0.type == .weights }
            guard !weightExercises.isEmpty else { return nil }
            let volume = weightExercises.reduce(0.0) { total, exercise in
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
        var bestByName: [String: (weight: Double, reps: Int)] = [:]
        var items: [PRItem] = []
        let sessions = filteredSessions.sorted { $0.date < $1.date }
        for session in sessions {
            for exercise in session.mergedExercises() where exercise.type == .weights {
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = name.lowercased()
                let bestSegment = exercise.allSegments.max { $0.weightKg < $1.weightKg }
                guard let bestSegment else { continue }
                let currentBest = bestByName[key] ?? (weight: 0, reps: 0)
                let isBetterWeight = bestSegment.weightKg > currentBest.weight
                let isSameWeightMoreReps = abs(bestSegment.weightKg - currentBest.weight) < 0.0001 && bestSegment.reps > currentBest.reps
                if isBetterWeight || isSameWeightMoreReps {
                    bestByName[key] = (weight: bestSegment.weightKg, reps: bestSegment.reps)
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
