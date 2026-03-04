import SwiftUI

struct ExerciseEditorRow: View {
    @Binding var draft: ExerciseDraft
    let suggestions: [String]
    let suggestionDetail: ((String) -> String?)?
    let showsMetrics: Bool
    let knownType: ExerciseType?
    let isNameLocked: Bool
    let isDropSetsEnabled: Bool
    let isExerciseNotesEnabled: Bool
    let isTodaysNotesEnabled: Bool
    let isSpottingEnabled: Bool
    let latestExerciseForName: ((String) -> WorkoutExercise?)?
    let exerciseNoteForName: ((String) -> String)?
    let onDelete: (() -> Void)?
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onNameFocusChange: ((Bool) -> Void)?
    let onSpotHud: ((Bool) -> Void)?
    @State private var lastUnit: WeightUnit = .kg
    @State private var isNameFocused = false
    @State private var showSpotSheet = false
    @State private var showExerciseNotesInfoSheet = false
    @State private var showTodaysNotesInfoSheet = false
    private static let spotIntroKey = "spotIntroShown"
    private static let exerciseNotesInfoKey = "exerciseNotesInfoShown"
    private static let todaysNotesInfoKey = "todaysNotesInfoShown"

    init(
        draft: Binding<ExerciseDraft>,
        suggestions: [String],
        suggestionDetail: ((String) -> String?)? = nil,
        showsMetrics: Bool,
        knownType: ExerciseType?,
        isNameLocked: Bool = false,
        isDropSetsEnabled: Bool,
        isExerciseNotesEnabled: Bool,
        isTodaysNotesEnabled: Bool,
        isSpottingEnabled: Bool,
        latestExerciseForName: ((String) -> WorkoutExercise?)? = nil,
        exerciseNoteForName: ((String) -> String)?,
        onDelete: (() -> Void)?,
        onMoveUp: (() -> Void)?,
        onMoveDown: (() -> Void)?,
        onSpotHud: ((Bool) -> Void)? = nil,
        onNameFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._draft = draft
        self.suggestions = suggestions
        self.suggestionDetail = suggestionDetail
        self.showsMetrics = showsMetrics
        self.knownType = knownType
        self.isNameLocked = isNameLocked
        self.isDropSetsEnabled = isDropSetsEnabled
        self.isExerciseNotesEnabled = isExerciseNotesEnabled
        self.isTodaysNotesEnabled = isTodaysNotesEnabled
        self.isSpottingEnabled = isSpottingEnabled
        self.latestExerciseForName = latestExerciseForName
        self.exerciseNoteForName = exerciseNoteForName
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onSpotHud = onSpotHud
        self.onNameFocusChange = onNameFocusChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                nameField
                metricsSection
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeColor(.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                    )
            )

