import SwiftUI
import SwiftData

struct PlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [Plan]

    @State private var showNewPlan = false
    @State private var newPlanName = ""
    @State private var planToRename: Plan? = nil
    @State private var renameText = ""
    @State private var showSettings = false
    @State private var showLibrary = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(plans) { plan in
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.name)
                                    .font(.headline)
                                Text("\(plan.workoutDays.count) workout days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if plan.isActive {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            setActive(plan: plan)
                        } label: {
                            Label(plan.isActive ? "Deactivate" : "Set Active", systemImage: plan.isActive ? "xmark.circle" : "checkmark.circle")
                        }
                        .tint(plan.isActive ? .orange : .green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deletePlan(plan)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            planToRename = plan
                            renameText = plan.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewPlan = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showLibrary = true
                    } label: {
                        Label("Exercise Library", systemImage: "books.vertical")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .alert("New Plan", isPresented: $showNewPlan) {
                TextField("Plan name", text: $newPlanName)
                Button("Create") {
                    guard !newPlanName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let plan = Plan(name: newPlanName.trimmingCharacters(in: .whitespaces))
                    modelContext.insert(plan)
                    newPlanName = ""
                }
                Button("Cancel", role: .cancel) { newPlanName = "" }
            }
            .alert("Rename Plan", isPresented: Binding(get: { planToRename != nil }, set: { if !$0 { planToRename = nil } })) {
                TextField("Plan name", text: $renameText)
                Button("Save") {
                    planToRename?.name = renameText
                    planToRename = nil
                }
                Button("Cancel", role: .cancel) { planToRename = nil }
            }
            .sheet(isPresented: $showLibrary) {
                ExerciseLibraryView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func setActive(plan: Plan) {
        for p in plans { p.isActive = false }
        plan.isActive = true
    }

    private func deletePlan(_ plan: Plan) {
        modelContext.delete(plan)
    }
}
