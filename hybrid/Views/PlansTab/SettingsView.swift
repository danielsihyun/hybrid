import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultWeightUnit") private var defaultWeightUnit: String = WeightUnit.lb.rawValue
    @AppStorage("weekStartDay") private var weekStartDay: Int = 2 // Monday = 2

    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]

    private var selectedUnit: WeightUnit {
        WeightUnit(rawValue: defaultWeightUnit) ?? .lb
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Weights") {
                    Picker("Default Unit", selection: $defaultWeightUnit) {
                        ForEach(WeightUnit.allCases, id: \.rawValue) { unit in
                            Text(unit.rawValue).tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button("Apply unit to all exercises") {
                        applyUnitToAll()
                    }
                    .foregroundStyle(Color.eCyan)
                }

                Section("Calendar") {
                    Picker("Week Starts On", selection: $weekStartDay) {
                        ForEach(Weekday.allCases, id: \.rawValue) { day in
                            Text(day.name).tag(day.rawValue)
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("hybrid")
                            .foregroundStyle(Color.appSubtext)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(Color.appSubtext)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        resetSeedFlag()
                    } label: {
                        Text("Re-seed Exercise Library")
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Re-runs the starter exercise seeding on next launch. Does not delete custom exercises.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.eCyan)
    }

    private func applyUnitToAll() {
        let unit = WeightUnit(rawValue: defaultWeightUnit) ?? .lb
        for exercise in exercises {
            exercise.defaultUnit = unit
        }
        try? modelContext.save()
    }

    private func resetSeedFlag() {
        UserDefaults.standard.removeObject(forKey: "hasSeededExercises")
    }
}
