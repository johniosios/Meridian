import SwiftUI

struct AppTabView: View {
    @StateObject private var healthStore = HealthStore()
    @StateObject private var apiConfig = APIConfig()
    @StateObject private var folderStore = FolderStore()
    @StateObject private var notif = NotificationManager()
    @StateObject private var period = AnalysisPeriod()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "house.fill") }

            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

            ChartsView()
                .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(healthStore)
        .environmentObject(apiConfig)
        .environmentObject(folderStore)
        .environmentObject(notif)
        .environmentObject(period)
    }
}
