import Foundation
import CoreGraphics

struct V: Equatable {
    var x: Double; var y: Double
    static func +(a: V, b: V) -> V { V(x:a.x+b.x,y:a.y+b.y) }
    static func -(a: V, b: V) -> V { V(x:a.x-b.x,y:a.y-b.y) }
    static func *(a: V, b: Double) -> V { V(x:a.x*b,y:a.y*b) }
    var length: Double { hypot(x,y) }
    var point: CGPoint { CGPoint(x:x,y:y) }
}
func clamp(_ p: V, _ r: CGRect) -> V {
    V(x: min(max(p.x,r.minX),r.maxX), y:min(max(p.y,r.minY),r.maxY))
}
func lerp(_ a: V, _ b: V, _ t: Double) -> V { a + (b-a)*t }
enum Ability: String { case swing, dash, quiet }
struct Flight {
    var start: V; var end: V; var control: V; var anchor: V
    var began: Double; var duration: Double; var ability: Ability
    func progress(_ now: Double) -> Double { min(1,max(0,(now-began)/duration)) }
    func position(_ now: Double) -> V {
        let p = progress(now)
        if ability == .quiet { return p < 0.5 ? start : end }
        // Smooth launch and landing; all control points stay in the safe rectangle.
        let t = p*p*(3-2*p)
        return start*((1-t)*(1-t)) + control*(2*(1-t)*t) + end*(t*t)
    }
}
struct Motion {
    var bounds: CGRect
    var position: V
    var flight: Flight?
    var radius: Double = 125
    var reducedMotion = false
    var mode = "Automatic"
    var escapeCount = 0
    var swingCount = 0
    var dashCount = 0
    var lastEscape = -100.0
    var nextAllowed = 0.0
    var armed = true
    var lastAbility = "idle"
    var lastLanding = -100.0
    mutating func resize(_ newBounds: CGRect) {
        bounds = newBounds; position = clamp(position,bounds); flight = nil; armed = true
    }
    mutating func update(now: Double, cursor: V, velocity: V, enabled: Bool = true) {
        if let f = flight {
            position = f.position(now)
            if f.progress(now) >= 1 {
                position = f.end; flight = nil; lastLanding = now
                nextAllowed = now + 0.45
            }
            return
        }
        guard enabled else { return }
        let distance = (cursor-position).length
        if distance > radius + 45 { armed = true }
        // Hysteresis avoids jitter; persistent pursuit can re-arm after a short rest.
        guard now >= nextAllowed, distance < radius,
              armed || now-lastLanding > 1.1 else { return }
        escape(now:now,cursor:cursor,velocity:velocity)
    }
    mutating func escape(now: Double, cursor: V, velocity: V, forced: Ability? = nil) {
        let chase = now-lastEscape < 4
        let reach = chase ? 410.0 : 290.0
        let speed = velocity.length
        let kind: Ability = reducedMotion ? .quiet : forced ?? (mode == "Swing" ? .swing : mode == "Jump-dash" ? .dash : speed > 750 || escapeCount % 3 == 2 ? .dash : .swing)
        let look = speed > 0 ? velocity * (min(speed,1100)/speed*0.18) : V(x:0,y:0)
        let predicted = cursor+look
        var best = position; var bestControl = position; var bestScore = -Double.infinity
        for i in 0..<24 {
            let angle = Double(i)*Double.pi/12
            let end = clamp(position+V(x:cos(angle),y:sin(angle))*reach,bounds)
            let travel = (end-position).length
            guard travel > 110 else { continue }
            let control = clamp(lerp(position,end,kind == .dash ? 0.42 : 0.5)+V(x:0,y:kind == .dash ? 65 : 110),bounds)
            var clearance = Double.infinity
            // Ignore departure point, which is necessarily near the cursor.
            for j in 2...8 {
                let t = Double(j)/8
                let p = position*((1-t)*(1-t))+control*(2*t*(1-t))+end*(t*t)
                clearance = min(clearance,(p-lerp(cursor,predicted,t)).length)
            }
            let edge = min(end.x-bounds.minX,bounds.maxX-end.x,end.y-bounds.minY,bounds.maxY-end.y)
            let score = (end-predicted).length + clearance*1.7 + min(edge,65)*0.25 - abs(travel-reach)*0.12
            if score > bestScore { bestScore=score;best=end;bestControl=control }
        }
        guard (best-position).length > 30 else { nextAllowed=now+1;return }
        let duration = kind == .quiet ? 0.20 : kind == .dash ? 0.38 : 0.57
        flight=Flight(start:position,end:best,control:bestControl,
                      anchor:clamp(lerp(position,best,0.55)+V(x:0,y:185),bounds),
                      began:now,duration:duration,ability:kind)
        lastEscape=now;armed=false;escapeCount+=1;lastAbility=kind.rawValue
        if kind == .swing { swingCount+=1 };if kind == .dash { dashCount+=1 }
    }
}
