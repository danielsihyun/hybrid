import SwiftUI
import SwiftData
import Charts

// Note: The tab uses ProgressChartView to avoid conflict with SwiftUI's built-in ProgressView name.
struct ProgressChartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty { return exercises.sorted { $0.name < $1.name } }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }.sorted { $0.name < $1.name }
    }

    private var exercisesWithHistory: [Exercise] {
        filteredExercises.filter { exercise in
            sessions.contains { session in
                session.entries.contains { $0.exercise?.id == exercise.id }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Progress")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.appSubtext)
                        TextField("Search exercises", text: $searchText)
                            .foregroundStyle(.white)
                            .tint(Color.eCyan)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    if exercisesWithHistory.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            searchText.isEmpty ? "No History Yet" : "No Results",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text(searchText.isEmpty ? "Log workouts to see your progress." : "Try a different search.")
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(exercisesWithHistory) { exercise in
                                    NavigationLink {
                                        ExerciseProgressDetailView(exercise: exercise, sessions: sessions)
                                    } label: {
                                        StyledExerciseHistoryRow(exercise: exercise, sessions: sessions)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Styled Exercise History Row
struct StyledExerciseHistoryRow: View {
    var exercise: Exercise
    var sessions: [WorkoutSession]

    private var logCount: Int {
        sessions.filter { s in s.entries.contains { $0.exercise?.id == exercise.id } }.count
    }

    private var lastWeight: Double? {
        for session in sessions {
            if let entry = session.entries.first(where: { $0.exercise?.id == exercise.id }) {
                return entry.weight
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                // Muscle group cyan pill
                Text(exercise.muscleGroup.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.eCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.eCyan.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.eCyan)
                if let w = lastWeight {
                    Text("\(w.formatted()) \(exercise.defaultUnit.rawValue)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appSubtext)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.appBorder, lineWidth: 1)
        )
    }
}

// MARK: - ExerciseHistoryRow (kept for compatibility)
struct ExerciseHistoryRow: View {
    var exercise: Exercise
    var sessions: [WorkoutSession]

    private var logCount: Int {
        sessions.filter { s in s.entries.contains { $0.exercise?.id == exercise.id } }.count
    }

    private var lastWeight: Double? {
        for session in sessions {
            if let entry = session.entries.first(where: { $0.exercise?.id == exercise.id }) {
                return entry.weight
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.headline)
            HStack {
                Text(exercise.muscleGroup.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let w = lastWeight {
                    Text("Last: \(w.formatted()) \(exercise.defaultUnit.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(logCount) sessions")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ExerciseProgressDetailView
struct ExerciseProgressDetailView: View {
    var exercise: Exercise
    var sessions: [WorkoutSession]

    enum TimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"

        var days: Int? {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            case .all: return nil
            }
        }
    }

    @State private var selectedRange: TimeRange = .threeMonths
    @State private var selectedPoint: DataPoint? = nil

    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
        let reps: [Int]
        let unit: String
    }

    private var dataPoints: [DataPoint] {
        let cutoff: Date?
        if let days = selectedRange.days {
            cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        } else {
            cutoff = nil
        }

        return sessions
            .compactMap { session -> DataPoint? in
                guard let entry = session.entries.first(where: { $0.exercise?.id == exercise.id }) else { return nil }
                if let cutoff, session.date < cutoff { return nil }
                return DataPoint(
                    date: session.date,
                    weight: entry.weight,
                    reps: entry.reps,
                    unit: exercise.defaultUnit.rawValue
                )
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Exercise header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.muscleGroup.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.eCyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.eCyan.opacity(0.12))
                            .clipShape(Capsule())

                        Text(exercise.name)
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    // Time range picker
                    HStack(spacing: 0) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            let isSelected = selectedRange == range
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedRange = range
                                }
                            } label: {
                                Text(range.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(isSelected ? Color.eCyan : Color.appSubtext)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? Color.appCard : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.appMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                    if dataPoints.isEmpty {
                        ContentUnavailableView("No data in range", systemImage: "chart.line.uptrend.xyaxis")
                            .frame(height: 200)
                    } else {
                        // Chart card
                        VStack(alignment: .leading, spacing: 12) {
                            Chart {
                                ForEach(dataPoints) { point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Weight", point.weight)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Color.eCyan)

                                    PointMark(
                                        x: .value("Date", point.date),
                                        y: .value("Weight", point.weight)
                                    )
                                    .foregroundStyle(selectedPoint?.id == point.id ? Color.eGreen : Color.eCyan)
                                    .symbolSize(selectedPoint?.id == point.id ? 120 : 60)
                                }
                            }
                            .chartYAxisLabel(exercise.defaultUnit.rawValue)
                            .chartXAxis {
                                AxisMarks(values: .automatic) {
                                    AxisGridLine().foregroundStyle(Color.appBorder)
                                    AxisTick().foregroundStyle(Color.appBorder)
                                    AxisValueLabel().foregroundStyle(Color.appSubtext)
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: .automatic) {
                                    AxisGridLine().foregroundStyle(Color.appBorder)
                                    AxisTick().foregroundStyle(Color.appBorder)
                                    AxisValueLabel().foregroundStyle(Color.appSubtext)
                                }
                            }
                            .frame(height: 220)
                            .chartOverlay { proxy in
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(.clear)
                                        .contentShape(Rectangle())
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                                    if let date: Date = proxy.value(atX: x) {
                                                        selectedPoint = dataPoints.min(by: {
                                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                                        })
                                                    }
                                                }
                                                .onEnded { _ in
                                                    // keep selection
                                                }
                                        )
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.appBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 24)

                        // Selected point detail
                        if let point = selectedPoint {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(point.date, style: .date)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 24) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Weight")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.appSubtext)
                                        Text("\(point.weight.formatted()) \(point.unit)")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Reps")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.appSubtext)
                                        Text(point.reps.map(String.init).joined(separator: ", "))
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appCard)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.appBorder, lineWidth: 1)
                            )
                            .padding(.horizontal, 24)
                        }

                        // History list
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Session History")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.bottom, 2)

                            ForEach(dataPoints.reversed()) { point in
                                HStack {
                                    Text(point.date, style: .date)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.appSubtext)
                                    Spacer()
                                    Text("\(point.weight.formatted()) \(point.unit)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("· \(point.reps.map(String.init).joined(separator: "/"))")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.appSubtext)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.appCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.appBorder, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Back button is auto-rendered; just tint it
                EmptyView()
            }
        }
        .tint(Color.eCyan)
    }
}
