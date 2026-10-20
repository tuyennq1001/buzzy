import SwiftUI
import AppKit
import KeyboardShortcuts
import LaunchAtLogin

public enum TomikManagementTab: Hashable {
    case stats
    case settings
}

public class TomikStatsWindowController: NSObject {
    public static let shared = TomikStatsWindowController()
    private var window: NSWindow?

    public func show(tab: TomikManagementTab = .stats) {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 730, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            let baseTitle = TomikLocalization.shared.tr("Management.windowTitle", value: "Tomik — Quản Lý & Cài Đặt")
            let localizedSuffix = baseTitle.replacingOccurrences(of: "Tomik — ", with: "")
            win.title = "\(tomikAppTitle) — \(localizedSuffix)"
            win.center()
            win.isReleasedWhenClosed = false
            win.appearance = NSAppearance(named: .aqua) // Force Light mode for pastel charm

            let view = TomikManagementContainerView(initialTab: tab)
            win.contentView = NSHostingView(rootView: view)
            self.window = win
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("TomikSwitchManagementTab"), object: tab)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

public struct TomikManagementContainerView: View {
    @ObservedObject var storage = TomikStorage.shared
    @ObservedObject var loc = TomikLocalization.shared
    @AppStorage("themeColor") private var themeColorRaw: String = TomikThemeColor.blue.rawValue
    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 16
    @State private var selectedTab: TomikManagementTab

    public init(initialTab: TomikManagementTab = .stats) {
        _selectedTab = State(initialValue: initialTab)
    }

