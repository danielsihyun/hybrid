import SwiftUI
import SwiftData

// MARK: - Set Entry (transient, in-memory during logging)
struct SetEntry: Identifiable {
    let id = UUID()
    var weight: String = ""
    var reps: String = ""
    var committed: Bool = false // true once user has tapped/typed
}

struct ExerciseEntry: Identifiable {
    let id = UUID()
    var planExercise: PlanExercise
    var sets: [SetEntry]
    var lastSession: SessionExercise? // suggestion source
}

// MARK: - LoggingFlowView
struct LoggingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allSessions: [WorkoutSession]

    var workoutDay: WorkoutDay
    var plan: Plan?
    var backfillDate: Date?

    @State private var currentIndex: Int = 0
    @State private var entries: [ExerciseEntry] = []
    @State private var sessionDate: Date = .now
    @State private var showOverview = false
    @State private var showDatePicker = false
    @State private var initialized = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView("No Exercises", systemImage: "dumbbell")
                } else {
                    VStack(spacing: 0) {
                        // Progress header
                        progressHeader

                        TabView(selection: $currentIndex) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                                ExerciseLoggingCard(entry: $entries[idx], suggestion: entries[idx].lastSession)
                                    .tag(idx)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))

                        bottomBar
                    }
                }
            }
            .navigationTitle(workoutDay.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showOverview = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showDatePicker = true
                    } label: {
                        Label("Date", systemImage: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showOverview) {
                SessionOverviewSheet(entries: entries, currentIndex: $currentIndex)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $sessionDate)
            }
            .onAppear {
                if !initialized {
                    initialized = true
                    sessionDate = backfillDate ?? .now
                    buildEntries()
                }
            }
        }
    }

    // MARK: - Sub-views

    private var progressHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Lift \(currentIndex + 1) of \(entries.count)")
                    .font(.subheadline.bold())
                Spacer()
                Text(sessionDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(currentIndex + 1), total: Double(entries.count))
                .tint(.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            if currentIndex > 0 {
                Button {
                    withAnimation { currentIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .background(.secondary.opacity(0.15), in: Circle())
                }
            }

            Spacer()

            if currentIndex < entries.count - 1 {
                Button {
                    withAnimation { currentIndex += 1 }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: Capsule())
                }
            } else {
                Button {
                    finishWorkout()
                } label: {
                    Text("Finish Workout")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.bar)
    }

    // MARK: - Logic

    private func buildEntries() {
        let ordered = workoutDay.orderedExercises
        entries = ordered.map { pe in
            let last = lastSession(for: pe.exercise)
            var sets: [SetEntry] = []
            for _ in 0..<pe.sets {
                sets.append(SetEntry())
            }
            return ExerciseEntry(planExercise: pe, sets: sets, lastSession: last)
        }
    }

    private func lastSession(for exercise: Exercise?) -> SessionExercise? {
        guard let exercise else { return nil }
        for session in allSessions {
            if let found = session.entries.first(where: { $0.exercise?.id == exercise.id }) {
                return found
            }
        }
        return nil
    }

    private func finishWorkout() {
        let session = WorkoutSession(date: sessionDate, plan: plan, workoutDay: workoutDay)
        modelContext.insert(session)

        for entry in entries {
            guard let exercise = entry.planExercise.exercise else { continue }
            // Only log sets that have some data committed
            let committedSets = entry.sets.filter { !$0.weight.isEmpty || !$0.reps.isEmpty }
            guard !committedSets.isEmpty else { continue }

            let weight = Double(committedSets.first?.weight ?? "") ?? 0
            let repsArray = committedSets.map { Int($0.reps) ?? 0 }
            let se = SessionExercise(exercise: exercise, weight: weight, reps: repsArray)
            se.session = session
            modelContext.insert(se)
            session.entries.append(se)
        }

        do {
            try modelContext.save()
        } catch {
            print("Save error: \(error)")
        }
        dismiss()
    }
}

// MARK: - ExerciseLoggingCard
struct ExerciseLoggingCard: View {
    @Binding var entry: ExerciseEntry
    var suggestion: SessionExercise?

