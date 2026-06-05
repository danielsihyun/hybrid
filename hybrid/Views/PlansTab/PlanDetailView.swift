import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: Plan

    @State private var showNewDaySheet = false
    @State private var newDayName = ""
    @State private var showScheduleEditor = false
    @State private var dayToDelete: WorkoutDay? = nil

    var body: some View {
        List {
            // Schedule section
            Section {
                Button {
                    showScheduleEditor = true
                } label: {
                    HStack {
                        Text("Weekly Schedule")
                        Spacer()
                        weekScheduleSummary
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            } header: {
                Text("Schedule")
            }

            // Workout Days section
            Section {
                if plan.workoutDays.isEmpty {
                    Text("No workout days yet. Tap + to add one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(plan.workoutDays.sorted { $0.name < $1.name }) { day in
                        NavigationLink {
                            WorkoutDayDetailView(workoutDay: day, plan: plan)
                        } label: {
                            HStack {
                                Text(day.name)
                                Spacer()
                                Text("\(day.planExercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteDay(day)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Workout Days")
                    Spacer()
                    Button {
                        showNewDaySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            // Activate section
            Section {
                Toggle("Active Plan", isOn: $plan.isActive)
                    .onChange(of: plan.isActive) { _, newValue in
                        if newValue {
                            // Deactivate others via context
                            activateThisPlan()
                        }
                    }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .alert("New Workout Day", isPresented: $showNewDaySheet) {
            TextField("Day name (e.g. Push, Pull, Legs)", text: $newDayName)
            Button("Add") {
                guard !newDayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let day = WorkoutDay(name: newDayName.trimmingCharacters(in: .whitespaces))
                modelContext.insert(day)
                plan.workoutDays.append(day)
                newDayName = ""
            }
            Button("Cancel", role: .cancel) { newDayName = "" }
        }
        .sheet(isPresented: $showScheduleEditor) {
            ScheduleEditorView(plan: plan)
        }
    }

    private var weekScheduleSummary: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.allCases, id: \.rawValue) { day in
                let hasWorkout = plan.workoutDay(for: day) != nil
                Text(day.short)
                    .font(.caption2.bold())
                    .foregroundStyle(hasWorkout ? .white : .secondary)
                    .frame(width: 26, height: 20)
                    .background(hasWorkout ? Color.accentColor : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func deleteDay(_ day: WorkoutDay) {
        // Remove from schedule
        for weekday in Weekday.allCases {
            if plan.workoutDay(for: weekday)?.id == day.id {
                plan.setWorkoutDay(nil, for: weekday)
            }
        }
        plan.workoutDays.removeAll { $0.id == day.id }
        modelContext.delete(day)
    }

    private func activateThisPlan() {
        let descriptor = FetchDescriptor<Plan>()
        if let allPlans = try? modelContext.fetch(descriptor) {
            for p in allPlans where p.id != plan.id {
                p.isActive = false
            }
        }
    }
}

// MARK: - Schedule Editor
struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var plan: Plan

    var body: some View {
        NavigationStack {
            List {
                ForEach(Weekday.allCases, id: \.rawValue) { weekday in
                    HStack {
                        Text(weekday.name)
                            .frame(width: 110, alignment: .leading)

                        Spacer()

                        Picker("", selection: Binding(
                            get: { plan.workoutDay(for: weekday)?.id },
                            set: { newID in
                                if let newID {
                                    let wd = plan.workoutDays.first { $0.id == newID }
                                    plan.setWorkoutDay(wd, for: weekday)
                                } else {
                                    plan.setWorkoutDay(nil, for: weekday)
                                }
                            }
                        )) {
                            Text("Rest").tag(Optional<UUID>.none)
                            ForEach(plan.workoutDays.sorted { $0.name < $1.name }) { wd in
                                Text(wd.name).tag(Optional(wd.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .navigationTitle("Weekly Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
