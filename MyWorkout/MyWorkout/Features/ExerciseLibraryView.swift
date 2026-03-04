import SwiftUI

struct ExerciseLibraryView: View {
    private enum ExploreSection: String, CaseIterable, Identifiable {
        case exercises = "Exercises"
        case notes = "Notes"

        var id: Self { self }
    }

    @ObservedObject var store: WorkoutStore
    @State private var searchText = ""
    @State private var draftTemplate: WorkoutTemplate?
    @State private var templateSeed: TemplateSeed?
    @State private var isSelecting = false
    @State private var selectedExerciseNames: [String] = []
    @State private var exploreSection: ExploreSection = .exercises
    @State private var isSearchPresented = false

    struct ExerciseNoteEntry: Identifiable {
        let id = UUID()
        let name: String
        let exerciseNote: String
    }

    private var exerciseNoteEntries: [ExerciseNoteEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let entries = store.exerciseNotesList().map { entry in
            ExerciseNoteEntry(name: displayName(for: entry.name), exerciseNote: entry.exerciseNote)
        }
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            entry.name.lowercased().contains(query) || entry.exerciseNote.lowercased().contains(query)
        }
    }

    private func displayName(for key: String) -> String {
        if let match = store.exerciseLibrary.first(where: { $0.name.lowercased() == key.lowercased() }) {
            return match.name
        }
        if let record = store.latestExerciseRecord(named: key) {
            return record.exercise.name
        }
        return key
    }

    private var groupedExercises: [MuscleGroup: [LibraryExercise]] {
        let filtered = store.exerciseLibrary.filter { exercise in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return exercise.name.lowercased().contains(query.lowercased())
        }
        return Dictionary(grouping: filtered, by: \.group)
    }

    private var orderedGroups: [MuscleGroup] {
        MuscleGroup.allCases.filter { group in
            (groupedExercises[group] ?? []).isEmpty == false
        }
    }

    private var searchPlaceholder: String {
        exploreSection == .exercises ? "Search exercises" : "Search notes"
    }

    private var exploreHeaderTitle: String {
        exploreSection == .exercises ? "Explore" : "Exercise Notes"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [themeColor(.night), themeColor(.coal)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                List {
                    Section {
                        HStack {
                            Text(exploreHeaderTitle)
                                .font(.custom("Avenir Next", size: 28))
                                .fontWeight(.semibold)
                                .foregroundStyle(themedPrimaryText())
                            Spacer()
                            if exploreSection == .exercises {
                                if isSelecting {
                                    Button("Finish") {
                                        Haptics.primaryAction()
                                        createTemplateFromSelection()
                                    }
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(themedAccentForeground())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(themeColor(.sand))
                                    .clipShape(Capsule())
                                    .disabled(selectedExerciseNames.isEmpty)
                                    .opacity(selectedExerciseNames.isEmpty ? 0.5 : 1)
                                }
                                Button {
                                    if isSelecting {
                                        selectedExerciseNames = []
                                    }
                                    Haptics.selection()
                                    isSelecting.toggle()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isSelecting ? "xmark.circle" : "checklist")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(isSelecting ? "Cancel" : "Create Template")
                                    }
                                }
                                .font(.custom("Avenir Next", size: 12))
                                .foregroundStyle(themedSecondaryText())
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 6, trailing: 20))

                        VStack(spacing: 10) {
                            exploreSectionToggle
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                    }

                    if exploreSection == .notes {
                        if store.isExerciseNotesEnabled, !exerciseNoteEntries.isEmpty {
                            Section {
                                ForEach(exerciseNoteEntries) { entry in
                                    noteRow(entry)
                                }
                            } header: {
                                HStack(spacing: 10) {
                                    Capsule()
                                        .fill(themeColor(.sand).opacity(0.18))
                                        .frame(width: 18, height: 6)
                                    Text("EXERCISE NOTES")
                                        .font(.custom("Avenir Next", size: 13))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(themedSecondaryText())
                                }
                                .padding(.top, 8)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                        } else {
                            emptyStateRow("No exercise notes yet.")
                        }
                    } else {
                        ForEach(orderedGroups, id: \.self) { group in
                            Section {
                                ForEach(groupedExercises[group] ?? []) { exercise in
                                    exerciseRow(exercise)
                                }
                            } header: {
                                HStack(spacing: 10) {
                                    Capsule()
                                        .fill(themeColor(.sand).opacity(0.18))
                                        .frame(width: 18, height: 6)
                                    Text(group.rawValue.uppercased())
                                        .font(.custom("Avenir Next", size: 13))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(themedSecondaryText())
                                }
                                .padding(.top, 8)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
            }
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .toolbar,
                prompt: searchPlaceholder
            )
            .navigationTitle(" ")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $draftTemplate) { template in
            LiveWorkoutView(store: store, template: template)
        }
        .sheet(item: $templateSeed) { seed in
            AddTemplateView(store: store, seed: seed)
        }
        .onChange(of: exploreSection) { _, section in
            isSearchPresented = false
            guard section == .exercises else {
                isSelecting = false
                selectedExerciseNames = []
                return
            }
        }
        .onAppear {
            if !searchText.isEmpty {
                searchText = ""
            }
            isSearchPresented = false
        }
    }

    private func startQuickWorkout(for name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        Haptics.selection()
        let type = store.exerciseType(for: trimmedName) ?? .weights
        draftTemplate = WorkoutTemplate(
            id: UUID(),
            title: "Explore",
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

    private func isSelected(_ name: String) -> Bool {
        selectedExerciseNames.contains(name)
    }

    private func toggleSelection(for exercise: LibraryExercise) {
        let name = exercise.name
        if let index = selectedExerciseNames.firstIndex(of: name) {
            selectedExerciseNames.remove(at: index)
        } else {
            selectedExerciseNames.append(name)
        }
    }

    private func createTemplateFromSelection() {
        let names = selectedExerciseNames
        guard !names.isEmpty else { return }
        let drafts = names.map { name -> ExerciseDraft in
            let type = store.exerciseType(for: name) ?? .weights
            return ExerciseDraft(
                name: name,
                type: type,
                weightUnit: store.defaultWeightUnit
            )
        }
        let seedDrafts = drafts.isEmpty ? [ExerciseDraft(weightUnit: store.defaultWeightUnit)] : drafts
        let title = "Template \(store.templates.count + 1)"
        templateSeed = TemplateSeed(title: title, drafts: seedDrafts)
        Haptics.success()
        selectedExerciseNames = []
        isSelecting = false
    }

    private func exerciseRow(_ exercise: LibraryExercise) -> some View {
        Button {
            if isSelecting {
                Haptics.selection()
                toggleSelection(for: exercise)
            } else {
                startQuickWorkout(for: exercise.name)
            }
        } label: {
            HStack {
                Text(exercise.name)
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(themedPrimaryText())
                Spacer()
                if isSelecting {
                    Image(systemName: isSelected(exercise.name) ? "checkmark.circle.fill" : "circle")
                        .font(.custom("Avenir Next", size: 15))
                        .foregroundStyle(isSelected(exercise.name) ? themeColor(.sand) : themedSecondaryText())
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(themedSecondaryText())
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelecting && isSelected(exercise.name)
                        ? themeColor(.sand).opacity(0.12)
                        : themeColor(.card).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }

    private func noteRow(_ entry: ExerciseNoteEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themedSecondaryText())
                Text(entry.name)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.medium)
                    .foregroundStyle(themedPrimaryText())
            }
            Text(entry.exerciseNote)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(themedSecondaryText())
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
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
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }

    private func emptyStateRow(_ text: String) -> some View {
        Text(text)
            .font(.custom("Avenir Next", size: 14))
            .foregroundStyle(themedSecondaryText())
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
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 6, trailing: 20))
    }

    private var exploreSectionToggle: some View {
        HStack(spacing: 8) {
            exploreSectionButton(for: .exercises, icon: "figure.strengthtraining.traditional")
            exploreSectionButton(for: .notes, icon: "note.text")
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColor(.card).opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeColor(.sand).opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func exploreSectionButton(for section: ExploreSection, icon: String) -> some View {
        let isSelected = exploreSection == section
        return Button {
            guard exploreSection != section else { return }
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                exploreSection = section
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(section.rawValue)
                    .font(.custom("Avenir Next", size: 13))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? themedAccentForeground() : themedSecondaryText())
            .background(
                Capsule()
                    .fill(isSelected ? themeColor(.sand) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(themeColor(.sand).opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
