import SwiftUI

struct TemplateSeed: Identifiable {
    let id: UUID
    let title: String
    let drafts: [ExerciseDraft]

    init(id: UUID = UUID(), title: String, drafts: [ExerciseDraft]) {
        self.id = id
        self.title = title
        self.drafts = drafts
    }
}

struct AddTemplateView: View {
    @ObservedObject var store: WorkoutStore
    let seed: TemplateSeed?
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var drafts: [ExerciseDraft]
    @State private var editMode: EditMode = .inactive
    @State private var isNameFocused = false
    @State private var isKeyboardVisible = false

    init(store: WorkoutStore, seed: TemplateSeed? = nil) {
        self.store = store
        self.seed = seed
        let initialDrafts = seed?.drafts ?? [ExerciseDraft(weightUnit: store.defaultWeightUnit)]
        let safeDrafts = initialDrafts.isEmpty ? [ExerciseDraft(weightUnit: store.defaultWeightUnit)] : initialDrafts
        _drafts = State(initialValue: safeDrafts)
        _title = State(initialValue: seed?.title ?? "")
    }

    private var validExercises: [TemplateExercise] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            return TemplateExercise(
                id: UUID(),
                name: name,
                type: draft.type,
                weightKg: nil,
                sets: nil,
                repsPerSet: nil
            )
        }
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && validExercises.count == drafts.count && validExercises.count >= 2
    }

    private func normalizedTemplateTitle(_ value: String) -> String {
        let leadingCount = value.prefix { $0.isWhitespace }.count
        let trailingCount = value.reversed().prefix { $0.isWhitespace }.count
        let core = value.dropFirst(leadingCount).dropLast(trailingCount)
        let normalizedCore = core.lowercased().capitalized
        return String(repeating: " ", count: leadingCount)
            + normalizedCore
            + String(repeating: " ", count: trailingCount)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Template")
                        .font(.custom("Avenir Next", size: 28))
                    
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColor(.sand))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    InputCard(title: "Template Name", text: $title, placeholder: "Push Day", keyboard: .default)
                        .padding(.leading, 24)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                        .onChange(of: title) { _, newValue in
                            let normalized = normalizedTemplateTitle(newValue)
                            if normalized != newValue {
                                title = normalized
                            }
                        }
                }

                templateList

                if validExercises.count < 2 {
                    Text("Templates need at least 2 exercises.")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                VStack(spacing: 10) {
                    Button {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.addTemplate(title: trimmedTitle, exercises: validExercises)
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text("Save Template")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night).opacity(canSave ? 1 : 0.55))
                            .background(themeColor(.sand))
                            .clipShape(Capsule())
                    }
                    .disabled(!canSave)

                    Button {
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private var templateList: some View {
        List {
            ForEach($drafts) { $draft in
                ExerciseEditorRow(
                    draft: $draft,
                    suggestions: store.exerciseNameCatalog(),
                    suggestionDetail: store.muscleGroupLabel(for:),
                    showsMetrics: false,
                    knownType: draft.isTypeLocked ? draft.type : store.exerciseType(for: draft.name),
                    isNameLocked: draft.isNameLocked,
                    isDropSetsEnabled: store.isDropSetsEnabled,
                    isExerciseNotesEnabled: store.isExerciseNotesEnabled,
                    isTodaysNotesEnabled: store.isTodaysNotesEnabled,
                    isSpottingEnabled: store.isSpottingEnabled,
                    latestExerciseForName: { store.latestExerciseRecord(named: $0)?.exercise },
                    exerciseNoteForName: nil,
                    onDelete: {
                        removeDraft(with: draft.id)
                    },
                    onMoveUp: nil,
                    onMoveDown: nil,
                    onNameFocusChange: { isNameFocused = $0 }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .contentShape(Rectangle())
                .onLongPressGesture {
                    editMode = .active
                }
            }
            .onMove { source, destination in
                drafts.move(fromOffsets: source, toOffset: destination)
                editMode = .inactive
            }

            Button {
                Haptics.selection()
                drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Exercise")
                }
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(themeColor(.sand))
            }
            .allowsHitTesting(!isNameFocused)
            .disabled(isNameFocused)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 16, trailing: 16))
            .buttonStyle(.plain)

        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.editMode, $editMode)
    }

    private func removeDraft(with id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            drafts.removeAll { $0.id == id }
            if drafts.isEmpty {
                drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
            }
        }
        Haptics.warning()
    }
}

