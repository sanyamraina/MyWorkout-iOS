import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: WorkoutStore
    @State private var editingSession: WorkoutSession?
    @State private var templateSeed: TemplateSeed?
    @State private var path: [UUID] = []
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var isDateFilterOn = false
    @State private var filterDate = Date()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [themeColor(.night), themeColor(.coal)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                List {
                    Section {
                        historyFilters
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))

                        if filteredSessions.isEmpty {
                            EmptyStateView()
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))
                        } else {
                            ForEach(filteredSessions) { session in
                                Button {
                                    path.append(session.id)
                                } label: {
                                    WorkoutSessionCard(
                                        session: session,
                                        sessionNumber: sessionNumbers[session.id] ?? 1,
                                        onEdit: { editingSession = session },
                                        onDelete: { store.removeSession(session) },
                                        onSaveTemplate: {
                                            let mergedExercises = session.mergedExercises()
                                            let title = "Template \(store.templates.count + 1)"
                                            let drafts = mergedExercises.map { exercise in
                                                ExerciseDraft(
                                                    name: exercise.name,
                                                    type: exercise.type,
                                                    weightUnit: store.defaultWeightUnit
                                                )
                                            }
                                            let seedDrafts = drafts.isEmpty
                                                ? [ExerciseDraft(weightUnit: store.defaultWeightUnit)]
                                                : drafts
                                            templateSeed = TemplateSeed(title: title, drafts: seedDrafts)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.removeSession(session)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        editingSession = session
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(themedAccent())
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
            }
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .toolbar,
                prompt: "Search exercise or date"
            )
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let session = store.sessions.first(where: { $0.id == id }) {
                    SessionDetailView(
                        session: session,
                        weightUnit: store.defaultWeightUnit,
                        onEdit: { editingSession = session },
                        onDeleteExercise: { exercise in
                            store.removeExercise(exercise, from: session)
                        }
                    )
                }
            }
        }
        .onChange(of: store.sessions) { _, newSessions in
            let validIds = Set(newSessions.map { $0.id })
            if path.contains(where: { !validIds.contains($0) }) {
                path = path.filter { validIds.contains($0) }
            }
        }
        .sheet(item: $editingSession) { session in
            AddWorkoutView(store: store, template: nil, session: session)
        }
        .sheet(item: $templateSeed) { seed in
            AddTemplateView(store: store, seed: seed)
        }
        .onAppear {
            isSearchPresented = false
        }
    }

    private var historyFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isDateFilterOn) {
                Text("Filter by date")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(themedPrimaryText())
            }
            .tint(themedAccent())

            if isDateFilterOn {
                DatePicker(
                    "Date",
                    selection: $filterDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .tint(themedAccent())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColor(.card).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var filteredSessions: [WorkoutSession] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dateFiltered = isDateFilterOn
            ? store.sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: filterDate) }
            : store.sessions
        guard !trimmedQuery.isEmpty else { return dateFiltered }

        return dateFiltered.filter { session in
            let exerciseMatch = session.mergedExercises().contains { exercise in
                exercise.name.lowercased().contains(trimmedQuery)
            }
            if exerciseMatch { return true }
            let dateLabel = relativeLabel(for: session.date).lowercased()
            let dateText = session.date.formatted(date: .abbreviated, time: .omitted).lowercased()
            return dateLabel.contains(trimmedQuery) || dateText.contains(trimmedQuery)
        }
    }

    private var sessionNumbers: [UUID: Int] {
        let grouped = Dictionary(grouping: store.sessions) { session in
            Calendar.current.startOfDay(for: session.date)
        }
        var mapping: [UUID: Int] = [:]
        for (_, sessions) in grouped {
            let ordered = sessions.sorted { $0.date < $1.date }
            for (idx, session) in ordered.enumerated() {
                mapping[session.id] = idx + 1
            }
        }
        return mapping
    }
}

struct WorkoutSessionCard: View {
    let session: WorkoutSession
    let sessionNumber: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSaveTemplate: (() -> Void)?

    init(
        session: WorkoutSession,
        sessionNumber: Int,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onSaveTemplate: (() -> Void)? = nil
    ) {
        self.session = session
        self.sessionNumber = sessionNumber
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onSaveTemplate = onSaveTemplate
    }

