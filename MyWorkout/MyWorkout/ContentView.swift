//
//  ContentView.swift
//  MyWorkout
//
//  Created by Sanyam Raina on 1/19/26.
//

import SwiftUI
import Combine

struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let weightKg: Double
    let sets: Int
    let repsPerSet: Int
}

struct TemplateExercise: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let weightKg: Double?
    let sets: Int?
    let repsPerSet: Int?
}

struct WorkoutSession: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let exercises: [WorkoutExercise]
}

struct WorkoutTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let exercises: [TemplateExercise]
}

final class WorkoutStore: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var templates: [WorkoutTemplate] = []
    private var hasLoaded = false

    init() {
        load()
    }

    func addSession(date: Date, exercises: [WorkoutExercise]) {
        let session = WorkoutSession(
            id: UUID(),
            date: date,
            exercises: exercises
        )
        sessions.insert(session, at: 0)
        saveSessions()
    }

    func removeSession(_ session: WorkoutSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }

    func addTemplate(title: String, exercises: [TemplateExercise]) {
        let template = WorkoutTemplate(
            id: UUID(),
            title: title,
            exercises: exercises
        )
        templates.insert(template, at: 0)
        saveTemplates()
    }

    func updateTemplate(id: UUID, title: String, exercises: [TemplateExercise]) {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[index] = WorkoutTemplate(id: id, title: title, exercises: exercises)
        saveTemplates()
    }

    func addTemplate(from session: WorkoutSession) {
        let title = "Template \(session.date.formatted(date: .abbreviated, time: .omitted))"
        let exercises = session.exercises.map { exercise in
            TemplateExercise(
                id: UUID(),
                name: exercise.name,
                weightKg: exercise.weightKg,
                sets: exercise.sets,
                repsPerSet: exercise.repsPerSet
            )
        }
        addTemplate(title: title, exercises: exercises)
    }

    func removeTemplate(_ template: WorkoutTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }

    func resolvedDrafts(for template: WorkoutTemplate) -> [ExerciseDraft] {
        template.exercises.map { exercise in
            let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let latest = latestExerciseRecord(named: trimmedName) {
                return ExerciseDraft(
                    name: latest.exercise.name,
                    weight: latest.exercise.weightKg == 0 ? "" : String(format: "%.1f", latest.exercise.weightKg),
                    sets: "\(latest.exercise.sets)",
                    reps: "\(latest.exercise.repsPerSet)"
                )
            }
            return ExerciseDraft(
                name: trimmedName,
                weight: formattedOptionalWeight(exercise.weightKg),
                sets: formattedOptionalInt(exercise.sets),
                reps: formattedOptionalInt(exercise.repsPerSet)
            )
        }
    }

    func latestExerciseRecord(named name: String) -> (exercise: WorkoutExercise, date: Date)? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }

        var latest: (date: Date, exercise: WorkoutExercise)?
        for session in sessions {
            for exercise in session.exercises {
                let exerciseKey = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard exerciseKey == key else { continue }
                if let current = latest {
                    if session.date >= current.date {
                        latest = (session.date, exercise)
                    }
                } else {
                    latest = (session.date, exercise)
                }
            }
        }
        return latest
    }

    func exerciseNameCatalog() -> [String] {
        let sessionNames = sessions.flatMap { $0.exercises.map { $0.name } }
        let templateNames = templates.flatMap { $0.exercises.map { $0.name } }
        let combined = sessionNames + templateNames
        let unique = Dictionary(grouping: combined, by: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            .compactMap { $0.value.first }
        return unique
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    private func formattedOptionalWeight(_ value: Double?) -> String {
        guard let value else { return "" }
        return value == 0 ? "" : String(format: "%.1f", value)
    }

    private func formattedOptionalInt(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private func load() {
        sessions = loadSessions()
        templates = loadTemplates()
        hasLoaded = true
    }

    private func loadSessions() -> [WorkoutSession] {
        do {
            let data = try Data(contentsOf: sessionsFileURL())
            return try JSONDecoder().decode([WorkoutSession].self, from: data)
        } catch {
            do {
                let data = try Data(contentsOf: sessionsFileURL())
                let legacy = try JSONDecoder().decode([LegacyWorkoutEntry].self, from: data)
                return legacy.map { entry in
                    WorkoutSession(
                        id: entry.id,
                        date: entry.date,
                        exercises: [
                            WorkoutExercise(
                                id: UUID(),
                                name: entry.name,
                                weightKg: entry.weightKg,
                                sets: entry.sets,
                                repsPerSet: entry.repsPerSet
                            )
                        ]
                    )
                }
            } catch {
                return []
            }
        }
    }

    private func loadTemplates() -> [WorkoutTemplate] {
        do {
            let data = try Data(contentsOf: templatesFileURL())
            return try JSONDecoder().decode([WorkoutTemplate].self, from: data)
        } catch {
            do {
                let data = try Data(contentsOf: templatesFileURL())
                let legacy = try JSONDecoder().decode([LegacyWorkoutTemplate].self, from: data)
                return legacy.map { template in
                    WorkoutTemplate(
                        id: template.id,
                        title: template.name,
                        exercises: [
                            TemplateExercise(
                                id: UUID(),
                                name: template.name,
                                weightKg: template.weightKg,
                                sets: template.sets,
                                repsPerSet: template.repsPerSet
                            )
                        ]
                    )
                }
            } catch {
                return []
            }
        }
    }

    private func saveSessions() {
        guard hasLoaded else { return }
        do {
            let data = try JSONEncoder().encode(sessions)
            let url = sessionsFileURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            // Ignore write failures; user can continue without persistence.
        }
    }

    private func saveTemplates() {
        guard hasLoaded else { return }
        do {
            let data = try JSONEncoder().encode(templates)
            let url = templatesFileURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            // Ignore write failures; user can continue without persistence.
        }
    }

    private func sessionsFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/workouts.json")
    }

    private func templatesFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MyWorkout/templates.json")
    }

    private struct LegacyWorkoutEntry: Codable {
        let id: UUID
        let name: String
        let weightKg: Double
        let sets: Int
        let repsPerSet: Int
        let date: Date
    }

    private struct LegacyWorkoutTemplate: Codable {
        let id: UUID
        let name: String
        let weightKg: Double
        let sets: Int
        let repsPerSet: Int
    }
}

