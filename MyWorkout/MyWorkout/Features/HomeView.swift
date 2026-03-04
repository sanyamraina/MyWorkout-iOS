import SwiftUI
import UIKit
import CoreImage

struct HomeView: View {
    @ObservedObject var store: WorkoutStore
    @State private var showingAdd = false
    @State private var showingTemplateAdd = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var editingSession: WorkoutSession?
    @State private var draftFromTemplate: WorkoutTemplate?
    @State private var templateFlow: WorkoutTemplate?
    @State private var showTemplateImport = false
    @State private var templateImportText = ""
    @State private var showTemplateImportError = false
    @State private var templateImportErrorMessage = ""
    @State private var showTemplateShareNotice = false
    @State private var showTemplateImportSuccess = false
    @State private var templateSharePayload: TemplateShareSheetPayload?
    @State private var showTemplateScanner = false
    @State private var showTemplatePhotoPicker = false
    @State private var pendingDeleteTemplate: WorkoutTemplate?
    @State private var showDeleteTemplateConfirm = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    header
                        .padding(.top, DesignSystem.Spacing.huge)
                        .padding(.horizontal, DesignSystem.Spacing.xxl)
                        .padding(.bottom, DesignSystem.Spacing.sm)

                    stats
                        .padding(.horizontal, DesignSystem.Spacing.xxl)
                        .padding(.bottom, DesignSystem.Spacing.xl)

                    templatesSection
                        .padding(.horizontal, DesignSystem.Spacing.xxl)
                        .padding(.bottom, DesignSystem.Spacing.xl)

