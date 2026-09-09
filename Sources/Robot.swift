// Original MechaPets character, drawn entirely with AppKit paths.
// No external sprite sheets, fonts, images, or model assets are used.
import AppKit

extension PetView {
    func drawRobot(row: Int, frame: Int, alpha: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(alpha)
        let ink=NSColor(calibratedRed:0.06,green:0.14,blue:0.20,alpha:1)
        let shell=NSColor(calibratedRed:0.29,green:0.78,blue:0.73,alpha:1)
        let plate=NSColor(calibratedRed:0.20,green:0.62,blue:0.59,alpha:1)
        let highlight=NSColor(calibratedRed:0.66,green:0.96,blue:0.86,alpha:1)
        let shine=NSColor(calibratedRed:0.84,green:0.99,blue:0.94,alpha:1)
        let orange=NSColor(calibratedRed:1,green:0.65,blue:0.25,alpha:1)
        let amber=NSColor(calibratedRed:1,green:0.82,blue:0.42,alpha:1)
        let steel=NSColor(calibratedRed:0.50,green:0.66,blue:0.70,alpha:1)
        let airborne=row==4 && (frame==1 || frame==2)
        let forging = model.flight == nil && (workloadCount ?? 0) > 0
        let forge = ForgeStyle(count: workloadCount ?? 0)
        let lift = forge.hammerLift(at: now, reducedMotion: model.reducedMotion)
        let still = model.reducedMotion
        let impact = forging && !still ? max(0, 1 - forge.impactAge(at: now) / 0.12) : 0
        let breath = still || airborne ? 0 : sin(now * 2.1) * 0.65
        let bob: CGFloat = forging ? CGFloat(lift) * (forge.level == 3 ? 3.8 : forge.level == 2 ? 2.3 : 1.5) - CGFloat(impact) * (forge.level == 3 ? 2.4 : 1.1) : CGFloat(breath)
        let antennaLag: CGFloat = still ? 0 : CGFloat(sin(now * (forging ? forge.strikesPerSecond * .pi * 2 : 2.1) - 0.7)) * (forging ? (forge.level == 3 ? 3.4 : 1.8) : 0.8)
        func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ r:CGFloat,_ color:NSColor) {
            let p=NSBezierPath(roundedRect:NSRect(x:x,y:y+bob,width:w,height:h),xRadius:r,yRadius:r)
            color.setFill();p.fill();ink.setStroke();p.lineWidth=1.8;p.stroke()
        }
        func plated(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ r:CGFloat,_ color:NSColor) {
            let rect=NSRect(x:x,y:y+bob,width:w,height:h)
            let p=NSBezierPath(roundedRect:rect,xRadius:r,yRadius:r)
            NSGradient(starting:color.blended(withFraction:0.18,of:ink)!, ending:color.blended(withFraction:0.28,of:shine)!)!.draw(in:p,angle:90)
            NSGraphicsContext.saveGraphicsState()
            p.addClip()
            highlight.withAlphaComponent(0.28).setFill()
            NSBezierPath(roundedRect:NSRect(x:x+1.6,y:y+bob+h*0.46,width:w-3.2,height:h*0.52),xRadius:max(1,r-1.2),yRadius:max(1,r-1.2)).fill()
            steel.withAlphaComponent(0.16).setFill()
            NSBezierPath(rect:NSRect(x:x,y:y+bob,width:max(2.4,w*0.17),height:h)).fill()
            ink.withAlphaComponent(0.20).setFill()
            NSBezierPath(rect:NSRect(x:x,y:y+bob,width:w,height:h*0.30)).fill()
            ink.withAlphaComponent(0.12).setFill()
            NSBezierPath(rect:NSRect(x:x+w-max(2.0,w*0.12),y:y+bob,width:max(2.0,w*0.12),height:h)).fill()
            shine.withAlphaComponent(0.58).setStroke()
            let rim=NSBezierPath();rim.move(to:NSPoint(x:x+r+1,y:y+bob+h-2.1));rim.line(to:NSPoint(x:x+w*0.46,y:y+bob+h-2.1))
            rim.lineWidth=1.2;rim.lineCapStyle = .round;rim.stroke()
            shine.withAlphaComponent(0.30).setStroke()
            let spec=NSBezierPath();spec.move(to:NSPoint(x:x+r+2.2,y:y+bob+h-4.0));spec.line(to:NSPoint(x:x+w*0.30,y:y+bob+h-4.0))
            spec.lineWidth=0.8;spec.lineCapStyle = .round;spec.stroke()
            NSGraphicsContext.restoreGraphicsState()
            ink.setStroke();p.lineWidth=1.8;p.stroke()
        }
        func line(_ from:NSPoint,_ to:NSPoint,_ color:NSColor,_ width:CGFloat) {
            let p=NSBezierPath();p.move(to:from);p.line(to:to);p.lineCapStyle = .round;p.lineWidth=width;color.setStroke();p.stroke()
        }
        func joint(_ x:CGFloat,_ y:CGFloat,_ r:CGFloat, bobbing:Bool=false) {
            let dy=bobbing ? bob : 0
            ink.setFill();NSBezierPath(ovalIn:NSRect(x:x-r,y:y-r+dy,width:r*2,height:r*2)).fill()
            steel.setFill();NSBezierPath(ovalIn:NSRect(x:x-r+0.8,y:y-r+0.85+dy,width:r*2-1.6,height:r*2-1.6)).fill()
            shell.setFill();NSBezierPath(ovalIn:NSRect(x:x-r+1.45,y:y-r+1.65+dy,width:r*2-2.9,height:r*2-2.7)).fill()
            highlight.withAlphaComponent(0.32).setFill()
            NSBezierPath(ovalIn:NSRect(x:x-r*0.52,y:y-r*0.12+dy,width:r*1.02,height:r*0.68)).fill()
            shine.setFill();NSBezierPath(ovalIn:NSRect(x:x-r*0.28,y:y+r*0.12+dy,width:r*0.7,height:r*0.55)).fill()
        }
        func fin(baseX:CGFloat, pointing:CGFloat) {
            let p=NSBezierPath()
            p.move(to:NSPoint(x:baseX,y:10+bob))
            p.line(to:NSPoint(x:baseX+pointing*9,y:13+bob))
            p.line(to:NSPoint(x:baseX+pointing*8.5,y:24+bob))
            p.line(to:NSPoint(x:baseX,y:27+bob))
            p.close()
            orange.setFill();p.fill();ink.setStroke();p.lineWidth=1.7;p.stroke()
            ink.withAlphaComponent(0.22).setStroke()
            let seam=NSBezierPath();seam.move(to:NSPoint(x:baseX+pointing*2.1,y:13.5+bob));seam.line(to:NSPoint(x:baseX+pointing*2.0,y:23.2+bob))
            seam.lineWidth=1.0;seam.lineCapStyle = .round;seam.stroke()
            let rim=NSBezierPath();rim.move(to:NSPoint(x:baseX+pointing*1.2,y:24.5+bob));rim.line(to:NSPoint(x:baseX+pointing*6.5,y:22.5+bob))
            rim.lineCapStyle = .round;rim.lineWidth=1.15;amber.setStroke();rim.stroke()
        }
        // Short, articulated boots: they tuck up during jumps.
        let footY:CGFloat=(airborne ? -27 : -36) - bob // Feet stay planted while the torso compresses.
        box(-21,footY,16,11,3.4,ink);box(-22,footY,7,7,2.2,ink)
        box(5,footY,16,11,3.4,ink);box(15,footY,7,7,2.2,ink)
        steel.withAlphaComponent(0.42).setFill()
        NSBezierPath(roundedRect:NSRect(x:-19.6,y:footY+5.6+bob,width:11.2,height:3.2),xRadius:1.3,yRadius:1.3).fill()
        NSBezierPath(roundedRect:NSRect(x:6.4,y:footY+5.6+bob,width:11.2,height:3.2),xRadius:1.3,yRadius:1.3).fill()
        plated(-19,-26,38,24,7,shell)
        joint(-12,-25,3.2,bobbing:true);joint(12,-25,3.2,bobbing:true)
        box(-8,-21,16,10,3,orange)
        shine.withAlphaComponent(0.34).setFill()
        NSBezierPath(roundedRect:NSRect(x:-6.2,y:-18.8+bob,width:12.4,height:3.4),xRadius:1.4,yRadius:1.4).fill()
        if forging {
            let pulse: CGFloat = still ? 0.10 : CGFloat(impact) * (0.18 + 0.10 * CGFloat(forge.level))
            amber.withAlphaComponent(0.28+pulse).setFill()
            NSBezierPath(roundedRect:NSRect(x:-5,y:-18+bob,width:10,height:5),xRadius:2,yRadius:2).fill()
        }
        line(NSPoint(x:0,y:-18+bob),NSPoint(x:0,y:-14+bob),highlight,2)
        func arm(_ from:NSPoint,_ to:NSPoint) {
            let dx=to.x-from.x,dy=to.y-from.y
            let distance=max(0.001,hypot(dx,dy))
            let reach:CGFloat=(airborne || (forging && from.x > 0)) ? 15.5 : 8.5
            let bend=sqrt(max(0,reach*reach-distance*distance/4))
            let side:CGFloat=from.x < 0 || forging ? -1 : 1
            let elbow=NSPoint(x:(from.x+to.x)/2-side*dy/distance*bend,y:(from.y+to.y)/2+side*dx/distance*bend)
            for (a,b) in [(from,elbow),(elbow,to)] {
                line(a,b,ink,8);line(a,b,plate,5)
                line(NSPoint(x:a.x-0.7,y:a.y+0.8),NSPoint(x:b.x-0.7,y:b.y+0.8),highlight.withAlphaComponent(0.65),1.3)
            }
            joint(from.x,from.y,4.1)
            joint(elbow.x,elbow.y,3.1)
        }
        // Arms can reach toward the tether without changing the body silhouette.
        var hammerHead=NSPoint.zero
        var hammerHand=NSPoint.zero
        var hammerTilt:CGFloat=0
        if airborne {
            arm(NSPoint(x:-21,y:-11),NSPoint(x:-30,y:2))
            arm(NSPoint(x:21,y:-11),NSPoint(x:28,y:15))
        } else if forging {
            // One hand steadies the robot while the other works a small steel hammer.
            arm(NSPoint(x:-21,y:-12+bob),NSPoint(x:-18,y:-24))
            joint(-18,-24,3.4)
            let t=CGFloat(lift)
            // Hammer head sits on the anvil face at rest; raise tilts it back. Drawn without bob.
            hammerHead=NSPoint(x:40.5-9*t,y:-16.9+34*t)
            hammerTilt = -0.72 * t
            // Fixed-length handle, perpendicular to the hammer face at every pose.
            hammerHand=NSPoint(x:hammerHead.x+sin(hammerTilt)*13,y:hammerHead.y-cos(hammerTilt)*13)
            arm(NSPoint(x:21,y:-12+bob),hammerHand)
        } else {
            arm(NSPoint(x:-21,y:-12),NSPoint(x:-26,y:-24))
            arm(NSPoint(x:21,y:-12),NSPoint(x:26,y:-24))
            joint(-26,-24,3.2);joint(26,-24,3.2)
        }
        // A little head follow-through sells the weight of each blow.
        NSGraphicsContext.saveGraphicsState()
        let headMotion=NSAffineTransform()
        headMotion.translateX(by:forging && !still ? CGFloat(lift)*0.7 + (forge.level == 3 ? CGFloat(sin(now*45))*0.9 : 0) : 0,yBy:0)
        headMotion.rotate(byRadians:forging && !still ? CGFloat(lift)*(-0.025)+CGFloat(impact)*0.018 : 0)
        headMotion.concat()
        // Angular receiver fins and an amber antenna distinguish the character.
        fin(baseX:-27,pointing:-1);fin(baseX:27,pointing:1)
        line(NSPoint(x:0,y:31+bob),NSPoint(x:antennaLag,y:40+bob),ink,3.2)
        line(NSPoint(x:0,y:31+bob),NSPoint(x:antennaLag,y:39+bob),plate,1.6)
        orange.setFill();NSBezierPath(ovalIn:NSRect(x:-3.4+antennaLag,y:37.4+bob,width:6.8,height:6.8)).fill()
        amber.setFill();NSBezierPath(ovalIn:NSRect(x:-1.8+antennaLag,y:39.2+bob,width:3.2,height:3.0)).fill()
        plated(-27,-3,54,36,10,shell)
        box(-10,-6,20,7,3,plate)
        line(NSPoint(x:-6,y:-2.5+bob),NSPoint(x:6,y:-2.5+bob),highlight,1.1)
        ink.setFill()
        NSBezierPath(roundedRect:NSRect(x:-20.5,y:3.5+bob,width:41,height:23.5),xRadius:7,yRadius:7).fill()
        let glass=NSBezierPath(roundedRect:NSRect(x:-18.5,y:5.5+bob,width:37,height:19.5),xRadius:6,yRadius:6)
        NSColor(calibratedRed:0.07,green:0.23,blue:0.26,alpha:1).setFill()
        glass.fill()
        NSGraphicsContext.saveGraphicsState()
        glass.addClip()
        highlight.withAlphaComponent(0.11).setFill()
        NSBezierPath(ovalIn:NSRect(x:-16.5,y:13.5+bob,width:21,height:11.5)).fill()
        ink.withAlphaComponent(0.28).setFill()
        NSBezierPath(rect:NSRect(x:-18.5,y:5.5+bob,width:37,height:4.6)).fill()
        NSGraphicsContext.restoreGraphicsState()
        func rivet(_ x:CGFloat,_ y:CGFloat) {
            ink.setFill();NSBezierPath(ovalIn:NSRect(x:x-2.1,y:y-2.1+bob,width:4.2,height:4.2)).fill()
            steel.setFill();NSBezierPath(ovalIn:NSRect(x:x-1.5,y:y-1.45+bob,width:3.0,height:3.0)).fill()
            highlight.setFill();NSBezierPath(ovalIn:NSRect(x:x-0.9,y:y-0.2+bob,width:2.1,height:2.0)).fill()
        }
        rivet(-23.2,8.5);rivet(23.2,8.5)
        let blink = !still && !airborne && now.truncatingRemainder(dividingBy: 4.7) > 4.55
        let lookX:CGFloat = forging ? 1.25 : (still ? 0 : CGFloat(sin(now * 0.65)) * 0.65)
        let lookY:CGFloat = forging ? -0.85 : (airborne ? 0.45 : 0)
        let squint:CGFloat = forging ? (still ? 0.12 : 0.18 + CGFloat(impact) * (forge.level >= 3 ? 0.38 : 0.16)) : 0
        func eye(_ x:CGFloat) {
            let h=11.2 - squint*3.4
            let oy:CGFloat=10.2 + squint*1.4
            highlight.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect:NSRect(x:x-1.2,y:oy-1.1+bob,width:10.4,height:h+2.2),xRadius:4.2,yRadius:4.2).fill()
            let lens=NSBezierPath(roundedRect:NSRect(x:x,y:oy+bob,width:8,height:h),xRadius:3.3,yRadius:3.3)
            highlight.setFill();lens.fill()
            NSGraphicsContext.saveGraphicsState()
            lens.addClip()
            shine.setFill()
            NSBezierPath(roundedRect:NSRect(x:x+0.7,y:oy+h*0.42+bob,width:6.4,height:h*0.48),xRadius:2.4,yRadius:2.4).fill()
            plate.withAlphaComponent(0.22+squint*0.28).setFill()
            NSBezierPath(rect:NSRect(x:x,y:oy+h*0.66+bob,width:8,height:h*0.42)).fill()
            ink.withAlphaComponent(0.12+squint*0.10).setFill()
            NSBezierPath(rect:NSRect(x:x,y:oy+bob,width:8,height:h*0.20)).fill()
            NSColor(calibratedRed:0.16,green:0.52,blue:0.50,alpha:0.55).setFill()
            NSBezierPath(ovalIn:NSRect(x:x+1.55+lookX,y:oy+1.45+lookY+bob,width:4.9,height:5.7-squint*1.5)).fill()
            ink.setFill()
            NSBezierPath(ovalIn:NSRect(x:x+2.1+lookX,y:oy+2.0+lookY+bob,width:3.7,height:4.6-squint*1.6)).fill()
            shine.setFill()
            NSBezierPath(ovalIn:NSRect(x:x+2.5+lookX,y:oy+4.8+lookY+bob,width:2.05,height:2.15)).fill()
            shine.withAlphaComponent(0.85).setFill()
            NSBezierPath(ovalIn:NSRect(x:x+4.55+lookX,y:oy+2.4+lookY+bob,width:1.1,height:1.1)).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        if blink {
            let lid=NSBezierPath()
            lid.move(to:NSPoint(x:-13.4,y:13.7+bob))
            lid.curve(to:NSPoint(x:-4.8,y:13.9+bob), controlPoint1:NSPoint(x:-11.0,y:15.5+bob), controlPoint2:NSPoint(x:-7.2,y:15.6+bob))
            lid.lineWidth=2.8;lid.lineCapStyle = .round;highlight.setStroke();lid.stroke()
            let lidR=NSBezierPath()
            lidR.move(to:NSPoint(x:4.8,y:13.9+bob))
            lidR.curve(to:NSPoint(x:13.4,y:13.7+bob), controlPoint1:NSPoint(x:7.2,y:15.6+bob), controlPoint2:NSPoint(x:11.0,y:15.5+bob))
            lidR.lineWidth=2.8;lidR.lineCapStyle = .round;lidR.stroke()
        } else {
            eye(-13.2);eye(5.2)
        }
        // Small smile lives on the visor, separate from the chin vents.
        let smile=NSBezierPath()
        smile.move(to:NSPoint(x:-3,y:8.8+bob))
        smile.curve(to:NSPoint(x:3,y:8.8+bob),controlPoint1:NSPoint(x:-1.4,y:(forging ? 7.7 : 6.5)+bob),controlPoint2:NSPoint(x:1.4,y:(forging ? 7.7 : 6.5)+bob))
        smile.lineWidth=1.1;smile.lineCapStyle = .round;highlight.withAlphaComponent(0.8).setStroke();smile.stroke()
        let browDrop:CGFloat = forging ? (0.55 + squint*1.15) : (airborne ? -0.75 : 0)
        line(NSPoint(x:-15.6,y:23.7+bob-browDrop),NSPoint(x:-6.1,y:24.3+bob-browDrop*0.3),highlight.withAlphaComponent(0.62),1.35)
        line(NSPoint(x:6.1,y:24.3+bob-browDrop*0.3),NSPoint(x:15.6,y:23.7+bob-browDrop),highlight.withAlphaComponent(0.62),1.35)
        // A small brow glint keeps the metal readable on dark and light desktops.
        line(NSPoint(x:-16,y:29.4+bob),NSPoint(x:5,y:29.4+bob),highlight,2)
        let grin:CGFloat = forging ? 0.05 : (airborne ? 0.45 : 0.95)
        line(NSPoint(x:-7.6,y:1.7+bob),NSPoint(x:7.6,y:1.7+bob),ink,1.45)
        line(NSPoint(x:-5.4,y:0.15+bob-grin),NSPoint(x:-3.1,y:0.15+bob-grin),ink,1.15)
        line(NSPoint(x:-1.15,y:-0.25+bob-grin*1.2),NSPoint(x:1.15,y:-0.25+bob-grin*1.2),ink,1.15)
        line(NSPoint(x:3.1,y:0.15+bob-grin),NSPoint(x:5.4,y:0.15+bob-grin),ink,1.15)
        NSGraphicsContext.restoreGraphicsState() // Head motion does not move the hammer.
        if forging {
            // Draw the hammer without body bob so impact meets the anvil precisely.
            joint(hammerHand.x,hammerHand.y,3.5)
            line(hammerHand,hammerHead,ink,5)
            line(hammerHand,hammerHead,orange,2.6)
            NSGraphicsContext.saveGraphicsState()
            let xf=NSAffineTransform()
            xf.translateX(by:hammerHead.x,yBy:hammerHead.y)
            xf.rotate(byRadians:hammerTilt)
            xf.concat()
            let head=NSBezierPath(roundedRect:NSRect(x:-9.2,y:-4.1,width:18.4,height:8.2),xRadius:2.1,yRadius:2.1)
            steel.setFill();head.fill()
            NSGraphicsContext.saveGraphicsState()
            head.addClip()
            ink.withAlphaComponent(0.16).setFill()
            NSBezierPath(rect:NSRect(x:-9.2,y:-4.1,width:18.4,height:2.6)).fill()
            highlight.withAlphaComponent(0.38).setFill()
            NSBezierPath(roundedRect:NSRect(x:-7.4,y:-0.2,width:14.6,height:3.6),xRadius:1.4,yRadius:1.4).fill()
            NSGraphicsContext.restoreGraphicsState()
            ink.setStroke();head.lineWidth=1.65;head.stroke()
            let peen=NSBezierPath(roundedRect:NSRect(x:6.4,y:-2.6,width:5.2,height:5.2),xRadius:1.3,yRadius:1.3)
            NSColor(calibratedRed:0.62,green:0.76,blue:0.78,alpha:1).setFill();peen.fill();ink.setStroke();peen.lineWidth=1.3;peen.stroke()
            shine.withAlphaComponent(0.5).setFill()
            NSBezierPath(ovalIn:NSRect(x:7.4,y:-0.6,width:2.4,height:1.8)).fill()
            line(NSPoint(x:-6.5,y:1.6),NSPoint(x:5.4,y:1.6),shine,1.25)
            if impact > 0 {
                let hot=CGFloat(impact)
                NSColor(calibratedRed:1,green:0.62,blue:0.22,alpha:0.18+0.28*hot).setFill()
                NSBezierPath(ovalIn:NSRect(x:-6,y:-3.2,width:12,height:6.4)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
