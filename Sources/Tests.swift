import AppKit

func runTests() {
    var checks=0
    func check(_ result:Bool,_ name:String){checks+=1;if !result{fputs("FAIL: \(name)\n",stderr);exit(1)}}
    let rectangles=[CGRect(x:60,y:65,width:1200,height:760),CGRect(x:60,y:65,width:320,height:240),CGRect(x:-1400,y:-700,width:1100,height:620)]
    for rect in rectangles {
        let positions=[V(x:rect.midX,y:rect.midY),V(x:rect.minX,y:rect.minY),V(x:rect.maxX,y:rect.minY),V(x:rect.minX,y:rect.maxY),V(x:rect.maxX,y:rect.maxY)]
        for origin in positions {
            for angle in 0..<16 {
                let a=Double(angle)*Double.pi/8
                let cursor=origin+V(x:cos(a),y:sin(a))*70
                for speed in [0.0,1400.0] {
                    var m=Motion(bounds:rect,position:origin)
                    m.update(now:10,cursor:cursor,velocity:(origin-cursor)*(speed/70))
                    check(m.flight != nil,"escape starts")
                    guard let f=m.flight else{continue}
                    check((f.end-cursor).length > (origin-cursor).length+50,"destination creates space")
                    check(f.ability == (speed>750 ? .dash:.swing),"speed selects ability")
                    for sample in 0...60 {
                        let point=f.position(f.began+f.duration*Double(sample)/60)
                        check(point.x>=rect.minX-0.001 && point.x<=rect.maxX+0.001 && point.y>=rect.minY-0.001 && point.y<=rect.maxY+0.001,"path contained")
                    }
                    m.update(now:11,cursor:cursor,velocity:V(x:0,y:0))
                    check(m.flight == nil && m.position == f.end,"lands exactly")
                    m.update(now:11.1,cursor:m.position,velocity:V(x:0,y:0))
                    check(m.flight == nil,"landing cooldown")
                    m.update(now:12.2,cursor:m.position,velocity:V(x:0,y:0))
                    check(m.flight != nil,"persistent pursuit escapes again")
                }
            }
        }
    }
    var idle=Motion(bounds:rectangles[0],position:V(x:500,y:300))
    for i in 0..<900 {idle.update(now:Double(i)/30,cursor:V(x:100,y:100),velocity:V(x:0,y:0))}
    check(idle.escapeCount==0,"distant cursor causes no wandering")
    idle.update(now:40,cursor:idle.position,velocity:V(x:0,y:0),enabled:false)
    check(idle.escapeCount==0,"paused model stays still")
    idle.reducedMotion=true;idle.update(now:41,cursor:idle.position,velocity:V(x:0,y:0))
    check(idle.flight?.ability == .quiet,"reduced motion removes acrobatics")
    let f=idle.flight!
    check(f.position(41.02)==f.start && f.position(41.18)==f.end,"gentle motion fades between endpoints")
    idle.resize(CGRect(x:0,y:0,width:100,height:100))
    check(idle.flight==nil && idle.position.x<=100 && idle.position.y<=100,"display resize cancels stale flight")
    print("PASS: \(checks) assertions; 480 directional/speed scenarios across regular, small and negative-origin display geometry; cooldown, pursuit, pause, idle, reduced motion and display resize.")
}
func renderPreview(to path:String) {
    _=NSApplication.shared
    let size=CGSize(width:1120,height:660)
    let image=NSImage(size:size)
    image.lockFocus()
    NSColor(calibratedRed:0.045,green:0.06,blue:0.09,alpha:1).setFill();CGRect(origin:.zero,size:size).fill()
    func text(_ value:String,_ x:Double,_ y:Double,_ size:Double,_ color:NSColor){(value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:color])}
    text("MechaPets",44,591,30,.white)
    text("A little more room to work.",44,558,16,.secondaryLabelColor)
    let view=PetView(frame:CGRect(origin:.zero,size:size))
    let flights=[Flight(start:V(x:120,y:270),end:V(x:495,y:270),control:V(x:300,y:490),anchor:V(x:315,y:475),began:0,duration:1,ability:.swing),Flight(start:V(x:670,y:270),end:V(x:1030,y:270),control:V(x:825,y:400),anchor:V(x:840,y:440),began:0,duration:1,ability:.dash)]
    for (index,f) in flights.enumerated(){
        NSColor(calibratedWhite:1,alpha:0.13).setStroke();let path=NSBezierPath();path.move(to:f.start.point)
        for j in 1...60{path.line(to:f.position(Double(j)/60).point)};path.lineWidth=1;path.setLineDash([3,6],count:2,phase:0);path.stroke()
        view.model=Motion(bounds:CGRect(origin:.zero,size:size),position:f.position(0.5),flight:f);view.now=0.5
        // Composite a transparent view image so it cannot clear the background.
        let layer=NSImage(size:size);layer.lockFocus();view.draw(CGRect(origin:.zero,size:size));layer.unlockFocus();layer.draw(at:.zero,from:.zero,operation:.sourceOver,fraction:1)
        text(index==0 ? "SWING":"JUMP-DASH",index==0 ? 80:650,174,13,NSColor(calibratedRed:0.65,green:0.85,blue:1,alpha:1))
        text(index==0 ? "A short tether. A graceful escape.":"A quick leap when the cursor rushes in.",index==0 ? 80:650,140,15,.white)
    }
    text("Cursor-aware  ·  Click-through  ·  Pause from the menu bar",44,47,14,NSColor(calibratedWhite:0.7,alpha:1))
    image.unlockFocus()
    let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
    try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
}
