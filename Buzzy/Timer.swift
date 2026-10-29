import KeyboardShortcuts
import SwiftState
import SwiftUI

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer", default: .init(.s, modifiers: [.command, .shift]))
}

class BuzzyTimer: ObservableObject {
    public static let shared = BuzzyTimer()

    @AppStorage("autoStartBreak") var autoStartBreak = false
    @AppStorage("autoStartFocus") var autoStartFocus = false
    @AppStorage("showTimerInMenuBar") var showTimerInMenuBar = true
    @AppStorage("workIntervalLength") var workIntervalLength = 25
    @AppStorage("shortRestIntervalLength") var shortRestIntervalLength = 5
    @AppStorage("longRestIntervalLength") var longRestIntervalLength = 15
    @AppStorage("workIntervalsInSet") var workIntervalsInSet = 4
    // This preference is "hidden"
    @AppStorage("overrunTimeLimit") var overrunTimeLimit = -60.0

    private var stateMachine = BuzzyStateMachine(state: .idle)
    public let player = BuzzyPlayer()
    private var consecutiveWorkIntervals: Int = 0
    private var notificationCenter = BuzzyNotificationCenter()
    private var finishTime: Date?
    private var timerFormatter = DateComponentsFormatter()
    @Published var timeLeftString: String = ""
    @Published var timer: DispatchSourceTimer?

    init() {
        // Migrate legacy stopAfterBreak if needed
        if UserDefaults.standard.object(forKey: "autoStartFocus") == nil,
           UserDefaults.standard.object(forKey: "stopAfterBreak") != nil {
            let legacyStop = UserDefaults.standard.bool(forKey: "stopAfterBreak")
            self.autoStartFocus = !legacyStop
        }

        /*
         * State diagram
         *
         *                 start/stop
         *       +--------------+-------------+
         *       |              |             |
         *       |  start/stop  |  timerFired |
         *       V    |         |    |        |
         * +--------+ |  +--------+  | +--------+
         * | idle   |--->| work   |--->| rest   |
         * +--------+    +--------+    +--------+
         *   A                  A        |    |
         *   |                  |        |    |
         *   |                  +--------+    |
         *   |  timerFired (autoStartFocus)   |
         *   |             skipRest           |
         *   |                                |
         *   +--------------------------------+
         *      timerFired (!autoStartFocus)
         *
         */
        stateMachine.addRoutes(event: .startStop, transitions: [
            .idle => .work, .work => .idle, .rest => .idle,
        ])
        stateMachine.addRoutes(event: .timerFired, transitions: [.work => .rest])
        stateMachine.addRoutes(event: .timerFired, transitions: [.rest => .work]) { _ in
            self.autoStartFocus
        }
        stateMachine.addRoutes(event: .timerFired, transitions: [.rest => .idle]) { _ in
            !self.autoStartFocus
        }
        stateMachine.addRoutes(event: .skipRest, transitions: [.rest => .work])

        /*
         * "Finish" handlers are called when time interval ended
         * "End"    handlers are called when time interval ended or was cancelled
         */
        stateMachine.addAnyHandler(.any => .work, handler: onWorkStart)
        stateMachine.addAnyHandler(.work => .rest, order: 0, handler: onWorkFinish)
        stateMachine.addAnyHandler(.work => .any, order: 1, handler: onWorkEnd)
        stateMachine.addAnyHandler(.any => .rest, handler: onRestStart)
        stateMachine.addAnyHandler(.rest => .work, handler: onRestFinish)
        stateMachine.addAnyHandler(.rest => .idle, handler: onRestFinish)
        stateMachine.addAnyHandler(.any => .idle, handler: onIdleStart)
        stateMachine.addAnyHandler(.any => .any, handler: { ctx in
            logger.append(event: BuzzyLogEventTransition(fromContext: ctx))
        })

        stateMachine.addErrorHandler { ctx in fatalError("state machine context: <\(ctx)>") }

        timerFormatter.unitsStyle = .positional
        timerFormatter.allowedUnits = [.minute, .second]
        timerFormatter.zeroFormattingBehavior = .pad

        KeyboardShortcuts.onKeyDown(for: .startStopTimer) {
            BuzzyStatusItem.shared.togglePopover(nil)
        }
        notificationCenter.setActionHandler(handler: onNotificationAction)

        let aem: NSAppleEventManager = NSAppleEventManager.shared()
        aem.setEventHandler(self,
                            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
                            forEventClass: AEEventClass(kInternetEventClass),
                            andEventID: AEEventID(kAEGetURL))
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                 withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.forKeyword(AEKeyword(keyDirectObject))?.stringValue else {
            print("url handling error: cannot get url")
            return
        }
        let url = URL(string: urlString)
        guard url != nil,
              let scheme = url!.scheme,
              let host = url!.host else {
            print("url handling error: cannot parse url")
            return
        }
        guard scheme.caseInsensitiveCompare("buzzy") == .orderedSame else {
            print("url handling error: unknown scheme \(scheme)")
            return
        }
        switch host.lowercased() {
        case "startstop":
            startStop()
        default:
            print("url handling error: unknown command \(host)")
            return
        }
    }

