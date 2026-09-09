import Foundation
import AppKit
import SQLite3
import ImageIO

func runWorkloadTests() {
    var assertions=0
    func check(_ value:Bool,_ label:String){assertions+=1;if !value{fputs("FAIL workload: \(label)\n",stderr);exit(1)}}
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("mechapets-fixture-"+UUID().uuidString)
    try! FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    defer{try? FileManager.default.removeItem(at:root)}
    func execute(_ name:String,_ sql:String){
        var db:OpaquePointer?;precondition(sqlite3_open(root.appendingPathComponent(name).path,&db)==SQLITE_OK)
        defer{sqlite3_close(db)}
        precondition(sqlite3_exec(db,sql,nil,nil,nil)==SQLITE_OK)
    }
    execute("state_5.sqlite","CREATE TABLE threads(id TEXT PRIMARY KEY,source TEXT,agent_path TEXT,archived INT);")
    execute("thread_history_1.sqlite","CREATE TABLE thread_turns(thread_id TEXT,rollout_ordinal INT,status TEXT);")
    let first="00000000-0000-0000-0000-000000000001",second="00000000-0000-0000-0000-000000000002",third="00000000-0000-0000-0000-000000000003",helper="00000000-0000-0000-0000-000000000004",stale="00000000-0000-0000-0000-000000000005"
    for id in [first,second,third,stale] {execute("state_5.sqlite","INSERT INTO threads VALUES('\(id)','vscode',NULL,0)")}
    execute("state_5.sqlite","INSERT INTO threads VALUES('\(helper)','{\"subagent\":{}}','/root/helper',0)")
    let writers:Set<String>=[first,second,third,helper]
    let reader=WorkloadReader(home:root,openWriters:{_,_ in writers})
    check(reader.sample().activeCount==0,"zero tasks")
    execute("thread_history_1.sqlite","INSERT INTO thread_turns VALUES('\(first)',1,'inProgress'),('\(helper)',1,'inProgress'),('\(stale)',1,'inProgress')")
    check(reader.sample().activeCount==1,"subagents and abandoned turns excluded")
    execute("thread_history_1.sqlite","INSERT INTO thread_turns VALUES('\(second)',1,'inProgress')")
    check(reader.sample().activeCount==2,"two roots")
    execute("thread_history_1.sqlite","INSERT INTO thread_turns VALUES('\(third)',1,'inProgress')")
    check(reader.sample().activeCount==3,"three roots")
    execute("thread_history_1.sqlite","INSERT INTO thread_turns VALUES('\(second)',2,'completed')")
    check(reader.sample().activeCount==2,"latest completed overrides older inProgress")
    execute("thread_history_1.sqlite","INSERT INTO thread_turns VALUES('\(third)',2,'interrupted')")
    check(reader.sample().activeCount==1,"interrupted root removed")
    execute("thread_history_1.sqlite","INSERT INTO thread_turns VALUES('\(first)',2,'failed')")
    check(reader.sample().activeCount==0,"failed root removed; stale history not counted")
    execute("thread_history_1.sqlite","INSERT INTO thread_turns VALUES('\(first)',3,'inProgress')")
    execute("state_5.sqlite","UPDATE threads SET archived=1 WHERE id='\(first)'")
    check(reader.sample().activeCount==0,"archived root excluded")
    execute("state_5.sqlite","UPDATE threads SET archived=0 WHERE id='\(first)'")
    let crashed=WorkloadReader(home:root,openWriters:{_,_ in []})
    check(crashed.sample().activeCount==0,"no live writer after app exits")
    let denied=WorkloadReader(home:root,openWriters:{_,_ in throw WorkloadError.unavailable})
    check(denied.sample().activeCount==nil,"reader failure is unavailable, not idle")
    execute("thread_history_1.sqlite","INSERT INTO thread_turns VALUES('\(first)',4,'futureUnknownStatus')")
    check(reader.sample().activeCount==nil,"unknown lifecycle fails closed")
    execute("thread_history_1.sqlite","DROP TABLE thread_turns")
    check(reader.sample().activeCount==nil,"unsupported schema")
    check(WorkloadReader(home:root.appendingPathComponent("missing")).sample().activeCount==nil,"missing install")
    let paths=["/fixture/first.lock":first,"/fixture/second.lock":second]
    check(parseWriterIDs("p123\nccodex\nf10\nn/fixture/first.lock\np124\ncother\nf11\nn/fixture/second.lock\n",paths:paths)==[first],"only Codex writer commands")
    check(parseWriterIDs("p123\nccodex\nf10\nn/fixture/first.lock\np124\nf11\nn/fixture/second.lock\n",paths:paths)==[first],"command resets at process boundary")
    check(parseWriterIDs("p123\nccodex\nf10\nn/unrelated/first.lock",paths:paths).isEmpty,"exact candidate path match")
    check(parseWriterIDs("p123\nccodex\nf10\nn/fixture/first.lock\nf11\nn/fixture/first.lock",paths:paths).count==1,"duplicate handles count once")
    check(ForgeStyle(count:0).strikesPerSecond==0,"idle no hammer")
    for count in 1...3 {
        let style=ForgeStyle(count:count),previous=ForgeStyle(count:count-1)
        check(style.strikesPerSecond>previous.strikesPerSecond,"workload ramps cadence")
        check(style.sparkCount>previous.sparkCount,"workload ramps sparks")
        check(style.hammerLift(at:0.2,reducedMotion:true)==0,"reduced motion stops hammer")
        check(style.impactAge(at:0.881/style.strikesPerSecond)<0.002,"sparks synchronized with impact")
    }
    check(ForgeStyle(count:900).sparkCount==ForgeStyle(count:3).sparkCount,"frenzy has bounded particles")
    check(ForgeStyle(count:-1).level==0,"negative count clamps")
    check(WorkloadSnapshot.active(9).status.contains("Frenzy"),"3+ remains frenzy")
    print("PASS: \(assertions) workload and forge assertions: 0/1/2/3 tasks, lifecycle transitions, helpers, stale handles, failures, unknown schema, writer filtering, intensity and reduced motion.")
}

