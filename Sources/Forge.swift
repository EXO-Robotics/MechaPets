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
        if !reducedMotion && impact > 0 {
            NSColor(calibratedRed: 1, green: 0.72, blue: 0.28, alpha: 0.16 + impact * 0.38).setFill()
            NSBezierPath(ovalIn: NSRect(x: 35.5, y: -28.2, width: 10.5, height: 7.4)).fill()
            NSColor(calibratedRed: 1, green: 0.92, blue: 0.62, alpha: 0.20 + impact * 0.45).setFill()
            NSBezierPath(ovalIn: NSRect(x: 37.6, y: -26.4, width: 6.2, height: 3.8)).fill()
        }
        // Deterministic sparks have no retained particle state or unbounded allocation.
        guard !reducedMotion && age < 0.25 else { return }
        let progress = age / 0.25
        func sparkPoint(_ p: Double, x0: Double, y0: Double, vx: Double, vy: Double, grav: Double) -> NSPoint {
            let t = max(0, min(1, p))
            let x = min(53.5, max(-53.5, x0 + vx * t))
            let y = min(53.5, max(-41.8, y0 + vy * t - 0.5 * grav * t * t))
            return NSPoint(x: x, y: y)
        }
        for i in 0..<style.sparkCount {
            let seed = Double((i * 37 + 11) % 101) / 100
            let spread = Double((i * 61 + 29) % 101) / 100
            let hang = Double((i * 89 + 17) % 101) / 100
            let life = 0.72 + seed * 0.28
            let fade = max(0, 1 - progress / life)
            guard fade > 0.02 else { continue }
            let p = min(1, progress / life)
            let x0 = 40.0 + (spread - 0.5) * 2.4
            let y0 = -21.2
            let vx = -13.5 + spread * 23.0 + (seed - 0.5) * 5.0
            let levelScale = 0.55 + 0.15 * Double(style.level)
            let vy = (34 + seed * 40 + hang * 12) * levelScale
            let grav = 50 + hang * 28
            let head = sparkPoint(p, x0: x0, y0: y0, vx: vx, vy: vy, grav: grav)
            let thick: CGFloat = i % 3 == 0 ? 2.05 : 1.25
            for k in 0..<3 {
                let p0 = p - Double(k) * 0.085
                let p1 = p - Double(k + 1) * 0.085
                guard p0 > 0 else { continue }
                let a = sparkPoint(p0, x0: x0, y0: y0, vx: vx, vy: vy, grav: grav)
                let b = sparkPoint(max(0, p1), x0: x0, y0: y0, vx: vx, vy: vy, grav: grav)
                let ember = NSBezierPath()
                ember.move(to: a)
                ember.line(to: b)
                ember.lineWidth = thick * (1 - CGFloat(k) * 0.28)
                ember.lineCapStyle = .round
                let trail = fade * (0.92 - Double(k) * 0.28)
                NSColor(calibratedRed: 1, green: 0.48 + seed * 0.40 - Double(k) * 0.10, blue: 0.16 + seed * 0.28, alpha: trail).setStroke()
                ember.stroke()
            }
            NSColor(calibratedRed: 1, green: 0.78 + seed * 0.18, blue: 0.42 + seed * 0.28, alpha: fade * 0.95).setFill()
            NSBezierPath(ovalIn: NSRect(x: head.x - 1.15, y: head.y - 1.05, width: 2.3, height: 2.1)).fill()
        }
    }
}
