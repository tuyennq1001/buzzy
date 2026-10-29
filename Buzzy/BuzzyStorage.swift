import Foundation

public enum BuzzySessionStatus: String, Codable {
    case inProgress
    case completed
    case interrupted
}

public struct BuzzySession: Identifiable, Codable {
    public var id: UUID
    public var date: Date
    public var durationMinutes: Int
    public var subject: String
    public var isBreak: Bool
    public var taskID: UUID?
    public var note: String
    public var status: BuzzySessionStatus
    public var startedAt: Date

    public init(id: UUID = UUID(), date: Date = Date(), durationMinutes: Int, subject: String = "Tập trung", isBreak: Bool = false, taskID: UUID? = nil, note: String = "", status: BuzzySessionStatus = .completed, startedAt: Date? = nil) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.subject = subject
        self.isBreak = isBreak
        self.taskID = taskID
        self.note = note
        self.status = status
        self.startedAt = startedAt ?? date
    }

    private enum CodingKeys: String, CodingKey { case id, date, durationMinutes, subject, isBreak, taskID, note, status, startedAt }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        date = try values.decode(Date.self, forKey: .date)
        durationMinutes = try values.decode(Int.self, forKey: .durationMinutes)
        subject = try values.decodeIfPresent(String.self, forKey: .subject) ?? "Tập trung"
        isBreak = try values.decodeIfPresent(Bool.self, forKey: .isBreak) ?? false
        taskID = try values.decodeIfPresent(UUID.self, forKey: .taskID)
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        status = try values.decodeIfPresent(BuzzySessionStatus.self, forKey: .status) ?? .completed
        startedAt = try values.decodeIfPresent(Date.self, forKey: .startedAt) ?? date
    }

    public var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

public struct BuzzyDailyRecord: Identifiable {
    public var id: String { dateString }
    public var dateString: String // YYYY-MM-DD
    public var date: Date
    public var tomatoCount: Int
    public var totalMinutes: Int
    public var sessions: [BuzzySession]

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }

    public var displayDateFull: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let lang = BuzzyLocalization.shared.currentLanguage
        formatter.locale = Locale(identifier: lang == .en ? "en_US" : (lang == .ja ? "ja_JP" : "vi_VN"))
        return formatter.string(from: date)
    }
}

public class BuzzyStorage: ObservableObject {
    public static let shared = BuzzyStorage()
    private let storageKey = "buzzy_saved_sessions"
    private let legacyStorageKey = "tomik_saved_sessions"

    public static func migrateFromSandboxIfNeeded() {
        if UserDefaults.standard.data(forKey: "buzzy_todos_v1") != nil || UserDefaults.standard.data(forKey: "tomik_todos_v1") != nil {
            return
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let containerBase = homeDir.appendingPathComponent("Library/Containers")

        let candidateIDs = [
            Bundle.main.bundleIdentifier ?? "com.buzzy.focus",
            "com.buzzy.focus.dev",
            "com.buzzy.focus",
            "com.buzzy.app.dev",
            "com.buzzy.app",
            "com.tomik.app.dev",
            "com.tomik.app"
        ]

        for candidate in candidateIDs {
            let containerPlist = containerBase
                .appendingPathComponent(candidate)
                .appendingPathComponent("Data/Library/Preferences")
                .appendingPathComponent("\(candidate).plist")

            if FileManager.default.fileExists(atPath: containerPlist.path),
               let data = try? Data(contentsOf: containerPlist),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                for (key, val) in plist {
                    if UserDefaults.standard.object(forKey: key) == nil {
                        UserDefaults.standard.set(val, forKey: key)
                    }
                }
                NSLog("[Buzzy] Successfully migrated %d preference keys from sandbox container: %@", plist.count, candidate)
                break
            }
        }
    }

    @Published public var sessions: [BuzzySession] = []

    private init() {
        loadSessions()
        recoverInterruptedSessions()
    }

