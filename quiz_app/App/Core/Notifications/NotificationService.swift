//
//  NotificationService.swift
//  quiz_app
//
//  Promemoria locale "ripasso del giorno". Le notifiche locali non richiedono capability:
//  serve solo l'autorizzazione runtime dell'utente.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled); reschedule() }
    }
    @Published var reminderTime: Date {
        didSet { UserDefaults.standard.set(reminderTime.timeIntervalSince1970, forKey: Keys.time); reschedule() }
    }

    private enum Keys {
        static let enabled = "notif_daily_enabled"
        static let time = "notif_daily_time"
    }
    private let requestIdentifier = "daily_review_reminder"

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        let ts = UserDefaults.standard.double(forKey: Keys.time)
        reminderTime = ts > 0 ? Date(timeIntervalSince1970: ts) : Self.defaultTime()
        reschedule()
    }

    /// Orario predefinito: 20:00.
    static func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    }

    /// Attiva/disattiva il promemoria. Quando si attiva, richiede l'autorizzazione:
    /// se negata, lo stato resta disattivato.
    func setEnabled(_ on: Bool) {
        guard on else { isEnabled = false; return }
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            isEnabled = granted
        }
    }

    /// (Ri)pianifica il promemoria giornaliero ricorrente all'orario scelto.
    private func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ripasso del giorno"
        content.body = "È il momento di allenarti: apri il Quiz e fai una sessione di ripasso intelligente."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        center.add(request)
    }
}
