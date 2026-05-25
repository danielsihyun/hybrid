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
            ZStack {
                Color.appBg.ignoresSafeArea()

                List {
                    ForEach(plans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("\(plan.workoutDays.count) workout days")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.appSubtext)
                                }
                                Spacer()
                                if plan.isActive {
                                    Text("ACTIVE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundStyle(Color.eCyan)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.eCyan.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.appCard)
                        .listRowSeparatorTint(Color.appBorder)
                        .swipeActions(edge: .leading) {
                            Button {
                                setActive(plan: plan)
                            } label: {
                                Label(plan.isActive ? "Deactivate" : "Set Active", systemImage: plan.isActive ? "xmark.circle" : "checkmark.circle")
                            }
                            .tint(plan.isActive ? .orange : Color.eCyan)
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
                            .tint(Color.eCyan)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewPlan = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.eCyan)
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
