import SwiftData
import Foundation

@Model
final class WorkoutDay {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade) var planExercises: [PlanExercise]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.planExercises = []
    }

    var orderedExercises: [PlanExercise] {
        planExercises.sorted { $0.order < $1.order }
    }
}
