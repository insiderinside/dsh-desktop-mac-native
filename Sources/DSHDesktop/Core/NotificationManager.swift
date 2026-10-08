import Foundation
import UserNotifications

/// Manages native macOS system notifications via the UserNotifications framework.
public final class NotificationManager: @unchecked Sendable {
    public static let shared = NotificationManager()

    private init() {
        requestAuthorization()
    }

    /// Requests notification permissions from macOS
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[DSHDesktop] Failed to request notification authorization: \(error)")
            }
        }
    }

    /// Dispatches a local banner notification to macOS Notification Center
    public func sendNotification(title: String, subtitle: String? = nil, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[DSHDesktop] Failed to deliver notification: \(error)")
            }
        }
    }
}
