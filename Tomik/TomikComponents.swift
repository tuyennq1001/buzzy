import SwiftUI
import AppKit

// MARK: - 1. Mouse Pointer Hand Modifier (Safe Push/Pop)
public struct TomikPointerModifier: ViewModifier {
    @State private var isPushed = false

    public func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering && !isPushed {
                    NSCursor.pointingHand.push()
                    isPushed = true
                } else if !hovering && isPushed {
                    NSCursor.pop()
                    isPushed = false
                }
            }
            .onDisappear {
                if isPushed {
                    NSCursor.pop()
                    isPushed = false
                }
            }
    }
}

public extension View {
    func tomikPointer() -> some View {
        modifier(TomikPointerModifier())
    }
}

// MARK: - 2. Pressable Button Style
public struct TomikPressableButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96

    public init(scaleAmount: CGFloat = 0.96) {
        self.scaleAmount = scaleAmount
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
            .tomikPointer()
    }
}

// MARK: - 3. Soft Kawaii Card Container
public struct TomikCard<Content: View>: View {
    let title: String
    let icon: String
    let theme: TomikThemeColor
    let content: Content

    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 13

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    public init(title: String, icon: String, theme: TomikThemeColor, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.theme = theme
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.primaryColor.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.primaryColor)
                }

                Text(title)
                    .font(tFont(13.5, .bold))
                    .foregroundColor(.primary)

                Spacer()
            }

            // Card Content
            VStack(spacing: 0) {
                content
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
        .shadow(color: theme.primaryColor.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - 4. Modern Setting Row (Left Title, Right Control, Subtle Divider)
public struct TomikSettingRow<Control: View>: View {
    let title: String
    var subtitle: String? = nil
    var showDivider: Bool = true
    let control: Control

    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 13

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    public init(title: String, subtitle: String? = nil, showDivider: Bool = true, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.showDivider = showDivider
        self.control = control()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(tFont(12.5, .medium))
                        .foregroundColor(.primary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(tFont(10.5))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 12)

                control
            }
            .padding(.vertical, 7)

            if showDivider {
                Divider()
                    .opacity(0.35)
            }
        }
    }
}

// MARK: - 5. Custom Themed Pill Tabs (No Stuck-Red Segmented Control Bug)
public struct TomikPillTabs<T: Hashable>: View {
    let items: [(tag: T, label: String, icon: String)]
    @Binding var selection: T
    let theme: TomikThemeColor

    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 13

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.tag) { item in
                let isSelected = selection == item.tag
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selection = item.tag
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(item.icon)
                            .font(.system(size: 13))
                        Text(item.label)
                            .font(tFont(12, isSelected ? .bold : .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(isSelected ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .frame(minHeight: 32)
                    .background(
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: theme.gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: theme.primaryColor.opacity(0.35), radius: 4, x: 0, y: 2)
                            } else {
                                Capsule()
                                    .fill(Color.clear)
                            }
                        }
                    )
                }
                .buttonStyle(TomikPressableButtonStyle(scaleAmount: 0.97))
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - 6. Custom Clean Slider (Zero Glitch Lines, 100% Theme Color)
public struct TomikSlider: View {
    @Binding var value: Double // Range 0.0 to 1.0
    let theme: TomikThemeColor
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var isDragging: Bool = false

    public init(value: Binding<Double>, theme: TomikThemeColor, onEditingChanged: ((Bool) -> Void)? = nil) {
        self._value = value
        self.theme = theme
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let thumbRadius: CGFloat = 8
            let usableWidth = max(1, totalWidth - thumbRadius * 2)
            let clamped = min(1.0, max(0.0, value))
            let currentX = thumbRadius + CGFloat(clamped) * usableWidth

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(height: 6)
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )

                // Filled Theme Track
                Capsule()
                    .fill(theme.primaryColor)
                    .frame(width: max(6, currentX), height: 6)

                // Thumb Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                    .overlay(
                        Circle().stroke(theme.primaryColor, lineWidth: 2)
                    )
                    .offset(x: currentX - thumbRadius)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }
                        let touchX = gesture.location.x - thumbRadius
                        let fraction = Double(max(0, min(usableWidth, touchX)) / usableWidth)
                        value = min(1.0, max(0.0, fraction))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
            .tomikPointer()
        }
        .frame(height: 20)
    }
}

// MARK: - 7. Custom Smooth Switch Toggle (Matches Selected Theme 100%)
public struct TomikToggle: View {
    @Binding var isOn: Bool
    let theme: TomikThemeColor

    public init(isOn: Binding<Bool>, theme: TomikThemeColor) {
        self._isOn = isOn
        self.theme = theme
    }

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? theme.primaryColor : Color(NSColor.controlBackgroundColor).opacity(0.9))
                    .frame(width: 38, height: 22)
                    .overlay(
                        Capsule().stroke(isOn ? theme.primaryColor : Color.primary.opacity(0.15), lineWidth: 1)
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(TomikPressableButtonStyle(scaleAmount: 0.94))
    }
}

// MARK: - 8. Custom Pill Stepper: [ – ] Value [ + ] (Big & Friendly for Kids & Women)
public struct TomikStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var unit: String = ""
    let theme: TomikThemeColor

    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 13

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    public init(value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1, unit: String = "", theme: TomikThemeColor) {
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.theme = theme
    }

    public var body: some View {
        HStack(spacing: 4) {
            // Minus Button
            Button {
                if value - step >= range.lowerBound {
                    value -= step
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(value > range.lowerBound ? theme.primaryColor : Color.secondary.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(TomikPressableButtonStyle())
            .disabled(value <= range.lowerBound)

            // Value Label
            Text("\(value)\(unit.isEmpty ? "" : " " + unit)")
                .font(tFont(12, .bold))
                .foregroundColor(.primary)
                .frame(minWidth: 54, alignment: .center)

            // Plus Button
            Button {
                if value + step <= range.upperBound {
                    value += step
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(value < range.upperBound ? theme.primaryColor : Color.secondary.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(TomikPressableButtonStyle())
            .disabled(value >= range.upperBound)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.primaryColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 9. Bento Stat Card (Cute Summaries with Mascot Vibe)
public struct TomikStatCard: View {
    let emoji: String
    let title: String
    let value: String
    var subtitle: String? = nil
    let theme: TomikThemeColor

    @AppStorage("tomikFontName") private var tomikFontName: String = TomikUnicodeFont.system.rawValue
    @AppStorage("tomikFontSize") private var tomikFontSize: Int = 13

    private func tFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        tomikFont(size: size, weight: weight, fontName: tomikFontName, baseSize: tomikFontSize)
    }

    public init(emoji: String, title: String, value: String, subtitle: String? = nil, theme: TomikThemeColor) {
        self.emoji = emoji
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.theme = theme
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 16))
                Text(title)
                    .font(tFont(11.5, .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(value)
                .font(tFont(18, .heavy))
                .foregroundColor(theme.primaryColor)

            if let sub = subtitle {
                Text(sub)
                    .font(tFont(10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.softBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1.2)
        )
    }
}
