import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationManager: ObservableObject {

    private let identifier = "daily-health-insight"
    private let enabledKey = "dailyReminderEnabled"
    private let timeKey = "dailyReminderTime"

    @Published var isAuthorized: Bool = false
    @Published var dailyEnabled: Bool {
        didSet { UserDefaults.standard.set(dailyEnabled, forKey: enabledKey) }
    }
    @Published var dailyTime: Date {
        didSet {
            UserDefaults.standard.set(dailyTime, forKey: timeKey)
            if dailyEnabled { scheduleDailyNotification() }
        }
    }

    /// Set when a notification launched the app — HomeView reads this on appear.
    @Published var shouldAutoRegenerate: Bool = false

    init() {
        self.dailyEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        if let saved = UserDefaults.standard.object(forKey: timeKey) as? Date {
            self.dailyTime = saved
        } else {
            var comps = DateComponents(); comps.hour = 8; comps.minute = 0
            self.dailyTime = Calendar.current.date(from: comps) ?? Date()
        }
        Task { await refreshAuthStatus() }
    }

    func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    func enableDaily() async {
        let granted = isAuthorized ? true : await requestPermission()
        guard granted else {
            dailyEnabled = false
            return
        }
        dailyEnabled = true
        scheduleDailyNotification()
    }

    func disableDaily() {
        dailyEnabled = false
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func triggerNow() async {
        // For testing: fire in 5 seconds.
        let content = buildContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier + "-test", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Update the daily repeating notification's body with the latest AI insight summary.
    /// Called after AI generation completes so tomorrow's push carries fresh content.
    func updateDailyBody(_ bodyText: String) {
        UserDefaults.standard.set(bodyText, forKey: "dailyReminderBody")
        guard dailyEnabled else { return }
        scheduleDailyNotification()
    }

    private func scheduleDailyNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let comps = Calendar.current.dateComponents([.hour, .minute], from: dailyTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: buildContent(), trigger: trigger)

        center.add(request) { err in
            if let err = err { print("Notification schedule error: \(err)") }
        }
    }

    private func buildContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "每日健康"
        let cachedBody = UserDefaults.standard.string(forKey: "dailyReminderBody")
        content.body = cachedBody?.isEmpty == false
            ? cachedBody!
            : "打开查看今日 AI 洞察与健康提醒"
        content.sound = .default
        return content
    }
}

// MARK: - Notification delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Show notifications even when app is foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Triggered when user taps notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            // Signal to app that auto regenerate should run.
            NotificationCenter.default.post(name: .dailyNotificationTapped, object: nil)
            completionHandler()
        }
    }
}

extension Notification.Name {
    static let dailyNotificationTapped = Notification.Name("dailyNotificationTapped")
}
