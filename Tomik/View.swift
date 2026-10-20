import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI
import UniformTypeIdentifiers

struct TomikPopoverView: View {
    @ObservedObject var timer = TomikTimer.shared
    @ObservedObject var storage = TomikStorage.shared
    @ObservedObject var todoStorage = TomikTodoStorage.shared
    @ObservedObject var loc = TomikLocalization.shared
    @AppStorage("themeColor") private var themeColorRaw: String = TomikThemeColor.red.rawValue
    @AppStorage("dailyTarget") private var dailyTarget: Int = 10
    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 13

    @State private var newTodoText = ""
    @State private var breakTip = TomikBreakActivities.randomActivity()
    @State private var showStopConfirm = false
    @State private var showClearPastConfirm = false
    @State private var isTodayExpanded = true
    @State private var isPastDoneExpanded = false
    @State private var draggedTodo: TomikTodoItem? = nil

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    private var scale: CGFloat {
        tomikScale(baseSize: tomikFontSize)
    }

    private var theme: TomikThemeColor {
        TomikThemeColor(rawValue: themeColorRaw) ?? .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Header: Brand + Profile Picker + Daily Harvest Pill Badge
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Image("TomikLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("Tomik")
                        .font(tFont(15, .heavy))
                        .foregroundColor(.primary)
                }

                // Profile Pulldown Menu
                Picker("", selection: Binding(
                    get: {
                        TomikProfile.matchingProfile(
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
                    ForEach([TomikProfile.kid, TomikProfile.medium, TomikProfile.standard]) { p in
                        Text(p.displayName).tag(p)
                    }
                    if TomikProfile.matchingProfile(work: timer.workIntervalLength, shortRest: timer.shortRestIntervalLength, longRest: timer.longRestIntervalLength) == .custom {
                        Text(TomikProfile.custom.displayName).tag(TomikProfile.custom)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(tFont(11, .medium))
                .frame(minWidth: 155, alignment: .leading)
                .disabled(timer.isRunning)
                .tomikPointer()

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
                // Task Input Field (Idle mode)
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.outline")
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 13, weight: .semibold))

                    TextField(loc.tr("Task.placeholder", value: "Chọn công việc từ To-do list hoặc gõ vào"), text: $timer.activeSubject)
                        .textFieldStyle(.plain)
                        .font(tFont(12))

                    if !timer.activeSubject.isEmpty {
                        Button {
                            timer.activeSubject = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(TomikPressableButtonStyle())
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

                // Big Start Action Pill Button
                Button {
                    startTimerAction()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(loc.tr("TomikPopoverView.start.label", value: "Bắt đầu"))
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
                .buttonStyle(TomikPressableButtonStyle())
                .keyboardShortcut(.defaultAction)
            } else {
                // Running / Paused Mode Card
                VStack(spacing: 10) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(timer.isRest ? "☕️ " + loc.tr("Break.title", value: "Đang nghỉ giải lao") : (timer.activeSubject.isEmpty ? loc.tr("Task.defaultSubject", value: "Tập trung") : timer.activeSubject))
                                .font(tFont(12.5, .bold))
                                .lineLimit(1)
                            Text(timer.isPaused ? loc.tr("Timer.paused", value: "Đang tạm dừng") : (timer.isRest ? loc.tr("Timer.resting", value: "Thư giãn nạp năng lượng nào") : loc.tr("Timer.working", value: "Đang tập trung cùng bạn")))
                                .font(tFont(10.5))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(timer.timeLeftString)
                            .font(tFont(22, .heavy))
                            .foregroundColor(timer.isRest ? TomikThemeColor.breakColor : theme.primaryColor)
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
                                        colors: timer.isRest ? [TomikThemeColor.breakColor.opacity(0.7), TomikThemeColor.breakColor] : theme.gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Control Action Buttons: Pause/Resume and Cancel
                    HStack(spacing: 8) {
                        Button {
                            if timer.isPaused {
                                timer.resumeTimer()
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
                                    ? TomikThemeColor.breakColor
                                    : (timer.isPaused ? Color.orange : theme.primaryColor)
                            )
                            .cornerRadius(10)
                            .shadow(color: (timer.isRest && timer.isPaused ? TomikThemeColor.breakColor : (timer.isPaused ? Color.orange : theme.primaryColor)).opacity(0.3), radius: 3, x: 0, y: 1.5)
                        }
                        .buttonStyle(TomikPressableButtonStyle())

                        Button {
                            showStopConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(loc.tr("Button.cancel", value: "Hủy phiên"))
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
                        .buttonStyle(TomikPressableButtonStyle())
                    }
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
                        .font(.system(size: 34))
                        .shadow(color: TomikThemeColor.breakColor.opacity(0.3), radius: 3, x: 0, y: 2)

                    Text(loc.tr("Break.headline", value: "Thời gian thư giãn"))
                        .font(tFont(13.5, .bold))
                        .foregroundColor(.primary)

                    if timer.isPaused {
                        Text(loc.tr("Break.pausedPrompt", value: "✨ Đã xong phiên tập trung! Sẵn sàng thì bấm bắt đầu nghỉ nhé."))
                            .font(tFont(10.5, .medium))
                            .foregroundColor(TomikThemeColor.breakColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }

                    Text(breakTip)
                        .font(tFont(11.5))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)

                    // Shuffle dice button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            breakTip = TomikBreakActivities.randomActivity()
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
                    .buttonStyle(TomikPressableButtonStyle())

                    Button {
                        timer.skipRest()
                    } label: {
                        HStack(spacing: 4) {
                            Text(loc.tr("Break.skip", value: "Bỏ qua nghỉ ngơi"))
                                .font(tFont(11.5, .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(theme.primaryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(theme.primaryColor.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .buttonStyle(TomikPressableButtonStyle())
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.softBackground.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(TomikThemeColor.breakColor.opacity(0.25), lineWidth: 1.2)
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
                    .buttonStyle(TomikPressableButtonStyle())

                    if isTodayExpanded {
                        // Quick Add Todo Input
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14 * scale))
                                .foregroundColor(theme.primaryColor)

                            TextField(loc.tr("Todo.quickAdd.placeholder", value: "Thêm việc mới... (Nhấn Enter)"), text: $newTodoText)
                                .textFieldStyle(.plain)
                                .font(tFont(11.5))
                                .onSubmit {
                                    addQuickTodo()
                                }

                            if !newTodoText.isEmpty {
                                Button {
                                    addQuickTodo()
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(theme.primaryColor)
                                        .font(.system(size: 15 * scale))
                                }
                                .buttonStyle(TomikPressableButtonStyle())
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6 * scale)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
                        )

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
                                            isSelected: timer.activeSubject == item.title,
                                            isDragging: draggedTodo?.id == item.id,
                                            theme: theme,
                                            onSelect: {
                                                timer.activeSubject = item.title
                                            },
                                            onToggle: {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    todoStorage.toggle(id: item.id)
                                                }
                                            },
                                            onDelete: {
                                                todoStorage.delete(id: item.id)
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
                                                isSelected: timer.activeSubject == item.title,
                                                isDragging: false,
                                                theme: theme,
                                                onSelect: {
                                                    timer.activeSubject = item.title
                                                },
                                                onToggle: {
                                                    withAnimation(.easeInOut(duration: 0.25)) {
                                                        todoStorage.toggle(id: item.id)
                                                    }
                                                },
                                                onDelete: {
                                                    todoStorage.delete(id: item.id)
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
                        .buttonStyle(TomikPressableButtonStyle())

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
                            .buttonStyle(TomikPressableButtonStyle())
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
                                            isSelected: timer.activeSubject == item.title,
                                            isDragging: false,
                                            theme: theme,
                                            onSelect: {
                                                timer.activeSubject = item.title
                                            },
                                            onToggle: {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    todoStorage.toggle(id: item.id)
                                                }
                                            },
                                            onDelete: {
                                                todoStorage.delete(id: item.id)
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

            // MARK: - Footer: Stats Pill, Settings Pill & Quit
            HStack(spacing: 8) {
                // Stats Pill Button
                Button {
                    TomikStatsWindowController.shared.show(tab: .stats)
                    TomikStatusItem.shared.closePopover(nil)
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
                .buttonStyle(TomikPressableButtonStyle())
                .help(loc.tr("Stats.viewHistory", value: "Xem thống kê & tiến độ"))

                // Settings Pill Button
                Button {
                    TomikStatsWindowController.shared.show(tab: .settings)
                    TomikStatusItem.shared.closePopover(nil)
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
                .buttonStyle(TomikPressableButtonStyle())
                .help(loc.tr("Settings.open.help", value: "Mở Cài đặt & Âm thanh"))

                Spacer()

                // Quit Button
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text(loc.tr("TomikPopoverView.quit.label", value: "Thoát"))
                        .font(tFont(11, .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(TomikPressableButtonStyle())
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
                primaryButton: .destructive(Text(loc.tr("StopConfirm.confirm", value: "Hủy phiên"))) {
                    timer.cancelTimer()
                },
                secondaryButton: .cancel(Text(loc.tr("StopConfirm.cancel", value: "Tiếp tục làm việc")))
            )
        }
        .onAppear {
            breakTip = TomikBreakActivities.randomActivity()
        }
        .onChange(of: timer.isRest) { isRest in
            if isRest {
                breakTip = TomikBreakActivities.randomActivity()
            }
        }
    }

    private func startTimerAction() {
        let trimmed = timer.activeSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            todoStorage.add(title: trimmed)
        }
        TomikStatusItem.shared.closePopover(nil)
        timer.startStop()
    }

    private func addQuickTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todoStorage.add(title: trimmed)
        if timer.activeSubject.isEmpty {
            timer.activeSubject = trimmed
        }
        newTodoText = ""
    }
}

// MARK: - Todo Drop Delegate for Drag & Drop Reordering
private struct TodoDropDelegate: DropDelegate {
    let targetItem: TomikTodoItem
    let items: [TomikTodoItem]
    @Binding var draggedItem: TomikTodoItem?
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

// MARK: - Todo Item Row Component (Full Scaling with `tomikScale`)
private struct TodoItemRow: View {
    let item: TomikTodoItem
    let isSelected: Bool
    let isDragging: Bool
    let theme: TomikThemeColor
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 13

    @State private var isHovered = false

    private var scale: CGFloat {
        tomikScale(baseSize: tomikFontSize)
    }

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
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
            .buttonStyle(TomikPressableButtonStyle(scaleAmount: 0.9))

            // Title (click to select and fill into text field)
            Button {
                onSelect()
            } label: {
                Text(item.title)
                    .font(tFont(12, isSelected ? .bold : .regular))
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .secondary : (isSelected ? theme.primaryColor : .primary))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(TomikPressableButtonStyle(scaleAmount: 0.99))

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
                .buttonStyle(TomikPressableButtonStyle(scaleAmount: 0.9))
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
    }
}