    private var suggestionWeight: String {
        guard let s = suggestion, s.weight > 0 else { return "" }
        let unit = s.exercise?.defaultUnit.rawValue ?? "lb"
        return "\(s.weight.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }

    private func suggestionReps(setIndex: Int) -> String {
        guard let s = suggestion, setIndex < s.reps.count else { return "" }
        return "\(s.reps[setIndex])"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Exercise name
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.planExercise.exercise?.name ?? "Exercise")
                        .font(.largeTitle.bold())
                    if let group = entry.planExercise.exercise?.muscleGroup {
                        Text(group.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if let s = suggestion {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Last: \(s.weight.formatted()) \(s.exercise?.defaultUnit.rawValue ?? "lb") · \(s.reps.map(String.init).joined(separator: ", ")) reps")
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                }

                if !entry.planExercise.note.isEmpty {
                    Text(entry.planExercise.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }

                // Sets
                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("Set")
                            .frame(width: 40, alignment: .leading)
                        Text("Weight")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Reps")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { idx, _ in
                        SetRow(
                            setNumber: idx + 1,
                            weightEntry: $entry.sets[idx].weight,
                            repsEntry: $entry.sets[idx].reps,
                            committed: $entry.sets[idx].committed,
                            suggestionWeight: suggestionWeight,
                            suggestionReps: suggestionReps(setIndex: idx)
                        )
                    }
                }

                // Add/remove set
                HStack(spacing: 16) {
                    Button {
                        entry.sets.append(SetEntry())
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .font(.subheadline)
                    }
                    if entry.sets.count > 1 {
                        Button(role: .destructive) {
                            entry.sets.removeLast()
                        } label: {
                            Label("Remove Set", systemImage: "minus")
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - SetRow
struct SetRow: View {
    let setNumber: Int
    @Binding var weightEntry: String
    @Binding var repsEntry: String
    @Binding var committed: Bool
    var suggestionWeight: String
    var suggestionReps: String

    @FocusState private var focusedField: Field?

    enum Field { case weight, reps }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(setNumber)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            // Weight field with gray suggestion
            ZStack(alignment: .leading) {
                if weightEntry.isEmpty && !suggestionWeight.isEmpty {
                    Text(suggestionWeight)
                        .foregroundStyle(.secondary.opacity(0.6))
                        .font(.body)
                        .onTapGesture {
                            weightEntry = String(suggestionWeight.components(separatedBy: " ").first ?? "")
                            committed = true
                            focusedField = .weight
                        }
                }
                TextField("0", text: $weightEntry)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .onChange(of: weightEntry) { _, _ in committed = true }
                    .opacity(weightEntry.isEmpty && !suggestionWeight.isEmpty ? 0 : 1)
            }
            .frame(maxWidth: .infinity)

            // Reps field with gray suggestion
            ZStack(alignment: .trailing) {
                if repsEntry.isEmpty && !suggestionReps.isEmpty {
                    Text(suggestionReps)
                        .foregroundStyle(.secondary.opacity(0.6))
                        .font(.body)
                        .frame(width: 70, alignment: .trailing)
                        .onTapGesture {
                            repsEntry = suggestionReps
                            committed = true
                            focusedField = .reps
                        }
                }
                TextField("0", text: $repsEntry)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .reps)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .onChange(of: repsEntry) { _, _ in committed = true }
                    .opacity(repsEntry.isEmpty && !suggestionReps.isEmpty ? 0 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(setNumber % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
    }
}

// MARK: - Session Overview Sheet
struct SessionOverviewSheet: View {
    var entries: [ExerciseEntry]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    let done = entry.sets.contains { $0.committed && (!$0.weight.isEmpty || !$0.reps.isEmpty) }
                    Button {
                        currentIndex = idx
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(done ? .green : .secondary)
                            Text(entry.planExercise.exercise?.name ?? "Exercise")
                            Spacer()
                            Text("\(entry.sets.count) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Session Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Workout Date", selection: $date, in: ...Date(), displayedComponents: [.date])
                    .datePickerStyle(.graphical)
            }
            .navigationTitle("Backfill Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
