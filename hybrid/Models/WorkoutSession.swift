import SwiftData
import Foundation

@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    var plan: Plan?
    var workoutDay: WorkoutDay?
    @Relationship(deleteRule: .cascade) var entries: [SessionExercise]

    init(date: Date = .now, plan: Plan?, workoutDay: WorkoutDay?) {
        self.id = UUID()
        self.date = date
        self.plan = plan
        self.workoutDay = workoutDay
        self.entries = []
    }
}
