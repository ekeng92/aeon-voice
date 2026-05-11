import Foundation
import UserNotifications
import AppKit

/// Manages native macOS notifications via UNUserNotificationCenter.
///
/// This replaces the osascript approach so notifications appear under
/// "AEON Voice" in System Settings > Notifications (not "Script Editor").
final class NotificationManager: ObservableObject {

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    init() {
        checkAuthorizationStatus()
    }

    /// Request notification permission from macOS. Call when the user
    /// enables the "Show notifications" toggle.
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
            DispatchQueue.main.async {
                self.checkAuthorizationStatus()
            }
        }
    }

    /// Refresh the cached authorization status. Call on popover open.
    func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    /// Send a native notification. Falls back silently if not authorized.
    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    /// Whether notifications are enabled in-app but denied in macOS.
    var isDeniedInSystem: Bool {
        authorizationStatus == .denied
    }

    /// Whether the user has never been asked for permission.
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// Open System Settings > Notifications so the user can enable them.
    static func openNotificationSettings() {
        // macOS Ventura (13+) uses this URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
            NSWorkspace.shared.open(url)
        }
    }
}
