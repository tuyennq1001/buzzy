import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI
import UniformTypeIdentifiers

private struct CoffeeSteamView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            steam(delay: 0.15, rotation: -12)
            steam(delay: 0.55, rotation: 7)
            steam(delay: 0.9, rotation: -5)
        }
        .frame(width: 36, height: 28)
        .accessibilityHidden(true)
    }

    private func steam(delay: Double, rotation: Double) -> some View {
        CoffeeSteamWisp(delay: delay, rotation: rotation)
    }
}

private struct CoffeeSteamWisp: View {
    let delay: Double
    let rotation: Double
    @State private var isRising = false

    var body: some View {
        Capsule()
            .fill(Color.gray.opacity(isRising ? 0.18 : 0.5))
            .frame(width: 3.5, height: 13)
            .blur(radius: 1.4)
            .rotationEffect(.degrees(rotation))
            .offset(y: isRising ? -10 : 3)
            .scaleEffect(isRising ? 0.75 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.35).repeatForever(autoreverses: false).delay(delay)) {
                    isRising = true
                }
            }
    }
}

struct BuzzyPopoverView: View {
    @ObservedObject var timer = BuzzyTimer.shared
    @ObservedObject var storage = BuzzyStorage.shared
    @ObservedObject var todoStorage = BuzzyTodoStorage.shared
    @ObservedObject var loc = BuzzyLocalization.shared
    @ObservedObject private var updater = BuzzyUpdaterViewModel.shared
    @AppStorage("themeColor") private var themeColorRaw: String = BuzzyThemeColor.blue.rawValue
    @AppStorage("dailyTarget") private var dailyTarget: Int = 10
    @AppStorage("buzzyFontName") private var buzzyFontName: String = BuzzyUnicodeFont.system.rawValue
    @AppStorage("buzzyFontSize") private var buzzyFontSize: Int = 16