struct ContentView: View {
    @StateObject private var store = WorkoutStore()

    var body: some View {
        TabView {
            HomeView(store: store)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ExercisesView(store: store)
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet")
                }
        }
    }
}

struct HomeView: View {
    @ObservedObject var store: WorkoutStore
    @State private var showingAdd = false
    @State private var showingTemplateAdd = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var draftFromTemplate: WorkoutTemplate?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    stats
                    templatesSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            addButton
        }
        .sheet(isPresented: $showingAdd, onDismiss: { draftFromTemplate = nil }) {
            AddWorkoutView(store: store, template: draftFromTemplate)
        }
        .sheet(isPresented: $showingTemplateAdd) {
            AddTemplateView(store: store)
        }
        .sheet(item: $editingTemplate) { template in
            EditTemplateView(store: store, template: template)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MyWorkout")
                .font(.custom("Avenir Next", size: 34))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))
            Text("Track what you lift, keep it simple.")
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(Color("Sand").opacity(0.7))
        }
    }

    private var stats: some View {
        let totalSets = store.sessions.reduce(0) { total, session in
            total + session.exercises.reduce(0) { $0 + $1.sets }
        }
        return HStack(spacing: 12) {
            StatCard(title: "Workouts", value: "\(store.sessions.count)")
            StatCard(title: "Total Sets", value: "\(totalSets)")
        }
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.sessions.isEmpty {
                EmptyStateView()
            } else {
                ForEach(store.sessions) { session in
                    WorkoutSessionCard(
                        session: session,
                        onDelete: { store.removeSession(session) },
                        onSaveTemplate: { store.addTemplate(from: session) }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: store.sessions)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))
            sessionsList
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Templates")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Spacer()
                Button {
                    showingTemplateAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(Color("Sand"))
                }
            }

            if store.templates.isEmpty {
                Text("Create a template to reuse your go-to workouts.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.templates) { template in
                            TemplateCard(
                                template: template,
                                onUse: {
                                    draftFromTemplate = template
                                    showingAdd = true
                                },
                                onEdit: {
                                    editingTemplate = template
                                },
                                onDelete: {
                                    store.removeTemplate(template)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Workout")
            }
            .font(.custom("Avenir Next", size: 18))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color("Night"))
            .background(Color("Sand"))
            .clipShape(Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Color("Night").opacity(0.001))
    }
}

