import SwiftUI
import AppKit

public class TomikConfettiController {
    public static let shared = TomikConfettiController()
    private var window: NSWindow?

    public func showConfetti() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.window?.close()

            guard let screen = NSScreen.main else { return }
            let frame = screen.frame

            let win = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = false
            win.level = .floating
            win.ignoresMouseEvents = true

            let hostingView = NSHostingView(rootView: ConfettiRainView())
            win.contentView = hostingView

            win.makeKeyAndOrderFront(nil)
            self.window = win

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
                self?.window?.close()
                self?.window = nil
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var vx: CGFloat
    var vy: CGFloat
    var rotation: Double
    var vRot: Double
}

private struct ConfettiRainView: View {
    @State private var particles: [ConfettiParticle] = []
    private let colors: [Color] = [.red, .yellow, .green, .blue, .orange, .purple, .pink]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for p in particles {
                    context.drawLayer { ctx in
                        ctx.translateBy(x: p.x, y: p.y)
                        ctx.rotate(by: Angle(degrees: p.rotation))
                        let rect = CGRect(x: -p.size/2, y: -p.size/4, width: p.size, height: p.size * 0.6)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(p.color))
                    }
                }
            }
        }
        .onAppear {
            generateParticles()
        }
    }

    private func generateParticles() {
        guard let screen = NSScreen.main else { return }
        let screenWidth = screen.frame.width
        let startX = screenWidth * 0.8 // Top right near Menu Bar

        var list: [ConfettiParticle] = []
        for _ in 0..<80 {
            list.append(ConfettiParticle(
                x: startX + CGFloat.random(in: -120...80),
                y: CGFloat.random(in: 20...60),
                size: CGFloat.random(in: 8...15),
                color: colors.randomElement() ?? .red,
                vx: CGFloat.random(in: -4...4),
                vy: CGFloat.random(in: 3...8),
                rotation: Double.random(in: 0...360),
                vRot: Double.random(in: -8...8)
            ))
        }
        particles = list

        // Animate physics
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            for i in 0..<particles.count {
                particles[i].x += particles[i].vx
                particles[i].y += particles[i].vy
                particles[i].vy += 0.18 // gravity
                particles[i].rotation += particles[i].vRot
            }
            if particles.allSatisfy({ $0.y > screen.frame.height }) {
                timer.invalidate()
            }
        }
    }
}