func renderForgePreview(to path:String) {
    _=NSApplication.shared
    let size=CGSize(width:1280,height:520),image=NSImage(size:CGSize(width:1280,height:520))
    image.lockFocus()
    NSColor(calibratedRed:0.045,green:0.06,blue:0.09,alpha:1).setFill();CGRect(origin:.zero,size:size).fill()
    func text(_ value:String,_ x:Double,_ y:Double,_ size:Double,_ color:NSColor){(value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.medium),.foregroundColor:color])}
    text("MechaPets at work",42,450,30,.white)
    text("Your local Codex workload, brought to life.",42,418,16,NSColor(calibratedWhite:0.7,alpha:1))
    for count in 0...3 {
        let view=PetView(frame:CGRect(x:0,y:0,width:160,height:150))
        view.workloadCount=count
        view.model=Motion(bounds:CGRect(x:0,y:0,width:160,height:150),position:V(x:65,y:57))
        view.now=count==0 ? 0 : 0.88/ForgeStyle(count:count).strikesPerSecond+0.11
        let cell=NSImage(size:view.bounds.size)
        cell.lockFocus();view.draw(view.bounds);cell.unlockFocus()
        cell.draw(in:CGRect(x:Double(count)*310+22,y:145,width:256,height:240),from:.zero,operation:.sourceOver,fraction:1)
        text(["IDLE","1 TASK · CALM","2 TASKS · BUSY","3+ TASKS · FRENZY"][count],Double(count)*310+42,115,14,NSColor(calibratedRed:0.65,green:0.89,blue:0.83,alpha:1))
        text(["A cool anvil.","Steady hammering.","Faster, brighter strikes.","A shower of sparks."][count],Double(count)*310+42,86,16,.white)
    }
    text("Cursor avoidance always comes first.  •  Reduced motion supported.",42,34,13,NSColor(calibratedWhite:0.6,alpha:1))
    image.unlockFocus()
    let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
    try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
}

// Deterministic renderer demo, not a desktop screen recording.
func renderForgeAnimation(to path:String) {
    _=NSApplication.shared
    let width=960,height=340
    let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:path) as CFURL,"com.compuserve.gif" as CFString,90,nil)!
    CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
    for frame in 0..<90 {
        autoreleasepool {
            let image=NSImage(size:NSSize(width:width,height:height));image.lockFocus()
            NSColor(calibratedRed:0.045,green:0.06,blue:0.09,alpha:1).setFill();NSRect(x:0,y:0,width:width,height:height).fill()
            for count in 1...3 {
                let view=PetView(frame:CGRect(x:0,y:0,width:160,height:150))
                view.workloadCount=count;view.model=Motion(bounds:view.bounds,position:V(x:65,y:57));view.now=Double(frame)/30
                let cell=NSImage(size:view.bounds.size);cell.lockFocus();view.draw(view.bounds);cell.unlockFocus()
                cell.draw(in:CGRect(x:Double(count-1)*320+30,y:80,width:256,height:240),from:.zero,operation:.sourceOver,fraction:1)
                let label=["1 TASK · CALM","2 TASKS · BUSY","3+ TASKS · FRENZY"][count-1]
                (label as NSString).draw(at:CGPoint(x:Double(count-1)*320+48,y:45),withAttributes:[.font:NSFont.systemFont(ofSize:16,weight:.medium),.foregroundColor:NSColor.white])
            }
            image.unlockFocus()
            let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil)!
            CGImageDestinationAddImage(destination,cg,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
        }
    }
    precondition(CGImageDestinationFinalize(destination))
}
