import SwiftData
import Foundation

@Model
final class SessionExercise {
    var id: UUID
    var exercise: Exercise?
    var weight: Double
    var reps: [Int]
    var session: WorkoutSession?

    init(exercise: Exercise, weight: Double, reps: [Int]) {
        self.id = UUID()
        self.exercise = exercise
        self.weight = weight
        self.reps = reps
    }
}