    @State private var selectedTodoID: UUID? = nil
    @State private var draftDeadline: Date? = nil
    @State private var draftNote: String = ""
    @State private var breakTip = BuzzyBreakActivities.randomActivity()
    @State private var showStopConfirm = false
    @State private var showClearPastConfirm = false
    @State private var isTodayExpanded = true
    @State private var isPastDoneExpanded = false
    @State private var draggedTodo: BuzzyTodoItem? = nil
    @State private var showSessionNoteEditor = false
    @State private var sessionNoteDraft = ""

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        buzzyFont(size: size, weight: weight, fontName: buzzyFontName, baseSize: buzzyFontSize)
    }

    private var scale: CGFloat {
        buzzyScale(baseSize: buzzyFontSize)
    }

    private var theme: BuzzyThemeColor {
        BuzzyThemeColor(rawValue: themeColorRaw) ?? .blue
    }

    private var selectedOrMatchingTask: BuzzyTodoItem? {
        if let id = selectedTodoID, let item = todoStorage.items.first(where: { $0.id == id }) {
            return item
        }
        let trimmed = timer.activeSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return todoStorage.items.first(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame && !$0.isCompleted })
            ?? todoStorage.items.first(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame })
    }

    private var currentSelectedTask: BuzzyTodoItem? {
        selectedOrMatchingTask
    }

    private var runningTaskSubtitle: String? {
        guard let task = currentSelectedTask else { return nil }
        var parts: [String] = []
        if let deadline = task.formattedDeadline {
            parts.append("📅 \(deadline)")
        }
        if let note = task.note, !note.isEmpty {
            parts.append(note)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var runningTaskTooltip: String? {
        guard let task = currentSelectedTask else { return nil }
        var parts: [String] = [task.title]
        if let deadline = task.formattedDeadline {
            parts.append("📅 \(deadline)")
        }
        if let note = task.note, !note.isEmpty {
            parts.append("📝 \(note)")
        }
        return parts.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Header: Brand + Profile Picker + Daily Harvest Pill Badge
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Image("BuzzyLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                    Text(buzzyAppTitle)
                        .font(tFont(15, .heavy))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if isBuzzyDev {
                        Text("DEV")
                            .font(.system(size: 8.5, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                // Profile Pulldown Menu
                Picker("", selection: Binding(
                    get: {
                        BuzzyProfile.matchingProfile(
                            work: timer.workIntervalLength,
                            shortRest: timer.shortRestIntervalLength,
                            longRest: timer.longRestIntervalLength
                        )
                    },
                    set: { p in
                        if let inv = p.intervals {
                            timer.workIntervalLength = inv.work
                            timer.shortRestIntervalLength = inv.shortRest
                            timer.longRestIntervalLength = inv.longRest
                            timer.workIntervalsInSet = inv.sets
                        }
                    }
                )) {
                    ForEach([BuzzyProfile.kid, BuzzyProfile.medium, BuzzyProfile.standard]) { p in
                        Text(p.displayName).tag(p)
                    }
                    if BuzzyProfile.matchingProfile(work: timer.workIntervalLength, shortRest: timer.shortRestIntervalLength, longRest: timer.longRestIntervalLength) == .custom {
                        Text(BuzzyProfile.custom.displayName).tag(BuzzyProfile.custom)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(tFont(11, .medium))
                .frame(minWidth: 155, alignment: .leading)
                .disabled(timer.isRunning)
                .buzzyPointer()

                Spacer()

                // Daily Harvest Badge: e.g. "🍅 3/10"
                HStack(spacing: 3) {
                    Text("🍅")
                        .font(.system(size: 11))
                    Text("\(storage.todayTomatoesCount)/\(dailyTarget)")
                        .font(tFont(11.5, .heavy))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(theme.primaryColor.opacity(0.14))
                .foregroundColor(theme.primaryColor)
                .cornerRadius(12)
            }

            // MARK: - Timer Control & Status
            if !timer.isRunning {
                // Big Start Action Pill Button (Placed above task title & detail)
                Button {
                    timer.startOrResume()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(loc.tr("BuzzyPopoverView.start.label", value: "Bắt đầu"))
                            .font(tFont(14, .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: theme.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: theme.primaryColor.opacity(0.35), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(BuzzyPressableButtonStyle())
                .keyboardShortcut(.defaultAction)

                // Task Input Field (Idle mode)
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.outline")
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 13, weight: .semibold))

                    TextField(loc.tr("Task.placeholder", value: "Gõ việc mới hoặc chọn việc bên dưới..."), text: $timer.activeSubject)
                        .textFieldStyle(.plain)
                        .font(tFont(12))
                        .onSubmit {
                            handleTaskInputSubmit()
                        }

                    if !timer.activeSubject.isEmpty {
                        if selectedOrMatchingTask == nil {
                            // Button [+] Add to To-Do List (Enter)
                            Button {
                                addNewTaskFromInput()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(theme.primaryColor)
                                    .font(.system(size: 15 * scale))
                            }
                            .buttonStyle(BuzzyPressableButtonStyle())
                            .help(loc.tr("Task.addTooltip", value: "Thêm vào việc cần làm (Enter)"))
                        }

                        // Button [▶] Start Pomodoro (⌘+Enter)
                        Button {
                            startWithCurrentInput()
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(theme.primaryColor)
                                .font(.system(size: 15 * scale))
                        }
                        .buttonStyle(BuzzyPressableButtonStyle())
                        .keyboardShortcut(.return, modifiers: .command)
                        .help(
                            selectedOrMatchingTask != nil
                                ? loc.tr("Task.startTooltipExisting", value: "Bắt đầu tập trung (Enter hoặc ⌘+Enter)")
                                : loc.tr("Task.startTooltipNew", value: "Thêm & Bắt đầu ngay (⌘+Enter)")
                        )

                        // Button [✕] Clear / Deselect
                        Button {
                            clearTaskInput()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13 * scale))
                        }
                        .buttonStyle(BuzzyPressableButtonStyle())
                        .help(
                            selectedOrMatchingTask != nil
                                ? loc.tr("Task.deselectTooltip", value: "Bỏ chọn")
                                : loc.tr("Task.clearTooltip", value: "Xóa nội dung")
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.primaryColor.opacity(0.3), lineWidth: 1.2)
                )

                // Task Detail Inline Panel (Note + Deadline)
                TaskDetailPanel(
                    taskTitle: timer.activeSubject,
                    selectedTask: selectedOrMatchingTask,
                    draftDeadline: $draftDeadline,
                    draftNote: $draftNote,
                    theme: theme,
                    fontName: buzzyFontName,
                    fontSize: buzzyFontSize
                )
            } else {
                // Running / Paused Mode Card
                VStack(spacing: 10) {
                    // Control Action Buttons: Pause/Resume and Cancel (Placed above task title & countdown)
                    HStack(spacing: 8) {
                        Button {
                            if timer.isPaused {
                                timer.startOrResume()
                            } else {
                                timer.pauseTimer()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(
                                    timer.isRest && timer.isPaused
                                        ? loc.tr("Button.startBreak", value: "Bắt đầu nghỉ ngay ☕️")
                                        : (timer.isPaused ? loc.tr("Button.resume", value: "Tiếp tục") : loc.tr("Button.pause", value: "Tạm dừng"))
                                )
                                    .font(tFont(12, .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                timer.isRest && timer.isPaused
                                    ? BuzzyThemeColor.breakColor
                                    : (timer.isPaused ? Color.orange : theme.primaryColor)
                            )
                            .cornerRadius(10)
                            .shadow(color: (timer.isRest && timer.isPaused ? BuzzyThemeColor.breakColor : (timer.isPaused ? Color.orange : theme.primaryColor)).opacity(0.3), radius: 3, x: 0, y: 1.5)
                        }
                        .buttonStyle(BuzzyPressableButtonStyle())

                        Button {
                            if timer.isRest {
                                timer.cancelTimer()
                            } else {
                                showStopConfirm = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: timer.isRest ? "forward.fill" : "stop.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(timer.isRest ? loc.tr("Button.skip", value: "Bỏ qua") : loc.tr("Button.cancel", value: "Hủy"))
                                    .font(tFont(12, .bold))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(BuzzyPressableButtonStyle())
                    }

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(timer.isRest ? "☕️ " + loc.tr("Break.title", value: "Đang nghỉ giải lao") : (timer.activeSubject.isEmpty ? loc.tr("Task.defaultSubject", value: "Tập trung") : timer.activeSubject))
                                .font(tFont(12.5, .bold))
                                .lineLimit(1)

                            if timer.isRest {
                                Text(timer.isPaused ? loc.tr("Timer.paused", value: "Đang tạm dừng") : loc.tr("Timer.resting", value: "Thư giãn nạp năng lượng nào"))
                                    .font(tFont(10.5))
                                    .foregroundColor(.secondary)
                            } else if timer.isPaused {
                                Text(loc.tr("Timer.paused", value: "Đang tạm dừng"))
                                    .font(tFont(10.5))
                                    .foregroundColor(.secondary)
                            } else if let subtitle = runningTaskSubtitle {
                                Text(subtitle)
                                    .font(tFont(10.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .help(runningTaskTooltip ?? subtitle)
                            } else {
                                Text(loc.tr("Timer.working", value: "Đang tập trung cùng bạn"))
                                    .font(tFont(10.5))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if timer.isWork {
                            Button {
                                sessionNoteDraft = timer.activeSessionID.flatMap { id in storage.sessions.first(where: { $0.id == id })?.note } ?? ""
                                showSessionNoteEditor = true
                            } label: {
                                Image(systemName: "note.text")
                                    .foregroundColor(theme.primaryColor)
                            }
                            .buttonStyle(.plain)
                            .help("Ghi chú phiên")
                        }

                        Text(timer.timeLeftString)
                            .font(tFont(22, .heavy))
                            .foregroundColor(timer.isRest ? BuzzyThemeColor.breakColor : theme.primaryColor)
                    }

                    // Smooth Countdown Progress Bar
                    GeometryReader { geo in
                        let progress = min(1.0, max(0.0, timer.currentProgress))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: timer.isRest ? [BuzzyThemeColor.breakColor.opacity(0.7), BuzzyThemeColor.breakColor] : theme.gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1.2)
                )
            }

            // MARK: - Body Content: Rest Screen or To-Do List
            if timer.isRest {
                // Break relaxation cute card
                VStack(spacing: 10) {
                    Text("☕️")
                        .font(.system(size: 52))
                        .shadow(color: BuzzyThemeColor.breakColor.opacity(0.3), radius: 3, x: 0, y: 2)
                        .overlay(alignment: .top) {
                            CoffeeSteamView()
                                .offset(y: -17)
                        }

                    Text(loc.tr("Break.headline", value: "Thời gian thư giãn"))
                        .font(tFont(13.5, .bold))
                        .foregroundColor(.primary)

                    Text(breakTip)
                        .font(.custom("Georgia", size: 14 * scale).italic())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)

                    // Shuffle dice button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            breakTip = BuzzyBreakActivities.randomActivity()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "dice.fill")
                                .font(.system(size: 11))
                            Text(loc.tr("Break.shuffleTip", value: "Đổi mẹo khác"))
                                .font(tFont(10.5, .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BuzzyPressableButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.softBackground.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(BuzzyThemeColor.breakColor.opacity(0.25), lineWidth: 1.2)
                )
            } else {
                // Today's To-Do List Section (Collapsible Accordion)
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            isTodayExpanded.toggle()
                            if isTodayExpanded {
                                isPastDoneExpanded = false
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isTodayExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)

                            Label(loc.tr("Todo.section.title", value: "Việc cần làm hôm nay"), systemImage: "checklist")
                                .font(tFont(12, .bold))
                                .foregroundColor(.primary)

                            Spacer()

                            let completed = todoStorage.items.filter({ $0.isCompleted }).count
                            Text("\(completed)/\(todoStorage.items.count)")
                                .font(tFont(10.5, .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BuzzyPressableButtonStyle())

                    if isTodayExpanded {
                        let pendingItems = todoStorage.items.filter { !$0.isCompleted }
                        let todayDoneItems = todoStorage.items.filter { $0.isCompleted && Calendar.current.isDateInToday($0.completedAt ?? $0.createdAt) }

                        // Scrollable To-Do Items: Active tasks + Completed today
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                if pendingItems.isEmpty && todayDoneItems.isEmpty {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 4) {
                                            Text("📝")
                                                .font(.system(size: 18))
                                            Text(loc.tr("Todo.empty.hint", value: "Chưa có việc nào. Gõ việc cần làm ở trên nhé!"))
                                                .font(tFont(11))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 16)
                                        Spacer()
                                    }
                                } else {
                                    // 1. Active Pending Tasks
                                    ForEach(pendingItems) { item in
                                        TodoItemRow(
                                            item: item,
                                            isSelected: (selectedTodoID == item.id) || (timer.activeSubject.caseInsensitiveCompare(item.title) == .orderedSame),
                                            isDragging: draggedTodo?.id == item.id,
                                            theme: theme,
                                            onSelect: {
                                                selectTodo(item)
                                            },
                                            onToggle: {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    todoStorage.toggle(id: item.id)
                                                }
                                            },
                                            onDelete: {
                                                if selectedTodoID == item.id {
                                                    clearTaskInput()
                                                }
                                                todoStorage.delete(id: item.id)
                                            },
                                            onRename: { title in
                                                if selectedTodoID == item.id {
                                                    timer.activeSubject = title
                                                }
                                                return todoStorage.rename(id: item.id, title: title)
                                            }
                                        )
                                        .onDrag {
                                            self.draggedTodo = item
                                            return NSItemProvider(object: item.id.uuidString as NSString)
                                        }
                                        .onDrop(of: [UTType.text], delegate: TodoDropDelegate(
                                            targetItem: item,
                                            items: todoStorage.items,
                                            draggedItem: $draggedTodo,
                                            onMove: { fromId, toId in
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    todoStorage.move(id: fromId, toTargetId: toId)
                                                }
                                            }
                                        ))
                                    }

                                    // 2. Completed Today Tasks (Kept naturally inside To-Do)
                                    if !todayDoneItems.isEmpty {
                                        HStack {
                                            Text("🎉 " + loc.tr("Todo.doneToday.title", value: "Đã xong hôm nay") + " (\(todayDoneItems.count))")
                                                .font(tFont(10, .bold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .padding(.top, 5)
                                        .padding(.horizontal, 4)

                                        ForEach(todayDoneItems) { item in
                                            TodoItemRow(
                                                item: item,
                                                isSelected: (selectedTodoID == item.id) || (timer.activeSubject.caseInsensitiveCompare(item.title) == .orderedSame),
                                                isDragging: false,
                                                theme: theme,
                                                onSelect: {
                                                    selectTodo(item)
                                                },
                                                onToggle: {
                                                    withAnimation(.easeInOut(duration: 0.25)) {
                                                        todoStorage.toggle(id: item.id)
                                                    }
                                                },
                                                onDelete: {
                                                    if selectedTodoID == item.id {
                                                        clearTaskInput()
                                                    }
                                                    todoStorage.delete(id: item.id)
                                                },
                                                onRename: { title in
                                                    if selectedTodoID == item.id {
                                                        timer.activeSubject = title
                                                    }
                                                    return todoStorage.rename(id: item.id, title: title)
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.trailing, 4)
                        }
                        .frame(height: 190)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.primaryColor.opacity(0.15), lineWidth: 1.2)
                )

                // MARK: - Past Completed Tasks Accordion (Ngang hàng với To-Do Card)
                let pastDoneItems = todoStorage.items.filter { $0.isCompleted && !Calendar.current.isDateInToday($0.completedAt ?? $0.createdAt) }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                isPastDoneExpanded.toggle()
                                if isPastDoneExpanded {
                                    isTodayExpanded = false
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: isPastDoneExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)

                                Label(loc.tr("Todo.pastDone.title", value: "Việc đã xong trước đây"), systemImage: "clock.arrow.circlepath")
                                    .font(tFont(12, .bold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text("\(pastDoneItems.count)")
                                    .font(tFont(10.5, .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(BuzzyPressableButtonStyle())

                        if isPastDoneExpanded && !pastDoneItems.isEmpty {
                            Button {
                                showClearPastConfirm = true
                            } label: {
                                Text(loc.tr("Todo.clearAllDone", value: "Dọn dẹp"))
                                    .font(tFont(9, .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(BuzzyPressableButtonStyle())
                            .alert(isPresented: $showClearPastConfirm) {
                                Alert(
                                    title: Text(loc.tr("Todo.clearPastConfirm.title", value: "Xóa việc đã xong trước đây?")),
                                    message: Text(loc.tr("Todo.clearPastConfirm.message", value: "Các công việc đã hoàn thành từ những ngày trước sẽ được dọn sạch.")),
                                    primaryButton: .destructive(Text(loc.tr("Todo.clearDoneConfirm.button", value: "Dọn sạch"))) {
                                        todoStorage.deleteOlderCompleted()
                                    },
                                    secondaryButton: .cancel()
                                )
                            }
                        }
                    }

                    if isPastDoneExpanded {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                if pastDoneItems.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text(loc.tr("Todo.emptyPastDone.hint", value: "Không có công việc nào từ các ngày trước."))
                                            .font(tFont(10.5))
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 14)
                                        Spacer()
                                    }
                                } else {
                                    ForEach(pastDoneItems) { item in
                                        TodoItemRow(
                                            item: item,
                                            isSelected: (selectedTodoID == item.id) || (timer.activeSubject.caseInsensitiveCompare(item.title) == .orderedSame),
                                            isDragging: false,
                                            theme: theme,
                                            onSelect: {
                                                selectTodo(item)
                                            },
                                            onToggle: {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    todoStorage.toggle(id: item.id)
                                                }
                                            },
                                            onDelete: {
                                                if selectedTodoID == item.id {
                                                    clearTaskInput()
                                                }
                                                todoStorage.delete(id: item.id)
                                            },
                                            onRename: { title in
                                                if selectedTodoID == item.id {
                                                    timer.activeSubject = title
                                                }
                                                return todoStorage.rename(id: item.id, title: title)
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.trailing, 4)
                        }
                        .frame(height: 190)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.primaryColor.opacity(0.15), lineWidth: 1.2)
                )
            }

            if updater.isUpdateReady {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(theme.primaryColor)
                    Text(loc.tr("Updater.ready.popover", value: "Buzzy is ready to restart and update"))
                        .font(tFont(10.5, .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button {
                        BuzzyStatusItem.shared.closePopover(nil)
                        updater.restartAndInstallUpdate()
                    } label: {
                        Label(loc.tr("Updater.ready.restart.short", value: "Restart"), systemImage: "arrow.clockwise")
                            .font(tFont(11, .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.primaryColor)
                            .cornerRadius(10)
                    }
                    .buttonStyle(BuzzyPressableButtonStyle())
                    .help(loc.tr("Updater.ready.restart.help", value: "Cài đặt bản cập nhật và khởi động lại Buzzy"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.primaryColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }

            // MARK: - Footer: Stats Pill, Settings Pill & Quit
            HStack(spacing: 8) {
                // Stats Pill Button
                Button {
                    BuzzyStatsWindowController.shared.show(tab: .stats)
                    BuzzyStatusItem.shared.closePopover(nil)
                } label: {
                    HStack(spacing: 5) {
                        Text("📊")
                            .font(.system(size: 11))
                        Text(loc.tr("Stats.tab.title", value: "Thống kê"))
                            .font(tFont(11, .bold))
                    }
                    .foregroundColor(theme.primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.primaryColor.opacity(0.12))
                    .cornerRadius(10)
                }
                .buttonStyle(BuzzyPressableButtonStyle())
                .help(loc.tr("Stats.viewHistory", value: "Xem thống kê & tiến độ"))

                // Settings Pill Button
                Button {
                    BuzzyStatsWindowController.shared.show(tab: .settings)
                    BuzzyStatusItem.shared.closePopover(nil)
                } label: {
                    HStack(spacing: 5) {
                        Text("⚙️")
                            .font(.system(size: 11))
                        Text(loc.tr("Settings.tab.title", value: "Cài đặt"))
                            .font(tFont(11, .bold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                .buttonStyle(BuzzyPressableButtonStyle())
                .help(loc.tr("Settings.open.help", value: "Mở Cài đặt & Âm thanh"))

                Spacer()

                // Quit Button
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text(loc.tr("BuzzyPopoverView.quit.label", value: "Thoát"))
                        .font(tFont(11, .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(BuzzyPressableButtonStyle())
            }
        }
        .padding(14)
        .frame(width: 396)
        .preferredColorScheme(.light)
        .tint(theme.primaryColor)
        .environmentObject(timer)
        .environmentObject(timer.player)
        .alert(isPresented: $showStopConfirm) {
            Alert(
                title: Text(loc.tr("StopConfirm.title", value: "Hủy phiên hiện tại?")),
                message: Text(loc.tr("StopConfirm.message", value: "Thời gian và tiến độ của phiên này sẽ không được lưu.")),
                primaryButton: .destructive(Text(loc.tr("StopConfirm.confirm", value: "Hủy"))) {
                    timer.cancelTimer()
                },
                secondaryButton: .cancel(Text(loc.tr("StopConfirm.cancel", value: "Tiếp tục làm việc")))
            )
        }
        .onAppear {
            breakTip = BuzzyBreakActivities.randomActivity()
        }
        .onChange(of: timer.isRest) { isRest in
            if isRest {
                breakTip = BuzzyBreakActivities.randomActivity()
            }
        }
        .sheet(isPresented: $showSessionNoteEditor) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ghi chú phiên").font(.headline)
                TextEditor(text: $sessionNoteDraft).frame(minHeight: 140)
                HStack {
                    Button("Hủy") { showSessionNoteEditor = false }
                    Spacer()
                    Button("Lưu") {
                        if let id = timer.activeSessionID { storage.updateSessionNote(id: id, note: sessionNoteDraft) }
                        showSessionNoteEditor = false
                    }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(18)
            .frame(width: 360)
        }
        .onChange(of: timer.activeSubject) { newSubject in
            if let id = selectedTodoID, let item = todoStorage.items.first(where: { $0.id == id }) {
                if item.title != newSubject {
                    selectedTodoID = nil
                }
            }
        }
    }

    private func handleTaskInputSubmit() {
        let trimmed = timer.activeSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if selectedOrMatchingTask != nil {
            timer.startOrResume()
        } else {
            addNewTaskFromInput()
        }
    }

    private func addNewTaskFromInput() {
        let trimmed = timer.activeSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cleanNote = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteToSave = cleanNote.isEmpty ? nil : cleanNote
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = todoStorage.add(title: trimmed, note: noteToSave, deadline: draftDeadline)
        }
        clearTaskInput()
    }

    private func startWithCurrentInput() {
        let trimmed = timer.activeSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let cleanNote = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let noteToSave = cleanNote.isEmpty ? nil : cleanNote
            let item = todoStorage.add(title: trimmed, note: noteToSave, deadline: draftDeadline)
            selectedTodoID = item?.id
            timer.activeSubject = trimmed
        }
        draftDeadline = nil
        draftNote = ""
        timer.startOrResume()
    }

    private func clearTaskInput() {
        selectedTodoID = nil
        timer.activeSubject = ""
        draftDeadline = nil
        draftNote = ""
    }

    private func selectTodo(_ item: BuzzyTodoItem) {
        if selectedTodoID == item.id {
            clearTaskInput()
        } else {
            selectedTodoID = item.id
            timer.activeSubject = item.title
            draftDeadline = item.deadline
            draftNote = item.note ?? ""
        }
    }
}

// MARK: - Cute Compact Calendar Picker (Buzzy Aesthetic)
private struct BuzzyCalendarPicker: View {
    @Binding var selectedDate: Date
    let themeColor: Color
    let onSelect: (Date) -> Void

    @State private var displayedMonth: Date = Date()
    private let calendar = Calendar.current

    private var monthYearString: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) // 1 = Sunday
        let daysCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var result: [Date?] = []
        for _ in 1..<firstWeekday {
            result.append(nil)
        }
        for day in 0..<daysCount {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDay) {
                result.append(date)
            }
        }
        return result
    }

    private let weekdaySymbols = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation header
            HStack {
                Button {
                    if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.system(size: 12, weight: .bold, design: .rounded))

                Spacer()

                Button {
                    if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }

            // Weekday symbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.75))
                        .frame(maxWidth: .infinity)
                }
            }

            // Days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(0..<daysInMonth.count, id: \.self) { idx in
                    if let date = daysInMonth[idx] {
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(date)
                        let dayNum = calendar.component(.day, from: date)

                        Button {
                            selectedDate = date
                            onSelect(date)
                        } label: {
                            Text("\(dayNum)")
                                .font(.system(size: 11, weight: isSelected || isToday ? .bold : .regular, design: .rounded))
                                .foregroundColor(isSelected ? .white : (isToday ? themeColor : .primary))
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(isSelected ? themeColor : (isToday ? themeColor.opacity(0.18) : Color.clear))
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("")
                            .frame(width: 24, height: 24)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 200)
    }
}

// MARK: - Task Detail Inline Panel (Note + Deadline)
private struct TaskDetailPanel: View {
    let taskTitle: String
    let selectedTask: BuzzyTodoItem?
    @Binding var draftDeadline: Date?
    @Binding var draftNote: String
    let theme: BuzzyThemeColor
    let fontName: String
    let fontSize: Int

    @ObservedObject private var todoStorage = BuzzyTodoStorage.shared
    @ObservedObject private var loc = BuzzyLocalization.shared

    @State private var noteDraft = ""
    @State private var showDatePicker = false
    @State private var selectedDate = Date()
    @State private var isSyncing = false

    private var scale: CGFloat {
        buzzyScale(baseSize: fontSize)
    }

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        buzzyFont(size: size, weight: weight, fontName: fontName, baseSize: fontSize)
    }

    private var currentDeadline: Date? {
        selectedTask?.deadline ?? draftDeadline
    }

    private static let deadlineDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private var formattedDeadline: String? {
        guard let deadline = currentDeadline else { return nil }
        return Self.deadlineDateFormatter.string(from: deadline)
    }

    var body: some View {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                // Dòng 1: Deadline (Set deadline nếu chưa có => click vào mở mini calendar xinh xắn ngay)
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11 * scale, weight: .medium))
                        .foregroundColor(theme.primaryColor)

                    if let formatted = formattedDeadline {
                        Button {
                            selectedDate = currentDeadline ?? Date()
                            showDatePicker.toggle()
                        } label: {
                            Text(String(format: loc.tr("TaskDetail.deadlineFmt", value: "Hạn: %@"), formatted))
                                .font(tFont(11, .medium))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            saveDeadline(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11 * scale))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help(loc.tr("TaskDetail.clearDeadline", value: "Xóa deadline"))
                    } else {
                        Button {
                            selectedDate = Date()
                            showDatePicker.toggle()
                        } label: {
                            Text(loc.tr("TaskDetail.setDeadline", value: "Set deadline"))
                                .font(tFont(11))
                                .foregroundColor(theme.primaryColor)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .frame(height: 18 * scale)
                .popover(isPresented: $showDatePicker) {
                    BuzzyCalendarPicker(
                        selectedDate: $selectedDate,
                        themeColor: theme.primaryColor,
                        onSelect: { date in
                            saveDeadline(date)
                            showDatePicker = false
                        }
                    )
                }

                // Dòng 2: Description => mở rộng 2 dòng, click vào điền luôn, enter hoặc rời ô là save
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 10 * scale))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)

                    TextField(loc.tr("TaskDetail.notePlaceholder", value: "Ghi chú cho task này..."), text: $noteDraft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...2)
                        .font(tFont(11))
                        .onChange(of: noteDraft) { newVal in
                            if !isSyncing {
                                saveNote(newVal)
                            }
                        }
                }
                .frame(height: 36 * scale)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(height: 74 * scale)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .onAppear {
                syncWithTask()
            }
            .onChange(of: taskTitle) { _ in
                syncWithTask()
            }
            .onChange(of: selectedTask) { _ in
                syncWithTask()
            }
        }
    }

    private func syncWithTask() {
        isSyncing = true
        if let item = selectedTask {
            noteDraft = item.note ?? ""
            if let d = item.deadline {
                selectedDate = d
            } else {
                selectedDate = Date()
            }
        } else {
            noteDraft = draftNote
            selectedDate = draftDeadline ?? Date()
        }
        DispatchQueue.main.async {
            isSyncing = false
        }
    }

    private func saveNote(_ newNote: String) {
        draftNote = newNote
        if let task = selectedTask {
            todoStorage.updateDetails(id: task.id, note: newNote, deadline: task.deadline)
        }
    }

    private func saveDeadline(_ newDeadline: Date?) {
        draftDeadline = newDeadline
        if let task = selectedTask {
            todoStorage.updateDetails(id: task.id, note: task.note, deadline: newDeadline)
        }
    }
}

// MARK: - Todo Drop Delegate for Drag & Drop Reordering
private struct TodoDropDelegate: DropDelegate {
    let targetItem: BuzzyTodoItem
    let items: [BuzzyTodoItem]
    @Binding var draggedItem: BuzzyTodoItem?
    let onMove: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem,
              dragged.id != targetItem.id,
              let fromIndex = items.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = items.firstIndex(where: { $0.id == targetItem.id }),
              fromIndex != toIndex else {
            return
        }
        onMove(dragged.id, targetItem.id)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

// MARK: - Todo Item Row Component (Full Scaling with `buzzyScale`)
private struct TodoItemRow: View {
    let item: BuzzyTodoItem
    let isSelected: Bool
    let isDragging: Bool
    let theme: BuzzyThemeColor
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Bool

    @AppStorage("buzzyFontName") private var buzzyFontName: String = BuzzyUnicodeFont.system.rawValue
    @AppStorage("buzzyFontSize") private var buzzyFontSize: Int = 16

    @State private var isHovered = false
    @State private var showRename = false
    @State private var editedTitle = ""
    @State private var showRenameError = false

    @Environment(\.colorScheme) private var colorScheme

    private var scale: CGFloat {
        buzzyScale(baseSize: buzzyFontSize)
    }

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        buzzyFont(size: size, weight: weight, fontName: buzzyFontName, baseSize: buzzyFontSize)
    }

    private var titleWeight: Font.Weight {
        if isSelected {
            return .bold
        }
        if !item.isCompleted {
            if item.deadlineStatus == .overdue || item.deadlineStatus == .today {
                return .bold
            }
        }
        return .regular
    }

    private var titleColor: Color {
        if item.isCompleted {
            return .secondary
        }
        if isSelected {
            return theme.primaryColor
        }
        switch item.deadlineStatus {
        case .overdue:
            // Đỏ tươi
            return colorScheme == .dark ? Color(red: 255/255, green: 110/255, blue: 115/255) : Color(red: 220/255, green: 38/255, blue: 38/255)
        case .today:
            // Đỏ gạch (Terracotta/Crimson nhạt & ấm hơn đỏ quá hạn)
            return colorScheme == .dark ? Color(red: 251/255, green: 113/255, blue: 133/255) : Color(red: 225/255, green: 29/255, blue: 72/255)
        case .tomorrow:
            // Cam
            return colorScheme == .dark ? Color(red: 251/255, green: 146/255, blue: 60/255) : Color(red: 234/255, green: 88/255, blue: 12/255)
        case .withinThreeDays:
            // Vàng hổ phách
            return colorScheme == .dark ? Color(red: 251/255, green: 191/255, blue: 36/255) : Color(red: 217/255, green: 119/255, blue: 6/255)
        case .upcoming, .none:
            return .primary
        }
    }

    private var tooltipText: String {
        var lines: [String] = [item.title]
        if let deadline = item.formattedDeadline {
            let statusSuffix: String
            switch item.deadlineStatus {
            case .overdue: statusSuffix = " (\(BuzzyLocalization.shared.tr("TaskDetail.overdue", value: "Quá hạn")))"
            case .today: statusSuffix = " (\(BuzzyLocalization.shared.tr("TaskDetail.today", value: "Hôm nay")))"
            case .tomorrow: statusSuffix = " (\(BuzzyLocalization.shared.tr("TaskDetail.tomorrow", value: "Ngày mai")))"
            case .withinThreeDays(let days): statusSuffix = " (\(String(format: BuzzyLocalization.shared.tr("TaskDetail.daysRemaining", value: "Còn %d ngày"), days)))"
            default: statusSuffix = ""
            }
            lines.append("📅 \(deadline)\(statusSuffix)")
        }
        if let note = item.note, !note.isEmpty {
            lines.append("📝 \(note)")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        HStack(spacing: 7) {
            // Drag handle icon
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10 * scale, weight: .semibold))
                .foregroundColor(isHovered ? .secondary : .clear)
                .frame(width: 12)

            // Cute Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .secondary.opacity(0.65) : theme.primaryColor)
                    .font(.system(size: 15 * scale))
            }
            .buttonStyle(BuzzyPressableButtonStyle(scaleAmount: 0.9))

            // Title (click to select and fill into text field)
            Button {
                onSelect()
            } label: {
                Text(item.title)
                    .font(tFont(12, titleWeight))
                    .strikethrough(item.isCompleted)
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(BuzzyPressableButtonStyle(scaleAmount: 0.99))
            .help(tooltipText)
            .contextMenu {
                Button("Sửa tên", systemImage: "pencil") {
                    editedTitle = item.title
                    showRename = true
                }
                Button("Xem các phiên làm việc", systemImage: "clock") { }
            }

            // Tomato count badge
            if item.tomatoesCount > 0 {
                Text("🍅 \(item.tomatoesCount)")
                    .font(tFont(10, .bold))
                    .foregroundColor(theme.primaryColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(theme.primaryColor.opacity(0.12))
                    .cornerRadius(6)
            }

            // Delete button on hover
            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BuzzyPressableButtonStyle(scaleAmount: 0.9))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4 * scale)
        .background(
            isSelected ? theme.primaryColor.opacity(0.12) : (isHovered ? theme.softBackground.opacity(0.6) : Color.clear)
        )
        .cornerRadius(8)
        .opacity(isDragging ? 0.35 : 1.0)
        .onHover { hover in
            isHovered = hover
        }
        .alert("Sửa tên task", isPresented: $showRename) {
            TextField("Tên task", text: $editedTitle)
            Button("Hủy", role: .cancel) { }
            Button("Lưu") {
                if !onRename(editedTitle) { showRenameError = true }
            }
        }
        .alert("Tên task không hợp lệ hoặc đã tồn tại", isPresented: $showRenameError) {
            Button("OK", role: .cancel) { }
        }
    }
}
