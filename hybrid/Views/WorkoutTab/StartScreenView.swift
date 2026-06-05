import SwiftUI
import SwiftData

struct StartScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [Plan]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @State private var showLoggingFlow = false
    @State private var selectedWorkoutDay: WorkoutDay? = nil
    @State private var selectedPlan: Plan? = nil
    @State private var showManualPicker = false
    @State private var showYesterdayOption = false

    private var activePlan: Plan? {
        plans.first { $0.isActive }
    }

    private var todayWeekday: Weekday {
        let cal = Calendar.current
        let idx = cal.component(.weekday, from: Date())
        return Weekday(rawValue: idx) ?? .monday
    }

    private var yesterdayWeekday: Weekday {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let idx = cal.component(.weekday, from: yesterday)
        return Weekday(rawValue: idx) ?? .sunday
    }

    private var todayWorkoutDay: WorkoutDay? {
        activePlan?.workoutDay(for: todayWeekday)
    }

    private var yesterdayWorkoutDay: WorkoutDay? {
        activePlan?.workoutDay(for: yesterdayWeekday)
    }

    private var trainedToday: Bool {
        let cal = Calendar.current
        return sessions.contains { cal.isDateInToday($0.date) }
    }

    private var todaySession: WorkoutSession? {
        let cal = Calendar.current
        return sessions.first { cal.isDateInToday($0.date) }
    }

    private var missedYesterday: Bool {
        guard yesterdayWorkoutDay != nil else { return false }
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return !sessions.contains { cal.isDate($0.date, inSameDayAs: yesterday) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.largeTitle.bold())
                    Text(Date(), style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)

                if trainedToday {
                    trainedTodayView
                } else if let wd = todayWorkoutDay {
                    todayWorkoutView(wd: wd)
                } else if activePlan != nil {
                    restDayView
                } else {
                    noActivePlanView
                }

                // Missed yesterday
                if !trainedToday, missedYesterday, let wd = yesterdayWorkoutDay {
                    Divider().padding(.horizontal, 24).padding(.vertical, 16)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Missed Yesterday")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                        Button {
                            selectedWorkoutDay = wd
                            selectedPlan = activePlan
                            showLoggingFlow = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(wd.name)
                                        .font(.title3.bold())
                                    Text("\(wd.planExercises.count) exercises")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .font(.title2)
                            }
                            .padding()
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()

                // Manual workout
                Button {
                    showManualPicker = true
                } label: {
                    Label("Log Different Workout", systemImage: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showLoggingFlow) {
                if let wd = selectedWorkoutDay {
                    LoggingFlowView(workoutDay: wd, plan: selectedPlan, backfillDate: nil)
                }
            }
            .sheet(isPresented: $showManualPicker) {
                ManualWorkoutPickerView { wd, plan in
                    selectedWorkoutDay = wd
                    selectedPlan = plan
                    showManualPicker = false
                    showLoggingFlow = true
                }
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        default: return "Good evening."
        }
    }

    @ViewBuilder
    private func todayWorkoutView(wd: WorkoutDay) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if let plan = activePlan {
                    Text(plan.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                }
                Button {
                    selectedWorkoutDay = wd
                    selectedPlan = activePlan
                    showLoggingFlow = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start \(wd.name)")
                                .font(.title2.bold())
                            Text("\(wd.planExercises.count) exercises")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                    }
                    .padding(24)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
            }

            // Exercise preview
            if !wd.orderedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(wd.orderedExercises.prefix(4)) { pe in
                        HStack {
                            Text(pe.exercise?.name ?? "Exercise")
                                .font(.subheadline)
                            Spacer()
                            Text("\(pe.sets) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)
                    }
                    if wd.orderedExercises.count > 4 {
                        Text("+ \(wd.orderedExercises.count - 4) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var restDayView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Rest Day")
                .font(.title2.bold())
            Text("Scheduled rest — enjoy the recovery.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var noActivePlanView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Active Plan")
                .font(.title2.bold())
            Text("Set a plan as active in the Plans tab to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    private var trainedTodayView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Workout Complete!")
                .font(.title2.bold())
            if let session = todaySession {
                Text("\(session.entries.count) exercises logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                if let session = todaySession, let wd = session.workoutDay ?? todayWorkoutDay {
                    selectedWorkoutDay = wd
                    selectedPlan = activePlan
                    showLoggingFlow = true
                }
            } label: {
                Label("Edit Today's Workout", systemImage: "pencil")
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }
            .foregroundStyle(.primary)
        }
    }
}

struct ManualWorkoutPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var plans: [Plan]
    var onSelect: (WorkoutDay, Plan?) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(plans) { plan in
                    Section(plan.name) {
                        ForEach(plan.workoutDays) { wd in
                            Button(wd.name) {
                                onSelect(wd, plan)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pick Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