struct EditTemplateView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var drafts: [ExerciseDraft]
    @State private var editMode: EditMode = .inactive
    @State private var isNameFocused = false
    @State private var isKeyboardVisible = false

    init(store: WorkoutStore, template: WorkoutTemplate) {
        self.store = store
        self.template = template
        _title = State(initialValue: template.title)
        _drafts = State(initialValue: template.exercises.map {
            ExerciseDraft(
                name: $0.name,
                type: $0.type,
                weightUnit: store.defaultWeightUnit
            )
        })
    }

    private var validExercises: [TemplateExercise] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return TemplateExercise(id: UUID(), name: name, type: draft.type, weightKg: nil, sets: nil, repsPerSet: nil)
        }
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && validExercises.count == drafts.count && validExercises.count >= 2
    }

    private func normalizedTemplateTitle(_ value: String) -> String {
        let leadingCount = value.prefix { $0.isWhitespace }.count
        let trailingCount = value.reversed().prefix { $0.isWhitespace }.count
        let core = value.dropFirst(leadingCount).dropLast(trailingCount)
        let normalizedCore = core.lowercased().capitalized
        return String(repeating: " ", count: leadingCount)
            + normalizedCore
            + String(repeating: " ", count: trailingCount)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Edit Template")
                            .font(.custom("Avenir Next", size: 28))
                            .fontWeight(.semibold)
                            .foregroundStyle(themeColor(.sand))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    InputCard(title: "Template Name", text: $title, placeholder: "Push Day", keyboard: .default)
                        .padding(.leading, 24)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                        .onChange(of: title) { _, newValue in
                            let normalized = normalizedTemplateTitle(newValue)
                            if normalized != newValue {
                                title = normalized
                            }
                        }
                }

                List {
                    ForEach($drafts) { $draft in
                        ExerciseEditorRow(
                            draft: $draft,
                            suggestions: store.exerciseNameCatalog(),
                            suggestionDetail: store.muscleGroupLabel(for:),
                            showsMetrics: false,
                            knownType: draft.isTypeLocked ? draft.type : store.exerciseType(for: draft.name),
                            isNameLocked: draft.isNameLocked,
                            isDropSetsEnabled: store.isDropSetsEnabled,
                            isExerciseNotesEnabled: store.isExerciseNotesEnabled,
                            isTodaysNotesEnabled: store.isTodaysNotesEnabled,
                            isSpottingEnabled: store.isSpottingEnabled,
                            latestExerciseForName: { store.latestExerciseRecord(named: $0)?.exercise },
                            exerciseNoteForName: nil,
                            onDelete: {
                                removeDraft(with: draft.id)
                            },
                            onMoveUp: nil,
                            onMoveDown: nil,
                            onNameFocusChange: { isNameFocused = $0 }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            editMode = .active
                        }
                    }
                    .onMove { source, destination in
                        drafts.move(fromOffsets: source, toOffset: destination)
                        editMode = .inactive
                    }

                    Button {
                        Haptics.selection()
                        drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Exercise")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(themeColor(.sand))
                    }
                    .allowsHitTesting(!isNameFocused)
                    .disabled(isNameFocused)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 16, trailing: 16))
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .environment(\.editMode, $editMode)

                if validExercises.count < 2 {
                    Text("Templates need at least 2 exercises.")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themeColor(.sand).opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                VStack(spacing: 10) {
                    Button {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.updateTemplate(id: template.id, title: trimmedTitle, exercises: validExercises)
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text("Save Changes")
                            .font(.custom("Avenir Next", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(themeColor(.night))
                            .background(
                                themeColor(.sand).opacity(canSave ? 1 : 0.55)
                            )
                            .clipShape(Capsule())
                    }
                    .disabled(!canSave)

                    Button {
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
    }

    private func removeDraft(with id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            drafts.removeAll { $0.id == id }
            if drafts.isEmpty {
                drafts.append(ExerciseDraft(weightUnit: store.defaultWeightUnit))
            }
        }
        Haptics.warning()
    }
}
