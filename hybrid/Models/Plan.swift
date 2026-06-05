import SwiftData
import Foundation

enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    var short: String { String(name.prefix(3)) }
}

@Model
final class Plan {
    var id: UUID
    var name: String
    var isActive: Bool
    @Relationship(deleteRule: .cascade) var workoutDays: [WorkoutDay]
    var scheduleWeekdays: [Int]
    var scheduleWorkoutDayIDs: [UUID]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isActive = false
        self.workoutDays = []
        self.scheduleWeekdays = []
        self.scheduleWorkoutDayIDs = []
    }

    func workoutDay(for weekday: Weekday) -> WorkoutDay? {
        guard let idx = scheduleWeekdays.firstIndex(of: weekday.rawValue) else { return nil }
        let wdID = scheduleWorkoutDayIDs[idx]
        return workoutDays.first { $0.id == wdID }
    }

    func setWorkoutDay(_ workoutDay: WorkoutDay?, for weekday: Weekday) {
        if let idx = scheduleWeekdays.firstIndex(of: weekday.rawValue) {
            scheduleWeekdays.remove(at: idx)
            scheduleWorkoutDayIDs.remove(at: idx)
        }
        if let wd = workoutDay {
            scheduleWeekdays.append(weekday.rawValue)
            scheduleWorkoutDayIDs.append(wd.id)
        }
    }
}
