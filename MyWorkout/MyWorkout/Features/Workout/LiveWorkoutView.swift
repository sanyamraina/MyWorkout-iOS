import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage.CIFilterBuiltins

extension ExerciseDraft {
    var hasContent: Bool {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if !durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if !calories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if !exerciseNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if !todaysNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        for set in isometricSets {
            if !set.duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !set.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        for set in sets {
            for segment in set.segments {
                if !segment.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !segment.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
            }
        }
        return false
    }
}

private struct DraftSelection: Identifiable {
    let id: UUID
    let index: Int
}

struct LiveWorkoutView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var workoutDate = Date()
    @State private var usesManualTimes = false
    @State private var showsTimeEditor = false
    @State private var manualStartTime = Date()
    @State private var manualEndTime = Date()
    @State private var drafts: [ExerciseDraft] = []
    @State private var newDraftIds: Set<UUID> = []
    @State private var pendingTemplateDrafts: [ExerciseDraft] = []
    @State private var selectedDraft: DraftSelection?
    @State private var pendingDeleteIndex: Int?
    @State private var showDeleteConfirm = false
    @State private var hasLoadedDrafts = false
    @State private var hasUserEdits = false
    @State private var showResumePrompt = false
    @State private var pendingResumeDraft: LiveWorkoutDraft?
    @State private var autosaveWorkItem: DispatchWorkItem?

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
                    Text("New Workout")
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedPrimaryText())

                    scheduleCard

                    timelineSection
                }
                .padding(24)
                .padding(.bottom, 140)
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .sheet(item: $selectedDraft) { selection in
            if drafts.indices.contains(selection.index) {
                TodaysNotesEntryView(
                    store: store,
                    workoutDate: workoutDate,
                    usesManualTimes: usesManualTimes,
                    draft: $drafts[selection.index],
                    onSave: { updated in
                        handleDraftSave(updated, at: selection.index)
                    },
                    onCancel: {
                        handleDraftCancel(at: selection.index)
                    }
                )
            }
        }
        .alert("Delete Exercise?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                pendingDeleteIndex = nil
            }
            Button("Delete", role: .destructive) {
                if let index = pendingDeleteIndex, drafts.indices.contains(index) {
                    let id = drafts[index].id
                    drafts.remove(at: index)
                    newDraftIds.remove(id)
                    Haptics.warning()
                }
                pendingDeleteIndex = nil
            }
        } message: {
            Text("This will remove the exercise from this workout.")
        }
        .onAppear {
            guard !hasLoadedDrafts else { return }
            loadDraftIfNeeded()
        }
        .onChange(of: manualStartTime) { _, newValue in
            let minimumEnd = minimumWorkoutEndTime(start: newValue)
            if manualEndTime < minimumEnd {
                manualEndTime = minimumEnd
            }
            handleUserEdit()
        }
        .onChange(of: manualEndTime) { _, newValue in
            let minimumEnd = minimumWorkoutEndTime(start: manualStartTime)
            if newValue < minimumEnd {
                manualEndTime = minimumEnd
            }
            handleUserEdit()
        }
        .onChange(of: workoutDate) { _, _ in
            handleUserEdit()
        }
        .onChange(of: usesManualTimes) { _, _ in
            handleUserEdit()
        }
        .onChange(of: drafts) { _, _ in
            handleUserEdit()
        }
        .onChange(of: newDraftIds) { _, _ in
            handleUserEdit()
        }
        .onChange(of: pendingTemplateDrafts) { _, _ in
            handleUserEdit()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                persistDraftIfNeeded()
            }
        }
        .alert("Resume workout?", isPresented: $showResumePrompt) {
            Button("Discard", role: .destructive) {
                pendingResumeDraft = nil
                DraftStore.clear(.live)
                Haptics.warning()
                initializeFreshWorkout()
            }
            Button("Resume") {
                if let pendingResumeDraft {
                    applyResumeDraft(pendingResumeDraft)
                } else {
                    initializeFreshWorkout()
                }
                Haptics.selection()
                pendingResumeDraft = nil
            }
        } message: {
            Text("We saved your in-progress workout so you can pick up where you left off.")
        }
    }

    private func loadDraftIfNeeded() {
        if let saved = DraftStore.load(.live, as: LiveWorkoutDraft.self) {
            let currentTemplateId = template?.id
            let matchesTemplate = saved.templateId == currentTemplateId
                || (saved.templateId == nil && currentTemplateId == nil)
            guard matchesTemplate else {
                DraftStore.clear(.live)
                initializeFreshWorkout()
                return
            }
            pendingResumeDraft = saved
            showResumePrompt = true
            return
        }
        initializeFreshWorkout()
    }

    private func initializeFreshWorkout() {
        workoutDate = Date()
        usesManualTimes = false
        showsTimeEditor = false
        manualStartTime = Date()
        manualEndTime = Date()
        drafts = []
        newDraftIds = []
        pendingTemplateDrafts = []
        selectedDraft = nil
        if let template {
            pendingTemplateDrafts = store.resolvedDrafts(for: template)
            if drafts.isEmpty, !pendingTemplateDrafts.isEmpty {
                startNextExercise()
            }
        }
        markLoaded(hasEdits: false)
    }

    private func applyResumeDraft(_ draft: LiveWorkoutDraft) {
        workoutDate = draft.workoutDate
        usesManualTimes = draft.usesManualTimes
        manualStartTime = draft.manualStartTime
        manualEndTime = draft.manualEndTime
        drafts = draft.drafts
        newDraftIds = draft.newDraftIds
        pendingTemplateDrafts = draft.pendingTemplateDrafts
        if let selectedId = draft.selectedDraftId ?? newDraftIds.first,
           let index = drafts.firstIndex(where: { $0.id == selectedId }) {
            selectedDraft = DraftSelection(id: selectedId, index: index)
        }
        markLoaded(hasEdits: true)
    }

    private func markLoaded(hasEdits: Bool) {
        DispatchQueue.main.async {
            hasLoadedDrafts = true
            hasUserEdits = hasEdits
        }
    }

    private func handleUserEdit() {
        guard hasLoadedDrafts else { return }
        hasUserEdits = true
        scheduleAutosave()
    }

    private var shouldPersistDraft: Bool {
        guard hasUserEdits else { return false }
        let hasDraftContent = drafts.contains { $0.hasContent } || pendingTemplateDrafts.contains { $0.hasContent }
        let hasScheduleChange = usesManualTimes || !Calendar.current.isDateInToday(workoutDate)
        return hasDraftContent || hasScheduleChange
    }

    private func scheduleAutosave() {
        autosaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            persistDraftIfNeeded()
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    private func persistDraftIfNeeded() {
        guard hasLoadedDrafts else { return }
        guard shouldPersistDraft else {
            DraftStore.clear(.live)
            return
        }
        let payload = LiveWorkoutDraft(
            templateId: template?.id,
            workoutDate: workoutDate,
            usesManualTimes: usesManualTimes,
            manualStartTime: manualStartTime,
            manualEndTime: manualEndTime,
            drafts: drafts,
            newDraftIds: newDraftIds,
            pendingTemplateDrafts: pendingTemplateDrafts,
            selectedDraftId: selectedDraft?.id ?? newDraftIds.first
        )
        DraftStore.save(payload, kind: .live)
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themedSecondaryText())

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    if showsTimeEditor {
                        usesManualTimes = !shouldUseLiveSchedule()
                        showsTimeEditor = false
                    } else {
                        usesManualTimes = true
                        showsTimeEditor = true
                    }
                } label: {
                    HStack {
                        Text(scheduleSummary)
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(themedPrimaryText())
                        Spacer()
                        Image(systemName: showsTimeEditor ? "chevron.up" : "chevron.down")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(themedSecondaryText())
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(themeColor(.card))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                if showsTimeEditor {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Date")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(themedSecondaryText())
                        HStack {
                            Text(relativeLabel(for: workoutDate))
                                .font(.custom("Avenir Next", size: 16))
                                .foregroundStyle(themedPrimaryText())
                            Spacer()
                            DatePicker(
                                "",
                                selection: $workoutDate,
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(themeColor(.card))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Time")
                                .font(.custom("Avenir Next", size: 11))
                                .foregroundStyle(themedSecondaryText())
                            Spacer()
                            if isNowTime(manualStartTime) || isNowTime(manualEndTime) {
                                Text("Now")
                                    .font(.custom("Avenir Next", size: 11))
                                    .foregroundStyle(themedSecondaryText())
                            }
                        }
                        HStack {
                            Text("Start")
                                .font(.custom("Avenir Next", size: 13))
                                .foregroundStyle(themedSecondaryText())
                            Spacer()
                            DatePicker(
                                "",
                                selection: $manualStartTime,
                                displayedComponents: [.hourAndMinute]
                            )
                            .labelsHidden()
                        }

                        HStack {
                            Text("End")
                                .font(.custom("Avenir Next", size: 13))
                                .foregroundStyle(themedSecondaryText())
                            Spacer()
                            DatePicker(
                                "",
                                selection: $manualEndTime,
                                displayedComponents: [.hourAndMinute]
                            )
                            .labelsHidden()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(themeColor(.card))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )

                    if isFutureDay(workoutDate) {
                        Text("Future date")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(themedSecondaryText())
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(themedPrimaryText())

            if completedIndices.isEmpty {
                emptyCard(text: "No exercises yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(completedIndices, id: \.self) { index in
                        if let exercise = workoutExercise(from: drafts[index]) {
                            Button {
                                selectedDraft = DraftSelection(id: drafts[index].id, index: index)
                            } label: {
                                ExerciseTimelineCard(
                                    exercise: exercise,
                                    weightUnit: store.defaultWeightUnit,
                                    timestamp: displayTimestamp(for: index)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingDeleteIndex = index
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            Button {
                Haptics.selection()
                startNextExercise()
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Next Exercise")
                }
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themedPrimaryText())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button {
                finishWorkout()
            } label: {
                Text("Finish Workout")
                    .font(.custom("Avenir Next", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(themedAccentForeground())
                    .background(themeColor(.sand))
                    .clipShape(Capsule())
            }
            .disabled(completedIndices.isEmpty)
            .opacity(completedIndices.isEmpty ? 0.4 : 1)

            Button {
                DraftStore.clear(.live)
                Haptics.tap()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.custom("Avenir Next", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(themedPrimaryText())
                    .background(
                        Capsule()
                            .stroke(themedAccentMuted(), lineWidth: 1)
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

    private var completedIndices: [Int] {
        drafts.indices.filter { !newDraftIds.contains(drafts[$0].id) }
    }

    private func startNextExercise() {
        var draft: ExerciseDraft
        if !pendingTemplateDrafts.isEmpty {
            draft = pendingTemplateDrafts.removeFirst()
            draft.isNameLocked = true
            draft.isTypeLocked = true
        } else {
            draft = ExerciseDraft(weightUnit: store.defaultWeightUnit)
        }
        drafts.append(draft)
        newDraftIds.insert(draft.id)
        selectedDraft = DraftSelection(id: draft.id, index: drafts.count - 1)
    }

    private func handleDraftSave(_ draft: ExerciseDraft, at index: Int) {
        guard drafts.indices.contains(index) else { return }
        var updated = draft
        if updated.entryId == nil {
            updated.entryId = draft.id
        }
        drafts[index] = updated
        newDraftIds.remove(updated.id)
    }

    private func handleDraftCancel(at index: Int) {
        guard drafts.indices.contains(index) else { return }
        let draft = drafts[index]
        let draftId = draft.id
        guard newDraftIds.contains(draftId) else { return }
        drafts.remove(at: index)
        newDraftIds.remove(draftId)
        if draft.isNameLocked && completedIndices.isEmpty {
            DraftStore.clear(.live)
            dismiss()
        }
    }

    private func finishWorkout() {
        let exercises = completedIndices.compactMap { index -> WorkoutExercise? in
            guard let exercise = workoutExercise(from: drafts[index]) else { return nil }
            return exercise
        }
        guard !exercises.isEmpty else { return }
        let finalExercises: [WorkoutExercise]
        if usesManualTimes {
            let start = combineDate(workoutDate, time: manualStartTime)
            let end = combineDate(workoutDate, time: manualEndTime)
            let times = distributedTimes(count: exercises.count, start: start, end: end)
            finalExercises = exercises.enumerated().map { index, exercise in
                WorkoutExercise(
                    id: exercise.id,
                    name: exercise.name,
                    type: exercise.type,
                    sets: exercise.sets,
                    durationSeconds: exercise.durationSeconds,
                    calories: exercise.calories,
                    isometricWeightKg: exercise.isometricWeightKg,
                    isometricSets: exercise.isometricSets,
                    loggedAt: times[index],
                    todaysNotes: exercise.todaysNotes
                )
            }
        } else {
            let fallback = combineDate(workoutDate, time: Date())
            finalExercises = exercises.map { exercise in
                let loggedAt = exercise.loggedAt ?? fallback
                return WorkoutExercise(
                    id: exercise.id,
                    name: exercise.name,
                    type: exercise.type,
                    sets: exercise.sets,
                    durationSeconds: exercise.durationSeconds,
                    calories: exercise.calories,
                    isometricWeightKg: exercise.isometricWeightKg,
                    isometricSets: exercise.isometricSets,
                    loggedAt: loggedAt,
                    todaysNotes: exercise.todaysNotes
                )
            }
        }
        store.addSession(date: sessionDate(from: finalExercises), exercises: finalExercises)
        if store.isExerciseNotesEnabled {
            for index in completedIndices {
                let draft = drafts[index]
                let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                store.setExerciseNote(draft.exerciseNote, for: name)
            }
        }
        DraftStore.clear(.live)
        Haptics.success()
        dismiss()
    }

    private func sessionDate(from exercises: [WorkoutExercise]) -> Date {
        exercises.map(\.loggedAt).compactMap { $0 }.min() ?? workoutDate
    }

    private var scheduleSummary: String {
        if usesManualTimes == false || shouldUseLiveSchedule() {
            return "\(relativeLabel(for: Date())) · Now"
        }
        let dateLabel = relativeLabel(for: workoutDate)
        let seeStartLabel = manualStartTime.formatted(date: .omitted, time: .shortened)
        let endLabel = manualEndTime.formatted(date: .omitted, time: .shortened)
        return "\(dateLabel) · \(seeStartLabel) – \(endLabel)"
    }

    private func shouldUseLiveSchedule() -> Bool {
        Calendar.current.isDateInToday(workoutDate)
            && isNowTime(manualStartTime)
            && isNowTime(manualEndTime)
    }

    private func displayTimestamp(for index: Int) -> Date? {
        if usesManualTimes {
            let indices = completedIndices
            guard let position = indices.firstIndex(of: index) else { return nil }
            let start = combineDate(workoutDate, time: manualStartTime)
            let end = combineDate(workoutDate, time: manualEndTime)
            let times = distributedTimes(count: indices.count, start: start, end: end)
            return times[position]
        }
        return drafts[index].loggedAt
    }

    private func workoutExercise(from draft: ExerciseDraft) -> WorkoutExercise? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        switch draft.type {
        case .weights:
            var setModels: [WorkoutSet] = []

            for setDraft in draft.sets {
                var segmentModels: [WorkoutSetSegment] = []

                for segment in setDraft.segments {
                    let weightText = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                    let repsText = segment.reps.trimmingCharacters(in: .whitespacesAndNewlines)

                    if weightText.isEmpty && repsText.isEmpty {
                        continue
                    }

                    guard let inputValue = Double(weightText),
                          let repsValue = Int(repsText) else {
                        continue
                    }

                    let weightValue = draft.weightUnit == .lb ? inputValue * 0.45359237 : inputValue
                    guard repsValue > 0, weightValue >= 0 else {
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

                guard !segmentModels.isEmpty else {
                    continue
                }

                setModels.append(WorkoutSet(id: setDraft.id, segments: segmentModels))
            }

            guard !setModels.isEmpty else { return nil }

            return WorkoutExercise(
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
            )
        case .cardio:
            let durationTrimmed = draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            let caloriesTrimmed = draft.calories.trimmingCharacters(in: .whitespacesAndNewlines)
            let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
            let caloriesValue = caloriesTrimmed.isEmpty ? nil : Int(caloriesTrimmed)
            let hasMetrics = durationValue != nil || caloriesValue != nil

            guard hasMetrics else { return nil }

            return WorkoutExercise(
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
            )
        case .isometric:
            var isometricModels: [IsometricSet] = []
            for setDraft in draft.isometricSets {
                let durationTrimmed = setDraft.duration.trimmingCharacters(in: .whitespacesAndNewlines)
                let weightTrimmed = setDraft.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
                let weightValue = weightTrimmed.isEmpty ? nil : Double(weightTrimmed)

                if durationTrimmed.isEmpty && weightTrimmed.isEmpty {
                    continue
                }

                guard let durationValue, durationValue > 0 else { return nil }
                if let weightValue, weightValue < 0 { return nil }

                let kgValue: Double = {
                    guard let weightValue, weightValue > 0 else { return 0 }
                    return draft.weightUnit == .lb ? weightValue * 0.45359237 : weightValue
                }()

                isometricModels.append(
                    IsometricSet(
                        id: setDraft.id,
                        durationSeconds: durationValue,
                        weightKg: kgValue
                    )
                )
            }

            guard !isometricModels.isEmpty else { return nil }
            let totalSeconds = isometricModels.reduce(0) { $0 + $1.durationSeconds }
            let maxWeight = isometricModels.map(\.weightKg).max() ?? 0
            let weightValue = maxWeight > 0 ? maxWeight : nil

            return WorkoutExercise(
                id: draft.entryId ?? UUID(),
                name: name,
                type: .isometric,
                sets: [],
                durationSeconds: totalSeconds > 0 ? totalSeconds : nil,
                calories: nil,
                isometricWeightKg: weightValue,
                isometricSets: isometricModels,
                loggedAt: draft.loggedAt,
                todaysNotes: draft.todaysNotes
            )
        }
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

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.custom("Avenir Next", size: DesignSystem.FontSize.body))
            .foregroundStyle(themedSecondaryText())
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground(cornerRadius: DesignSystem.CornerRadius.lg, opacity: 1.0)
    }
}

struct ExerciseTimelineCard: View {
    let exercise: WorkoutExercise
    let weightUnit: WeightUnit
    let timestamp: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themedPrimaryText())
                    Text(exercise.type.label)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themedSecondaryText())
                }
                Spacer()
                if let timestamp {
                    Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themedSecondaryText())
                }
            }

            Text(detailLine)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(themedSecondaryText())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColor(.card).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var detailLine: String {
        switch exercise.type {
        case .weights:
            let setCount = exercise.sets.count
            if setCount == 0 {
                return "Weights"
            }
            let maxWeight = exercise.allSegments.map(\.weightKg).max() ?? 0
            let maxReps = exercise.allSegments.map(\.reps).max() ?? 0
            let weightLabel = maxWeight == 0 ? "Bodyweight" : "Max \(formattedWeight(maxWeight, unit: weightUnit))"
            return "\(setCount) sets · \(weightLabel) · Max \(maxReps) reps"
        case .cardio:
            var details: [String] = []
            if let duration = exercise.durationSeconds, duration > 0 {
                details.append(durationLabel(duration))
            }
            if let calories = exercise.calories, calories > 0 {
                details.append("\(calories) cal")
            }
            return details.isEmpty ? "Cardio" : details.joined(separator: " · ")
        case .isometric:
            let setCount = max(exercise.isometricSets.count, (exercise.durationSeconds ?? 0) > 0 ? 1 : 0)
            let totalSeconds = exercise.isometricSets.isEmpty
                ? (exercise.durationSeconds ?? 0)
                : exercise.isometricSets.reduce(0) { $0 + $1.durationSeconds }
            let maxWeight = exercise.isometricSets.isEmpty
                ? (exercise.isometricWeightKg ?? 0)
                : (exercise.isometricSets.map(\.weightKg).max() ?? 0)
            var details: [String] = ["\(setCount) sets"]
            if totalSeconds > 0 {
                details.append(durationLabel(totalSeconds))
            }
            if maxWeight > 0 {
                details.append(formattedWeight(maxWeight, unit: weightUnit))
            } else {
                details.append("Bodyweight")
            }
            return details.joined(separator: " · ")
        }
    }
}
