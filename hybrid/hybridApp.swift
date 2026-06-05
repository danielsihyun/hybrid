import SwiftUI
import SwiftData

@main
struct hybridApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Exercise.self, Plan.self, WorkoutSession.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        seedStarterDataIfNeeded(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

private func seedStarterDataIfNeeded(container: ModelContainer) {
    guard !UserDefaults.standard.bool(forKey: "hasSeededExercises") else { return }
    let context = ModelContext(container)

    let starterExercises: [(String, MuscleGroup, WeightUnit)] = [
        ("Bench Press", .chest, .lb),
        ("Incline Bench Press", .chest, .lb),
        ("Dumbbell Fly", .chest, .lb),
        ("Pull-Up", .back, .lb),
        ("Barbell Row", .back, .lb),
        ("Lat Pulldown", .back, .lb),
        ("Cable Row", .back, .lb),
        ("Overhead Press", .shoulders, .lb),
        ("Lateral Raise", .shoulders, .lb),
        ("Face Pull", .shoulders, .lb),
        ("Barbell Curl", .biceps, .lb),
        ("Dumbbell Curl", .biceps, .lb),
        ("Hammer Curl", .biceps, .lb),
        ("Tricep Pushdown", .triceps, .lb),
        ("Skull Crusher", .triceps, .lb),
        ("Overhead Tricep Extension", .triceps, .lb),
        ("Squat", .legs, .lb),
        ("Romanian Deadlift", .legs, .lb),
        ("Leg Press", .legs, .lb),
        ("Leg Curl", .legs, .lb),
        ("Plank", .core, .lb),
        ("Ab Wheel Rollout", .core, .lb),
        ("Deadlift", .back, .lb),
    ]

    for (name, group, unit) in starterExercises {
        context.insert(Exercise(name: name, muscleGroup: group, defaultUnit: unit, isCustom: false))
    }

    try? context.save()
    UserDefaults.standard.set(true, forKey: "hasSeededExercises")
}
