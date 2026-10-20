import Foundation

public struct BuzzySession: Identifiable, Codable {
    public var id: UUID
    public var date: Date
    public var durationMinutes: Int
    public var subject: String
    public var isBreak: Bool

    public init(id: UUID = UUID(), date: Date = Date(), durationMinutes: Int, subject: String = "Tập trung", isBreak: Bool = false) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.subject = subject
        self.isBreak = isBreak
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
            Bundle.main.bundleIdentifier ?? "com.buzzy.app",
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
    }

    public func addSession(durationMinutes: Int, subject: String = "Tập trung", isBreak: Bool = false) {
        let newSession = BuzzySession(durationMinutes: durationMinutes, subject: subject, isBreak: isBreak)
        sessions.append(newSession)
        saveSessions()
    }

    public var todayTomatoesCount: Int {
        let calendar = Calendar.current
        return sessions.filter {
            !$0.isBreak && calendar.isDateInToday($0.date)
        }.count
    }

    public var totalTomatoesCount: Int {
        sessions.filter { !$0.isBreak }.count
    }

    public var totalFocusMinutes: Int {
        sessions.filter { !$0.isBreak }.reduce(0) { $0 + $1.durationMinutes }
    }

    public var currentStreakDays: Int {
        let calendar = Calendar.current
        let workSessions = sessions.filter { !$0.isBreak }
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
            calendar.isDate($0.date, inSameDayAs: date)
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
            let daySessions = sessionsFor(date: targetDate).filter { !$0.isBreak }
            let tomatoCount = daySessions.count
            let totalMins = daySessions.reduce(0) { $0 + $1.durationMinutes }

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
