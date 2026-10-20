import AppKit
import QuartzCore

public class BuzzyConfettiController {
    public static let shared = BuzzyConfettiController()
    private var window: NSWindow?
    private var dismissWorkItem: DispatchWorkItem?

    public func showConfetti() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.dismissWorkItem?.cancel()
            self.dismissWorkItem = nil
            self.closeConfettiWindow()

            guard let screen = NSScreen.main else { return }
            let frame = screen.frame

            let win = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            // Critical for AppKit ARC windows to prevent double release / EXC_BAD_ACCESS
            win.isReleasedWhenClosed = false
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = false
            win.level = .floating
            win.ignoresMouseEvents = true

            let confettiView = ConfettiEmitterView(frame: NSRect(origin: .zero, size: frame.size))
            win.contentView = confettiView

            win.orderFrontRegardless()
            self.window = win

            // Stop emitting new particles after 0.5s so they clear naturally
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak confettiView] in
                confettiView?.stopEmitting()
            }

            // Close and clean up after 2.8s
            let workItem = DispatchWorkItem { [weak self] in
                self?.closeConfettiWindow()
            }
            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: workItem)
        }
    }

    private func closeConfettiWindow() {
        guard let win = window else { return }
        win.orderOut(nil)
        win.contentView = nil
        win.close()
        window = nil
    }
}

private final class ConfettiEmitterView: NSView {
    private let emitterLayer = CAEmitterLayer()

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupEmitter()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupEmitter()
    }

    private func setupEmitter() {
        guard let layer = self.layer else { return }

        let screenWidth = bounds.width
        let emitterX = screenWidth * 0.8
        let emitterY: CGFloat = 10

        emitterLayer.emitterPosition = CGPoint(x: emitterX, y: emitterY)
        emitterLayer.emitterShape = .line
        emitterLayer.emitterSize = CGSize(width: 260, height: 1)
        emitterLayer.renderMode = .unordered

        let colors: [NSColor] = [
            NSColor(srgbRed: 239/255, green: 68/255, blue: 68/255, alpha: 1),   // Red
            NSColor(srgbRed: 245/255, green: 158/255, blue: 11/255, alpha: 1),  // Amber
            NSColor(srgbRed: 16/255, green: 185/255, blue: 129/255, alpha: 1),  // Green
            NSColor(srgbRed: 59/255, green: 130/255, blue: 246/255, alpha: 1),  // Blue
            NSColor(srgbRed: 236/255, green: 72/255, blue: 153/255, alpha: 1),  // Pink
            NSColor(srgbRed: 168/255, green: 85/255, blue: 247/255, alpha: 1)   // Purple
        ]

        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 18
            cell.lifetime = 3.0
            cell.lifetimeRange = 0.5
            cell.velocity = 180
            cell.velocityRange = 80
            cell.yAcceleration = 220
            cell.xAcceleration = 0
            cell.emissionLongitude = .pi / 2
            cell.emissionRange = .pi / 3
            cell.spin = 3.0
            cell.spinRange = 4.0
            cell.scale = 0.8
            cell.scaleRange = 0.4

            if let img = makeParticleImage(color: color, size: CGSize(width: 9, height: 6)) {
                cell.contents = img
            }
            cells.append(cell)
        }

        emitterLayer.emitterCells = cells
        layer.addSublayer(emitterLayer)
    }

    func stopEmitting() {
        emitterLayer.birthRate = 0
    }

    private func makeParticleImage(color: NSColor, size: CGSize) -> CGImage? {
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5)
            color.setFill()
            path.fill()
            return true
        }
        var imageRect = CGRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
    }
}