            if showsMetrics && (isTodaysNotesEnabled || isExerciseNotesEnabled) {
                VStack(alignment: .leading, spacing: 12) {
                    if isTodaysNotesEnabled {
                        todaysNotesSection
                    }
                    if isTodaysNotesEnabled && isExerciseNotesEnabled {
                        Divider()
                            .overlay(themeColor(.sand).opacity(0.12))
                    }
                    if isExerciseNotesEnabled {
                        notesSection
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(themeColor(.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
        .zIndex(isNameFocused ? 5 : 1)
        .sheet(isPresented: $showSpotSheet) {
            VStack(spacing: 16) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(themedPrimaryText())
                Text("Spotted Set")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(themedPrimaryText())
                Text("Tap the 👥 icon to mark a set as spotted. This helps you remember where you got a spot.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themedSecondaryText())
                    .multilineTextAlignment(.center)
                Button("Got it") {
                    showSpotSheet = false
                }
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themedAccentForeground())
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(themeColor(.sand))
                .clipShape(Capsule())
            }
            .padding(24)
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
            .presentationBackground(
                LinearGradient(
                    colors: [themeColor(.night), themeColor(.coal)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .background(
                LinearGradient(
                    colors: [themeColor(.night), themeColor(.coal)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .sheet(isPresented: $showExerciseNotesInfoSheet) {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(themeColor(.sand).opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "note.text")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(themedPrimaryText())
                    }
                    Text("Exercise Notes")
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedPrimaryText())
                    Text("Saved with the exercise and shown every time you use it.")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(themedSecondaryText())
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeColor(.card).opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(themeColor(.sand).opacity(0.12), lineWidth: 1)
                        )
                )

                Button("Got it") {
                    showExerciseNotesInfoSheet = false
                }
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themedAccentForeground())
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(themeColor(.sand))
                .clipShape(Capsule())
            }
            .padding(24)
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .presentationBackground(
                LinearGradient(
                    colors: [themeColor(.night), themeColor(.coal)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .background(
                LinearGradient(
                    colors: [themeColor(.night), themeColor(.coal)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .sheet(isPresented: $showTodaysNotesInfoSheet) {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(themeColor(.sand).opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(themedPrimaryText())
                    }
                    Text("Today's Notes")
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedPrimaryText())
                    Text("Only for this workout. It shows in history for that session.")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(themedSecondaryText())
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeColor(.card).opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(themeColor(.sand).opacity(0.12), lineWidth: 1)
                        )
                )

                Button("Got it") {
                    showTodaysNotesInfoSheet = false
                }
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themedAccentForeground())
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(themeColor(.sand))
                .clipShape(Capsule())
            }
            .padding(24)
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .presentationBackground(
                LinearGradient(
                    colors: [themeColor(.night), themeColor(.coal)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .background(
                LinearGradient(
                    colors: [themeColor(.night), themeColor(.coal)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear {
            lastUnit = draft.weightUnit
            if let knownType {
                draft.type = knownType
            }
        }
        .onChange(of: draft.weightUnit) { _, newValue in
            guard lastUnit != newValue else { return }
            convertWeights(from: lastUnit, to: newValue)
            lastUnit = newValue
        }
        .onChange(of: knownType) { _, newValue in
            if let newValue {
                draft.type = newValue
            }
        }
        .onChange(of: draft.name) { _, _ in
            if let knownType {
                draft.type = knownType
            }
            if isExerciseNotesEnabled, let exerciseNoteForName,
               draft.exerciseNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let note = exerciseNoteForName(draft.name)
                if !note.isEmpty {
                    draft.exerciseNote = note
                }
            }
            applyLatestPlaceholders()
        }
        .onChange(of: draft.type) { _, newValue in
            if newValue == .cardio || newValue == .isometric {
                draft.sets = []
                if newValue == .isometric && draft.isometricSets.isEmpty {
                    draft.isometricSets = [IsometricSetDraft()]
                }
            } else if draft.sets.isEmpty {
                draft.sets = [WorkoutSetDraft()]
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Exercise")
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(themedSecondaryText())
            if let knownType {
                typeBadge(for: knownType)
            } else {
                typePicker
            }
            Spacer()
            if let onMoveUp {
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(themedSecondaryText())
                }
            }
            if let onMoveDown {
                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(themedSecondaryText())
                }
            }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(themedSecondaryText())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nameField: some View {
        ExerciseNameField(
            title: "Exercise",
            showsTitle: false,
            text: $draft.name,
            suggestions: suggestions,
            suggestionDetail: suggestionDetail,
            isLocked: isNameLocked,
            onFocusChange: { isFocused in
                isNameFocused = isFocused
                onNameFocusChange?(isFocused)
            }
        )
        .zIndex(2)
    }

    @ViewBuilder
    private var metricsSection: some View {
        if showsMetrics {
            if draft.type == .weights {
                weightsSection
            } else if draft.type == .cardio {
                cardioSection
            } else {
                isometricSection
            }
        }
    }

    private var weightsSection: some View {
        VStack(spacing: 10) {
            ForEach($draft.sets) { $set in
                let setId = $set.wrappedValue.id
                SetCardView(
                    set: $set,
                    weightUnit: $draft.weightUnit,
                    isCompact: draft.sets.count > 1,
                    canRemoveSet: draft.sets.count > 1,
                    allowDropSets: isDropSetsEnabled,
                    allowSpotting: isSpottingEnabled,
                    isBodyweightSegment: isBodyweightSegment,
                    onRemoveSet: {
                        draft.sets.removeAll { $0.id == setId }
                    },
                    onSpotToggle: handleSpotToggle
                )
            }
            .animation(.easeInOut(duration: 0.2), value: draft.sets.count)

            Divider()
                .overlay(themeColor(.sand).opacity(0.12))

            Button {
                draft.sets.append(WorkoutSetDraft())
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Set")
                }
                 .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themedPrimaryText())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardioSection: some View {
        HStack(spacing: 12) {
            InputCard(
                title: "Time (mm:ss)",
                text: $draft.durationMinutes,
                placeholder: draft.durationPlaceholder.isEmpty ? "20:00" : draft.durationPlaceholder,
                keyboard: .numbersAndPunctuation
            )
            InputCard(
                title: "Calories",
                text: $draft.calories,
                placeholder: draft.caloriesPlaceholder.isEmpty ? "150" : draft.caloriesPlaceholder,
                keyboard: .numberPad
            )
        }
    }

    private var isometricSection: some View {
        VStack(spacing: 10) {
            ForEach(Array($draft.isometricSets.enumerated()), id: \.element.id) { index, $set in
                isometricSetRow(index: index, set: $set)
            }

            Divider()
                .overlay(themeColor(.sand).opacity(0.12))

            Button {
                draft.isometricSets.append(IsometricSetDraft())
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Set")
                }
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themedPrimaryText())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func isometricSetRow(index: Int, set: Binding<IsometricSetDraft>) -> some View {
        let setId = set.wrappedValue.id
        let showsTitle = index == 0
        let setValue = set.wrappedValue
        return HStack(alignment: .center, spacing: 12) {
            if draft.isometricSets.count > 1 {
                Button {
                    draft.isometricSets.removeAll { $0.id == setId }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(themedSecondaryText())
                }
                .buttonStyle(.plain)
            }
            InputCard(
                title: "Time (mm:ss)",
                text: set.duration,
                placeholder: setValue.durationPlaceholder.isEmpty ? "00:45" : setValue.durationPlaceholder,
                keyboard: .numbersAndPunctuation,
                showsTitle: showsTitle
            )
            InputCard(
                title: "Weight",
                text: set.weight,
                placeholder: setValue.weightPlaceholder.isEmpty ? "0" : setValue.weightPlaceholder,
                keyboard: .decimalPad,
                showsTitle: showsTitle
            )
            UnitPillAligned(unit: $draft.weightUnit, showsTitle: showsTitle)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        let trimmedNote = draft.exerciseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 12) {
            if draft.isExerciseNoteExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(themedSecondaryText())
                            Text("Exercise Note")
                                .font(.custom("Avenir Next", size: 12))
                                .fontWeight(.medium)
                                .foregroundStyle(themedSecondaryText())
                        }
                        Spacer()
                        Button {
                            presentExerciseNotesInfoIfNeeded()
                            draft.isExerciseNoteExpanded = false
                        } label: {
                            Text("Done")
                                .font(.custom("Avenir Next", size: 13))
                                .fontWeight(.medium)
                                .foregroundStyle(themedAccentForeground())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(themedAccent())
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ZStack(alignment: .topLeading) {
                        if trimmedNote.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Example:")
                                    .font(.custom("Avenir Next", size: 14))
                                    .fontWeight(.medium)
                                    .foregroundStyle(themedSecondaryText().opacity(0.8))
                                Text("Pain: left shoulder, Seat: 3, Grip: wide")
                                    .font(.custom("Avenir Next", size: 14))
                                    .foregroundStyle(themedSecondaryText().opacity(0.6))
                            }
                            .padding(.top, 18)
                            .padding(.leading, 18)
                        }
                        TextEditor(text: $draft.exerciseNote)
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(themedPrimaryText())
                            .scrollContentBackground(.hidden)
                            .padding(.top, 10)
                            .padding(.leading, 10)
                    }
                    .frame(minHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeColor(.card).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themedAccent().opacity(0.15), lineWidth: 1.5)
                            )
                    )
                }
            } else if trimmedNote.isEmpty {
                Button {
                    presentExerciseNotesInfoIfNeeded()
                    draft.isExerciseNoteExpanded = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Exercise Note")
                    }
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(themedPrimaryText())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(themedSecondaryText())
                            Text("Exercise Note")
                                .font(.custom("Avenir Next", size: 12))
                                .fontWeight(.medium)
                                .foregroundStyle(themedSecondaryText())
                            Spacer()
                            Button {
                                presentExerciseNotesInfoIfNeeded()
                                draft.isExerciseNoteExpanded = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("Edit")
                                }
                            }
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(themedSecondaryText())
                            .buttonStyle(.plain)
                        }
                        Text(trimmedNote)
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(themedPrimaryText())
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeColor(.card).opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )

                }
            }
        }
    }

    @ViewBuilder
    private var todaysNotesSection: some View {
        let trimmedEntry = draft.todaysNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 12) {
            if draft.isTodaysNotesExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(themedSecondaryText())
                            Text("Today's Notes")
                                .font(.custom("Avenir Next", size: 12))
                                .fontWeight(.medium)
                                .foregroundStyle(themedSecondaryText())
                        }
                        Spacer()
                        Button {
                            presentTodaysNotesInfoIfNeeded()
                            draft.isTodaysNotesExpanded = false
                        } label: {
                            Text("Done")
                                .font(.custom("Avenir Next", size: 13))
                                .fontWeight(.medium)
                                .foregroundStyle(themedAccentForeground())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(themedAccent())
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ZStack(alignment: .topLeading) {
                        if trimmedEntry.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Example:")
                                    .font(.custom("Avenir Next", size: 14))
                                    .fontWeight(.medium)
                                    .foregroundStyle(themedSecondaryText().opacity(0.8))
                                Text("Today: felt tight, reduced weight, eased tempo")
                                    .font(.custom("Avenir Next", size: 14))
                                    .foregroundStyle(themedSecondaryText().opacity(0.6))
                            }
                            .padding(.top, 18)
                            .padding(.leading, 18)
                        }
                        TextEditor(text: $draft.todaysNotes)
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(themedPrimaryText())
                            .scrollContentBackground(.hidden)
                            .padding(.top, 10)
                            .padding(.leading, 10)
                    }
                    .frame(minHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeColor(.card).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themedAccent().opacity(0.15), lineWidth: 1.5)
                            )
                    )
                }
            } else if trimmedEntry.isEmpty {
                Button {
                    presentTodaysNotesInfoIfNeeded()
                    draft.isTodaysNotesExpanded = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Today's Notes")
                    }
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(themedPrimaryText())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(themedSecondaryText())
                            Text("Today's Notes")
                                .font(.custom("Avenir Next", size: 12))
                                .fontWeight(.medium)
                                .foregroundStyle(themedSecondaryText())
                            Spacer()
                            Button {
                                presentTodaysNotesInfoIfNeeded()
                                draft.isTodaysNotesExpanded = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("Edit")
                                }
                            }
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(themedSecondaryText())
                            .buttonStyle(.plain)
                        }
                        Text(trimmedEntry)
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(themedPrimaryText())
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeColor(.card).opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                            )
                    )

                }
            }
        }
    }

    private var typePicker: some View {
        Picker("Type", selection: $draft.type) {
            ForEach(ExerciseType.allCases, id: \.self) { type in
                Text(type.label).tag(type)
            }
        }
        .themedSegmentedPicker()
        .controlSize(.mini)
        .scaleEffect(0.9)
    }

    private func convertWeights(from: WeightUnit, to: WeightUnit) {
        guard from != to else { return }
        let multiplier: Double
        if from == .kg && to == .lb {
            multiplier = 2.20462262
        } else {
            multiplier = 0.45359237
        }
        draft.sets = draft.sets.map { set in
            let segments = set.segments.map { segment in
                let trimmedWeight = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = Double(trimmedWeight) ?? 0
                let converted = roundToHalf(value * multiplier)
                let placeholderValue = Double(segment.weightPlaceholder) ?? 0
                let convertedPlaceholder = roundToHalf(placeholderValue * multiplier)
                return WorkoutSetSegmentDraft(
                    id: segment.id,
                    weight: trimmedWeight.isEmpty ? "" : (value == 0 ? "0" : String(format: "%.1f", converted)),
                    reps: segment.reps,
                    weightPlaceholder: placeholderValue == 0 ? segment.weightPlaceholder : String(format: "%.1f", convertedPlaceholder),
                    repsPlaceholder: segment.repsPlaceholder,
                    isSpotted: segment.isSpotted,
                    isSpottedPlaceholder: segment.isSpottedPlaceholder
                )
            }
            return WorkoutSetDraft(id: set.id, segments: segments)
        }
        draft.isometricSets = draft.isometricSets.map { set in
            let trimmedWeight = set.weight.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = Double(trimmedWeight) ?? 0
            let converted = roundToHalf(value * multiplier)
            let placeholderValue = Double(set.weightPlaceholder) ?? 0
            let convertedPlaceholder = roundToHalf(placeholderValue * multiplier)
            return IsometricSetDraft(
                id: set.id,
                duration: set.duration,
                weight: trimmedWeight.isEmpty ? "" : (value == 0 ? "0" : String(format: "%.1f", converted)),
                durationPlaceholder: set.durationPlaceholder,
                weightPlaceholder: placeholderValue == 0 ? set.weightPlaceholder : String(format: "%.1f", convertedPlaceholder)
            )
        }
    }

    private func isBodyweightSegment(_ segment: WorkoutSetSegmentDraft) -> Bool {
        let weight = segment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(weight) else { return false }
        return value == 0
    }

    private func applyLatestPlaceholders() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let latestExercise = latestExerciseForName?(trimmedName) else { return }

        switch latestExercise.type {
        case .weights:
            guard draft.type == .weights else { return }
            let hasAnyInput = draft.sets.contains { set in
                set.segments.contains {
                    !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !$0.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
            guard !hasAnyInput else { return }

            let setDrafts = latestExercise.sets.map { set in
                let segmentDrafts = set.segments.map { segment in
                    WorkoutSetSegmentDraft(
                        weight: "",
                        reps: "",
                        weightPlaceholder: segment.weightKg == 0
                            ? "0"
                            : String(format: "%.1f", weightValue(segment.weightKg, unit: draft.weightUnit)),
                        repsPlaceholder: "\(segment.reps)",
                        isSpotted: false,
                        isSpottedPlaceholder: segment.isSpotted
                    )
                }
                return WorkoutSetDraft(segments: segmentDrafts.isEmpty ? [WorkoutSetSegmentDraft()] : segmentDrafts)
            }
            if !setDrafts.isEmpty {
                draft.sets = setDrafts
            }
        case .cardio:
            guard draft.type == .cardio else { return }
            if draft.durationMinutes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.durationPlaceholder = formattedDurationValue(latestExercise.durationSeconds)
            }
            if draft.calories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.caloriesPlaceholder = formattedOptionalInt(latestExercise.calories)
            }
        case .isometric:
            guard draft.type == .isometric else { return }
            let hasAnyInput = draft.isometricSets.contains {
                !$0.duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            guard !hasAnyInput else { return }
            let latestSets = latestExercise.isometricSets
            guard !latestSets.isEmpty else { return }
            draft.isometricSets = latestSets.map { set in
                let weightPlaceholder = set.weightKg > 0
                    ? String(format: "%.1f", weightValue(set.weightKg, unit: draft.weightUnit))
                    : "0"
                return IsometricSetDraft(
                    duration: "",
                    weight: "",
                    durationPlaceholder: formattedDurationValue(set.durationSeconds),
                    weightPlaceholder: weightPlaceholder
                )
            }
        }
    }

    private func weightValue(_ kg: Double, unit: WeightUnit) -> Double {
        if unit == .lb {
            return kg * 2.20462262
        }
        return kg
    }

    private func formattedOptionalInt(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private func handleSpotToggle(isSpotted: Bool) {
        guard isSpottingEnabled else { return }
        if !hasShownSpotIntro {
            markSpotIntroShown()
            showSpotSheet = true
            return
        }
        onSpotHud?(isSpotted)
    }

    private var hasShownSpotIntro: Bool {
        UserDefaults.standard.bool(forKey: Self.spotIntroKey)
    }

    private func markSpotIntroShown() {
        UserDefaults.standard.set(true, forKey: Self.spotIntroKey)
    }

    private func presentExerciseNotesInfoIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.exerciseNotesInfoKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.exerciseNotesInfoKey)
        showExerciseNotesInfoSheet = true
    }

    private func presentTodaysNotesInfoIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.todaysNotesInfoKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.todaysNotesInfoKey)
        showTodaysNotesInfoSheet = true
    }

    private func roundToHalf(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }

    private func typeBadge(for type: ExerciseType) -> some View {
        Text(type.label)
            .font(.custom("Avenir Next", size: 12))
            .foregroundStyle(themedPrimaryText())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(themeColor(.sand).opacity(0.12))
            )
    }

    private var typePlaceholder: some View {
        Text("Type")
            .font(.custom("Avenir Next", size: 12))
            .foregroundStyle(themedSecondaryText())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(themeColor(.sand).opacity(0.08))
            )
    }
}
