// Original MechaPets character, drawn entirely with AppKit paths.
// No external sprite sheets, fonts, images, or model assets are used.
import AppKit

extension PetView {
    func drawRobot(row: Int, frame: Int, alpha: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(alpha)
        let ink=NSColor(calibratedRed:0.06,green:0.14,blue:0.20,alpha:1)
        let shell=NSColor(calibratedRed:0.29,green:0.78,blue:0.73,alpha:1)
        let highlight=NSColor(calibratedRed:0.66,green:0.96,blue:0.86,alpha:1)
        let orange=NSColor(calibratedRed:1,green:0.65,blue:0.25,alpha:1)
        let airborne=row==4 && (frame==1 || frame==2)
        let bob:CGFloat = row==0 ? (frame==1 || frame==4 ? 1:0):0
        func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ r:CGFloat,_ color:NSColor) {
            let p=NSBezierPath(roundedRect:NSRect(x:x,y:y+bob,width:w,height:h),xRadius:r,yRadius:r)
            color.setFill();p.fill();ink.setStroke();p.lineWidth=1.8;p.stroke()
        }
        func line(_ from:NSPoint,_ to:NSPoint,_ color:NSColor,_ width:CGFloat) {
            let p=NSBezierPath();p.move(to:from);p.line(to:to);p.lineCapStyle = .round;p.lineWidth=width;color.setStroke();p.stroke()
        }
        // Short, articulated feet: they tuck up during jumps.
        let footY:CGFloat=airborne ? -27:-36
        box(-18,footY,13,10,4,ink);box(5,footY,13,10,4,ink)
        box(-19,-26,38,23,7,shell)
        box(-7,-20,14,9,3,orange)
        line(NSPoint(x:0,y:-18),NSPoint(x:0,y:-14),highlight,2)
        // Arms can reach toward the tether without changing the body silhouette.
        if airborne {
            line(NSPoint(x:-21,y:-11),NSPoint(x:-30,y:2),ink,9)
            line(NSPoint(x:-21,y:-11),NSPoint(x:-30,y:2),shell,5)
            line(NSPoint(x:21,y:-11),NSPoint(x:28,y:15),ink,9)
            line(NSPoint(x:21,y:-11),NSPoint(x:28,y:15),shell,5)
        } else {
            line(NSPoint(x:-21,y:-12),NSPoint(x:-26,y:-24),ink,9)
            line(NSPoint(x:-21,y:-12),NSPoint(x:-26,y:-24),shell,5)
            line(NSPoint(x:21,y:-12),NSPoint(x:26,y:-24),ink,9)
            line(NSPoint(x:21,y:-12),NSPoint(x:26,y:-24),shell,5)
        }
        // Angular receiver ears and an amber antenna distinguish the character.
        box(-34,9,9,17,3,orange);box(25,9,9,17,3,orange)
        line(NSPoint(x:0,y:30+bob),NSPoint(x:0,y:38+bob),ink,3)
        orange.setFill();NSBezierPath(ovalIn:NSRect(x:-3,y:36+bob,width:6,height:6)).fill()
        box(-27,-3,54,36,10,shell)
        box(-20,3,40,23,7,ink)
        let blink=row==0 && frame==4
        if blink {
            line(NSPoint(x:-12,y:14+bob),NSPoint(x:-6,y:14+bob),highlight,3)
            line(NSPoint(x:6,y:14+bob),NSPoint(x:12,y:14+bob),highlight,3)
        } else {
            highlight.setFill()
            NSBezierPath(roundedRect:NSRect(x:-13,y:10+bob,width:7,height:10),xRadius:3,yRadius:3).fill()
            NSBezierPath(roundedRect:NSRect(x:6,y:10+bob,width:7,height:10),xRadius:3,yRadius:3).fill()
        }
        // A small brow glint keeps the metal readable on dark and light desktops.
        line(NSPoint(x:-15,y:29+bob),NSPoint(x:3,y:29+bob),highlight,2)
        NSGraphicsContext.restoreGraphicsState()
    }
}
