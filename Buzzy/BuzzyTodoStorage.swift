import Foundation
import SwiftUI

public struct BuzzyTodoItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var tomatoesCount: Int

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        tomatoesCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.tomatoesCount = tomatoesCount
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
    public func add(title: String) -> BuzzyTodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If exists and incomplete, reuse
        if let existing = items.first(where: { $0.title.lowercased() == trimmed.lowercased() && !$0.isCompleted }) {
            return existing
        }

        let newItem = BuzzyTodoItem(title: trimmed)
        items.insert(newItem, at: 0)
        save()
        return newItem
    }

    public func toggle(id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isCompleted.toggle()
            items[idx].completedAt = items[idx].isCompleted ? Date() : nil
            save()
        }
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
