import UserNotifications

enum TomikNotification {
    enum Category: String {
        case restStarted, restFinished
    }

    enum Action: String {
        case skipRest
    }
}

typealias TomikNotificationHandler = (TomikNotification.Action) -> Void

class TomikNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private var center = UNUserNotificationCenter.current()
    private var handler: TomikNotificationHandler?

    override init() {
        super.init()

        center.requestAuthorization(
            options: [.alert]
        ) { _, error in
            if error != nil {
                print("Error requesting notification authorization: \(error!)")
            }
        }

        center.delegate = self

        let actionSkipRest = UNNotificationAction(
            identifier: TomikNotification.Action.skipRest.rawValue,
            title: NSLocalizedString("TomikTimer.onRestStart.skip.title", comment: "Skip"),
            options: []
        )
        let restStartedCategory = UNNotificationCategory(
            identifier: TomikNotification.Category.restStarted.rawValue,
            actions: [actionSkipRest],
            intentIdentifiers: []
        )
        let restFinishedCategory = UNNotificationCategory(
            identifier: TomikNotification.Category.restFinished.rawValue,
            actions: [],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            restStartedCategory,
            restFinishedCategory,
        ])
    }

    func setActionHandler(handler: TomikNotificationHandler?) {
        self.handler = handler
    }

    func sendNotification(title: String, body: String, category: TomikNotification.Category) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.rawValue

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if error != nil {
                print("Error adding notification: \(error!)")
            }
        }
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        if action == TomikNotification.Action.skipRest.rawValue {
            handler?(.skipRest)
        }
        completionHandler()
    }
}
