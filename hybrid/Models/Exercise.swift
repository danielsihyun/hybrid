import SwiftData
import Foundation

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case other = "Other"
}

enum WeightUnit: String, Codable, CaseIterable {
    case lb = "lb"
    case kg = "kg"
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var muscleGroup: MuscleGroup
    var defaultUnit: WeightUnit
    var isCustom: Bool

    init(name: String, muscleGroup: MuscleGroup, defaultUnit: WeightUnit = .lb, isCustom: Bool = false) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.defaultUnit = defaultUnit
        self.isCustom = isCustom
    }
}