    @Published public var isPaused: Bool = false
    private var pausedRemainingSeconds: TimeInterval = 0

    public var isWork: Bool { stateMachine.state == .work }
    public var isRest: Bool { stateMachine.state == .rest }
    public var isIdle: Bool { stateMachine.state == .idle }
    public var isRunning: Bool { stateMachine.state != .idle }

    func startStop() {
        if isPaused {
            resumeTimer()
            return
        }
        stateMachine <-! .startStop
    }

    func pauseTimer() {
        guard isRunning && !isPaused else { return }
        if let finish = finishTime {
            pausedRemainingSeconds = max(0, finish.timeIntervalSince(Date()))
        }
        timer?.cancel()
        timer = nil
        player.stopTicking()
        isPaused = true
        updateTimeLeft()
    }

    func resumeTimer() {
        guard isRunning && isPaused else { return }
        isPaused = false
        finishTime = Date().addingTimeInterval(pausedRemainingSeconds)
        if stateMachine.state == .work {
            player.startTicking()
        }
        let queue = DispatchQueue(label: "Timer")
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer!.schedule(deadline: .now(), repeating: .seconds(1), leeway: .never)
        timer!.setEventHandler(handler: onTimerTick)
        timer!.setCancelHandler(handler: onTimerCancel)
        timer!.resume()
        updateTimeLeft()
    }

    func cancelTimer() {
        isPaused = false
        pausedRemainingSeconds = 0
        if stateMachine.state != .idle {
            stateMachine <-! .startStop
        }
    }

    func skipRest() {
        isPaused = false
        stateMachine <-! .skipRest
    }

    public var totalIntervalSeconds: Int = 25 * 60
    @Published public var currentProgress: Double = 0.0
    @Published public var activeSubject: String = ""
    @Published public var activeTaskID: UUID?
    @Published public var activeSessionID: UUID?

    func updateTimeLeft() {
        guard let finishTime = finishTime, (timer != nil || isPaused) else {
            timeLeftString = ""
            currentProgress = 0.0
            BuzzyStatusItem.shared.setIcon(name: .idle)
            BuzzyStatusItem.shared.setTitle(title: nil)
            return
        }

        let remaining = isPaused ? pausedRemainingSeconds : finishTime.timeIntervalSince(Date())
        if let str = timerFormatter.string(from: Date(), to: Date().addingTimeInterval(max(0, remaining))) {
            timeLeftString = str
        }
        let elapsed = Double(totalIntervalSeconds) - max(0, remaining)
        currentProgress = max(0.0, min(1.0, elapsed / Double(totalIntervalSeconds)))

        let themeColorRaw = UserDefaults.standard.string(forKey: "themeColor") ?? "blue"
        let theme = BuzzyThemeColor(rawValue: themeColorRaw) ?? .blue

        BuzzyStatusItem.shared.updateProgressRing(
            progress: currentProgress,
            isBreak: stateMachine.state == .rest,
            theme: theme
        )
        if showTimerInMenuBar {
            let isRest = stateMachine.state == .rest
            let prefix: String
            if isPaused {
                prefix = isRest ? "⏸ ☕️ " : "⏸ "
            } else {
                prefix = isRest ? "☕️ " : ""
            }
            let menuTitle = "\(prefix)\(timeLeftString)"
            BuzzyStatusItem.shared.setTitle(title: menuTitle)
        } else {
            BuzzyStatusItem.shared.setTitle(title: nil)
        }
    }