                    exercisesSection
                        .padding(.horizontal, DesignSystem.Spacing.xxl)
                        .padding(.bottom, DesignSystem.Spacing.xxxl)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            addButton
        }
        .sheet(isPresented: $showingAdd) {
            LiveWorkoutView(store: store, template: nil)
        }
        .sheet(item: $templateFlow) { template in
            TemplateFlowView(store: store, template: template)
        }
        .sheet(item: $draftFromTemplate) { template in
            LiveWorkoutView(store: store, template: template)
        }
        .sheet(item: $editingSession) { session in
            AddWorkoutView(store: store, template: nil, session: session)
        }
        .sheet(isPresented: $showingTemplateAdd) {
            AddTemplateView(store: store)
        }
        .sheet(item: $editingTemplate) { template in
            EditTemplateView(store: store, template: template)
                .id(template.id)
                .presentationBackground(
                    LinearGradient(
                        colors: [themeColor(.night), themeColor(.coal)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .sheet(item: $templateSharePayload) { payload in
            TemplateShareSheet(
                code: payload.code,
                templateName: payload.templateName,
                onCopy: {
                    UIPasteboard.general.string = payload.code
                    Haptics.success()
                    showTemplateShareNotice = true
                }
            )
            .id(payload.id)
        }
        .sheet(isPresented: $showTemplateScanner) {
            TemplateQRScanner(
                onScan: { code in
                    showTemplateScanner = false
                    do {
                        try store.importTemplate(from: code)
                        Haptics.success()
                        showTemplateImportSuccess = true
                    } catch {
                        Haptics.error()
                        templateImportErrorMessage = "Invalid template code."
                        showTemplateImportError = true
                    }
                },
                onImportPhoto: {
                    showTemplateScanner = false
                    showTemplatePhotoPicker = true
                }
            )
        }
        .sheet(isPresented: $showTemplatePhotoPicker) {
            PhotoPicker(
                onImage: { image in
                    showTemplatePhotoPicker = false
                    handleTemplateImageImport(image)
                },
                onError: { message in
                    showTemplatePhotoPicker = false
                    Haptics.error()
                    templateImportErrorMessage = message
                    showTemplateImportError = true
                }
            )
        }
        .alert("Import Template", isPresented: $showTemplateImport) {
            TextField("Paste template code", text: $templateImportText)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {}
            Button("Import") {
                do {
                    try store.importTemplate(from: templateImportText)
                    Haptics.success()
                    templateImportText = ""
                    showTemplateImportSuccess = true
                } catch {
                    Haptics.error()
                    templateImportErrorMessage = "Invalid template code."
                    showTemplateImportError = true
                }
            }
        } message: {
            Text("Paste a template code to import it.")
        }
        .alert("Import Failed", isPresented: $showTemplateImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(templateImportErrorMessage)
        }
        .alert("Template Ready to Share", isPresented: $showTemplateShareNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Template code copied to the clipboard.")
        }
        .alert("Template Imported", isPresented: $showTemplateImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Template added to your list.")
        }
        .alert("Delete Template?", isPresented: $showDeleteTemplateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let template = pendingDeleteTemplate {
                    Haptics.warning()
                    store.removeTemplate(template)
                }
                pendingDeleteTemplate = nil
            }
        } message: {
            Text("This will permanently remove the template.")
        }
    }

    private func handleTemplateImageImport(_ image: UIImage) {
        guard let code = extractQRCode(from: image) else {
            Haptics.error()
            templateImportErrorMessage = "No QR code found in that image."
            showTemplateImportError = true
            return
        }
        do {
            try store.importTemplate(from: code)
            Haptics.success()
            showTemplateImportSuccess = true
        } catch {
            Haptics.error()
            templateImportErrorMessage = "Invalid template code."
            showTemplateImportError = true
        }
    }

    private func extractQRCode(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) ?? []
        return features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: DesignSystem.FrameSize.logoSize, height: DesignSystem.FrameSize.logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous))
                Text("MyWorkout")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.title1))
                    .fontWeight(.semibold)
                    .foregroundStyle(themedPrimaryText())
                Spacer()
            }
            Text("Track what you lift, keep it simple.")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                .foregroundStyle(themedSecondaryText())
        }
    }

    private var stats: some View {
        let statsData = calculateStats()
        return HStack(spacing: DesignSystem.Spacing.md) {
            StatPager(
                pages: [
                    StatPage(title: "Current Streak", value: "\(statsData.currentStreak)"),
                    StatPage(title: "Max Streak", value: "\(statsData.maxStreak)")
                ]
            )
            StatPager(
                pages: [
                    StatPage(title: "Today's Sets", value: "\(statsData.todaySets)"),
                    StatPage(title: "Total Sets", value: "\(statsData.totalSets)")
                ]
            )
        }
    }
    
    private func calculateStats() -> (currentStreak: Int, maxStreak: Int, totalSets: Int, todaySets: Int) {
        let currentStreak = currentWorkoutStreak()
        let maxStreak = maxWorkoutStreak()
        let totalSets = store.sessions.reduce(0) { total, session in
            total + session.mergedExercises().filter { $0.type == .weights }.reduce(0) { $0 + $1.sets.count }
        }
        let todaySets = store.sessions
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { total, session in
                total + session.mergedExercises().filter { $0.type == .weights }.reduce(0) { $0 + $1.sets.count }
            }
        return (currentStreak, maxStreak, totalSets, todaySets)
    }

    private func workoutDays() -> [Date] {
        let calendar = Calendar.current
        let unique = Set(store.sessions.map { calendar.startOfDay(for: $0.date) })
        return unique.sorted()
    }

    private func currentWorkoutStreak() -> Int {
        let calendar = Calendar.current
        let days = Set(workoutDays())
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let startDay: Date
        if days.contains(today) {
            startDay = today
        } else if let yesterday, days.contains(yesterday) {
            startDay = yesterday
        } else {
            return 0
        }
        var count = 0
        var cursor = startDay
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private func maxWorkoutStreak() -> Int {
        let calendar = Calendar.current
        let days = workoutDays()
        guard let first = days.first else { return 0 }
        var maxStreak = 1
        var currentStreak = 1
        var previous = first
        for day in days.dropFirst() {
            let diff = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            if diff == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            if currentStreak > maxStreak {
                maxStreak = currentStreak
            }
            previous = day
        }
        return maxStreak
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("Templates")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                    .fontWeight(.semibold)
                    .foregroundStyle(themedPrimaryText())
                Spacer()
                Menu {
                    Button {
                        Haptics.selection()
                        showingTemplateAdd = true
                    } label: {
                        Label("New Template", systemImage: "plus")
                    }
                    Button {
                        Haptics.selection()
                        templateImportText = ""
                        showTemplateImport = true
                    } label: {
                        Label("Import Template", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        Haptics.selection()
                        showTemplateScanner = true
                    } label: {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.custom("Avenir Next", size: DesignSystem.FontSize.subheadline))
                        .foregroundStyle(themedPrimaryText())
                }
                .accessibilityLabel("Template options")
                .accessibilityHint("Add new template, import template, or scan QR code")
            }

            if store.templates.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Create a template to reuse your go-to workouts.")
                        .font(.custom("Avenir Next", size: DesignSystem.FontSize.body))
                        .foregroundStyle(themedSecondaryText())
                }
                .padding(DesignSystem.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground(cornerRadius: DesignSystem.CornerRadius.xxl, opacity: 0, hasStroke: false)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(store.templates) { template in
                            TemplateCard(
                                template: template,
                                onUse: {
                                    Haptics.selection()
                                    templateFlow = template
                                },
                                onShare: {
                                    do {
                                        let code = try store.shareString(for: template)
                                        Haptics.selection()
                                        templateSharePayload = TemplateShareSheetPayload(
                                            code: code,
                                            templateName: template.title
                                        )
                                    } catch {
                                        Haptics.error()
                                        templateImportErrorMessage = "Unable to share template."
                                        showTemplateImportError = true
                                    }
                                },
                                onEdit: {
                                    Haptics.selection()
                                    editingTemplate = template
                                },
                                onDelete: {
                                    Haptics.selection()
                                    pendingDeleteTemplate = template
                                    showDeleteTemplateConfirm = true
                                }
                            )
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Quick Start")
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())

            let recentExercises = recentWorkoutExercises(limit: 8)
            if recentExercises.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("No exercises yet. Add a workout to start your log.")
                        .font(.custom("Avenir Next", size: DesignSystem.FontSize.body))
                        .foregroundStyle(themedSecondaryText())
                }
                .padding(DesignSystem.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground(cornerRadius: DesignSystem.CornerRadius.xxl, opacity: 0, hasStroke: false)
            } else {
                ForEach(recentExercises, id: \.self) { name in
                    Button {
                        startQuickWorkout(for: name)
                    } label: {
                        ExerciseHistoryCard(
                            name: name,
                            record: store.latestExerciseRecord(named: name),
                            weightUnit: store.defaultWeightUnit
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func startQuickWorkout(for name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        Haptics.selection()
        let type = store.latestExerciseRecord(named: trimmedName)?.exercise.type ?? .weights
        draftFromTemplate = WorkoutTemplate(
            id: UUID(),
            title: "Quick Start",
            exercises: [
                TemplateExercise(
                    id: UUID(),
                    name: trimmedName,
                    type: type,
                    weightKg: nil,
                    sets: nil,
                    repsPerSet: nil
                )
            ]
        )
    }

    private func recentWorkoutExercises(limit: Int) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for session in store.sessions.sorted(by: { $0.date > $1.date }) {
            for exercise in session.mergedExercises() {
                let trimmed = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = trimmed.lowercased()
                guard !trimmed.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                ordered.append(trimmed)
                if ordered.count >= limit {
                    return ordered
                }
            }
        }
        return ordered
    }

    private var addButton: some View {
        Button {
            Haptics.primaryAction()
            showingAdd = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Workout")
            }
            .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
            .padding(.vertical, DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity)
            .foregroundStyle(themedAccentForeground())
            .background(themeColor(.sand))
            .clipShape(Capsule())
            .padding(.horizontal, DesignSystem.Spacing.xxxl)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .accessibilityLabel("Add new workout")
        .accessibilityHint("Opens the workout creation screen")
        .background(themeColor(.night).opacity(0.001))
    }
}

struct ExerciseHistoryCard: View {
    let name: String
    let record: (exercise: WorkoutExercise, date: Date)?
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(name)
                .font(.custom("Avenir Next", size: DesignSystem.FontSize.headline))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())

            if let record {
                Text("Last used \(record.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.caption))
                    .foregroundStyle(themedSecondaryText())

                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(tags(for: record.exercise), id: \.self) { tag in
                        TagView(text: tag)
                    }
                }
            } else {
                Text("No logged workout yet")
                    .font(.custom("Avenir Next", size: DesignSystem.FontSize.caption))
                    .foregroundStyle(themedSecondaryText())
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: DesignSystem.CornerRadius.xxl)
    }

    private func tags(for exercise: WorkoutExercise) -> [String] {
        switch exercise.type {
        case .weights:
            let setCount = exercise.sets.count
            let maxWeight = exercise.allSegments.map(\.weightKg).max() ?? 0
            let maxReps = exercise.allSegments.map(\.reps).max() ?? 0
            let isBodyweight = !exercise.sets.isEmpty && exercise.allSegments.allSatisfy { $0.weightKg == 0 }
            var tags = ["\(setCount) sets"]
            if setCount > 0 {
                if isBodyweight {
                    tags.append("Bodyweight")
                } else {
                    tags.append("Max \(formattedWeight(maxWeight, unit: weightUnit))")
                }
                tags.append("Max \(maxReps) reps")
            }
            return tags
        case .cardio:
            var tags: [String] = []
            if let duration = exercise.durationSeconds, duration > 0 {
                tags.append(durationLabel(duration))
            }
            if let calories = exercise.calories, calories > 0 {
                tags.append("\(calories) cal")
            }
            return tags.isEmpty ? ["Cardio"] : tags
        case .isometric:
            let setCount = exercise.isometricSets.count
            let totalSeconds = exercise.isometricSets.reduce(0) { $0 + $1.durationSeconds }
            let maxWeight = exercise.isometricSets.map(\.weightKg).max() ?? 0
            var tags = ["\(setCount) sets"]
            if totalSeconds > 0 {
                tags.append(durationLabel(totalSeconds))
            }
            if maxWeight > 0 {
                tags.append(formattedWeight(maxWeight, unit: weightUnit))
            } else {
                tags.append("Bodyweight")
            }
            return tags
        }
    }
}
