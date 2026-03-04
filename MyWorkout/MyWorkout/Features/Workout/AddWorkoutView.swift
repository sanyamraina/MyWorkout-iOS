import SwiftUI

struct AddWorkoutView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate?
    let session: WorkoutSession?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var workoutDate = Date()
    @State private var drafts: [ExerciseDraft] = []
    @State private var hasLoadedDrafts = false
    @State private var hasUserEdits = false
    @State private var showsTimeEditor = false
    @State private var usesManualTimes = false
    @State private var manualStartTime = Date()
    @State private var manualEndTime = Date()
    @State private var showSpotHud = false
    @State private var spotHudMessage = ""
    @State private var spotHudDismissWorkItem: DispatchWorkItem?
    @State private var showResumePrompt = false
    @State private var pendingResumeDraft: AddWorkoutDraft?
    @State private var autosaveWorkItem: DispatchWorkItem?

    private var validation: (validExercises: [WorkoutExercise], hasInvalid: Bool) {
        var validExercises: [WorkoutExercise] = []
        var hasInvalid = false

        for draft in drafts {
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
                    hasInvalid = true
                    continue
                }

                if name.isEmpty && hasAnySetInput {
                    hasInvalid = true
                    continue
                }

                guard !setModels.isEmpty else {
                    continue
                }

                guard !name.isEmpty else {
                    hasInvalid = true
                    continue
                }

                validExercises.append(
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
                    )
                )
            case .cardio:
                let durationTrimmed = draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
                let caloriesTrimmed = draft.calories.trimmingCharacters(in: .whitespacesAndNewlines)
                let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
                let caloriesValue = caloriesTrimmed.isEmpty ? nil : Int(caloriesTrimmed)
                let hasMetrics = durationValue != nil || caloriesValue != nil

                if name.isEmpty && (!durationTrimmed.isEmpty || !caloriesTrimmed.isEmpty) {
                    hasInvalid = true
                    continue
                }

                if !durationTrimmed.isEmpty && durationValue == nil {
                    hasInvalid = true
                    continue
                }
                if let durationValue, durationValue <= 0 { hasInvalid = true; continue }
                if let caloriesValue, caloriesValue <= 0 { hasInvalid = true; continue }

                if name.isEmpty && !hasMetrics {
                    continue
                }

                guard hasMetrics, !name.isEmpty else {
                    hasInvalid = true
                    continue
                }

                validExercises.append(
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
                    )
                )
            case .isometric:
                var isometricModels: [IsometricSet] = []
                var hasAnyInput = false
                var hasInvalidSet = false

                for setDraft in draft.isometricSets {
                    let durationTrimmed = setDraft.duration.trimmingCharacters(in: .whitespacesAndNewlines)
                    let weightTrimmed = setDraft.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                    let durationValue = durationTrimmed.isEmpty ? nil : parseDurationSeconds(durationTrimmed)
                    let weightValue = weightTrimmed.isEmpty ? nil : Double(weightTrimmed)

                    if durationTrimmed.isEmpty && weightTrimmed.isEmpty {
                        continue
                    }

                    hasAnyInput = true

                    if durationValue == nil || durationValue == 0 {
                        hasInvalidSet = true
                        continue
                    }
                    if let weightValue, weightValue < 0 {
                        hasInvalidSet = true
                        continue
                    }

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

                if hasInvalidSet {
                    hasInvalid = true
                    continue
                }

                if name.isEmpty && hasAnyInput {
                    hasInvalid = true
                    continue
                }

                guard !isometricModels.isEmpty else {
                    continue
                }

                guard !name.isEmpty else {
                    hasInvalid = true
                    continue
                }

                let totalSeconds = isometricModels.reduce(0) { $0 + $1.durationSeconds }
                let maxWeight = isometricModels.map(\.weightKg).max() ?? 0

                validExercises.append(
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
                    )
                )
            }
        }

        return (validExercises, hasInvalid)
    }

    private var validExercises: [WorkoutExercise] {
        validation.validExercises
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

    private var canSave: Bool {
        !drafts.isEmpty
            && !validExercises.isEmpty
            && !validation.hasInvalid
    }

    private var titleText: String {
        session == nil ? "New Workout" : "Edit Workout"
    }

    private var saveLabel: String {
        session == nil ? "Save Workout" : "Update Workout"
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
                    Text(titleText)
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedPrimaryText())

                    scheduleCard

                    exerciseEditors

                    Button {
                        Haptics.selection()
                        drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Exercise")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themedPrimaryText())
                    }
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
                    .foregroundStyle(themedAccentForeground())
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
        .onChange(of: workoutDate) { _, newValue in
            if !Calendar.current.isDateInToday(newValue) {
                usesManualTimes = true
                showsTimeEditor = true
                setDefaultManualTimes()
            }
            handleUserEdit()
        }
        .onChange(of: usesManualTimes) { _, _ in
            handleUserEdit()
        }
        .onChange(of: drafts) { _, _ in
            handleUserEdit()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                persistDraftIfNeeded()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    let finalExercises: [WorkoutExercise]
                    if session == nil {
                        finalExercises = applyTimes(to: validExercises)
                    } else if usesManualTimes {
                        finalExercises = applyTimes(to: validExercises)
                    } else {
                        finalExercises = fillMissingTimes(validExercises)
                    }
                    if let session {
                        store.updateSession(session, date: sessionDate(from: finalExercises), exercises: finalExercises)
                    } else {
                        store.addSession(date: sessionDate(from: finalExercises), exercises: finalExercises)
                        if let template {
                            store.incrementTemplateUsage(for: template)
                        }
                    }
                    if store.isExerciseNotesEnabled {
                        for draft in drafts {
                            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { continue }
                            store.setExerciseNote(draft.exerciseNote, for: name)
                        }
                    }
                    DraftStore.clear(.add)
                    Haptics.success()
                    dismiss()
                } label: {
                    Text(saveLabel)
                        .font(.custom("Avenir Next", size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(themedAccentForeground())
                        .background(themeColor(.sand))
                        .clipShape(Capsule())
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)

                Button {
                    DraftStore.clear(.add)
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
        .alert("Resume workout?", isPresented: $showResumePrompt) {
            Button("Discard", role: .destructive) {
                pendingResumeDraft = nil
                DraftStore.clear(.add)
                Haptics.warning()
                initializeFreshDraft()
            }
            Button("Resume") {
                if let pendingResumeDraft {
                    applyResumeDraft(pendingResumeDraft)
                } else {
                    initializeFreshDraft()
                }
                Haptics.selection()
                pendingResumeDraft = nil
            }
        } message: {
            Text("We saved your in-progress workout so you can pick up where you left off.")
        }
        .onAppear {
            guard !hasLoadedDrafts else { return }
            loadDraftIfNeeded()
        }
    }

    private func loadDraftIfNeeded() {
        if let saved = DraftStore.load(.add, as: AddWorkoutDraft.self) {
            let matchesSession = saved.sessionId == session?.id
            let matchesNew = saved.sessionId == nil && session == nil
            let currentTemplateId = template?.id
            let matchesTemplate = saved.templateId == currentTemplateId
                || (saved.templateId == nil && currentTemplateId == nil)
            if (matchesSession || matchesNew) && matchesTemplate {
                pendingResumeDraft = saved
                showResumePrompt = true
                return
            }
        }
        initializeFreshDraft()
    }

    private func initializeFreshDraft() {
        usesManualTimes = false
        showsTimeEditor = false
        if let session {
            workoutDate = session.date
            drafts = drafts(for: session)
            if !Calendar.current.isDateInToday(workoutDate) {
                setDefaultManualTimes()
            } else {
                manualStartTime = Date()
                manualEndTime = Date()
            }
            markLoaded(hasEdits: false)
            return
        }
        workoutDate = Date()
        if let template {
            drafts = store.resolvedDrafts(for: template)
        } else {
            drafts = [ExerciseDraft(weightUnit: store.defaultWeightUnit)]
        }
        manualStartTime = Date()
        manualEndTime = Date()
        markLoaded(hasEdits: false)
    }

    private func applyResumeDraft(_ draft: AddWorkoutDraft) {
        workoutDate = draft.workoutDate
        usesManualTimes = draft.usesManualTimes
        manualStartTime = draft.manualStartTime
        manualEndTime = draft.manualEndTime
        drafts = draft.drafts
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
            DraftStore.clear(.add)
            return
        }
        let payload = AddWorkoutDraft(
            sessionId: session?.id,
            templateId: template?.id,
            workoutDate: workoutDate,
            usesManualTimes: usesManualTimes,
            manualStartTime: manualStartTime,
            manualEndTime: manualEndTime,
            drafts: drafts,
            showsTimeEditor: showsTimeEditor
        )
        DraftStore.save(payload, kind: .add)
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

    private func drafts(for session: WorkoutSession) -> [ExerciseDraft] {
        session.exercises.map { exercise in
            switch exercise.type {
            case .weights:
                let setDrafts = exercise.sets.map { set in
                let segmentDrafts = set.segments.map { segment in
                    WorkoutSetSegmentDraft(
                        weight: segment.weightKg == 0
                            ? "0"
                            : String(format: "%.1f", weightValue(segment.weightKg, unit: store.defaultWeightUnit)),
                        reps: "\(segment.reps)",
                        isSpotted: segment.isSpotted
                    )
                }
                    return WorkoutSetDraft(segments: segmentDrafts.isEmpty ? [WorkoutSetSegmentDraft()] : segmentDrafts)
                }
                return ExerciseDraft(
                    name: exercise.name,
                    type: .weights,
                    sets: setDrafts.isEmpty ? [WorkoutSetDraft()] : setDrafts,
                    weightUnit: store.defaultWeightUnit,
                    exerciseNote: store.exerciseNote(for: exercise.name),
                    todaysNotes: exercise.todaysNotes ?? "",
                    entryId: exercise.id,
                    loggedAt: exercise.loggedAt
                )
            case .cardio:
                return ExerciseDraft(
                    name: exercise.name,
                    type: .cardio,
                    sets: [],
                    isometricSets: [IsometricSetDraft()],
                    weightUnit: store.defaultWeightUnit,
                    durationMinutes: formattedDurationValue(exercise.durationSeconds),
                    calories: formattedOptionalInt(exercise.calories),
                    exerciseNote: store.exerciseNote(for: exercise.name),
                    todaysNotes: exercise.todaysNotes ?? "",
                    entryId: exercise.id,
                    loggedAt: exercise.loggedAt
                )
            case .isometric:
                let setDrafts: [IsometricSetDraft]
                if !exercise.isometricSets.isEmpty {
                    setDrafts = exercise.isometricSets.map { set in
                        let weightText = set.weightKg > 0
                            ? String(format: "%.1f", weightValue(set.weightKg, unit: store.defaultWeightUnit))
                            : ""
                        return IsometricSetDraft(
                            duration: formattedDurationValue(set.durationSeconds),
                            weight: weightText,
                            durationPlaceholder: "",
                            weightPlaceholder: ""
                        )
                    }
                } else {
                    setDrafts = [IsometricSetDraft(duration: formattedDurationValue(exercise.durationSeconds))]
                }
                return ExerciseDraft(
                    name: exercise.name,
                    type: .isometric,
                    sets: [],
                    isometricSets: setDrafts,
                    weightUnit: store.defaultWeightUnit,
                    exerciseNote: store.exerciseNote(for: exercise.name),
                    todaysNotes: exercise.todaysNotes ?? "",
                    entryId: exercise.id,
                    loggedAt: exercise.loggedAt
                )
            }
        }
    }

    private var exerciseEditors: some View {
        let suggestions = store.exerciseNameCatalog()
        return ForEach($drafts) { $draft in
            ExerciseEditorRow(
                draft: $draft,
                suggestions: suggestions,
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
                onDelete: {
                    drafts.removeAll { $0.id == draft.id }
                },
                onMoveUp: nil,
                onMoveDown: nil,
                onSpotHud: { isSpotted in
                    presentSpotHud(message: isSpotted ? "Spotted set" : "Spot removed")
                }
            )
        }
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

    private func setDefaultManualTimes() {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        let end = calendar.date(byAdding: .minute, value: 30, to: noon) ?? noon
        manualStartTime = noon
        manualEndTime = end
    }

    private func formattedOptionalInt(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
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

    private func fillMissingTimes(_ exercises: [WorkoutExercise]) -> [WorkoutExercise] {
        let fallback = combineDate(workoutDate, time: Date())
        var lastLoggedAt: Date?
        var lastType: ExerciseType?
        var lastDurationSeconds: Int?

        return exercises.map { exercise in
            if let loggedAt = exercise.loggedAt {
                lastLoggedAt = loggedAt
                lastType = exercise.type
                lastDurationSeconds = exercise.durationSeconds
                return exercise
            }

            let base = lastLoggedAt ?? fallback
            let increment: TimeInterval
            if let lastType {
                if lastType == .cardio || lastType == .isometric {
                    let duration = lastDurationSeconds ?? 0
                    increment = duration > 0 ? TimeInterval(duration) : 60
                } else {
                    increment = 300
                }
            } else {
                increment = 0
            }
            let assigned = base.addingTimeInterval(increment)
            lastLoggedAt = assigned
            lastType = exercise.type
            lastDurationSeconds = exercise.durationSeconds

            return WorkoutExercise(
                id: exercise.id,
                name: exercise.name,
                type: exercise.type,
                sets: exercise.sets,
                durationSeconds: exercise.durationSeconds,
                calories: exercise.calories,
                isometricWeightKg: exercise.isometricWeightKg,
                isometricSets: exercise.isometricSets,
                loggedAt: assigned,
                todaysNotes: exercise.todaysNotes
            )
        }
    }

    private func weightValue(_ kg: Double, unit: WeightUnit) -> Double {
        if unit == .lb {
            return kg * 2.20462262
        }
        return kg
    }
}