    private func recoverInterruptedSessions() {
        var changed = false
        for index in sessions.indices where sessions[index].status == .inProgress {
            sessions[index].status = .interrupted
            changed = true
        }
        if changed { saveSessions() }
    }

    @discardableResult
    public func beginSession(durationMinutes: Int, subject: String, taskID: UUID?) -> UUID {
        let session = BuzzySession(durationMinutes: durationMinutes, subject: subject, taskID: taskID, status: .inProgress)
        sessions.append(session)
        saveSessions()
        return session.id
    }

    @discardableResult
    public func finishSession(id: UUID, status: BuzzySessionStatus) -> Bool {
        guard status != .inProgress,
              let index = sessions.firstIndex(where: { $0.id == id }),
              sessions[index].status == .inProgress else { return false }
        sessions[index].status = status
        sessions[index].date = Date()
        saveSessions()
        return true
    }

    public func updateSessionNote(id: UUID, note: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        saveSessions()
    }

    public func sessionsFor(taskID: UUID) -> [BuzzySession] {
        sessions.filter { $0.taskID == taskID && !$0.isBreak && $0.status != .inProgress }.sorted { $0.date > $1.date }
    }

    public func addSession(durationMinutes: Int, subject: String = "Tập trung", isBreak: Bool = false) {
        let newSession = BuzzySession(durationMinutes: durationMinutes, subject: subject, isBreak: isBreak)
        sessions.append(newSession)
        saveSessions()
    }

    public var todayTomatoesCount: Int {
        let calendar = Calendar.current
        return sessions.filter {
            !$0.isBreak && $0.status == .completed && calendar.isDateInToday($0.date)
        }.count
    }

    public var totalTomatoesCount: Int {
        sessions.filter { !$0.isBreak && $0.status == .completed }.count
    }

    public var totalFocusMinutes: Int {
        sessions.filter { !$0.isBreak && $0.status == .completed }.reduce(0) { $0 + $1.durationMinutes }
    }

    public var currentStreakDays: Int {
        let calendar = Calendar.current
        let workSessions = sessions.filter { !$0.isBreak && $0.status == .completed }
        if workSessions.isEmpty { return 0 }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let activeDates = Set(workSessions.map { df.string(from: $0.date) })

        var streak = 0
        var checkDate = Date()

        let todayStr = df.string(from: checkDate)
        if !activeDates.contains(todayStr) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            let yesterdayStr = df.string(from: yesterday)
            if !activeDates.contains(yesterdayStr) {
                return 0
            }
            checkDate = yesterday
        }

        while true {
            let str = df.string(from: checkDate)
            if activeDates.contains(str) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    public func sessionsFor(date: Date) -> [BuzzySession] {
        let calendar = Calendar.current
        return sessions.filter {
            !$0.isBreak && $0.status != .inProgress && calendar.isDate($0.date, inSameDayAs: date)
        }.sorted(by: { $0.date > $1.date })
    }

    public func getHeatmapDays(weeks: Int = 18) -> [BuzzyDailyRecord] {
        let calendar = Calendar.current
        var records: [BuzzyDailyRecord] = []
        let today = Date()
        let totalDays = weeks * 7

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for offset in (0..<totalDays).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let daySessions = sessionsFor(date: targetDate)
            let completedSessions = daySessions.filter { $0.status == .completed }
            let tomatoCount = completedSessions.count
            let totalMins = completedSessions.reduce(0) { $0 + $1.durationMinutes }

            records.append(BuzzyDailyRecord(
                dateString: df.string(from: targetDate),
                date: targetDate,
                tomatoCount: tomatoCount,
                totalMinutes: totalMins,
                sessions: daySessions
            ))
        }

        return records
    }

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadSessions() {
        let rawData = UserDefaults.standard.data(forKey: storageKey) ?? UserDefaults.standard.data(forKey: legacyStorageKey)
        if let data = rawData,
           let decoded = try? JSONDecoder().decode([BuzzySession].self, from: data) {
            self.sessions = decoded
        } else {
            self.sessions = []
        }
    }
}
