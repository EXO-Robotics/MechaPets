// Original, procedural workshop artwork. Activity is a count, never task content.
import AppKit

struct ForgeStyle {
    let level: Int
    var strikesPerSecond: Double { [0, 1.0, 2.0, 3.3][level] }
    var sparkCount: Int { [0, 5, 10, 16][level] }
    var glow: Double { [0, 0.45, 0.72, 1.0][level] }
    init(count: Int) { level = min(3, max(0, count)) }

    func phase(at time: Double) -> Double {
        guard level > 0 else { return 0 }
        return (max(0, time) * strikesPerSecond).truncatingRemainder(dividingBy: 1)
    }
    // Long wind-up, quick strike, short contact. Shared by hammer and sparks.
    func hammerLift(at time: Double, reducedMotion: Bool) -> Double {
        guard level > 0 && !reducedMotion else { return 0 }
        let phase = phase(at: time)
        return phase < 0.7 ? sin(phase / 0.7 * .pi / 2) : max(0, 1 - (phase - 0.7) / 0.18)
    }
    func impactAge(at time: Double) -> Double {
        guard level > 0 else { return .infinity }
        return (phase(at: time) + 0.12).truncatingRemainder(dividingBy: 1) / strikesPerSecond
    }
}

extension PetView {
    func drawForge(at position: V, count: Int, time: Double, reducedMotion: Bool) {
        let style = ForgeStyle(count: count)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: position.x, yBy: position.y)
        transform.concat()
        let ink = NSColor(calibratedRed: 0.06, green: 0.14, blue: 0.20, alpha: 1)
        let metal = NSColor(calibratedRed: 0.24, green: 0.35, blue: 0.41, alpha: 1)
        let edge = NSColor(calibratedRed: 0.57, green: 0.72, blue: 0.72, alpha: 1)
        func box(_ rect: NSRect, radius: CGFloat, color: NSColor) {
            let p = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            color.setFill(); p.fill(); ink.setStroke(); p.lineWidth = 1.5; p.stroke()
        }
        // Compact side anvil: all artwork fits inside the pet's existing safe margin.
        box(NSRect(x: 27, y: -42, width: 25, height: 5), radius: 2, color: metal)
        box(NSRect(x: 35, y: -38, width: 10, height: 12), radius: 2, color: metal)
        let anvil = NSBezierPath()
        anvil.move(to: NSPoint(x: 24, y: -25))
        anvil.line(to: NSPoint(x: 54, y: -25))
        anvil.line(to: NSPoint(x: 48, y: -31))
        anvil.line(to: NSPoint(x: 30, y: -31))
        anvil.close(); metal.setFill(); anvil.fill(); ink.setStroke(); anvil.lineWidth = 1.5; anvil.stroke()
        let rim = NSBezierPath(); rim.move(to: NSPoint(x: 29, y: -26)); rim.line(to: NSPoint(x: 49, y: -26))
        edge.setStroke(); rim.lineWidth = 1.4; rim.stroke()

        guard style.level > 0 else { return }
        let age = style.impactAge(at: time)
        let impact = reducedMotion ? 0 : max(0, 1 - age / 0.16)
        let glow = NSColor(calibratedRed: 1, green: 0.48 + 0.2 * style.glow, blue: 0.13, alpha: 0.10 + 0.12 * style.glow + impact * 0.10)
        glow.setFill()
        NSBezierPath(ovalIn: NSRect(x: 29, y: -33, width: 25, height: 22)).fill()
        let hot = NSColor(calibratedRed: 1, green: 0.51 + impact * 0.32, blue: 0.21 + impact * 0.25, alpha: 1)
        box(NSRect(x: 35, y: -25, width: 11, height: 4), radius: 1.5, color: hot)
        // Deterministic sparks have no retained particle state or unbounded allocation.
        guard !reducedMotion && age < 0.25 else { return }
        let progress = age / 0.25
        for i in 0..<style.sparkCount {
            let seed = Double((i * 37 + 11) % 101) / 100
            let reach = (28 + seed * 48) * (0.55 + 0.15 * Double(style.level))
            let spread = Double((i * 61 + 29) % 101) / 100
            let dx = -15 + spread * 27
            let x = 40 + dx * progress
            let y = -21 + reach * sin(progress * .pi * 0.76) - 5 * progress
            let spark = NSBezierPath()
            spark.move(to: NSPoint(x: x, y: y))
            spark.line(to: NSPoint(x: x - dx * 0.04, y: y - 3.2))
            spark.lineWidth = i % 3 == 0 ? 2 : 1.25
            spark.lineCapStyle = .round
            NSColor(calibratedRed: 1, green: 0.58 + seed * 0.36, blue: 0.20 + seed * 0.39, alpha: (1 - progress) * 0.95).setStroke()
            spark.stroke()
        }
    }
}
