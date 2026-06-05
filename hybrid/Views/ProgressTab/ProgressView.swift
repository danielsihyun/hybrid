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
            List {
                if exercisesWithHistory.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No History Yet" : "No Results",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(searchText.isEmpty ? "Log workouts to see your progress." : "Try a different search.")
                    )
                } else {
                    ForEach(exercisesWithHistory) { exercise in
                        NavigationLink {
                            ExerciseProgressDetailView(exercise: exercise, sessions: sessions)
                        } label: {
                            ExerciseHistoryRow(exercise: exercise, sessions: sessions)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Progress")
        }
    }
}

// MARK: - ExerciseHistoryRow
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Time range picker
                Picker("Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if dataPoints.isEmpty {
                    ContentUnavailableView("No data in range", systemImage: "chart.line.uptrend.xyaxis")
                        .frame(height: 200)
                } else {
                    // Chart
                    Chart {
                        ForEach(dataPoints) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", point.weight)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.accentColor)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", point.weight)
                            )
                            .foregroundStyle(selectedPoint?.id == point.id ? Color.orange : Color.accentColor)
                            .symbolSize(selectedPoint?.id == point.id ? 120 : 60)
                        }
                    }
                    .chartYAxisLabel(exercise.defaultUnit.rawValue)
                    .frame(height: 220)
                    .padding(.horizontal)
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

                    // Selected point detail
                    if let point = selectedPoint {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(point.date, style: .date)
                                .font(.headline)
                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("Weight")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(point.weight.formatted()) \(point.unit)")
                                        .font(.title3.bold())
                                }
                                VStack(alignment: .leading) {
                                    Text("Reps")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(point.reps.map(String.init).joined(separator: ", "))
                                        .font(.title3.bold())
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // History list
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Session History")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                        ForEach(dataPoints.reversed()) { point in
                            HStack {
                                Text(point.date, style: .date)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(point.weight.formatted()) \(point.unit)")
                                    .font(.subheadline.bold())
                                Text("· \(point.reps.map(String.init).joined(separator: "/"))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            Divider().padding(.leading)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
