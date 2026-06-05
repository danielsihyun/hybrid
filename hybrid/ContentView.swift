import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StartScreenView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
            ProgressChartView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            PlansView()
                .tabItem { Label("Plans", systemImage: "list.bullet.rectangle") }
        }
    }
}
