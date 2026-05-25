import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var exerciseToDelete: Exercise? = nil

    private var grouped: [MuscleGroup: [Exercise]] {
        let filtered = searchText.isEmpty
            ? exercises
            : exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return Dictionary(grouping: filtered, by: { $0.muscleGroup })
    }

    private var sortedGroups: [MuscleGroup] {
        MuscleGroup.allCases.filter { grouped[$0] != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                List {
                    ForEach(sortedGroups, id: \.self) { group in
                        Section {
                            ForEach(grouped[group] ?? []) { exercise in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                        if exercise.isCustom {
                                            Text("Custom")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.black)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(LinearGradient.cyan)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Spacer()
                                    Text(exercise.defaultUnit.rawValue)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.appSubtext)
                                }
                                .padding(.vertical, 2)
                                .listRowBackground(Color.appCard)
                                .listRowSeparatorTint(Color.appBorder)
                                .swipeActions(edge: .trailing) {
                                    if exercise.isCustom {
                                        Button(role: .destructive) {
                                            modelContext.delete(exercise)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } header: {
                            // Cyan muscle group section header
                            Text(group.rawValue.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Color.eCyan)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.eCyan)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateExerciseSheet()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.eCyan)
    }
}

// MARK: - Create Exercise Sheet
struct CreateExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .other
    @State private var unit: WeightUnit = .lb

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Exercise name", text: $name)
                }
                Section("Muscle Group") {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Default Unit") {
                    Picker("Unit", selection: $unit) {
                        ForEach(WeightUnit.allCases, id: \.self) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let exercise = Exercise(
                            name: name.trimmingCharacters(in: .whitespaces),
                            muscleGroup: muscleGroup,
                            defaultUnit: unit,
                            isCustom: true
                        )
                        modelContext.insert(exercise)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.eCyan)
    }
}
