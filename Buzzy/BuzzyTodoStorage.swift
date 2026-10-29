import Foundation
import SwiftUI

public struct BuzzyTodoItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var tomatoesCount: Int
    public var note: String?
    public var deadline: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        tomatoesCount: Int = 0,
        note: String? = nil,
        deadline: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.tomatoesCount = tomatoesCount
        self.note = note
        self.deadline = deadline
    }

    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, createdAt, completedAt, tomatoesCount, note, deadline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        tomatoesCount = try container.decodeIfPresent(Int.self, forKey: .tomatoesCount) ?? 0
        note = try container.decodeIfPresent(String.self, forKey: .note)
        deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
    }

    public enum DeadlineStatus: Equatable {
        case overdue
        case today
        case tomorrow
        case withinThreeDays(daysRemaining: Int)
        case upcoming
        case none
    }

    private static let deadlineDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    public var formattedDeadline: String? {
        guard let deadline = deadline else { return nil }
        return Self.deadlineDateFormatter.string(from: deadline)
    }

    public var deadlineStatus: DeadlineStatus {
        guard let deadline = deadline else { return .none }
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfDeadline = cal.startOfDay(for: deadline)

        let diff = cal.dateComponents([.day], from: startOfToday, to: startOfDeadline).day ?? 0

        if diff < 0 {
            return .overdue
        } else if diff == 0 {
            return .today
        } else if diff == 1 {
            return .tomorrow
        } else if diff <= 3 {
            return .withinThreeDays(daysRemaining: diff)
        } else {
            return .upcoming
        }
    }
}

public class BuzzyTodoStorage: ObservableObject {
    public static let shared = BuzzyTodoStorage()
    private let userDefaultsKey = "buzzy_todos_v1"
    private let legacyUserDefaultsKey = "tomik_todos_v1"

    @Published public var items: [BuzzyTodoItem] = []

    private init() {
        load()
        if items.isEmpty {
            items = [
                BuzzyTodoItem(title: "🐝 Thử phiên tập trung đầu tiên với Buzzy"),
                BuzzyTodoItem(title: "📖 Đọc sách 15 phút"),
            ]
            save()
        }
    }

    @discardableResult
    public func add(title: String, note: String? = nil, deadline: Date? = nil) -> BuzzyTodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If exists and incomplete, reuse
        if let idx = items.firstIndex(where: { $0.title.lowercased() == trimmed.lowercased() && !$0.isCompleted }) {
            if note != nil { items[idx].note = note }
            if deadline != nil { items[idx].deadline = deadline }
            save()
            return items[idx]
        }

        let newItem = BuzzyTodoItem(title: trimmed, note: note, deadline: deadline)
        items.insert(newItem, at: 0)
        save()
        return newItem
    }

    public func updateDetails(id: UUID, note: String?, deadline: Date?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        items[idx].note = (cleanNote?.isEmpty == false) ? cleanNote : nil
        items[idx].deadline = deadline
        save()
    }

    public func toggle(id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isCompleted.toggle()
            items[idx].completedAt = items[idx].isCompleted ? Date() : nil
            save()
        }
    }

    @discardableResult
    public func rename(id: UUID, title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = items.firstIndex(where: { $0.id == id }),
              !items.contains(where: { $0.id != id && !$0.isCompleted && $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return false }
        items[index].title = trimmed
        save()
        return true
    }

    public func delete(id: UUID) {
        items.removeAll(where: { $0.id == id })
        save()
    }

    public func deleteOlderCompleted() {
        let calendar = Calendar.current
        items.removeAll { $0.isCompleted && !calendar.isDateInToday($0.completedAt ?? $0.createdAt) }
        save()
    }

    public func clearCompleted() {
        items.removeAll(where: { $0.isCompleted })
        save()
    }

    public func move(id: UUID, toTargetId: UUID) {
        guard let fromIndex = items.firstIndex(where: { $0.id == id }),
              let toIndex = items.firstIndex(where: { $0.id == toTargetId }),
              fromIndex != toIndex else { return }
        let item = items.remove(at: fromIndex)
        items.insert(item, at: toIndex)
        save()
    }

    public func move(fromOffsets: IndexSet, toOffset: Int) {
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
        save()
    }

    public func incrementTomato(for title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = items.firstIndex(where: { $0.title.lowercased() == trimmed.lowercased() }) {
            items[idx].tomatoesCount += 1
            save()
        }
    }

    public func incrementTomato(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].tomatoesCount += 1
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func load() {
        let rawData = UserDefaults.standard.data(forKey: userDefaultsKey) ?? UserDefaults.standard.data(forKey: legacyUserDefaultsKey)
        if let data = rawData,
           let decoded = try? JSONDecoder().decode([BuzzyTodoItem].self, from: data) {
            self.items = decoded
        }
    }
}
