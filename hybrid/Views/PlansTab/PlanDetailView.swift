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
        ZStack {
            Color.appBg.ignoresSafeArea()

            List {
                // Schedule section
                Section {
                    Button {
                        showScheduleEditor = true
                    } label: {
                        HStack {
                            Text("Weekly Schedule")
                                .foregroundStyle(.white)
                            Spacer()
                            weekScheduleSummary
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.appSubtext)
                        }
                    }
                    .listRowBackground(Color.appCard)
                } header: {
                    Text("SCHEDULE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.appSubtext)
                }

                // Workout Days section
                Section {
                    if plan.workoutDays.isEmpty {
                        Text("No workout days yet. Tap + to add one.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSubtext)
                            .listRowBackground(Color.appCard)
                    } else {
                        ForEach(plan.workoutDays.sorted { $0.name < $1.name }) { day in
                            NavigationLink {
                                WorkoutDayDetailView(workoutDay: day, plan: plan)
                            } label: {
                                HStack {
                                    Text(day.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(day.planExercises.count) exercises")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.appSubtext)
                                }
                                .padding(.vertical, 2)
                            }
                            .listRowBackground(Color.appCard)
                            .listRowSeparatorTint(Color.appBorder)
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
                        Text("WORKOUT DAYS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.appSubtext)
                        Spacer()
                        Button {
                            showNewDaySheet = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(Color.eCyan)
                        }
                    }
                }

                // Activate section
                Section {
                    Toggle("Active Plan", isOn: $plan.isActive)
                        .onChange(of: plan.isActive) { _, newValue in
                            if newValue {
                                activateThisPlan()
                            }
                        }
                        .tint(Color.eCyan)
                    .listRowBackground(Color.appCard)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(Color.eCyan)
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(hasWorkout ? .black : Color.appSubtext)
                    .frame(width: 26, height: 20)
                    .background(
                        hasWorkout
                            ? AnyShapeStyle(LinearGradient.cyan)
                            : AnyShapeStyle(Color.appMuted),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
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
            ZStack {
                Color.appBg.ignoresSafeArea()

                List {
                    ForEach(Weekday.allCases, id: \.rawValue) { weekday in
                        HStack {
                            Text(weekday.name)
                                .foregroundStyle(.white)
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
                        .listRowBackground(Color.appCard)
                        .listRowSeparatorTint(Color.appBorder)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Weekly Schedule")
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