    private var theme: TomikThemeColor {
        TomikThemeColor(rawValue: themeColorRaw) ?? .blue
    }

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image("TomikLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(tomikAppTitle)
                                .font(tFont(16, .heavy))
                                .foregroundColor(.primary)
                            if isTomikDev {
                                Text("DEV")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(loc.tr("Management.subtitle", value: "Trung tâm thống kê & thiết lập cá nhân"))
                            .font(tFont(11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Custom Themed Pill Tabs
                TomikPillTabs(
                    items: [
                        (tag: .stats, label: loc.tr("Stats.tab.title", value: "Thống kê"), icon: "📊"),
                        (tag: .settings, label: loc.tr("Settings.tab.title", value: "Cài đặt"), icon: "⚙️")
                    ],
                    selection: $selectedTab,
                    theme: theme
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()
                .opacity(0.4)

            // Content Area
            Group {
                if selectedTab == .stats {
                    TomikStatsBodyView(theme: theme)
                } else {
                    TomikSettingsBodyView(theme: theme)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.softBackground.opacity(0.35))
        }
        .frame(minWidth: 700, minHeight: 560)
        .preferredColorScheme(.light)
        .tint(theme.primaryColor)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TomikSwitchManagementTab"))) { notif in
            if let tab = notif.object as? TomikManagementTab {
                selectedTab = tab
            }
        }
    }
}

// MARK: - Bento Stats & Progress Body View (1-Screen Overview)
private struct TomikStatsBodyView: View {
    let theme: TomikThemeColor
    @ObservedObject var storage = TomikStorage.shared
    @ObservedObject var loc = TomikLocalization.shared
    @AppStorage("dailyTarget") private var dailyTarget: Int = 10
    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 16

    @State private var selectedDayIndex: Int = -1

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    var body: some View {
        let heatmapDays = storage.getHeatmapDays(weeks: 18)
        let safeIndex = selectedDayIndex >= 0 && selectedDayIndex < heatmapDays.count ? selectedDayIndex : max(0, heatmapDays.count - 1)
        let selectedRecord = heatmapDays.indices.contains(safeIndex) ? heatmapDays[safeIndex] : nil

        ScrollView {
            VStack(spacing: 16) {
                // Top Row: 3 Bento Stat Cards
                HStack(spacing: 14) {
                    let todayCount = storage.todayTomatoesCount
                    let todayPercent = min(100, Int((Double(todayCount) / Double(max(1, dailyTarget))) * 100))
                    TomikStatCard(
                        emoji: "🍅",
                        title: loc.tr("Stats.today.card", value: "Hôm nay"),
                        value: "\(todayCount)/\(dailyTarget) " + loc.tr("Units.tomatoesShort", value: "quả"),
                        subtitle: "\(todayPercent)% " + loc.tr("Stats.target.done", value: "mục tiêu ngày"),
                        theme: theme
                    )

                    TomikStatCard(
                        emoji: "🔥",
                        title: loc.tr("Stats.streak.card", value: "Chuỗi chăm chỉ"),
                        value: "\(storage.currentStreakDays) " + loc.tr("Stats.days", value: "ngày"),
                        subtitle: storage.currentStreakDays > 0 ? loc.tr("Stats.streak.cheer", value: "Giữ vững phong độ nhé!") : loc.tr("Stats.streak.start", value: "Bắt đầu chuỗi mới nào!"),
                        theme: theme
                    )

                    let totalTomatoes = storage.totalTomatoesCount
                    let totalHours = Double(storage.totalFocusMinutes) / 60.0
                    let hourString = loc.tr("Stats.hours.fmt", String(format: totalHours >= 10 ? "%.0f" : "%.1f", totalHours))
                    TomikStatCard(
                        emoji: "🏆",
                        title: loc.tr("Stats.total.card", value: "Tổng thu hoạch"),
                        value: "\(totalTomatoes) " + loc.tr("Units.tomatoesShort", value: "quả"),
                        subtitle: "\(hourString) " + loc.tr("Stats.focused", value: "tập trung"),
                        theme: theme
                    )
                }

                // Middle Bento Card: Heatmap Grid (18 Weeks)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(loc.tr("Stats.garden.title", value: "Vườn Cà Chua 18 Tuần"), systemImage: "square.grid.3x3.fill")
                            .font(tFont(13.5, .bold))
                            .foregroundColor(.primary)

                        Spacer()

                        // Heatmap Legend
                        HStack(spacing: 5) {
                            Text(loc.tr("Stats.less", value: "Ít"))
                                .font(tFont(10))
                                .foregroundColor(.secondary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                .frame(width: 12, height: 12)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.primaryColor.opacity(0.35))
                                .frame(width: 12, height: 12)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.primaryColor.opacity(0.65))
                                .frame(width: 12, height: 12)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.primaryColor)
                                .frame(width: 12, height: 12)
                            Text(loc.tr("Stats.more", value: "Nhiều"))
                                .font(tFont(10))
                                .foregroundColor(.secondary)
                        }
                    }

                    HeatmapGridView(
                        days: heatmapDays,
                        selectedIndex: Binding(
                            get: { safeIndex },
                            set: { selectedDayIndex = $0 }
                        ),
                        theme: theme
                    )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.primaryColor.opacity(0.18), lineWidth: 1.2)
                )

                // Bottom Bento Card: Selected Day Details & Sessions
                if let record = selectedRecord {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            // Date navigation
                            HStack(spacing: 6) {
                                Button {
                                    if safeIndex > 0 { selectedDayIndex = safeIndex - 1 }
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(safeIndex > 0 ? theme.primaryColor : .secondary.opacity(0.4))
                                        .frame(width: 22, height: 22)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(TomikPressableButtonStyle())
                                .disabled(safeIndex <= 0)

                                Text(record.displayDateFull)
                                    .font(tFont(13.5, .bold))
                                    .foregroundColor(.primary)

                                Button {
                                    if safeIndex < heatmapDays.count - 1 { selectedDayIndex = safeIndex + 1 }
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(safeIndex < heatmapDays.count - 1 ? theme.primaryColor : .secondary.opacity(0.4))
                                        .frame(width: 22, height: 22)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(TomikPressableButtonStyle())
                                .disabled(safeIndex >= heatmapDays.count - 1)
                            }

                            Spacer()

                            Text("🍅 \(record.tomatoCount) \(loc.tr("Units.tomatoesShort", value: "quả")) • \(record.totalMinutes) \(loc.tr("Units.min", value: "phút"))")
                                .font(tFont(12.5, .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.primaryColor.opacity(0.14))
                                .foregroundColor(theme.primaryColor)
                                .cornerRadius(8)
                        }

                        Divider()
                            .opacity(0.35)

                        if record.sessions.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Text("🌱")
                                        .font(.system(size: 28))
                                    Text(loc.tr("Stats.day.empty", value: "Ngày này chưa có phiên tập trung nào. Cùng gieo mầm nhé!"))
                                        .font(tFont(12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 16)
                                Spacer()
                            }
                        } else {
                            VStack(spacing: 6) {
                                ForEach(record.sessions) { s in
                                    HStack(spacing: 10) {
                                        Text("🍅")
                                            .font(.system(size: 14))
                                        Text(s.subject)
                                            .font(tFont(12, .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(s.timeString) • \(s.durationMinutes)p")
                                            .font(tFont(11))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                                            .cornerRadius(6)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(theme.softBackground.opacity(0.4))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.primaryColor.opacity(0.18), lineWidth: 1.2)
                    )
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Heatmap Grid View (Clean 18-Week Responsive Grid)
private struct HeatmapGridView: View {
    let days: [TomikDailyRecord]
    @Binding var selectedIndex: Int
    let theme: TomikThemeColor

    private var weeklyColumns: [[TomikDailyRecord]] {
        var cols: [[TomikDailyRecord]] = []
        var current: [TomikDailyRecord] = []
        for day in days {
            current.append(day)
            if current.count == 7 {
                cols.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            cols.append(current)
        }
        return cols
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(weeklyColumns.indices, id: \.self) { colIdx in
                VStack(spacing: 6) {
                    ForEach(weeklyColumns[colIdx].indices, id: \.self) { rowIdx in
                        let day = weeklyColumns[colIdx][rowIdx]
                        let flatIdx = colIdx * 7 + rowIdx
                        HeatmapCell(
                            day: day,
                            theme: theme,
                            isSelected: flatIdx == selectedIndex
                        )
                        .onTapGesture {
                            selectedIndex = flatIdx
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 6)
    }
}

private struct HeatmapCell: View {
    let day: TomikDailyRecord
    let theme: TomikThemeColor
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(colorForCount(day.tomatoCount))
            .frame(width: 16, height: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.primary : (isHovered ? theme.primaryColor : Color.clear), lineWidth: isSelected ? 2 : 1.2)
            )
            .scaleEffect(isHovered ? 1.2 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            .help(String(format: TomikLocalization.shared.tr("Stats.heatmap.cellHelp", value: "%@: %d quả cà chua (%d phút)"), day.displayDateFull, day.tomatoCount, day.totalMinutes))
            .tomikPointer()
            .onHover { hover in
                isHovered = hover
            }
    }

    private func colorForCount(_ count: Int) -> Color {
        if count == 0 {
            return Color(NSColor.controlBackgroundColor).opacity(0.8)
        } else if count <= 2 {
            return theme.primaryColor.opacity(0.35)
        } else if count <= 5 {
            return theme.primaryColor.opacity(0.68)
        } else {
            return theme.primaryColor
        }
    }
}

// MARK: - Settings & Sounds Body View (Soft Kawaii Cards)
private struct TomikSettingsBodyView: View {
    let theme: TomikThemeColor
    @ObservedObject var loc = TomikLocalization.shared
    @ObservedObject var player = TomikTimer.shared.player
    @ObservedObject var timer = TomikTimer.shared
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable
    @ObservedObject private var updater = TomikUpdaterViewModel.shared
    @AppStorage("themeColor") private var themeColorRaw: String = TomikThemeColor.blue.rawValue
    @AppStorage("dailyTarget") private var dailyTarget: Int = 10
    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 16

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Card 1: Time Intervals
                TomikCard(title: loc.tr("Settings.section.intervals", value: "Thời lượng các phiên"), icon: "clock.fill", theme: theme) {
                    TomikSettingRow(title: loc.tr("Profile.label", value: "Chế độ / Profile")) {
                        Picker("", selection: Binding(
                            get: {
                                TomikProfile.matchingProfile(
                                    work: timer.workIntervalLength,
                                    shortRest: timer.shortRestIntervalLength,
                                    longRest: timer.longRestIntervalLength
                                )
                            },
                            set: { newProfile in
                                if let intervals = newProfile.intervals {
                                    timer.workIntervalLength = intervals.work
                                    timer.shortRestIntervalLength = intervals.shortRest
                                    timer.longRestIntervalLength = intervals.longRest
                                    timer.workIntervalsInSet = intervals.sets
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
                        .frame(width: 175)
                        .tomikPointer()
                    }

                    TomikSettingRow(title: loc.tr("IntervalsView.workIntervalLength.label", value: "Thời gian tập trung:")) {
                        TomikStepper(value: $timer.workIntervalLength, in: 1...60, unit: loc.tr("Units.min", value: "phút"), theme: theme)
                    }

                    TomikSettingRow(title: loc.tr("IntervalsView.shortRestIntervalLength.label", value: "Nghỉ ngắn:")) {
                        TomikStepper(value: $timer.shortRestIntervalLength, in: 1...60, unit: loc.tr("Units.min", value: "phút"), theme: theme)
                    }

                    TomikSettingRow(title: loc.tr("IntervalsView.longRestIntervalLength.label", value: "Nghỉ dài:")) {
                        TomikStepper(value: $timer.longRestIntervalLength, in: 1...60, unit: loc.tr("Units.min", value: "phút"), theme: theme)
                    }

                    TomikSettingRow(title: loc.tr("IntervalsView.workIntervalsInSet.label", value: "Số phiên trong 1 chu kỳ:")) {
                        TomikStepper(value: $timer.workIntervalsInSet, in: 1...10, unit: loc.tr("Units.sets", value: "phiên"), theme: theme)
                    }

                    TomikSettingRow(title: loc.tr("Settings.dailyTarget.label", value: "Mục tiêu hàng ngày:"), showDivider: false) {
                        TomikStepper(value: $dailyTarget, in: 1...50, unit: loc.tr("Units.tomatoes", value: "quả 🍅"), theme: theme)
                    }
                }

                // Card 2: Sounds & Chimes
                TomikCard(title: loc.tr("Settings.section.sounds", value: "Âm thanh & Chuông báo"), icon: "speaker.wave.3.fill", theme: theme) {
                    TomikSettingRow(title: loc.tr("SoundsView.soundTheme.label", value: "Âm thanh báo kết thúc:")) {
                        Picker("", selection: Binding(
                            get: { player.currentSoundTheme },
                            set: { newSound in
                                player.currentSoundTheme = newSound
                                player.playThemeSound(newSound)
                            }
                        )) {
                            ForEach(TomikSoundTheme.allCases) { sound in
                                Text("\(sound.icon) \(sound.displayName(for: loc.currentLanguage))").tag(sound)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 175)
                        .tomikPointer()
                    }

                    TomikSettingRow(title: loc.tr("SoundsView.isDingEnabled.label", value: "Tiếng chuông kết thúc")) {
                        VolumeControlRow(volume: $player.dingVolume, theme: theme) {
                            player.playDing()
                        }
                    }

                    TomikSettingRow(title: loc.tr("SoundsView.isWindupEnabled.label", value: "Tiếng vặn cót")) {
                        VolumeControlRow(volume: $player.windupVolume, theme: theme) {
                            player.playWindup()
                        }
                    }

                    TomikSettingRow(title: loc.tr("SoundsView.isTickingEnabled.label", value: "Tiếng tích tắc đồng hồ"), showDivider: false) {
                        VolumeControlRow(volume: $player.tickingVolume, theme: theme)
                    }
                }

                // Card 3: Customization & Appearance
                TomikCard(title: loc.tr("Settings.section.general", value: "Tùy biến & Hoạt động"), icon: "paintpalette.fill", theme: theme) {
                    // Theme Colors Palette (6 Sweet Colors)
                    TomikSettingRow(title: loc.tr("SettingsView.themeColor.label", value: "Màu chủ đề:")) {
                        HStack(spacing: 8) {
                            ForEach(TomikThemeColor.allCases) { c in
                                let isSelected = themeColorRaw == c.rawValue
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        themeColorRaw = c.rawValue
                                        timer.updateTimeLeft()
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(c.primaryColor)
                                            .frame(width: 26, height: 26)

                                        if isSelected {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2.5)
                                                .frame(width: 22, height: 22)

                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .black))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .shadow(color: c.primaryColor.opacity(isSelected ? 0.45 : 0.15), radius: isSelected ? 4 : 2, x: 0, y: 2)
                                }
                                .buttonStyle(TomikPressableButtonStyle(scaleAmount: 0.9))
                                .help("\(c.emoji) \(c.displayName)")
                            }
                        }
                    }

                    // Language Picker
                    TomikSettingRow(title: loc.tr("SettingsView.language.label", value: "Ngôn ngữ:")) {
                        Picker("", selection: $loc.currentLanguageRaw) {
                            ForEach(TomikLanguage.allCases) { lang in
                                Text("\(lang.flag) \(lang.displayName)").tag(lang.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 175)
                        .tomikPointer()
                    }

                    // Font Picker (4 Sweet Fonts)
                    TomikSettingRow(title: loc.tr("SettingsView.fontName.label", value: "Kiểu font (4 font dễ thương):")) {
                        Picker("", selection: Binding(
                            get: {
                                TomikUnicodeFont.match(tomikFontName).rawValue
                            },
                            set: { newVal in
                                tomikFontName = newVal
                            }
                        )) {
                            ForEach(TomikUnicodeFont.allCases) { f in
                                Text(f.displayName).tag(f.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 270)
                        .tomikPointer()
                    }

                    // Font Size
                    TomikSettingRow(title: loc.tr("SettingsView.fontSize.label", value: "Cỡ chữ:")) {
                        TomikStepper(value: $tomikFontSize, in: 10...20, unit: loc.tr("Units.pt", value: "pt"), theme: theme)
                    }

                    // Shortcut Recorder
                    TomikSettingRow(title: loc.tr("SettingsView.shortcut.label", value: "Phím tắt mở Tomik:")) {
                        KeyboardShortcuts.Recorder(for: .startStopTimer)
                            .tomikPointer()
                    }

                    // Auto Start Break Toggle
                    TomikSettingRow(title: loc.tr("SettingsView.autoStartBreak.label", value: "Tự động bắt đầu giờ nghỉ")) {
                        TomikToggle(isOn: $timer.autoStartBreak, theme: theme)
                    }

                    // Auto Start Focus Toggle
                    TomikSettingRow(title: loc.tr("SettingsView.autoStartFocus.label", value: "Tự động bắt đầu tập trung")) {
                        TomikToggle(isOn: $timer.autoStartFocus, theme: theme)
                    }

                    // Show Timer in Menu Bar Toggle
                    TomikSettingRow(title: loc.tr("SettingsView.showTimerInMenuBar.label", value: "Hiện số phút trên Menu Bar")) {
                        TomikToggle(isOn: Binding(
                            get: { timer.showTimerInMenuBar },
                            set: { val in
                                timer.showTimerInMenuBar = val
                                timer.updateTimeLeft()
                            }
                        ), theme: theme)
                    }

                    // Launch at Login Toggle
                    TomikSettingRow(title: loc.tr("SettingsView.launchAtLogin.label", value: "Khởi động cùng máy Mac"), showDivider: false) {
                        TomikToggle(isOn: $launchAtLogin.isEnabled, theme: theme)
                    }
                }

                // Card 4: About & Updates
                TomikCard(title: loc.tr("Settings.section.updates", value: "Thông tin & Cập nhật"), icon: "arrow.triangle.2.circlepath.circle.fill", theme: theme) {
                    TomikSettingRow(title: loc.tr("Settings.updates.version.label", value: "Phiên bản hiện tại:")) {
                        Text(updater.appVersionString)
                            .font(tFont(12, .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }

                    TomikSettingRow(title: loc.tr("Settings.updates.author.label", value: "Tác giả:")) {
                        if let url = URL(string: "mailto:tuyennq.1001@gmail.com") {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Text("Terry")
                                        .font(tFont(12, .semibold))
                                        .foregroundColor(.primary)
                                    Text("•")
                                        .font(tFont(10, .regular))
                                        .foregroundColor(.secondary)
                                    Text("tuyennq.1001@gmail.com")
                                        .font(tFont(11.5, .medium))
                                        .foregroundColor(theme.primaryColor)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.tintBackground)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .tomikPointer()
                            .help("tuyennq.1001@gmail.com")
                        }
                    }

                    TomikSettingRow(title: loc.tr("Settings.updates.autoDownload.label", value: "Tự động tải về âm thầm:")) {
                        TomikToggle(isOn: $updater.automaticallyDownloadsUpdates, theme: theme)
                            .disabled(!updater.isAvailable)
                            .help(loc.tr("Settings.updates.autoDownload.help", value: "Tự động tải về bản cập nhật trong nền và áp dụng khi khởi động lại"))
                    }

                    TomikSettingRow(title: loc.tr("Settings.updates.check.label", value: "Cập nhật ứng dụng:"), showDivider: false) {
                        Button {
                            updater.checkForUpdates()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .bold))
                                Text(loc.tr("Settings.updates.checkNow", value: "Kiểm tra bản cập nhật..."))
                                    .font(tFont(11.5, .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.primaryColor)
                            .cornerRadius(8)
                        }
                        .buttonStyle(TomikPressableButtonStyle())
                        .disabled(!updater.isAvailable && !updater.canCheckForUpdates)
                        .help(loc.tr("Settings.updates.check.help", value: "Kiểm tra phiên bản mới nhất từ GitHub Releases"))
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Volume Control Row (Custom Clean Themed Slider & Minus/Plus)
private struct VolumeControlRow: View {
    @Binding var volume: Double
    let theme: TomikThemeColor
    var onAdjust: (() -> Void)? = nil

    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 16

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    private var volume100: Int {
        min(100, max(0, Int((volume * 100).rounded())))
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                let next = max(0, volume100 - 5)
                volume = Double(next) / 100.0
                onAdjust?()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(volume100 > 0 ? theme.primaryColor : Color.secondary.opacity(0.35))
            }
            .buttonStyle(TomikPressableButtonStyle())
            .disabled(volume100 <= 0)

            TomikSlider(
                value: $volume,
                theme: theme,
                onEditingChanged: { isEditing in
                    if !isEditing {
                        onAdjust?()
                    }
                }
            )
            .frame(width: 130)

            Button {
                let next = min(100, volume100 + 5)
                volume = Double(next) / 100.0
                onAdjust?()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(volume100 < 100 ? theme.primaryColor : Color.secondary.opacity(0.35))
            }
            .buttonStyle(TomikPressableButtonStyle())
            .disabled(volume100 >= 100)

            Text("\(volume100)%")
                .font(tFont(11.5, .bold))
                .foregroundColor(.primary)
                .frame(width: 42, alignment: .trailing)
        }
    }
}
