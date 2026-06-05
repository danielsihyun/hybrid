import SwiftData
import Foundation

@Model
final class PlanExercise {
    var id: UUID
    var exercise: Exercise?
    var sets: Int
    var note: String
    var order: Int

    init(exercise: Exercise, sets: Int, order: Int, note: String = "") {
        self.id = UUID()
        self.exercise = exercise
        self.sets = sets
        self.note = note
        self.order = order
    }
}
