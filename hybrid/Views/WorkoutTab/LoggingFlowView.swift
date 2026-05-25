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
        ZStack {
            Color.appBg.ignoresSafeArea()

            Group {
                if entries.isEmpty {
                    ContentUnavailableView("No Exercises", systemImage: "dumbbell")
                } else {
                    VStack(spacing: 0) {
                        // Progress header
                        progressHeader

                        // Overview panel
                        if showOverview {
                            overviewPanel
                        }

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
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                // X button
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.appMuted)
                            .frame(width: 36, height: 36)
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(workoutDay.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(currentIndex + 1) of \(entries.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appSubtext)
                }

                Spacer()

                // Overview toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showOverview.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.appMuted)
                            .frame(width: 36, height: 36)
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(showOverview ? Color.eCyan : .white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.appCard)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color.appMuted
                    LinearGradient.cyan
                        .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(max(entries.count, 1)))
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Overview Panel

    private var overviewPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    let isActive = idx == currentIndex
                    let isDone = entry.sets.contains { $0.committed && (!$0.weight.isEmpty || !$0.reps.isEmpty) }
                    Button {
                        withAnimation { currentIndex = idx }
                        withAnimation(.easeInOut(duration: 0.25)) { showOverview = false }
                    } label: {
                        HStack(spacing: 8) {
                            // Number badge
                            ZStack {
                                Circle()
                                    .fill(isActive ? .black.opacity(0.3) : Color.appBg)
                                    .frame(width: 24, height: 24)
                                Text("\(idx + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(isActive ? .black : Color.appSubtext)
                            }
                            Text(entry.planExercise.exercise?.name ?? "Exercise")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(isActive ? .black : .white)
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(isActive ? .black : Color.eGreen)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isActive ? LinearGradient.cyan : LinearGradient(colors: [Color.appMuted, Color.appMuted], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.appCard)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.appBorder),
            alignment: .bottom
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentIndex > 0 {
                Button {
                    withAnimation { currentIndex -= 1 }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                        Text("Prev")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(height: 56)
                    .padding(.horizontal, 20)
                    .background(Color.appMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }

            if currentIndex < entries.count - 1 {
                Button {
                    withAnimation { currentIndex += 1 }
                } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color(red: 0, green: 0.851, blue: 1).opacity(0.3), radius: 15)
                }
            } else {
                Button {
                    finishWorkout()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                        Text("Finish Workout")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient.green)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color(red: 0, green: 1, blue: 0.533).opacity(0.3), radius: 15)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.appCard
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.appBorder),
                    alignment: .top
                )
        )
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

    private func acceptWeightSuggestion() {
        guard let s = suggestion, s.weight > 0 else { return }
        let raw = s.weight.formatted(.number.precision(.fractionLength(0...1)))
        for idx in entry.sets.indices {
            if entry.sets[idx].weight.isEmpty {
                entry.sets[idx].weight = raw
                entry.sets[idx].committed = true
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 24) {

                // Exercise header
                VStack(spacing: 10) {
                    // Set count pill
                    Text("\(entry.sets.count) SETS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(LinearGradient.cyan)
                        .clipShape(Capsule())

                    Text(entry.planExercise.exercise?.name ?? "Exercise")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let group = entry.planExercise.exercise?.muscleGroup {
                        Text(group.rawValue)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appSubtext)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Weight input card
                VStack(spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        ZStack(alignment: .center) {
                            LinearGradient(
                                colors: [Color.appCard, Color.appMuted],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .strokeBorder(Color.appBorder, lineWidth: 2)
                            )

                            if entry.sets.indices.contains(0) {
                                WeightFieldOverlay(
                                    weightEntry: $entry.sets[0].weight,
                                    committed: $entry.sets[0].committed,
                                    suggestionWeight: suggestionWeight
                                )
                                .frame(height: 80)
                            }
                        }
                        .frame(height: 100)

                        // "Last: X" badge
                        if !suggestionWeight.isEmpty {
                            Text("Last: \(suggestionWeight)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.eCyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.appCard)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 1))
                                .offset(x: -12, y: -10)
                        }
                    }
                    .padding(.horizontal, 24)

                    // "Use X from last session" button
                    if !suggestionWeight.isEmpty {
                        Button {
                            acceptWeightSuggestion()
                        } label: {
                            Text("Use \(suggestionWeight) from last session")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.eCyan)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.appMuted)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !entry.planExercise.note.isEmpty {
                    Text(entry.planExercise.note)
                        .font(.caption)
                        .foregroundStyle(Color.appSubtext)
                        .padding(.horizontal, 24)
                }

                // Sets section
                VStack(alignment: .leading, spacing: 12) {
                    Text("REPS PER SET")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2.5)
                        .foregroundStyle(Color.appSubtext)
                        .padding(.horizontal, 24)

                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { idx, _ in
                        StyledSetRow(
                            setNumber: idx + 1,
                            weightEntry: $entry.sets[idx].weight,
                            repsEntry: $entry.sets[idx].reps,
                            committed: $entry.sets[idx].committed,
                            suggestionWeight: suggestionWeight,
                            suggestionReps: suggestionReps(setIndex: idx)
                        )
                        .padding(.horizontal, 24)
                    }
                }

                // Add/remove set
                HStack(spacing: 16) {
                    Button {
                        entry.sets.append(SetEntry())
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.eCyan)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.appMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    if entry.sets.count > 1 {
                        Button(role: .destructive) {
                            entry.sets.removeLast()
                        } label: {
                            Label("Remove", systemImage: "minus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.8))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.appMuted)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Color.appBg)
    }
}

// MARK: - Weight Field Overlay (for the large centered weight display)
struct WeightFieldOverlay: View {
    @Binding var weightEntry: String
    @Binding var committed: Bool
    var suggestionWeight: String

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .center) {
            if weightEntry.isEmpty && !suggestionWeight.isEmpty {
                Text(suggestionWeight)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.appSubtext)
                    .onTapGesture {
                        let raw = suggestionWeight.components(separatedBy: " ").first ?? ""
                        weightEntry = raw
                        committed = true
                        isFocused = true
                    }
            }
            TextField("0", text: $weightEntry)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
                .onChange(of: weightEntry) { _, _ in committed = true }
                .opacity(weightEntry.isEmpty && !suggestionWeight.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Styled Set Row
struct StyledSetRow: View {
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
            // Numbered badge
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient.cyan)
                    .frame(width: 36, height: 36)
                Text("\(setNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
            }

            // Weight field with gray suggestion
            ZStack(alignment: .center) {
                if weightEntry.isEmpty && !suggestionWeight.isEmpty {
                    Text(suggestionWeight)
                        .foregroundStyle(Color.appSubtext)
                        .font(.system(size: 24, weight: .semibold))
                        .onTapGesture {
                            weightEntry = String(suggestionWeight.components(separatedBy: " ").first ?? "")
                            committed = true
                            focusedField = .weight
                        }
                }
                TextField("0", text: $weightEntry)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .onChange(of: weightEntry) { _, _ in committed = true }
                    .opacity(weightEntry.isEmpty && !suggestionWeight.isEmpty ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.appBorder, lineWidth: 1))

            // Reps field with gray suggestion
            ZStack(alignment: .center) {
                if repsEntry.isEmpty && !suggestionReps.isEmpty {
                    Text(suggestionReps)
                        .foregroundStyle(Color.appSubtext)
                        .font(.system(size: 24, weight: .semibold))
                        .onTapGesture {
                            repsEntry = suggestionReps
                            committed = true
                            focusedField = .reps
                        }
                }
                TextField("0", text: $repsEntry)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .reps)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .onChange(of: repsEntry) { _, _ in committed = true }
                    .opacity(repsEntry.isEmpty && !suggestionReps.isEmpty ? 0 : 1)
            }
            .frame(width: 80)
            .frame(height: 54)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.appBorder, lineWidth: 1))
        }
    }
}

// MARK: - Session Overview Sheet
struct SessionOverviewSheet: View {
    var entries: [ExerciseEntry]
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                List {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                        let done = entry.sets.contains { $0.committed && (!$0.weight.isEmpty || !$0.reps.isEmpty) }
                        Button {
                            currentIndex = idx
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? Color.eGreen : Color.appSubtext)
                                Text(entry.planExercise.exercise?.name ?? "Exercise")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(entry.sets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(Color.appSubtext)
                            }
                        }
                        .listRowBackground(Color.appCard)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Session Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
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
        .preferredColorScheme(.dark)
    }
}
