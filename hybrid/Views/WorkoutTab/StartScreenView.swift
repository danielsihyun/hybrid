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
    @State private var todayButtonPressed = false

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
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ready to Train?")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.white)
                            Text(subtitleText)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.appSubtext)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        if trainedToday {
                            trainedTodayView
                                .padding(.horizontal, 20)
                        } else if let wd = todayWorkoutDay {
                            todayWorkoutView(wd: wd)
                                .padding(.horizontal, 20)
                        } else if activePlan != nil {
                            restDayView
                                .padding(.horizontal, 20)
                        } else {
                            noActivePlanView
                                .padding(.horizontal, 20)
                        }

                        // Missed yesterday catch-up
                        if !trainedToday, missedYesterday, let wd = yesterdayWorkoutDay {
                            yesterdayCatchupView(wd: wd)
                                .padding(.horizontal, 20)
                        }

                        // Quick Start section
                        quickStartSection
                            .padding(.horizontal, 20)

                        // Manual workout
                        Button {
                            showManualPicker = true
                        } label: {
                            Label("Log Different Workout", systemImage: "pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appSubtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 32)
                    }
                }
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

    private var subtitleText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 5..<12: greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        default: greeting = "Good evening"
        }
        return "\(greeting) · \(Date().formatted(.dateTime.weekday(.wide).month().day()))"
    }

    // MARK: - Today Workout Card

    @ViewBuilder
    private func todayWorkoutView(wd: WorkoutDay) -> some View {
        Button {
            selectedWorkoutDay = wd
            selectedPlan = activePlan
            showLoggingFlow = true
        } label: {
            ZStack {
                LinearGradient.cyan
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TODAY'S WORKOUT")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.black.opacity(0.6))
                        Text(wd.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.black)
                        Text("\(wd.planExercises.count) exercises")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.2))
                            .frame(width: 64, height: 64)
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .shadow(color: Color(red: 0, green: 0.851, blue: 1).opacity(0.3), radius: 15)
            .scaleEffect(todayButtonPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: todayButtonPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in todayButtonPressed = true }
                .onEnded { _ in todayButtonPressed = false }
        )
    }

    // MARK: - Yesterday Catchup

    @ViewBuilder
    private func yesterdayCatchupView(wd: WorkoutDay) -> some View {
        Button {
            selectedWorkoutDay = wd
            selectedPlan = activePlan
            showLoggingFlow = true
        } label: {
            ZStack {
                LinearGradient.purple
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CATCH UP — YESTERDAY")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(wd.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(wd.planExercises.count) exercises")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rest Day

    @ViewBuilder
    private var restDayView: some View {
        ZStack {
            LinearGradient.darkCard
            VStack(spacing: 14) {
                Text("🧘")
                    .font(.system(size: 60))
                Text("Rest Day")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("Scheduled rest — enjoy the recovery.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appSubtext)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32))
    }

    // MARK: - No Active Plan

    @ViewBuilder
    private var noActivePlanView: some View {
        ZStack {
            LinearGradient.darkCard
            VStack(spacing: 14) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.eCyan)
                Text("No Active Plan")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("Set a plan as active in the Plans tab to get started.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appSubtext)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32))
    }

    // MARK: - Trained Today

    @ViewBuilder
    private var trainedTodayView: some View {
        ZStack {
            LinearGradient.darkCard
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.eGreen.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.eGreen)
                }
                Text("Workout Complete!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                if let session = todaySession {
                    Text("\(session.entries.count) exercises logged")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appSubtext)
                }
                Button {
                    if let session = todaySession, let wd = session.workoutDay ?? todayWorkoutDay {
                        selectedWorkoutDay = wd
                        selectedPlan = activePlan
                        showLoggingFlow = true
                    }
                } label: {
                    Label("Edit Today's Workout", systemImage: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.eCyan)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.appMuted, in: Capsule())
                }
            }
            .padding(32)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color(red: 0, green: 1, blue: 0.533).opacity(0.3), radius: 15)
    }

    // MARK: - Quick Start Section

    @ViewBuilder
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("QUICK START")
                .font(.system(size: 12, weight: .bold))
                .tracking(3)
                .foregroundStyle(Color.appSubtext)

            let dotColors: [Color] = [.eCyan, .eGreen, .ePurple, .ePink]

            ForEach(Array(plans.enumerated()), id: \.element.id) { planIdx, plan in
                ForEach(Array(plan.workoutDays.prefix(2).enumerated()), id: \.element.id) { dayIdx, wd in
                    let colorIndex = (planIdx * 2 + dayIdx) % dotColors.count
                    Button {
                        selectedWorkoutDay = wd
                        selectedPlan = plan
                        showLoggingFlow = true
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(dotColors[colorIndex])
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wd.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(plan.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.appSubtext)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appSubtext)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.appBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ManualWorkoutPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var plans: [Plan]
    var onSelect: (WorkoutDay, Plan?) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                List {
                    ForEach(plans) { plan in
                        Section(plan.name) {
                            ForEach(plan.workoutDays) { wd in
                                Button(wd.name) {
                                    onSelect(wd, plan)
                                }
                                .foregroundStyle(Color.eCyan)
                                .listRowBackground(Color.appCard)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Pick Workout")
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
