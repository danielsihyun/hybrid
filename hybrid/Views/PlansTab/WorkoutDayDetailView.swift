import SwiftUI
import SwiftData

struct WorkoutDayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutDay: WorkoutDay
    var plan: Plan

    @State private var showExercisePicker = false
    @State private var editingExercise: PlanExercise? = nil

    private var ordered: [PlanExercise] {
        workoutDay.orderedExercises
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            List {
                if ordered.isEmpty {
                    Text("No exercises. Tap + to add from the library.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSubtext)
                        .listRowBackground(Color.appCard)
                } else {
                    ForEach(ordered, id: \.id) { pe in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pe.exercise?.name ?? "Unknown Exercise")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(pe.exercise?.muscleGroup.rawValue ?? "")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.appSubtext)
                                    if !pe.note.isEmpty {
                                        Text("· \(pe.note)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.appSubtext)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            Spacer()
                            // Set count cyan badge
                            Text("\(pe.sets) sets")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.eCyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.eCyan.opacity(0.12))
                                .clipShape(Capsule())
                            Button {
                                editingExercise = pe
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundStyle(Color.eCyan)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCard)
                        .listRowSeparatorTint(Color.appBorder)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeExercise(pe)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: moveExercises)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(workoutDay.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.eCyan)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet { exercise in
                addExercise(exercise)
            }
        }
        .sheet(item: $editingExercise) { pe in
            EditPlanExerciseSheet(planExercise: pe)
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let order = (workoutDay.planExercises.map { $0.order }.max() ?? -1) + 1
        let pe = PlanExercise(exercise: exercise, sets: 3, order: order)
        modelContext.insert(pe)
        workoutDay.planExercises.append(pe)
    }

    private func removeExercise(_ pe: PlanExercise) {
        workoutDay.planExercises.removeAll { $0.id == pe.id }
        modelContext.delete(pe)
        reorderAll()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var reordered = ordered
        reordered.move(fromOffsets: source, toOffset: destination)
        for (idx, pe) in reordered.enumerated() {
            pe.order = idx
        }
    }

    private func reorderAll() {
        for (idx, pe) in ordered.enumerated() {
            pe.order = idx
        }
    }
}

// MARK: - Exercise Picker Sheet (uses ExerciseLibrary inline)
struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    var onSelect: (Exercise) -> Void

    @State private var searchText = ""

    private var grouped: [MuscleGroup: [Exercise]] {
        let filtered = searchText.isEmpty ? exercises : exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return Dictionary(grouping: filtered, by: { $0.muscleGroup })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                List {
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        if let exs = grouped[group], !exs.isEmpty {
                            Section(group.rawValue) {
                                ForEach(exs) { exercise in
                                    Button {
                                        onSelect(exercise)
                                        dismiss()
                                    } label: {
                                        Text(exercise.name)
                                            .foregroundStyle(.white)
                                    }
                                    .listRowBackground(Color.appCard)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Edit Plan Exercise Sheet
struct EditPlanExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var planExercise: PlanExercise

    @State private var setsText: String = ""
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    Text(planExercise.exercise?.name ?? "Unknown")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Section("Sets") {
                    Stepper("\(planExercise.sets) sets", value: $planExercise.sets, in: 1...20)
                }
                Section("Note (optional)") {
                    TextField("e.g. full range of motion", text: $planExercise.note)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.eCyan)
    }
}
