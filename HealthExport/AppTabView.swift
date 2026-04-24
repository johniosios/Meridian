import SwiftUI

struct AppTabView: View {
    @StateObject private var apiConfig = APIConfig()
    @StateObject private var folderStore = FolderStore()
    @StateObject private var notif = NotificationManager()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("今日", systemImage: "house.fill") }

            ContentView()
                .tabItem { Label("导出", systemImage: "square.and.arrow.up") }

            ChartsView()
                .tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gear") }
        }
        .environmentObject(apiConfig)
        .environmentObject(folderStore)
        .environmentObject(notif)
    }
}