struct ExercisesView: View {
    @ObservedObject var store: WorkoutStore
    @State private var searchText = ""

    private var filteredNames: [String] {
        let names = store.exerciseNameCatalog()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return names }
        return names.filter { $0.lowercased().contains(query) }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises")
                        .font(.custom("Avenir Next", size: 30))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("Sand"))

                    SearchField(text: $searchText, placeholder: "Search exercises")

                    if store.exerciseNameCatalog().isEmpty {
                        Text("No exercises yet. Add a workout to start your log.")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(Color("Sand").opacity(0.6))
                    } else {
                        ForEach(filteredNames, id: \.self) { name in
                            ExerciseHistoryCard(name: name, record: store.latestExerciseRecord(named: name))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
    }
}

struct ExerciseHistoryCard: View {
    let name: String
    let record: (exercise: WorkoutExercise, date: Date)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))

            if let record {
                Text("Last used \(record.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))

                HStack(spacing: 12) {
                    TagView(text: String(format: "%.1f kg", record.exercise.weightKg))
                    TagView(text: "\(record.exercise.sets) sets")
                    TagView(text: "\(record.exercise.repsPerSet) reps")
                }
            } else {
                Text("No logged workout yet")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card").opacity(0.9))
        )
    }
}

struct ExerciseDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var weight: String
    var sets: String
    var reps: String

    init(id: UUID = UUID(), name: String = "", weight: String = "", sets: String = "", reps: String = "") {
        self.id = id
        self.name = name
        self.weight = weight
        self.sets = sets
        self.reps = reps
    }
}

struct AddWorkoutView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate?
    @Environment(\.dismiss) private var dismiss

    @State private var workoutDate = Date()
    @State private var drafts: [ExerciseDraft] = []

    private var validExercises: [WorkoutExercise] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let setsValue = Int(draft.sets) ?? 0
            let repsValue = Int(draft.reps) ?? 0
            let weightValue = Double(draft.weight) ?? 0
            guard setsValue > 0, repsValue > 0, weightValue >= 0 else { return nil }
            return WorkoutExercise(
                id: UUID(),
                name: name,
                weightKg: weightValue,
                sets: setsValue,
                repsPerSet: repsValue
            )
        }
    }

    private var canSave: Bool {
        !drafts.isEmpty && validExercises.count == drafts.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("New Workout")
                            .font(.custom("Avenir Next", size: 28))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("Sand"))

                        datePickerCard

                        ForEach($drafts) { $draft in
                            ExerciseEditorRow(
                                draft: $draft,
                                suggestions: store.exerciseNameCatalog(),
                                showsMetrics: true,
                                onDelete: {
                                    drafts.removeAll { $0.id == draft.id }
                                },
                                onMoveUp: nil,
                                onMoveDown: nil
                            )
                        }

                        Button {
                            drafts.append(ExerciseDraft())
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Exercise")
                            }
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(Color("Sand"))
                        }
                    }
                    .padding(24)
                }

                Button {
                    store.addSession(date: workoutDate, exercises: validExercises)
                    dismiss()
                } label: {
                    Text("Save Workout")
                        .font(.custom("Avenir Next", size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color("Night"))
                        .background(Color("Sand"))
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
            }
        }
        .onAppear {
            if drafts.isEmpty {
                if let template {
                    drafts = store.resolvedDrafts(for: template)
                } else {
                    drafts = [ExerciseDraft()]
                }
            }
        }
    }

    private var datePickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color("Sand").opacity(0.6))
            HStack {
                Text(relativeLabel(for: workoutDate))
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(Color("Sand"))
                Spacer()
                DatePicker(
                    "",
                    selection: $workoutDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .colorScheme(.dark)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("Card"))
            )
        }
    }

    private func relativeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct ExerciseEditorRow: View {
    @Binding var draft: ExerciseDraft
    let suggestions: [String]
    let showsMetrics: Bool
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercise")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))
                Spacer()
                if let onMoveUp {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(Color("Sand").opacity(0.7))
                    }
                }
                if let onMoveDown {
                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(Color("Sand").opacity(0.7))
                    }
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color("Sand").opacity(0.7))
                }
            }

            ExerciseNameField(title: "Name", text: $draft.name, suggestions: suggestions)

            if showsMetrics {
                InputCard(title: "Weight (kg)", text: $draft.weight, placeholder: "10", keyboard: .decimalPad)
                HStack(spacing: 12) {
                    InputCard(title: "Sets", text: $draft.sets, placeholder: "3", keyboard: .numberPad)
                    InputCard(title: "Reps / Set", text: $draft.reps, placeholder: "10", keyboard: .numberPad)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card"))
        )
    }
}

