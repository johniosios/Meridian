import SwiftUI
import UserNotifications

@main
struct HealthExportApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            AppTabView()
        }
    }
}
