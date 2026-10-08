import Foundation
import UserNotifications

/// Mengelola notifikasi sistem native macOS menggunakan UserNotifications framework.
public final class NotificationManager: @unchecked Sendable {
    public static let shared = NotificationManager()

    private init() {
        requestAuthorization()
    }

    /// Meminta izin notifikasi ke macOS
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[DSHDesktop] Gagal request izin notifikasi: \(error)")
            }
        }
    }

    /// Mengirim notifikasi lokal ke Notification Center macOS
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
                print("[DSHDesktop] Gagal mengirim notifikasi: \(error)")
            }
        }
    }
}