    var body: some View {
        let mergedExercises = session.mergedExercises()
        let weightExercises = mergedExercises.filter { $0.type == .weights }
        let cardioExercises = mergedExercises.filter { $0.type == .cardio }
        let isometricExercises = mergedExercises.filter { $0.type == .isometric }
        let totalSets = weightExercises.reduce(0) { $0 + $1.sets.count }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(session.date.formatted(date: .abbreviated, time: .omitted)) • Session \(sessionNumber)")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(themedPrimaryText())
                Spacer()
                Text("\(mergedExercises.count) exercises")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themedSecondaryText())
            }
            HStack(spacing: 12) {
                if totalSets > 0 {
                    TagView(text: "\(totalSets) sets")
                }
                if !cardioExercises.isEmpty {
                    TagView(text: "\(cardioExercises.count) cardio")
                }
                if !isometricExercises.isEmpty {
                    TagView(text: "\(isometricExercises.count) isometric")
                }
                if let first = mergedExercises.first {
                    TagView(text: first.name)
                }
                if mergedExercises.count > 1 {
                    TagView(text: "+\(mergedExercises.count - 1) more")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(mergedExercises.prefix(3)) { exercise in
                    Text(sessionLine(for: exercise))
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(themedSecondaryText())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                )
        )
        .contextMenu {
            if let onSaveTemplate {
                Button {
                    onSaveTemplate()
                } label: {
                    Label("Save as Template", systemImage: "square.and.arrow.down")
                }
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func sessionLine(for exercise: WorkoutExercise) -> String {
        switch exercise.type {
        case .weights:
            return "\(exercise.name) - \(exercise.sets.count) sets"
        case .cardio:
            var details: [String] = []
            if let duration = exercise.durationSeconds, duration > 0 {
                details.append(durationLabel(duration))
            }
            if let calories = exercise.calories, calories > 0 {
                details.append("\(calories) cal")
            }
            if details.isEmpty {
                details.append("Cardio")
            }
            return "\(exercise.name) - \(details.joined(separator: ", "))"
        case .isometric:
            let setCount = exercise.isometricSets.count
            let totalSeconds = exercise.isometricSets.reduce(0) { $0 + $1.durationSeconds }
            let maxWeight = exercise.isometricSets.map(\.weightKg).max() ?? 0
            var details: [String] = ["\(setCount) sets"]
            if totalSeconds > 0 {
                details.append(durationLabel(totalSeconds))
            }
            details.append(maxWeight > 0 ? "Weighted" : "Bodyweight")
            return "\(exercise.name) - \(details.joined(separator: ", "))"
        }
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession
    let weightUnit: WeightUnit
    let onEdit: () -> Void
    let onDeleteExercise: (WorkoutExercise) -> Void
    @State private var exerciseToDelete: WorkoutExercise?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeColor(.night), themeColor(.coal)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            List {
                Section {
                    ForEach(session.mergedExercises()) { exercise in
                        ExerciseDetailCard(exercise: exercise, weightUnit: weightUnit)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    exerciseToDelete = exercise
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    onEdit()
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(themedAccent())
                            }
                    }
                } header: {
                    Text("\(relativeLabel(for: session.date)) • \(sessionTimeRangeLabel(start: session.date, end: session.endDate))")
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.semibold)
                        .foregroundStyle(themedPrimaryText())
                        .textCase(nil)
                        .padding(.top, 8)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    onEdit()
                }
                .foregroundStyle(themedPrimaryText())
            }
        }
        .alert("Delete Exercise?", isPresented: Binding(
            get: { exerciseToDelete != nil },
            set: { if !$0 { exerciseToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let exerciseToDelete {
                    onDeleteExercise(exerciseToDelete)
                }
                exerciseToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                exerciseToDelete = nil
            }
        } message: {
            Text("This removes the exercise from this session.")
        }
    }
}

struct ExerciseDetailCard: View {
    let exercise: WorkoutExercise
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exercise.name)
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(themedPrimaryText())
                Spacer()
                Text(exercise.type.label)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themedSecondaryText())
            }
            if let loggedAt = exercise.loggedAt {
                Text("Time: \(formattedTime(loggedAt))")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(themedSecondaryText())
            }

            switch exercise.type {
            case .weights:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(set.segments.enumerated()), id: \.element.id) { segmentIndex, segment in
                                segmentLineView(setIndex: index, segmentIndex: segmentIndex, segment: segment)
                            }
                        }
                    }
                }
            case .cardio:
                VStack(alignment: .leading, spacing: 6) {
                    if let duration = exercise.durationSeconds, duration > 0 {
                        Text("Duration: \(durationLabel(duration))")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themedSecondaryText())
                    }
                    if let calories = exercise.calories, calories > 0 {
                        Text("Calories: \(calories) cal")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themedSecondaryText())
                    }
                }
            case .isometric:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(exercise.isometricSets.enumerated()), id: \.element.id) { index, set in
                        let weightLabel = set.weightKg > 0
                            ? formattedWeight(set.weightKg, unit: weightUnit)
                            : "Bodyweight"
                        Text("Set \(index + 1): \(durationLabel(set.durationSeconds)) • \(weightLabel)")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(themedSecondaryText())
                    }
                }
            }
            if let entry = exercise.todaysNotes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !entry.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(themedSecondaryText())
                        Text("Today's Notes")
                            .font(.custom("Avenir Next", size: 12))
                            .fontWeight(.medium)
                            .foregroundStyle(themedSecondaryText())
                    }
                    Text(entry)
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(themedPrimaryText())
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeColor(.card).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(themeColor(.card))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(themeColor(.sand).opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func weightLabel(for kg: Double) -> String {
        formattedWeight(kg, unit: weightUnit)
    }

    private func segmentLineView(
        setIndex: Int,
        segmentIndex: Int,
        segment: WorkoutSetSegment
    ) -> some View {
        let base = "\(weightLabel(for: segment.weightKg)) x \(segment.reps)"
        let prefix = segmentIndex == 0 ? "Set \(setIndex + 1): " : "  ↳ "
        let icon = segment.isSpotted
            ? Text(" ") + Text(Image(systemName: "person.2.fill"))
                .font(.system(size: 10, weight: .semibold))
            : Text("")
        return (Text(prefix + base) + icon)
            .font(.custom("Avenir Next", size: 13))
            .foregroundStyle(themedSecondaryText())
     }
}