    private func startTimer(seconds: Int) {
        totalIntervalSeconds = max(1, seconds)
        finishTime = Date().addingTimeInterval(TimeInterval(seconds))

        let queue = DispatchQueue(label: "Timer")
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer!.schedule(deadline: .now(), repeating: .seconds(1), leeway: .never)
        timer!.setEventHandler(handler: onTimerTick)
        timer!.setCancelHandler(handler: onTimerCancel)
        timer!.resume()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func onTimerTick() {
        /* Cannot publish updates from background thread */
        DispatchQueue.main.async { [self] in
            guard let finishTime = finishTime else { return }
            updateTimeLeft()
            let timeLeft = finishTime.timeIntervalSince(Date())
            if timeLeft <= 0 {
                /*
                 Ticks can be missed during the machine sleep.
                 Stop the timer if it goes beyond an overrun time limit.
                 */
                if timeLeft < overrunTimeLimit {
                    stateMachine <-! .startStop
                } else {
                    stateMachine <-! .timerFired
                }
            }
        }
    }

    private func onTimerCancel() {
        DispatchQueue.main.async { [self] in
            updateTimeLeft()
        }
    }

    private func onNotificationAction(action: BuzzyNotification.Action) {
        if action == .skipRest, stateMachine.state == .rest {
            skipRest()
        }
    }

    private func onWorkStart(context _: BuzzyStateMachine.Context) {
        let subject = activeSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subject.isEmpty {
            if activeTaskID == nil {
                activeTaskID = BuzzyTodoStorage.shared.add(title: subject)?.id
            }
            activeSessionID = BuzzyStorage.shared.beginSession(durationMinutes: workIntervalLength, subject: subject, taskID: activeTaskID)
        } else {
            activeSessionID = BuzzyStorage.shared.beginSession(durationMinutes: workIntervalLength, subject: BuzzyLocalization.shared.tr("Task.defaultSubject", value: "Tập trung"), taskID: nil)
        }
        let themeColorRaw = UserDefaults.standard.string(forKey: "themeColor") ?? "blue"
        let theme = BuzzyThemeColor(rawValue: themeColorRaw) ?? .blue
        BuzzyStatusItem.shared.updateProgressRing(progress: 0.0, isBreak: false, theme: theme)
        player.playWindup()
        player.startTicking()
        startTimer(seconds: workIntervalLength * 60)
    }

    private func onWorkFinish(context _: BuzzyStateMachine.Context) {
        consecutiveWorkIntervals += 1
        player.playDing()
        let trimmed = activeSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = BuzzyLocalization.shared.tr("Task.defaultSubject", value: "Tập trung")
        let subjectToSave = trimmed.isEmpty ? fallback : trimmed
        if let sessionID = activeSessionID,
           BuzzyStorage.shared.finishSession(id: sessionID, status: .completed),
           let taskID = activeTaskID {
            BuzzyTodoStorage.shared.incrementTomato(id: taskID)
        } else if activeSessionID == nil {
            BuzzyStorage.shared.addSession(durationMinutes: workIntervalLength, subject: subjectToSave)
        }
        BuzzyConfettiController.shared.showConfetti()
    }

    private func onWorkEnd(context _: BuzzyStateMachine.Context) {
        player.stopTicking()
        if let sessionID = activeSessionID {
            BuzzyStorage.shared.finishSession(id: sessionID, status: .interrupted)
            activeSessionID = nil
        }
    }

    private func onRestStart(context _: BuzzyStateMachine.Context) {
        var body = NSLocalizedString("BuzzyTimer.onRestStart.short.body", comment: "Short break body")
        var length = shortRestIntervalLength
        if consecutiveWorkIntervals >= workIntervalsInSet {
            body = NSLocalizedString("BuzzyTimer.onRestStart.long.body", comment: "Long break body")
            length = longRestIntervalLength
            consecutiveWorkIntervals = 0
        }
        let breakActivity = BuzzyBreakActivities.randomActivity()
        let fullBody = "\(body)\n\(breakActivity)"

        notificationCenter.sendNotification(
            title: NSLocalizedString("BuzzyTimer.onRestStart.title", comment: "Time's up title"),
            body: fullBody,
            category: .restStarted
        )
        let themeColorRaw = UserDefaults.standard.string(forKey: "themeColor") ?? "blue"
        let theme = BuzzyThemeColor(rawValue: themeColorRaw) ?? .blue
        BuzzyStatusItem.shared.updateProgressRing(progress: 0.0, isBreak: true, theme: theme)
        startTimer(seconds: length * 60)
        if !autoStartBreak {
            pauseTimer()
        }
        DispatchQueue.main.async {
            BuzzyStatusItem.shared.showPopover(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func onRestFinish(context ctx: BuzzyStateMachine.Context) {
        guard ctx.event == .timerFired else {
            return
        }
        notificationCenter.sendNotification(
            title: NSLocalizedString("BuzzyTimer.onRestFinish.title", comment: "Break is over title"),
            body: NSLocalizedString("BuzzyTimer.onRestFinish.body", comment: "Break is over body"),
            category: .restFinished
        )
        if !autoStartFocus {
            DispatchQueue.main.async {
                BuzzyStatusItem.shared.showPopover(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func onIdleStart(context _: BuzzyStateMachine.Context) {
        stopTimer()
        finishTime = nil
        isPaused = false
        pausedRemainingSeconds = 0
        currentProgress = 0.0
        timeLeftString = ""
        BuzzyStatusItem.shared.setIcon(name: .idle)
        BuzzyStatusItem.shared.setTitle(title: nil)
        consecutiveWorkIntervals = 0
    }
}
