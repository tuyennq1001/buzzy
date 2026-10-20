import UserNotifications

enum BuzzyNotification {
    enum Category: String {
        case restStarted, restFinished
    }

    enum Action: String {
        case skipRest
    }
}

typealias BuzzyNotificationHandler = (BuzzyNotification.Action) -> Void

class BuzzyNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private var center = UNUserNotificationCenter.current()
    private var handler: BuzzyNotificationHandler?

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
            identifier: BuzzyNotification.Action.skipRest.rawValue,
            title: NSLocalizedString("BuzzyTimer.onRestStart.skip.title", comment: "Skip"),
            options: []
        )
        let restStartedCategory = UNNotificationCategory(
            identifier: BuzzyNotification.Category.restStarted.rawValue,
            actions: [actionSkipRest],
            intentIdentifiers: []
        )
        let restFinishedCategory = UNNotificationCategory(
            identifier: BuzzyNotification.Category.restFinished.rawValue,
            actions: [],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            restStartedCategory,
            restFinishedCategory,
        ])
    }

    func setActionHandler(handler: BuzzyNotificationHandler?) {
        self.handler = handler
    }

    func sendNotification(title: String, body: String, category: BuzzyNotification.Category) {
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
        if action == BuzzyNotification.Action.skipRest.rawValue {
            handler?(.skipRest)
        }
        completionHandler()
    }
}
