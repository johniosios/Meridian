import SwiftUI
import UserNotifications

@main
struct MeridianApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup("Meridian") {
            AppTabView()
        }
    }
}
