import SwiftUI

struct TodaysNotesEntryView: View {
    private struct BriefingNoteItem: Identifiable, Equatable {
        let id: String
        let label: String
        let text: String
    }

    private struct BriefingMetric: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let value: String
    }

    private struct BriefingTrendPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    @ObservedObject var store: WorkoutStore
    let workoutDate: Date
    let usesManualTimes: Bool
    @Binding var draft: ExerciseDraft
    let onSave: (ExerciseDraft) -> Void
    let onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var isKeyboardVisible = false
    @State private var didSave = false
    @State private var showSpotHud = false
    @State private var spotHudMessage = ""
    @State private var spotHudDismissWorkItem: DispatchWorkItem?
    @State private var showNotesPreviewPage = false
    @State private var hasPresentedNotesPreview = false
    @State private var didCancelExplicitly = false

    private var notesPreviewItems: [BriefingNoteItem] {
        var items: [BriefingNoteItem] = []
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let todays = draft.todaysNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTodays = trimmedName.isEmpty
            ? ""
            : (store.latestExerciseRecord(named: trimmedName)?.exercise.todaysNotes?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        let todaysToShow = !todays.isEmpty ? todays : fallbackTodays
        let tips = draft.exerciseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTips = trimmedName.isEmpty
            ? ""
            : store.exerciseNote(for: trimmedName).trimmingCharacters(in: .whitespacesAndNewlines)
        let tipsToShow = !tips.isEmpty ? tips : fallbackTips
        if !todaysToShow.isEmpty {
            items.append(BriefingNoteItem(id: "today", label: "Today's Note", text: todaysToShow))
        }
        if !tipsToShow.isEmpty {
            items.append(BriefingNoteItem(id: "tips", label: "Exercise Tip", text: tipsToShow))
        }
        return items
    }

    private var normalizedDraftName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var historyRecords: [(date: Date, exercise: WorkoutExercise)] {
        guard !normalizedDraftName.isEmpty else { return [] }
        return store.sessions
            .flatMap { session in
                session.exercises.compactMap { exercise -> (date: Date, exercise: WorkoutExercise)? in
                    let exerciseName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard exerciseName == normalizedDraftName, exercise.type == draft.type else { return nil }
                    return (exercise.loggedAt ?? session.date, exercise)
                }
            }
            .sorted { $0.date < $1.date }
    }

    private var latestRecord: (date: Date, exercise: WorkoutExercise)? {
        historyRecords.last
    }

    private var briefingMetrics: [BriefingMetric] {
        guard let latest = latestRecord else { return [] }
        let exercise = latest.exercise
        switch exercise.type {
        case .weights:
            let segments = exercise.allSegments
            guard let topSegment = segments.max(by: {
                if $0.weightKg == $1.weightKg { return $0.reps < $1.reps }
                return $0.weightKg < $1.weightKg
            }) else { return [] }
            let totalVolumeKg = segments.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
            let totalVolume = store.defaultWeightUnit == .lb ? totalVolumeKg * 2.20462262 : totalVolumeKg
            return [
                BriefingMetric(label: "Top Set", value: "\(formattedWeight(topSegment.weightKg, unit: store.defaultWeightUnit)) x \(topSegment.reps)"),
                BriefingMetric(label: "Sets", value: "\(exercise.sets.count)"),
                BriefingMetric(label: "Volume", value: String(format: "%.0f %@", totalVolume, store.defaultWeightUnit.label))
            ]
        case .cardio:
            let duration = exercise.durationSeconds ?? 0
            let calories = exercise.calories ?? 0
            return [
                BriefingMetric(label: "Duration", value: duration > 0 ? durationLabel(duration) : "--"),
                BriefingMetric(label: "Calories", value: calories > 0 ? "\(calories) cal" : "--")
            ]
        case .isometric:
            let totalSeconds: Int
            if exercise.isometricSets.isEmpty {
                totalSeconds = exercise.durationSeconds ?? 0
            } else {
                totalSeconds = exercise.isometricSets.reduce(0) { $0 + $1.durationSeconds }
            }
            let maxWeight = exercise.isometricSets.isEmpty
                ? (exercise.isometricWeightKg ?? 0)
                : (exercise.isometricSets.map(\.weightKg).max() ?? 0)
            let setCount = exercise.isometricSets.isEmpty ? (totalSeconds > 0 ? 1 : 0) : exercise.isometricSets.count
            return [
                BriefingMetric(label: "Hold", value: totalSeconds > 0 ? durationLabel(totalSeconds) : "--"),
                BriefingMetric(label: "Peak Weight", value: maxWeight > 0 ? formattedWeight(maxWeight, unit: store.defaultWeightUnit) : "Bodyweight"),
                BriefingMetric(label: "Sets", value: "\(setCount)")
            ]
        }
    }

    private var trendPoints: [BriefingTrendPoint] {
        let records = Array(historyRecords.suffix(8))
        let points: [BriefingTrendPoint] = records.compactMap { record in
            let exercise = record.exercise
            switch exercise.type {
            case .weights:
                guard let topSegment = exercise.allSegments.max(by: {
                    if $0.weightKg == $1.weightKg { return $0.reps < $1.reps }
                    return $0.weightKg < $1.weightKg
                }) else { return nil }
                let weight = store.defaultWeightUnit == .lb ? topSegment.weightKg * 2.20462262 : topSegment.weightKg
                return BriefingTrendPoint(date: record.date, value: weight)
            case .cardio:
                let minutes = Double(exercise.durationSeconds ?? 0) / 60.0
                guard minutes > 0 else { return nil }
                return BriefingTrendPoint(date: record.date, value: minutes)
            case .isometric:
                let totalSeconds: Int
                if exercise.isometricSets.isEmpty {
                    totalSeconds = exercise.durationSeconds ?? 0
                } else {
                    totalSeconds = exercise.isometricSets.reduce(0) { $0 + $1.durationSeconds }
                }
                let minutes = Double(totalSeconds) / 60.0
                guard minutes > 0 else { return nil }
                return BriefingTrendPoint(date: record.date, value: minutes)
            }
        }
        return points
    }

    private var trendTitle: String {
        switch draft.type {
        case .weights:
            return "Top Set Trend"
        case .cardio:
            return "Duration Trend"
        case .isometric:
            return "Hold Time Trend"
        }
    }

    private var trendUnit: String {
        switch draft.type {
        case .weights:
            return store.defaultWeightUnit.label
        case .cardio, .isometric:
            return "min"
        }
    }

    private var hasBriefingContent: Bool {
        !notesPreviewItems.isEmpty || !briefingMetrics.isEmpty || trendPoints.count >= 2
    }

    init(
        store: WorkoutStore,
        workoutDate: Date,
        usesManualTimes: Bool,
        draft: Binding<ExerciseDraft>,
        onSave: @escaping (ExerciseDraft) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.store = store
        self.workoutDate = workoutDate
        self.usesManualTimes = usesManualTimes
        self._draft = draft
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var validation: (exercise: WorkoutExercise?, hasInvalid: Bool) {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch draft.type {
        case .weights:
            var setModels: [WorkoutSet] = []
            var hasPartialSet = false

            for setDraft in draft.sets {
                var segmentModels: [WorkoutSetSegment] = []
                var hasPartialSegment = false

                for segment in setDraft.segments {
                    let weightText = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsText = segment.reps.trimmingCharacters(in: .whitespacesAndNewlines)

                    if weightText.isEmpty && repsText.isEmpty {
                        continue
                    }

                    if weightText.isEmpty || repsText.isEmpty {
                        hasPartialSegment = true
                        continue
                    }

                    guard let inputValue = Double(weightText),
                          let repsValue = Int(repsText) else {
                        hasPartialSegment = true
                        continue
                    }

                    let weightValue = draft.weightUnit == .lb ? inputValue * 0.45359237 : inputValue
                    guard repsValue > 0, weightValue >= 0 else {
                        hasPartialSegment = true
                        continue
                    }

                    segmentModels.append(
                        WorkoutSetSegment(
                            id: UUID(),
                            weightKg: weightValue,
                            reps: repsValue,
                            isSpotted: segment.isSpotted
                        )
                    )
                }

                if hasPartialSegment {
                    hasPartialSet = true
                    continue
                }

                guard !segmentModels.isEmpty else {
                    continue
                }

                setModels.append(WorkoutSet(id: setDraft.id, segments: segmentModels))
            }

            let hasAnySetInput = draft.sets.contains { set in
                set.segments.contains {
                    !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }

            if hasPartialSet {
                return (nil, true)
            }

            if name.isEmpty && hasAnySetInput {
                return (nil, true)
            }

            guard !setModels.isEmpty else {
                return (nil, false)
            }

            guard !name.isEmpty else {
                return (nil, true)
            }

            return (
                WorkoutExercise(
                    id: draft.entryId ?? UUID(),
                    name: name,
                    type: .weights,
                    sets: setModels,
                    durationSeconds: nil,
                    calories: nil,
                    isometricWeightKg: nil,
                    isometricSets: [],
                    loggedAt: draft.loggedAt,
                    todaysNotes: draft.todaysNotes
                ),
                false
            )
        case .cardio:
            let durationTrimmed = draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            let caloriesTrimmed = draft.calories.trimmingCharacters(in: .whitespacesAndNewlines)
            let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
            let caloriesValue = caloriesTrimmed.isEmpty ? nil : Int(caloriesTrimmed)
            let hasMetrics = durationValue != nil || caloriesValue != nil

            if name.isEmpty && (!durationTrimmed.isEmpty || !caloriesTrimmed.isEmpty) {
                return (nil, true)
            }

            if !durationTrimmed.isEmpty && durationValue == nil {
                return (nil, true)
            }
            if let durationValue, durationValue <= 0 { return (nil, true) }
            if let caloriesValue, caloriesValue <= 0 { return (nil, true) }

            if name.isEmpty && !hasMetrics {
                return (nil, false)
            }

            guard hasMetrics, !name.isEmpty else {
                return (nil, true)
            }

            return (
                WorkoutExercise(
                    id: draft.entryId ?? UUID(),
                    name: name,
                    type: .cardio,
                    sets: [],
                    durationSeconds: durationValue,
                    calories: caloriesValue,
                    isometricWeightKg: nil,
                    isometricSets: [],
                    loggedAt: draft.loggedAt,
                    todaysNotes: draft.todaysNotes
                ),
                false
            )
        case .isometric:
            var isometricModels: [IsometricSet] = []
            var hasAnyInput = false

            for setDraft in draft.isometricSets {
                let durationTrimmed = setDraft.duration.trimmingCharacters(in: .whitespacesAndNewlines)
                let weightTrimmed = setDraft.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
                let weightValue = weightTrimmed.isEmpty ? nil : Double(weightTrimmed)

                if durationTrimmed.isEmpty && weightTrimmed.isEmpty {
                    continue
                }

                hasAnyInput = true

                if durationValue == nil || durationValue == 0 { return (nil, true) }
                if let weightValue, weightValue < 0 { return (nil, true) }

                let kgValue: Double = {
                    guard let weightValue, weightValue > 0 else { return 0 }
                    return draft.weightUnit == .lb ? weightValue * 0.45359237 : weightValue
                }()

                isometricModels.append(
                    IsometricSet(
                        id: setDraft.id,
                        durationSeconds: durationValue ?? 0,
                        weightKg: kgValue
                    )
                )
            }

            if name.isEmpty && hasAnyInput { return (nil, true) }
            guard !isometricModels.isEmpty else { return (nil, false) }
            guard !name.isEmpty else { return (nil, true) }

            let totalSeconds = isometricModels.reduce(0) { $0 + $1.durationSeconds }
            let maxWeight = isometricModels.map(\.weightKg).max() ?? 0

            return (
                WorkoutExercise(
                    id: draft.entryId ?? UUID(),
                    name: name,
                    type: .isometric,
                    sets: [],
                    durationSeconds: totalSeconds > 0 ? totalSeconds : nil,
                    calories: nil,
                    isometricWeightKg: maxWeight > 0 ? maxWeight : nil,
                    isometricSets: isometricModels,
                    loggedAt: draft.loggedAt,
                    todaysNotes: draft.todaysNotes
                ),
                false
            )
        }
    }

    private var canSave: Bool {
        validation.exercise != nil && !validation.hasInvalid
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(draft.name.isEmpty ? "Exercise" : draft.name)
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))

                    ExerciseEditorRow(
                        draft: $draft,
                        suggestions: store.exerciseNameCatalog(),
                        suggestionDetail: store.muscleGroupLabel(for:),
                        showsMetrics: true,
                        knownType: draft.isTypeLocked ? draft.type : store.exerciseType(for: draft.name),
                        isNameLocked: draft.isNameLocked,
                        isDropSetsEnabled: store.isDropSetsEnabled,
                        isExerciseNotesEnabled: store.isExerciseNotesEnabled,
                        isTodaysNotesEnabled: store.isTodaysNotesEnabled,
                        isSpottingEnabled: store.isSpottingEnabled,
                        latestExerciseForName: { store.latestExerciseRecord(named: $0)?.exercise },
                        exerciseNoteForName: store.exerciseNote(for:),
                        onDelete: nil,
                        onMoveUp: nil,
                        onMoveDown: nil,
                        onSpotHud: { isSpotted in
                            presentSpotHud(message: isSpotted ? "Spotted set" : "Spot removed")
                        }
                    )
                }
                .padding(24)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .top) {
            if showSpotHud {
                Text(spotHudMessage)
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themeColor(.night))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(themeColor(.sand))
                    )
                    .shadow(color: themeColor(.night).opacity(0.2), radius: 6, x: 0, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 12)
            }
        }
        .overlay {
            if showNotesPreviewPage {
                notesPreviewOverlay
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    .zIndex(2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                VStack(spacing: 10) {
                    Button {
                        if usesManualTimes == false, draft.loggedAt == nil {
                            draft.loggedAt = combineDate(workoutDate, time: Date())
                        }
                        didSave = true
                        onSave(draft)
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text("Save Exercise")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night).opacity(canSave ? 1 : 0.55))
                            .background(themeColor(.sand))
                            .clipShape(Capsule())
                    }
                    .disabled(!canSave)

                    Button {
                        didCancelExplicitly = true
                        onCancel?()
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.sand))
                            .background(
                                Capsule()
                                    .fill(themeColor(.night))
                                    .overlay(
                                        Capsule()
                                            .stroke(themeColor(.sand).opacity(0.6), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [
                            themeColor(.night).opacity(0.0),
                            themeColor(.night).opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onAppear {
            scheduleNotesPreviewPresentation()
        }
        .onChange(of: draft.name) { _, _ in
            maybePresentNotesPreview()
        }
        .onChange(of: draft.type) { _, _ in
            maybePresentNotesPreview()
        }
        .onDisappear {
            if !didSave && !didCancelExplicitly && !showNotesPreviewPage {
                onCancel?()
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showNotesPreviewPage)
    }

    private func presentSpotHud(message: String) {
        spotHudMessage = message
        Haptics.selection()
        spotHudDismissWorkItem?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            showSpotHud = true
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.2)) {
                showSpotHud = false
            }
        }
        spotHudDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    private func scheduleNotesPreviewPresentation() {
        maybePresentNotesPreview()
        // When this sheet is auto-opened (Quick Start/Explore), a tiny defer avoids
        // presentation races with the parent sheet animation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            maybePresentNotesPreview()
        }
    }

    private func maybePresentNotesPreview() {
        guard !hasPresentedNotesPreview else { return }
        guard hasBriefingContent else { return }
        hasPresentedNotesPreview = true
        showNotesPreviewPage = true
    }

    private var notesPreviewOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themedPrimaryText())
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(themeColor(.sand).opacity(0.2))
                        )
                    Text("Workout Briefing")
                        .font(.custom("Avenir Next", size: 22))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedPrimaryText())
                }
                .padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if !notesPreviewItems.isEmpty {
                            briefingSection(title: "Notes") {
                                ForEach(notesPreviewItems) { item in
                                    notePreviewRow(item)
                                }
                            }
                        }

                        if let latestRecord, !briefingMetrics.isEmpty {
                            briefingSection(title: "Last Session Snapshot") {
                                Text("\(relativeLabel(for: latestRecord.date)) • \(latestRecord.date.formatted(date: .omitted, time: .shortened))")
                                    .font(.custom("Avenir Next", size: 11))
                                    .foregroundStyle(themedSecondaryText())
                                    .padding(.bottom, 2)
                                ForEach(briefingMetrics) { metric in
                                    HStack {
                                        Text(metric.label)
                                            .font(.custom("Avenir Next", size: 13))
                                            .foregroundStyle(themedSecondaryText())
                                        Spacer()
                                        Text(metric.value)
                                            .font(.custom("Avenir Next", size: 14))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(themedPrimaryText())
                                    }
                                }
                            }
                        }

                        if trendPoints.count >= 2 {
                            briefingSection(title: trendTitle) {
                                briefingSparkline
                                    .frame(height: 66)
                                    .padding(.top, 2)
                                if let latest = trendPoints.last?.value {
                                    Text(String(format: "Latest: %.1f %@", latest, trendUnit))
                                        .font(.custom("Avenir Next", size: 11))
                                        .foregroundStyle(themedSecondaryText())
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .safeAreaInset(edge: .bottom) {
                Button {
                    Haptics.selection()
                    showNotesPreviewPage = false
                } label: {
                    Text("Continue")
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(themeColor(.night))
                        .background(themeColor(.sand))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [
                            themeColor(.night).opacity(0.0),
                            themeColor(.night).opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .onTapGesture {
            // Keep the notes gate mandatory until Continue.
        }
    }

    @ViewBuilder
    private func briefingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(themedSecondaryText())
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor(.card).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeColor(.sand).opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var briefingSparkline: some View {
        GeometryReader { geo in
            let points = trendPoints
            let values = points.map(\.value)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 0.001)
            let width = max(geo.size.width, 1)
            let height = max(geo.size.height, 1)

            ZStack {
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = points.count == 1
                            ? width / 2
                            : width * CGFloat(index) / CGFloat(points.count - 1)
                        let normalized = (point.value - minValue) / range
                        let y = height * (1 - CGFloat(normalized))
                        let location = CGPoint(x: x, y: y)
                        if index == 0 {
                            path.move(to: location)
                        } else {
                            path.addLine(to: location)
                        }
                    }
                }
                .stroke(themeColor(.sand), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    let x = points.count == 1
                        ? width / 2
                        : width * CGFloat(points.count - 1) / CGFloat(points.count - 1)
                    let normalized = (last.value - minValue) / range
                    let y = height * (1 - CGFloat(normalized))
                    Circle()
                        .fill(themeColor(.sand))
                        .frame(width: 7, height: 7)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private func notePreviewRow(_ item: BriefingNoteItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: previewIcon(for: item))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themedSecondaryText())
                .frame(width: 20, height: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.label)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(themedSecondaryText())
                Text(item.text)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(themedPrimaryText())
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor(.card).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeColor(.sand).opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func previewIcon(for item: BriefingNoteItem) -> String {
        item.id == "today" ? "square.and.pencil" : "note.text"
    }

    private func parseDurationSeconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { return nil }
        if cleaned.contains(":") {
            let parts = cleaned.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]),
                  minutes >= 0,
                  seconds >= 0,
                  seconds < 60 else {
                return nil
            }
            return minutes * 60 + seconds
        }
        guard let minutes = Int(cleaned), minutes >= 0 else { return nil }
        return minutes * 60
    }
}