struct WorkoutSessionCard: View {
    let session: WorkoutSession
    let onDelete: () -> Void
    let onSaveTemplate: (() -> Void)?

    init(session: WorkoutSession, onDelete: @escaping () -> Void, onSaveTemplate: (() -> Void)? = nil) {
        self.session = session
        self.onDelete = onDelete
        self.onSaveTemplate = onSaveTemplate
    }

    var body: some View {
        let totalSets = session.exercises.reduce(0) { $0 + $1.sets }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Spacer()
                Text("\(session.exercises.count) exercises")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.6))
            }

            HStack(spacing: 12) {
                TagView(text: "\(totalSets) sets")
                if let first = session.exercises.first {
                    TagView(text: first.name)
                }
                if session.exercises.count > 1 {
                    TagView(text: "+\(session.exercises.count - 1) more")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(session.exercises.prefix(3)) { exercise in
                    Text("\(exercise.name) - \(exercise.sets)x\(exercise.repsPerSet)")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Color("Sand").opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("Sand").opacity(0.08), lineWidth: 1)
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
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color("Sand").opacity(0.6))
            Text(value)
                .font(.custom("Avenir Next", size: 22))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("Card").opacity(0.8))
        )
    }
}

struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("Avenir Next", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color("Sand").opacity(0.12))
            )
            .foregroundStyle(Color("Sand"))
    }
}

struct ExerciseNameField: View {
    let title: String
    @Binding var text: String
    let suggestions: [String]
    @FocusState private var isFocused: Bool

    private var matches: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return suggestions
            .filter { $0.lowercased().contains(query) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color("Sand").opacity(0.6))
            TextField("Bicep Curls", text: $text)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(Color("Sand"))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color("Card"))
                )
                .focused($isFocused)

            if isFocused && !matches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(matches, id: \.self) { name in
                        Button {
                            text = name
                            isFocused = false
                        } label: {
                            Text(name)
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(Color("Sand"))
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("Card").opacity(0.95))
                )
            }
        }
    }
}

struct InputCard: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Color("Sand").opacity(0.6))
            TextField(placeholder, text: $text)
                .font(.custom("Avenir Next", size: 16))
                .keyboardType(keyboard)
                .foregroundStyle(Color("Sand"))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color("Card"))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No workouts yet")
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.semibold)
                .foregroundStyle(Color("Sand"))
            Text("Add a workout or create a template to get started.")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(Color("Sand").opacity(0.6))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Card").opacity(0.8))
        )
    }
}

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onUse: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onUse) {
            VStack(alignment: .leading, spacing: 8) {
                Text(template.title)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Sand"))
                Text("\(template.exercises.count) exercises")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(Color("Sand").opacity(0.7))
                if let first = template.exercises.first {
                    Text("Starts with \(first.name)")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Color("Sand").opacity(0.6))
                }
            }
            .padding(14)
            .frame(width: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("Card").opacity(0.9))
            )
        }
        .contextMenu {
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
}

