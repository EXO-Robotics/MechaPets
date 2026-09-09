// Original, procedural workshop artwork. Activity is a count, never task content.
import AppKit

struct ForgeStyle {
    let level: Int
    var strikesPerSecond: Double { [0, 1.0, 2.8, 5.0][level] }
    var sparkCount: Int { [0, 5, 28, 72][level] }
    var sparkLifetime: Double { [0, 0.40, 0.72, 0.90][level] }
    var sparkGenerations: Int { max(1, Int(ceil(sparkLifetime * strikesPerSecond))) }
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
        if phase < 0.64 { // Smooth anticipation; the last part of the lift slows down.
            let t = phase / 0.64
            return t * t * (3 - 2 * t)
        }
        if phase < 0.70 { return 1 } // Brief poised hold makes the strike readable.
        if phase < 0.88 {
            let t = (phase - 0.70) / 0.18
            return 1 - t * t // Accelerate into contact.
        }
        return 0
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
        anvil.close()
        NSGradient(starting:metal.blended(withFraction:0.2,of:ink)!,ending:edge)!.draw(in:anvil,angle:90)
        ink.setStroke(); anvil.lineWidth = 1.5; anvil.stroke()
        let rim = NSBezierPath(); rim.move(to: NSPoint(x: 29, y: -26)); rim.line(to: NSPoint(x: 49, y: -26))
        edge.setStroke(); rim.lineWidth = 1.4; rim.stroke()

        edge.withAlphaComponent(0.5).setFill()
        for x in [30.0,47.0] { NSBezierPath(ovalIn:NSRect(x:x,y:-40.6,width:2,height:2)).fill() }
        guard style.level > 0 else { return }
        let age = style.impactAge(at: time)
        let impact = reducedMotion ? 0 : max(0, 1 - age / 0.16)
        let glow = NSColor(calibratedRed: 1, green: 0.48 + 0.2 * style.glow, blue: 0.13, alpha: 0.10 + 0.12 * style.glow + impact * 0.10)
        glow.setFill()
        NSBezierPath(ovalIn: NSRect(x: 29, y: -33, width: 25, height: 22)).fill()
        let hot = NSColor(calibratedRed: 1, green: 0.51 + impact * 0.32, blue: 0.21 + impact * 0.25, alpha: 1)
        box(NSRect(x: 35, y: -25, width: 11, height: 4), radius: 1.5, color: hot)
    }

    // Effects render above the robot so leftward embers are not hidden by its arm.
    func drawForgeEffects(at position: V, count: Int, time: Double, reducedMotion: Bool) {
        let style=ForgeStyle(count:count)
        guard style.level > 0 && !reducedMotion else { return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform=NSAffineTransform();transform.translateX(by:position.x,yBy:position.y);transform.concat()
        let age=style.impactAge(at:time)
        let impact=max(0,1-age/0.16)
        if !reducedMotion && impact > 0 {
            NSColor(calibratedRed: 1, green: 0.72, blue: 0.28, alpha: 0.16 + impact * 0.38).setFill()
            NSBezierPath(ovalIn: NSRect(x: 35.5, y: -28.2, width: 10.5, height: 7.4)).fill()
            NSColor(calibratedRed: 1, green: 0.92, blue: 0.62, alpha: 0.20 + impact * 0.45).setFill()
            NSBezierPath(ovalIn: NSRect(x: 37.6, y: -26.4, width: 6.2, height: 3.8)).fill()
        }
        // Retain enough bounded generations for a continuous shower at levels 2 and 3.
        // Vary each strike without random state; no coordinate clamps that pile sparks up.
        guard !reducedMotion else { return }
        let strike = Int(floor(max(0,time) * style.strikesPerSecond - 0.88))
        for generation in 0..<style.sparkGenerations {
            let elapsed = age + Double(generation) / style.strikesPerSecond
            guard elapsed < style.sparkLifetime else { continue }
            for i in 0..<style.sparkCount {
                let salt = ((strike - generation) % 997 + 997) % 997
                let seed = Double((i * 37 + salt * 13 + 11) % 101) / 100
                let spread = Double((i * 61 + salt * 29 + 29) % 101) / 100
                let life = style.sparkLifetime * (0.72 + seed * 0.28)
                let p = elapsed / life
                guard p < 1 else { continue }
                let fade = pow(1-p, style.level == 1 ? 1.3 : 0.65)
                let vx = style.level == 1 ? -32 + spread * 42 : -(style.level == 3 ? 82.0 : 64.0) + spread * (style.level == 3 ? 94.0 : 76.0)
                let vy = style.level == 1 ? (44 + seed * 48) * 0.76 : (style.level == 3 ? 92 : 78) + seed * (style.level == 3 ? 48 : 38)
                let gravity = style.level == 1 ? 48.0 : 72.0
                func point(_ t:Double) -> NSPoint {
                    NSPoint(x:40.5 + vx*t, y:-21 + vy*t - gravity*t*t)
                }
                let head=point(p)
                for k in 0..<3 {
                    let tail = style.level == 1 ? 0.055 : (style.level == 2 ? 0.075 : 0.095)
                    let t0=max(0,p-Double(k)*tail),t1=max(0,p-Double(k+1)*tail)
                    guard t0 > 0 else { continue }
                    let trail=NSBezierPath();trail.move(to:point(t0));trail.line(to:point(t1))
                    trail.lineWidth=(i % 4 == 0 ? 1.8 : 1.1)*(style.level == 1 ? 1 : style.level == 2 ? 1.35 : 1.65)*(1-CGFloat(k)*0.24)
                    trail.lineCapStyle = .round
                    NSColor(calibratedRed:1,green:0.72-Double(k)*0.16,blue:0.22,alpha:fade*(0.85-Double(k)*0.22)).setStroke();trail.stroke()
                }
                NSColor(calibratedRed:1,green:0.90,blue:0.58,alpha:fade).setFill()
                let radius:CGFloat=style.level == 1 ? 0.85 : (i % 5 == 0 ? 1.6 : 1.1)
                NSBezierPath(ovalIn:NSRect(x:head.x-radius,y:head.y-radius,width:radius*2,height:radius*2)).fill()
            }
        }
    }
}
