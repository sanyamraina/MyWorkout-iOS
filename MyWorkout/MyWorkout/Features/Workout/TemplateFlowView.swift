import SwiftUI

private struct TemplateExerciseSelection: Identifiable {
    let index: Int
    var id: Int { index }
}

struct TemplateFlowView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var workoutDate = Date()
    @State private var drafts: [ExerciseDraft] = []
    @State private var hasLoadedDrafts = false
    @State private var hasUserEdits = false
    @State private var templateExercises: [TemplateExercise] = []
    @State private var addToTemplateDraftIds: Set<UUID> = []
    @State private var newDraftIds: Set<UUID> = []
    @State private var selectedExercise: TemplateExerciseSelection?
    @State private var showFinishConfirm = false
    @State private var hasStarted = false
    @State private var showsTimeEditor = false
    @State private var usesManualTimes = false
    @State private var manualStartTime = Date()
    @State private var manualEndTime = Date()
    @State private var showAddExercisePrompt = false
    @State private var pendingDeleteIndex: Int?
    @State private var showDeleteTemplateConfirm = false
    @State private var showResumePrompt = false
    @State private var pendingResumeDraft: TemplateFlowDraft?
    @State private var autosaveWorkItem: DispatchWorkItem?

    private var completion: (exercises: [WorkoutExercise], hasInvalid: Bool) {
        var exercises: [WorkoutExercise] = []
        var hasInvalid = false
        for draft in drafts {
            let result = workoutExercise(from: draft)
            if result.hasInvalid {
                hasInvalid = true
            }
            if let exercise = result.exercise {
                exercises.append(exercise)
            }
        }
        return (exercises, hasInvalid)
    }

    private var canFinish: Bool {
        !completion.exercises.isEmpty && !completion.hasInvalid
    }

    var body: some View {
        let base = AnyView(templateFlowBase)
        let withChanges = AnyView(base
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
            .onChange(of: hasStarted) { _, _ in
                handleUserEdit()
            }
            .onChange(of: drafts) { _, _ in
                handleUserEdit()
            }
            .onChange(of: newDraftIds) { _, _ in
                handleUserEdit()
            }
            .onChange(of: addToTemplateDraftIds) { _, _ in
                handleUserEdit()
            }
            .onChange(of: templateExercises) { _, _ in
                handleUserEdit()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    persistDraftIfNeeded()
                }
            }
        )
        let withDialogs = AnyView(withChanges
            .sheet(item: $selectedExercise) { selection in
                if drafts.indices.contains(selection.index) {
                    let draftId = drafts[selection.index].id
                    TodaysNotesEntryView(
                        store: store,
                        workoutDate: workoutDate,
                        usesManualTimes: usesManualTimes,
                        draft: $drafts[selection.index],
                        onSave: handleTemplateSave,
                        onCancel: {
                            handleTemplateCancel(draftId: draftId)
                        }
                    )
                }
            }
            .confirmationDialog("Add Exercise", isPresented: $showAddExercisePrompt) {
                Button("Just this workout") {
                    Haptics.selection()
                    addExercise(addToTemplate: false)
                }
                Button("Add to template") {
                    Haptics.selection()
                    addExercise(addToTemplate: true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Should this exercise live only in this workout, or be saved back to the template?")
            }
            .alert("Remove from Template?", isPresented: $showDeleteTemplateConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Haptics.warning()
                    removeDraftFromTemplate()
                }
            } message: {
                Text("This will remove the exercise from the template and the current workout.")
            }
            .alert("Resume workout?", isPresented: $showResumePrompt) {
                Button("Discard", role: .destructive) {
                    pendingResumeDraft = nil
                    DraftStore.clear(.templateFlow)
                    Haptics.warning()
                    initializeFreshFlow()
                }
                Button("Resume") {
                    if let pendingResumeDraft {
                        applyResumeDraft(pendingResumeDraft)
                    } else {
                        initializeFreshFlow()
                    }
                    Haptics.selection()
                    pendingResumeDraft = nil
                }
            } message: {
                Text("We saved your in-progress workout so you can pick up where you left off.")
            }
            .alert("Finish Template?", isPresented: $showFinishConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Finish") {
                    let exercises = applyTimes(to: completion.exercises)
                    store.addSession(date: sessionDate(from: exercises), exercises: exercises)
                    store.incrementTemplateUsage(for: template)
                    if store.isExerciseNotesEnabled {
                        for draft in drafts {
                            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { continue }
                            store.setExerciseNote(draft.exerciseNote, for: name)
                        }
                    }
                    DraftStore.clear(.templateFlow)
                    Haptics.success()
                    dismiss()
                }
            } message: {
                Text("This will save the completed exercises as one workout session.")
            }
            .onAppear {
                guard !hasLoadedDrafts else { return }
                loadDraftIfNeeded()
            }
        )
        return withDialogs
    }

    private var templateFlowBase: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if hasStarted {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.title)
                                .font(.custom("Avenir Next", size: 28))
                                .fontWeight(.semibold)
                                .foregroundStyle(themeColor(.sand))
                            Text("\(completion.exercises.count) of \(drafts.count) completed")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                        }
                        .padding(.top, 8)
                        ProgressView(value: Double(completion.exercises.count), total: Double(max(drafts.count, 1)))
                            .tint(themeColor(.sand))
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    let pendingIndices = drafts.indices.filter { !isComplete(index: $0) }
                    let completedIndices = drafts.indices.filter { isComplete(index: $0) }

                    if !pendingIndices.isEmpty {
                        Section {
                            ForEach(pendingIndices, id: \.self) { index in
                                exerciseRow(for: index, isComplete: false)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text("Up Next")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                                .textCase(nil)
                        }
                    }

                    if !completedIndices.isEmpty {
                        Section {
                            ForEach(completedIndices, id: \.self) { index in
                                exerciseRow(for: index, isComplete: true)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text("Completed")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                                .textCase(nil)
                        }
                    }

                    Button {
                        Haptics.selection()
                        showAddExercisePrompt = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Exercise")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themeColor(.sand))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 24, trailing: 0))
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 24)
            } else {
                startScreen
            }
        }
        .safeAreaInset(edge: .bottom) {
            if hasStarted {
                VStack(spacing: 10) {
                    if completion.hasInvalid {
                        Text("Finish requires fixing incomplete exercise entries.")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(themeColor(.sand).opacity(0.7))
                    }
                    Button {
                        Haptics.primaryAction()
                        showFinishConfirm = true
                    } label: {
                        Text("Finish Template")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night).opacity(canFinish ? 1 : 0.55))
                            .background(themeColor(.sand))
                            .clipShape(Capsule())
                    }
                    .disabled(!canFinish)

                    Button {
                        DraftStore.clear(.templateFlow)
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
    }

    private func loadDraftIfNeeded() {
        if let saved = DraftStore.load(.templateFlow, as: TemplateFlowDraft.self),
           saved.templateId == template.id {
            pendingResumeDraft = saved
            showResumePrompt = true
            return
        }
        initializeFreshFlow()
    }

    private func initializeFreshFlow() {
        workoutDate = Date()
        usesManualTimes = false
        showsTimeEditor = false
        hasStarted = false
        templateExercises = template.exercises
        drafts = store.resolvedDrafts(for: template)
        if drafts.isEmpty || drafts.count != templateExercises.count {
            drafts = templateExercises.map {
                ExerciseDraft(
                    name: $0.name,
                    type: $0.type,
                    sets: $0.type == .weights ? [WorkoutSetDraft()] : [],
                    weightUnit: store.defaultWeightUnit
                )
            }
        }
        addToTemplateDraftIds = []
        newDraftIds = []
        selectedExercise = nil
        manualStartTime = Date()
        manualEndTime = Date()
        markLoaded(hasEdits: false)
    }

    private func applyResumeDraft(_ draft: TemplateFlowDraft) {
        workoutDate = draft.workoutDate
        usesManualTimes = draft.usesManualTimes
        manualStartTime = draft.manualStartTime
        manualEndTime = draft.manualEndTime
        drafts = draft.drafts
        templateExercises = draft.templateExercises
        addToTemplateDraftIds = draft.addToTemplateDraftIds
        newDraftIds = draft.newDraftIds
        hasStarted = draft.hasStarted
        showsTimeEditor = draft.showsTimeEditor
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
        let hasDraftContent = drafts.contains { $0.hasContent }
        let hasScheduleChange = usesManualTimes || !Calendar.current.isDateInToday(workoutDate)
        return hasDraftContent || hasScheduleChange || hasStarted
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
            DraftStore.clear(.templateFlow)
            return
        }
        let payload = TemplateFlowDraft(
            templateId: template.id,
            workoutDate: workoutDate,
            usesManualTimes: usesManualTimes,
            manualStartTime: manualStartTime,
            manualEndTime: manualEndTime,
            drafts: drafts,
            templateExercises: templateExercises,
            addToTemplateDraftIds: addToTemplateDraftIds,
            newDraftIds: newDraftIds,
            hasStarted: hasStarted,
            showsTimeEditor: showsTimeEditor
        )
        DraftStore.save(payload, kind: .templateFlow)
    }

    private var startScreen: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(template.title)
                .font(.custom("Avenir Next", size: 28))
                .fontWeight(.semibold)
                .foregroundStyle(themeColor(.sand))

            Text("\(drafts.count) exercises")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themeColor(.sand).opacity(0.6))

            VStack(alignment: .leading, spacing: 10) {
                Text("Schedule")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themeColor(.sand).opacity(0.6))

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
                                .foregroundStyle(themeColor(.sand))
                            Spacer()
                            Image(systemName: showsTimeEditor ? "chevron.up" : "chevron.down")
                                .font(.custom("Avenir Next", size: 12))
                                .foregroundStyle(themeColor(.sand).opacity(0.5))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeColor(.card))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )
                    }
                    .buttonStyle(.plain)

                    if showsTimeEditor {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Date")
                                .font(.custom("Avenir Next", size: 11))
                                .foregroundStyle(themeColor(.sand).opacity(0.6))
                            HStack {
                                Text(relativeLabel(for: workoutDate))
                                    .font(.custom("Avenir Next", size: 16))
                                    .foregroundStyle(themeColor(.sand))
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
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeColor(.card))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Time")
                                    .font(.custom("Avenir Next", size: 11))
                                    .foregroundStyle(themeColor(.sand).opacity(0.6))
                                Spacer()
                                if isNowTime(manualStartTime) || isNowTime(manualEndTime) {
                                    Text("Now")
                                        .font(.custom("Avenir Next", size: 11))
                                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                                }
                            }
                            HStack {
                                Text("Start")
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(themeColor(.sand).opacity(0.75))
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
                                    .foregroundStyle(themeColor(.sand).opacity(0.75))
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
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeColor(.card))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )

                        if isFutureDay(workoutDate) {
                            Text("Future date")
                                .font(.custom("Avenir Next", size: 11))
                                .foregroundStyle(themeColor(.sand).opacity(0.55))
                        }
                    }
                }

            }

            Button {
                if usesManualTimes == false {
                    workoutDate = Date()
                }
                hasStarted = true
                Haptics.primaryAction()
            } label: {
                Text("Start Workout")
                    .font(.custom("Avenir Next", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(themeColor(.night))
                    .background(themeColor(.sand))
                    .clipShape(Capsule())
            }

            Button {
                DraftStore.clear(.templateFlow)
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
                            .stroke(themeColor(.sand).opacity(0.6), lineWidth: 1)
                    )
            }
        }
        .padding(24)
    }

    private func workoutExercise(from draft: ExerciseDraft) -> (exercise: WorkoutExercise?, hasInvalid: Bool) {
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

    private func sessionDate(from exercises: [WorkoutExercise]) -> Date {
        exercises.map(\.loggedAt).compactMap { $0 }.min() ?? workoutDate
    }

    private func applyTimes(to exercises: [WorkoutExercise]) -> [WorkoutExercise] {
        if usesManualTimes == false {
            let now = Date()
            return exercises.map { exercise in
                if exercise.loggedAt != nil {
                    return exercise
                }
                return WorkoutExercise(
                    id: exercise.id,
                    name: exercise.name,
                    type: exercise.type,
                    sets: exercise.sets,
                    durationSeconds: exercise.durationSeconds,
                    calories: exercise.calories,
                    isometricWeightKg: exercise.isometricWeightKg,
                    isometricSets: exercise.isometricSets,
                    loggedAt: combineDate(workoutDate, time: now),
                    todaysNotes: exercise.todaysNotes
                )
            }
        }
        let start = combineDate(workoutDate, time: manualStartTime)
        let end = combineDate(workoutDate, time: manualEndTime)
        let times = distributedTimes(count: exercises.count, start: start, end: end)
        return exercises.enumerated().map { index, exercise in
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
    }

    private var scheduleSummary: String {
        if usesManualTimes == false || shouldUseLiveSchedule() {
            return "\(relativeLabel(for: Date())) · Now"
        }
        let dateLabel = relativeLabel(for: workoutDate)
        let startLabel = manualStartTime.formatted(date: .omitted, time: .shortened)
        let endLabel = manualEndTime.formatted(date: .omitted, time: .shortened)
        return "\(dateLabel) · \(startLabel) – \(endLabel)"
    }

    private func shouldUseLiveSchedule() -> Bool {
        Calendar.current.isDateInToday(workoutDate)
            && isNowTime(manualStartTime)
            && isNowTime(manualEndTime)
    }

    private func isComplete(index: Int) -> Bool {
        guard drafts.indices.contains(index) else { return false }
        return workoutExercise(from: drafts[index]).exercise != nil
    }

    private func exerciseRow(for index: Int, isComplete: Bool) -> some View {
        let draft = drafts[index]
        let templateExercise = templateExercises.indices.contains(index)
            ? templateExercises[index]
            : nil
        return Button {
            selectedExercise = TemplateExerciseSelection(index: index)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.name.isEmpty ? (templateExercise?.name ?? "Exercise") : draft.name)
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themeColor(.sand))
                    Text((templateExercise?.type ?? draft.type).label)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                }
                Spacer()
                Text(isComplete ? "Done" : "Start")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(themeColor(.sand))
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
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeleteIndex = index
                showDeleteTemplateConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                pendingDeleteIndex = index
                removeDraftFromFlow()
            } label: {
                Label("Skip", systemImage: "forward.fill")
            }
            .tint(themeColor(.sand))
        }
    }

    private func removeDraftFromFlow() {
        guard let index = pendingDeleteIndex, drafts.indices.contains(index) else { return }
        let draftId = drafts[index].id
        drafts.remove(at: index)
        newDraftIds.remove(draftId)
        addToTemplateDraftIds.remove(draftId)
        pendingDeleteIndex = nil
        Haptics.selection()
    }

    private func removeDraftFromTemplate() {
        guard let index = pendingDeleteIndex, drafts.indices.contains(index) else { return }
        let draftId = drafts[index].id
        drafts.remove(at: index)
        newDraftIds.remove(draftId)
        addToTemplateDraftIds.remove(draftId)
        if templateExercises.indices.contains(index) {
            templateExercises.remove(at: index)
            store.updateTemplate(id: template.id, title: template.title, exercises: templateExercises)
        }
        pendingDeleteIndex = nil
    }

    private func addExercise(addToTemplate: Bool) {
        let newDraft = ExerciseDraft(
            type: .weights,
            sets: [WorkoutSetDraft()],
            weightUnit: store.defaultWeightUnit
        )
        drafts.append(newDraft)
        newDraftIds.insert(newDraft.id)
        if addToTemplate {
            addToTemplateDraftIds.insert(newDraft.id)
        }
        selectedExercise = TemplateExerciseSelection(index: drafts.count - 1)
    }

    private func handleTemplateSave(_ draft: ExerciseDraft) {
        newDraftIds.remove(draft.id)
        guard addToTemplateDraftIds.contains(draft.id) else { return }
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let newExercise = TemplateExercise(
            id: UUID(),
            name: trimmedName,
            type: draft.type,
            weightKg: nil,
            sets: nil,
            repsPerSet: nil
        )
        templateExercises.append(newExercise)
        store.updateTemplate(id: template.id, title: template.title, exercises: templateExercises)
        addToTemplateDraftIds.remove(draft.id)
        Haptics.success()
    }

    private func handleTemplateCancel(draftId: UUID) {
        guard newDraftIds.contains(draftId) else { return }
        guard let index = drafts.firstIndex(where: { $0.id == draftId }) else { return }
        if isDraftEmpty(drafts[index]) {
            drafts.remove(at: index)
        }
        newDraftIds.remove(draftId)
        addToTemplateDraftIds.remove(draftId)
    }

    private func isDraftEmpty(_ draft: ExerciseDraft) -> Bool {
        if !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if !draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if !draft.calories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        for set in draft.isometricSets {
            if !set.duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !set.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }
        for set in draft.sets {
            for segment in set.segments {
                if !segment.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !segment.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return false
                }
            }
        }
        return true
    }
}
