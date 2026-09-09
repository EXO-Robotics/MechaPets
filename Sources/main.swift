import AppKit
import QuartzCore

let args = CommandLine.arguments
let qaURL: URL? = {
    guard let i=args.firstIndex(of:"--qa-state"),i+1<args.count else{return nil}
    return URL(fileURLWithPath:args[i+1])
}()
let spriteSize = CGSize(width:86,height:93.1667)
func safeBounds(_ r: CGRect) -> CGRect {
    let x=min(spriteSize.width/2+18,r.width/3)
    let y=min(spriteSize.height/2+18,r.height/3)
    return r.insetBy(dx:x,dy:y)
}
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class PetView: NSView {
    var model: Motion!
    var now = 0.0
    var lastVisual = ""
    var workloadCount: Int?
    override var isOpaque: Bool { false }
    override init(frame: CGRect) { super.init(frame:frame) }
    required init?(coder:NSCoder){fatalError()}
    func visualFrame() -> (Int,Int) {
        if let f=model.flight {
            let p=f.progress(now)
            if f.ability == .quiet { return (0,0) }
            if f.ability == .swing { return (4,p<0.15 ? 0:p<0.75 ? 2:3) }
            return (4,min(4,Int(p*5)))
        }
        if now-model.lastLanding < 0.14 { return (4,0) }
        return (0,model.reducedMotion ? 0 : Int(now/0.75)%6)
    }
    func refresh() {
        let (r,c)=visualFrame()
        let key="\(r)-\(c)-\(model.position.x)-\(model.position.y)-\(model.flight != nil)"
        let workshopKey=key+"-\(workloadCount ?? -1)-\(model.reducedMotion)"
        if model.flight != nil || ((workloadCount ?? 0)>0 && !model.reducedMotion) || workshopKey != lastVisual { needsDisplay=true;lastVisual=workshopKey }
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.clear.setFill();dirtyRect.fill(using:.copy)
        guard let model=model else{return}
        let p=model.position
        let f=model.flight
        let progress=f?.progress(now) ?? 1
        if f == nil, let count=workloadCount { drawForge(at:p,count:count,time:now,reducedMotion:model.reducedMotion) }
        let quietAlpha: CGFloat = f?.ability == .quiet ? CGFloat(abs(progress-0.5)*2) : 1
        // A short tether is only visible during the middle of a swing.
        if let f=f, f.ability == .swing, progress > 0.06,progress < 0.88 {
            let tilt=sin(progress*Double.pi)*0.23*(f.end.x>f.start.x ? -1.0:1.0)
            let grip=CGPoint(x:p.x+28*cos(tilt)-15*sin(tilt),y:p.y+28*sin(tilt)+15*cos(tilt))
            let line=NSBezierPath();line.move(to:f.anchor.point);line.line(to:grip)
            NSColor(calibratedRed:0.66,green:0.88,blue:1,alpha:0.28).setStroke();line.lineWidth=5;line.stroke()
            NSColor(calibratedRed:0.85,green:0.97,blue:1,alpha:0.95).setStroke();line.lineWidth=1.6;line.stroke()
            NSColor(calibratedRed:0.85,green:0.97,blue:1,alpha:0.8).setFill()
            NSBezierPath(ovalIn:CGRect(x:f.anchor.x-2,y:f.anchor.y-2,width:4,height:4)).fill()
        }
        let (row,col)=visualFrame()
        if let f=f,f.ability == .dash,progress > 0.15,progress < 0.9 {
            for n in (1...3).reversed() {
                let old=f.position(now-Double(n)*0.025)
                drawSprite(row:row,col:col,at:old,alpha:CGFloat(0.15/Double(n)),angle:0)
            }
        }
        var angle:CGFloat=0
        if let f=f,f.ability == .swing { angle=CGFloat(sin(progress*Double.pi)*0.23*(f.end.x>f.start.x ? -1:1)) }
        drawSprite(row:row,col:col,at:p,alpha:quietAlpha,angle:angle)
    }
    func drawSprite(row:Int,col:Int,at p:V,alpha:CGFloat,angle:CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let transform=NSAffineTransform();transform.translateX(by:p.x,yBy:p.y);transform.rotate(byRadians:angle);transform.concat()
        drawRobot(row:row,frame:col,alpha:alpha)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class AppDelegate:NSObject,NSApplicationDelegate {
    var panel:PetPanel!
    var pet:PetView!
    var status:NSStatusItem!
    var timer:Timer?
    var previousCursor=V(x:0,y:0)
    var previousTime=0.0
    var velocity=V(x:0,y:0)
    var paused=false
    var screen:NSScreen!
    var screenID:AnyHashable?
    var lastQA=0.0
    var pauseItem:NSMenuItem!
    var hideDuringSleep=false
    var testWindow:NSWindow?
    var testClicks=0
    var autoReduceItem:NSMenuItem!
    var forceReduced=false
    var tickInterval=1.0/30
    var workloadMonitor=WorkloadMonitor()
    var workloadItem:NSMenuItem!
    var reactItem:NSMenuItem!
    var reactToWorkload=true
    var lastWorkload=WorkloadSnapshot.unavailable
    var lastWorkloadAt=0.0
    var previewCount:Int?
    var previewUntil=0.0
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        let cursor=NSEvent.mouseLocation
        screen=NSScreen.screens.first(where:{$0.frame.contains(cursor)}) ?? NSScreen.main ?? NSScreen.screens.first!
        createPanel()
        previousCursor=V(x:cursor.x,y:cursor.y);previousTime=CACurrentMediaTime()
        panel.orderFrontRegardless()
        setTimer(interval:1.0/30)
        startWorkload()
        NotificationCenter.default.addObserver(self,selector:#selector(displaysChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(willSleep),name:NSWorkspace.willSleepNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(willSleep),name:NSWorkspace.screensDidSleepNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(didWake),name:NSWorkspace.didWakeNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(didWake),name:NSWorkspace.screensDidWakeNotification,object:nil)
        if args.contains("--test-window") { showTestWindow() }
    }
    func createPanel() {
        screenID=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? AnyHashable
        let rect=screen.visibleFrame
        panel=PetPanel(contentRect:rect,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false
        panel.ignoresMouseEvents=true;panel.hidesOnDeactivate=false;panel.isFloatingPanel=true
        panel.level = .floating
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
        panel.isReleasedWhenClosed=false;panel.title="MechaPets Overlay"
        pet=PetView(frame:CGRect(origin:.zero,size:rect.size))
        let bounds=safeBounds(pet.bounds)
        pet.model=Motion(bounds:bounds,position:V(x:bounds.maxX-70,y:bounds.minY+90))
        pet.model.radius=UserDefaults.standard.double(forKey:"radius") == 0 ? 125:UserDefaults.standard.double(forKey:"radius")
        pet.model.mode=UserDefaults.standard.string(forKey:"mode") ?? "Automatic"
        panel.contentView=pet
    }
    func setTimer(interval:Double) {
        timer?.invalidate();tickInterval=interval
        timer=Timer(timeInterval:interval,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        timer?.tolerance=interval*0.1
        RunLoop.main.add(timer!,forMode:.common)
    }
    @objc func tick() {
        let now=CACurrentMediaTime(), raw=NSEvent.mouseLocation
        let cursor=V(x:raw.x-panel.frame.minX,y:raw.y-panel.frame.minY)
        let global=V(x:raw.x,y:raw.y)
        let dt=now-previousTime
        let measured=dt>0 && dt<0.3 ? (global-previousCursor)*(1/dt):V(x:0,y:0)
        velocity=lerp(velocity,measured,0.6)
        previousCursor=global;previousTime=now
        pet.model.reducedMotion=forceReduced || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let reduced=pet.model.reducedMotion
        if previewCount != nil && now>=previewUntil { previewCount=nil }
        if let preview=previewCount {
            pet.workloadCount=preview
            workloadItem.title="Preview: " + WorkloadSnapshot.active(preview).status
        } else {
            let snapshot = !reactToWorkload ? WorkloadSnapshot.disabled : now-lastWorkloadAt>8 ? .unavailable:lastWorkload
            pet.workloadCount=snapshot.activeCount;workloadItem.title=snapshot.status
        }
        autoReduceItem.state=forceReduced ? .on:.off
        if !paused && !hideDuringSleep {
            pet.model.update(now:now,cursor:cursor,velocity:velocity)
            pet.now=now;pet.refresh()
        }
        let desired=pet.model.flight != nil ? 1.0/60 : 1.0/30
        if desired != tickInterval { setTimer(interval:desired) }
        if let url=qaURL,now-lastQA > 0.20 {
            lastQA=now
            let state:[String:Any]=["pid":ProcessInfo.processInfo.processIdentifier,"position":[pet.model.position.x+panel.frame.minX,pet.model.position.y+panel.frame.minY],"panel":[panel.frame.minX,panel.frame.minY,panel.frame.width,panel.frame.height],"safeBounds":[pet.model.bounds.minX,pet.model.bounds.minY,pet.model.bounds.width,pet.model.bounds.height],"escapeCount":pet.model.escapeCount,"swings":pet.model.swingCount,"dashes":pet.model.dashCount,"ability":pet.model.lastAbility,"moving":pet.model.flight != nil,"paused":paused,"reducedMotion":reduced,"clickThrough":panel.ignoresMouseEvents,"canBecomeKey":panel.canBecomeKey,"frontmostApp":NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "","testClicks":testClicks,"screenCount":NSScreen.screens.count,"activeTasks":pet.workloadCount as Any? ?? NSNull(),"workloadStatus":workloadItem.title,"workshopVisible":pet.workloadCount != nil && pet.model.flight == nil]
            if let data=try? JSONSerialization.data(withJSONObject:state,options:[.prettyPrinted,.sortedKeys]) {try? data.write(to:url,options:.atomic)}
        }
    }
    func buildMenu() {
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        status.button?.image=NSImage(systemSymbolName:"hare.fill",accessibilityDescription:"MechaPets")
        status.button?.toolTip="MechaPets — gives your cursor room"
        let menu=NSMenu()
        let title=NSMenuItem(title:"MechaPets",action:nil,keyEquivalent:"");menu.addItem(title)
        let subtitle=NSMenuItem(title:"Swings and dashes out of your way",action:nil,keyEquivalent:"");menu.addItem(subtitle)
        menu.addItem(.separator())
        workloadItem=NSMenuItem(title:"Connecting to local Codex…",action:nil,keyEquivalent:"");menu.addItem(workloadItem)
        reactToWorkload=UserDefaults.standard.object(forKey:"reactToWorkload") as? Bool ?? true
        reactItem=add(menu,"React to Codex workload",#selector(toggleWorkload));reactItem.state=reactToWorkload ? .on:.off
        add(menu,"Choose Codex data folder…",#selector(chooseCodexHome))
        let previews=NSMenuItem(title:"Preview workshop",action:nil,keyEquivalent:"")
        let previewMenu=NSMenu()
        for (title,count) in [("Idle · 0 tasks",0),("Calm · 1 task",1),("Busy · 2 tasks",2),("Frenzy · 3+ tasks",3)] {
            let item=add(previewMenu,title,#selector(previewWorkshop));item.representedObject=count
        }
        previews.submenu=previewMenu;menu.addItem(previews)
        menu.addItem(.separator())
        pauseItem=add(menu,"Pause & hide pet",#selector(togglePause))
        add(menu,"Bring pet to this screen",#selector(bringHere))
        add(menu,"Show a swing",#selector(demoSwing));add(menu,"Show a jump-dash",#selector(demoDash))
        menu.addItem(.separator())
        let behavior=NSMenuItem(title:"Abilities",action:nil,keyEquivalent:"")
        let modes=NSMenu();for name in ["Automatic","Swing","Jump-dash"] { let item=add(modes,name,#selector(changeMode));item.representedObject=name;item.state=(UserDefaults.standard.string(forKey:"mode") ?? "Automatic")==name ? .on:.off }
        behavior.submenu=modes;menu.addItem(behavior)
        let sensitivity=NSMenuItem(title:"Personal space",action:nil,keyEquivalent:"")
        let spaces=NSMenu();for (name,radius) in [("Compact",100.0),("Comfortable",125.0),("Extra room",155.0)] {let item=add(spaces,name,#selector(changeRadius));item.representedObject=radius;item.state=(UserDefaults.standard.object(forKey:"radius") as? Double ?? 125)==radius ? .on:.off};sensitivity.submenu=spaces;menu.addItem(sensitivity)
        autoReduceItem=add(menu,"Gentle motion",#selector(toggleReduced))
        forceReduced=UserDefaults.standard.bool(forKey:"gentleMotion")
        menu.addItem(.separator());add(menu,"Quit MechaPets",#selector(quit),key:"q")
        status.menu=menu
    }
    @discardableResult func add(_ menu:NSMenu,_ title:String,_ action:Selector,key:String="") -> NSMenuItem {
        let item=NSMenuItem(title:title,action:action,keyEquivalent:key);item.target=self;menu.addItem(item);return item
    }
    func startWorkload() {
        workloadMonitor.stop()
        guard reactToWorkload && !hideDuringSleep else {return}
        let home=UserDefaults.standard.string(forKey:"codexDataFolder").map {URL(fileURLWithPath:$0,isDirectory:true)} ?? WorkloadReader.defaultHome
        workloadMonitor=WorkloadMonitor(home:home)
        workloadMonitor.start { [weak self] snapshot in
            guard let self=self else{return};self.lastWorkload=snapshot;self.lastWorkloadAt=CACurrentMediaTime()
        }
    }
    @objc func toggleWorkload() {
        reactToWorkload.toggle();previewCount=nil
        UserDefaults.standard.set(reactToWorkload,forKey:"reactToWorkload")
        reactItem.state=reactToWorkload ? .on:.off
        lastWorkload = .unavailable;lastWorkloadAt=0
        startWorkload()
    }
    @objc func chooseCodexHome() {
        let picker=NSOpenPanel();picker.canChooseDirectories=true;picker.canChooseFiles=false
        picker.allowsMultipleSelection=false;picker.showsHiddenFiles=true
        picker.message="Choose your Codex data folder (normally ~/.codex). Only local task status metadata is read."
        if picker.runModal() == .OK,let url=picker.url {
            UserDefaults.standard.set(url.path,forKey:"codexDataFolder");lastWorkload = .unavailable;lastWorkloadAt=0;startWorkload()
        }
    }
    @objc func previewWorkshop(_ sender:NSMenuItem) {
        previewCount=sender.representedObject as? Int;previewUntil=CACurrentMediaTime()+12
        if paused {togglePause()}
    }
    @objc func togglePause(){paused.toggle();pauseItem.title=paused ? "Resume pet":"Pause & hide pet";if paused{panel.orderOut(nil);pet.model.flight=nil}else{panel.orderFrontRegardless();pet.model.armed=true}}
    @objc func toggleReduced(){forceReduced.toggle();UserDefaults.standard.set(forceReduced,forKey:"gentleMotion");pet.model.flight=nil}
    @objc func changeMode(_ sender:NSMenuItem){let value=sender.representedObject as! String;pet.model.mode=value;UserDefaults.standard.set(value,forKey:"mode");sender.menu?.items.forEach{$0.state = $0===sender ? .on:.off}}
    @objc func changeRadius(_ sender:NSMenuItem){let value=sender.representedObject as! Double;pet.model.radius=value;UserDefaults.standard.set(value,forKey:"radius");sender.menu?.items.forEach{$0.state = $0===sender ? .on:.off}}
    @objc func demoSwing(){demo(.swing)}
    @objc func demoDash(){demo(.dash)}
    func demo(_ ability:Ability){if paused{togglePause()};pet.model.escape(now:CACurrentMediaTime(),cursor:pet.model.position+V(x:40,y:0),velocity:V(x:0,y:0),forced:ability)}
    @objc func bringHere(){let cursor=NSEvent.mouseLocation;if let target=NSScreen.screens.first(where:{$0.frame.contains(cursor)}){screen=target;relocate()}}
    @objc func displaysChanged(){screen=NSScreen.screens.first(where:{$0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? AnyHashable == screenID}) ?? NSScreen.main ?? NSScreen.screens.first;guard screen != nil else{return};relocate()}
    func relocate(){screenID=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? AnyHashable;panel.setFrame(screen.visibleFrame,display:false);pet.frame=CGRect(origin:.zero,size:screen.visibleFrame.size);pet.model.resize(safeBounds(pet.bounds));pet.needsDisplay=true}
    @objc func willSleep(){hideDuringSleep=true;panel.orderOut(nil);timer?.invalidate();workloadMonitor.stop()}
    @objc func didWake(){hideDuringSleep=false;previousTime=CACurrentMediaTime();velocity=V(x:0,y:0);pet.model.flight=nil;displaysChanged();if !paused{panel.orderFrontRegardless()};setTimer(interval:1.0/30);lastWorkloadAt=0;startWorkload()}
    @objc func quit(){NSApp.terminate(nil)}
    func showTestWindow(){
        let rect=screen.visibleFrame.insetBy(dx:25,dy:25)
        let w=NSWindow(contentRect:rect,styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        w.title="MechaPets — interaction test";w.isReleasedWhenClosed=false
        let b=NSButton(frame:CGRect(origin:.zero,size:rect.size));b.title="Click anywhere here to test the pet’s click-through behavior.\nThe pet should escape while this window receives your click.";b.target=self;b.action=#selector(testClick);b.bezelStyle = .regularSquare;b.autoresizingMask=[.width,.height]
        w.contentView=b;testWindow=w;w.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func testClick(){testClicks+=1;(testWindow?.contentView as? NSButton)?.title="Click received: \(testClicks)\nMove toward the pet again. It will give you room."}
}

if args.contains("--self-test") { runTests();runWorkloadTests();exit(0) }
if args.contains("--workload-status") {
    let result=WorkloadReader(home:WorkloadReader.defaultHome).sample()
    print(String(data:try! JSONEncoder().encode(result),encoding:.utf8)!)
    exit(result.activeCount == nil ? 1:0)
}
if let i=args.firstIndex(of:"--render-forge-animation"),i+1<args.count { renderForgeAnimation(to:args[i+1]);exit(0) }
if let i=args.firstIndex(of:"--render-forge-preview"),i+1<args.count { renderForgePreview(to:args[i+1]);exit(0) }
if let i=args.firstIndex(of:"--render-preview"),i+1<args.count { renderPreview(to:args[i+1]);exit(0) }
if args.contains("--ui-smoke-test") {
    let app=NSApplication.shared
    let previousFront=NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    let defaults=UserDefaults.standard
    let saved=["radius","mode","gentleMotion","reactToWorkload"].map { ($0,defaults.object(forKey:$0)) }
    let d=AppDelegate();app.delegate=d
    d.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
    precondition(d.panel.ignoresMouseEvents && !d.panel.canBecomeKey && !d.panel.canBecomeMain)
    precondition(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == previousFront,"Overlay stole focus")
    let menu=d.status.menu!
    func invoke(_ title:String) { menu.performActionForItem(at:menu.items.firstIndex(where:{$0.title==title})!) }
    let previewMenu=menu.items.first(where:{$0.title=="Preview workshop"})!.submenu!
    for count in 0...3 {
        previewMenu.performActionForItem(at:count);d.tick()
        precondition(d.pet.workloadCount==count && d.workloadItem.title.hasPrefix("Preview:"))
    }
    d.previewCount=nil;d.lastWorkload = .active(2);d.lastWorkloadAt=CACurrentMediaTime();d.reactToWorkload=true;d.tick()
    precondition(d.pet.workloadCount==2)
    invoke("React to Codex workload");d.tick();precondition(d.pet.workloadCount==nil)
    invoke("React to Codex workload");d.lastWorkload = .active(3);d.lastWorkloadAt=CACurrentMediaTime()-10;d.tick();precondition(d.pet.workloadCount==nil)
    invoke("Pause & hide pet");precondition(d.paused && !d.panel.isVisible)
    invoke("Resume pet");precondition(!d.paused && d.panel.isVisible)
    invoke("Show a swing");precondition(d.pet.model.flight?.ability == .swing)
    invoke("Show a jump-dash");precondition(d.pet.model.flight?.ability == .dash)
    let wasGentle=d.forceReduced
    invoke("Gentle motion");precondition(d.forceReduced != wasGentle)
    let modes=menu.items.first(where:{$0.title=="Abilities"})!.submenu!
    modes.performActionForItem(at:2);precondition(d.pet.model.mode=="Jump-dash")
    let spaces=menu.items.first(where:{$0.title=="Personal space"})!.submenu!
    spaces.performActionForItem(at:2);precondition(d.pet.model.radius==155)
    d.willSleep();precondition(!d.panel.isVisible && d.hideDuringSleep)
    d.didWake();precondition(d.panel.isVisible && !d.hideDuringSleep)
    precondition(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == previousFront,"Controls stole focus")
    for (key,value) in saved { if let value=value { defaults.set(value,forKey:key) } else { defaults.removeObject(forKey:key) } }
    defaults.synchronize();d.panel.orderOut(nil);d.timer?.invalidate();d.workloadMonitor.stop()
    print("PASS: native menu dispatch, pause/resume visibility, swing/dash actions, gentle mode, ability and radius selection, sleep/wake handlers, click-through flags and foreground-app retention.")
    exit(0)
}
let app=NSApplication.shared
// Do not spawn duplicate pets when the app is opened again.
if let id=Bundle.main.bundleIdentifier,NSRunningApplication.runningApplications(withBundleIdentifier:id).contains(where:{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier}) { exit(0) }
let delegate=AppDelegate();app.delegate=delegate;app.run()
