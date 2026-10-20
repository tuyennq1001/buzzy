import SwiftUI
import LaunchAtLogin

extension NSImage.Name {
    static let idle = Self("BarIconIdle")
    static let work = Self("BarIconWork")
    static let shortRest = Self("BarIconShortRest")
    static let longRest = Self("BarIconLongRest")
}

private let digitFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)

@main
struct TomikApp: App {
    @NSApplicationDelegateAdaptor(TomikStatusItem.self) var appDelegate

    init() {
        TomikStatusItem.shared = appDelegate
        TomikStorage.migrateFromSandboxIfNeeded()
        LaunchAtLogin.migrateIfNeeded()
        logger.append(event: TomikLogEventAppStart())
    }

    var body: some Scene {
        Settings {}
    }
}

class TomikStatusItem: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var popover = NSPopover()
    private var statusBarItem: NSStatusItem?
    private var isClosing: Bool = false
    static var shared: TomikStatusItem!

    func applicationDidFinishLaunching(_: Notification) {
        let view = TomikPopoverView()

        popover.behavior = .transient
        popover.delegate = self
        popover.appearance = NSAppearance(named: .aqua)
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: view)
        if let contentViewController = popover.contentViewController {
            popover.contentSize.height = contentViewController.view.intrinsicContentSize.height
            popover.contentSize.width = 396
        }

        statusBarItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        statusBarItem?.button?.imagePosition = .imageLeft
        setIcon(name: .idle)
        statusBarItem?.button?.action = #selector(TomikStatusItem.togglePopover(_:))
    }

    func popoverWillClose(_ notification: Notification) {
        isClosing = true
    }

    func popoverDidClose(_ notification: Notification) {
        isClosing = false
    }

    func setTitle(title: String?) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.9
        paragraphStyle.alignment = NSTextAlignment.center

        let attributedTitle = NSAttributedString(
            string: title != nil ? " \(title!)" : "",
            attributes: [
                NSAttributedString.Key.font: digitFont,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )
        let oldWidth = statusBarItem?.button?.bounds.width ?? 0
        statusBarItem?.button?.attributedTitle = attributedTitle
        let newWidth = statusBarItem?.button?.bounds.width ?? 0

        // If title cleared or changed size while popover is open, re-anchor popover to stay centered
        if popover.isShown && !isClosing, let button = statusBarItem?.button, abs(oldWidth - newWidth) > 1 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.popover.isShown, !self.isClosing, let b = self.statusBarItem?.button else { return }
                self.popover.show(relativeTo: b.bounds, of: b, preferredEdge: NSRectEdge.minY)
            }
        }
    }

    func setIcon(name: NSImage.Name) {
        statusBarItem?.button?.image = NSImage(named: name)
    }

    func updateProgressRing(progress: Double, isBreak: Bool, theme: TomikThemeColor) {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 6.8
            let lineWidth: CGFloat = 2.2

            // Background track ring
            let trackPath = NSBezierPath()
            trackPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            trackPath.lineWidth = lineWidth
            NSColor.secondaryLabelColor.withAlphaComponent(0.25).setStroke()
            trackPath.stroke()

            // Active progress arc
            if progress > 0 {
                let strokeColor = isBreak ? TomikThemeColor.breakNSColor : theme.nsColor
                strokeColor.setStroke()

                let startAngle: CGFloat = 90
                let endAngle: CGFloat = 90 - CGFloat(min(1.0, max(0.0, progress)) * 360)
                let progressPath = NSBezierPath()
                progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                progressPath.lineWidth = lineWidth
                progressPath.lineCapStyle = .round
                progressPath.stroke()
            }

            // Center status dot
            let dotRect = NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            (isBreak ? TomikThemeColor.breakNSColor : theme.nsColor).setFill()
            dotPath.fill()

            return true
        }
        img.isTemplate = false
        statusBarItem?.button?.image = img
    }

    func showPopover(_: AnyObject?) {
        if let button = statusBarItem?.button {
            isClosing = false
            popover.contentSize = NSSize(width: 396, height: 490)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover(_ sender: AnyObject?) {
        isClosing = true
        popover.performClose(sender)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
}
