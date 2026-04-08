import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    private let mealReminderId = "fitness.mealReminder"
    private let workoutReminderId = "fitness.workoutReminder"
    private let streakReminderId = "fitness.streakReminder"

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func getPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    func clearAllFitnessNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [mealReminderId, workoutReminderId, streakReminderId]
        )
    }

    func syncNotifications(for user: User?) {
        clearAllFitnessNotifications()

        let mealEnabled = UserDefaults.standard.bool(forKey: "settings_meal_reminders")
        let workoutEnabled = UserDefaults.standard.bool(forKey: "settings_workout_reminder")
        let streakEnabled = UserDefaults.standard.bool(forKey: "settings_streak_reminder")

        let mealHour = UserDefaults.standard.object(forKey: "settings_meal_reminder_hour") as? Int ?? 12
        let workoutHour = UserDefaults.standard.object(forKey: "settings_workout_reminder_hour") as? Int ?? 18
        let streakHour = UserDefaults.standard.object(forKey: "settings_streak_reminder_hour") as? Int ?? 20

        let firstName = user?.name.split(separator: " ").first.map(String.init) ?? "there"

        if mealEnabled {
            scheduleDailyReminder(
                id: mealReminderId,
                hour: mealHour,
                minute: 0,
                title: "Log your meals",
                body: "Hey \(firstName), log what you ate today so your calories stay on track."
            )
        }

        if workoutEnabled {
            scheduleDailyReminder(
                id: workoutReminderId,
                hour: workoutHour,
                minute: 0,
                title: "Workout check-in",
                body: "Hey \(firstName), don’t forget to log your workout for today."
            )
        }

        if streakEnabled {
            scheduleDailyReminder(
                id: streakReminderId,
                hour: streakHour,
                minute: 0,
                title: "Keep your streak alive",
                body: "Hey \(firstName), log today’s progress so you don’t break the streak."
            )
        }
    }

    private func scheduleDailyReminder(id: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Schedule notification error: \(error)")
            }
        }
    }
}