struct AddTemplateView: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var drafts: [ExerciseDraft] = [ExerciseDraft()]

    private var validExercises: [TemplateExercise] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let weightValue = draft.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : Double(draft.weight)
            let setsValue = draft.sets.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : Int(draft.sets)
            let repsValue = draft.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : Int(draft.reps)

            if let weightValue, weightValue < 0 { return nil }
            if let setsValue, setsValue <= 0 { return nil }
            if let repsValue, repsValue <= 0 { return nil }

            return TemplateExercise(
                id: UUID(),
                name: name,
                weightKg: weightValue,
                sets: setsValue,
                repsPerSet: repsValue
            )
        }
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && validExercises.count == drafts.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("New Template")
                            .font(.custom("Avenir Next", size: 28))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("Sand"))

                        InputCard(title: "Template Name", text: $title, placeholder: "Push Day", keyboard: .default)

                        ForEach($drafts) { $draft in
                            ExerciseEditorRow(
                                draft: $draft,
                                suggestions: store.exerciseNameCatalog(),
                                showsMetrics: false,
                                onDelete: {
                                    drafts.removeAll { $0.id == draft.id }
                                    if drafts.isEmpty {
                                        drafts.append(ExerciseDraft())
                                    }
                                },
                                onMoveUp: nil,
                                onMoveDown: nil
                            )
                        }

                        Button {
                            drafts.append(ExerciseDraft())
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Exercise")
                            }
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(Color("Sand"))
                        }
                    }
                    .padding(24)
                }

                Button {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.addTemplate(title: trimmedTitle, exercises: validExercises)
                    dismiss()
                } label: {
                    Text("Save Template")
                        .font(.custom("Avenir Next", size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color("Night"))
                        .background(Color("Sand"))
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
            }
        }
    }
}

struct EditTemplateView: View {
    @ObservedObject var store: WorkoutStore
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var drafts: [ExerciseDraft]
    @State private var editMode: EditMode = .active

    init(store: WorkoutStore, template: WorkoutTemplate) {
        self.store = store
        self.template = template
        _title = State(initialValue: template.title)
        _drafts = State(initialValue: template.exercises.map {
            ExerciseDraft(
                name: $0.name,
                weight: "",
                sets: "",
                reps: ""
            )
        })
    }

    private var validExercises: [TemplateExercise] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return TemplateExercise(id: UUID(), name: name, weightKg: nil, sets: nil, repsPerSet: nil)
        }
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && validExercises.count == drafts.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("Night"), Color("Coal")],
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
                            .foregroundStyle(Color("Sand"))
                        Spacer()
                        Button {
                            editMode = (editMode == .active) ? .inactive : .active
                        } label: {
                            Text(editMode == .active ? "Done" : "Reorder")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(Color("Sand"))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    InputCard(title: "Template Name", text: $title, placeholder: "Push Day", keyboard: .default)
                        .padding(.horizontal, 24)
                }

                List {
                    ForEach($drafts) { $draft in
                        ExerciseEditorRow(
                            draft: $draft,
                            suggestions: store.exerciseNameCatalog(),
                            showsMetrics: false,
                            onDelete: {
                                drafts.removeAll { $0.id == draft.id }
                                if drafts.isEmpty {
                                    drafts.append(ExerciseDraft())
                                }
                            },
                            onMoveUp: nil,
                            onMoveDown: nil
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                        .listRowBackground(Color("Night"))
                    }
                    .onMove { source, destination in
                        drafts.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        drafts.append(ExerciseDraft())
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Exercise")
                        }
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundStyle(Color("Sand"))
                    }
                    .listRowBackground(Color("Night"))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)

                Button {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.updateTemplate(id: template.id, title: trimmedTitle, exercises: validExercises)
                    dismiss()
                } label: {
                    Text("Save Changes")
                        .font(.custom("Avenir Next", size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color("Night"))
                        .background(Color("Sand"))
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("Sand").opacity(0.6))
            TextField(placeholder, text: $text)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(Color("Sand"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("Card"))
        )
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
