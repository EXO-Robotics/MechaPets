// Local metadata adapter. No prompts, titles, messages or tool output are queried.
import Foundation
import SQLite3
import Darwin

struct WorkloadSnapshot: Codable {
    let activeCount: Int?
    let status: String
    static func active(_ count: Int) -> WorkloadSnapshot {
        let mood = ["Idle", "Calm", "Busy", "Frenzy"][min(3, max(0,count))]
        return WorkloadSnapshot(activeCount: count, status: "Codex: \(count) active \(count == 1 ? "task" : "tasks") · \(mood)")
    }
    static let unavailable = WorkloadSnapshot(activeCount:nil, status:"Codex status unavailable")
    static let disabled = WorkloadSnapshot(activeCount:nil, status:"Codex reaction off")
}

enum WorkloadError: Error { case unavailable }
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct WorkloadReader {
    let home: URL
    // Injection point for lifecycle fixtures; production uses read-only lsof.
    var openWriters: ((URL, [String]) throws -> Set<String>) = liveWriterIDs
    static var defaultHome: URL {
        if let path=ProcessInfo.processInfo.environment["CODEX_HOME"], !path.isEmpty {
            return URL(fileURLWithPath:path, isDirectory:true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex",isDirectory:true)
    }
    func sample() -> WorkloadSnapshot {
        do { return .active(try count()) } catch { return .unavailable }
    }
    func count() throws -> Int {
        let history=home.appendingPathComponent("thread_history_1.sqlite")
        let state=home.appendingPathComponent("state_5.sqlite")
        guard FileManager.default.fileExists(atPath:history.path), FileManager.default.fileExists(atPath:state.path) else { throw WorkloadError.unavailable }
        var db: OpaquePointer?
        guard sqlite3_open_v2(history.path,&db,SQLITE_OPEN_READONLY|SQLITE_OPEN_URI,nil)==SQLITE_OK else {
            if let db=db { sqlite3_close(db) };throw WorkloadError.unavailable
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db,250)
        // Attached DB also uses mode=ro; never request a write transaction.
        var attach: OpaquePointer?
        guard sqlite3_prepare_v2(db,"ATTACH DATABASE ? AS metadata",-1,&attach,nil)==SQLITE_OK else { throw WorkloadError.unavailable }
        let uri=state.absoluteString+"?mode=ro"
        sqlite3_bind_text(attach,1,uri,-1,sqliteTransient)
        let attached=sqlite3_step(attach);sqlite3_finalize(attach)
        guard attached==SQLITE_DONE else { throw WorkloadError.unavailable }
        let sql="""
        SELECT t.id, h.status
        FROM metadata.threads t JOIN thread_turns h ON h.thread_id=t.id
        WHERE t.archived=0 AND t.agent_path IS NULL
          AND t.source IN ('vscode','cli','exec')
          AND NOT EXISTS (SELECT 1 FROM thread_turns later
                          WHERE later.thread_id=h.thread_id AND later.rollout_ordinal>h.rollout_ordinal)
          AND h.status NOT IN ('completed','failed','interrupted')
        LIMIT 129
        """
        var statement:OpaquePointer?
        guard sqlite3_prepare_v2(db,sql,-1,&statement,nil)==SQLITE_OK else { throw WorkloadError.unavailable }
        defer { sqlite3_finalize(statement) }
        var ids:[String]=[]
        while true {
            let result=sqlite3_step(statement)
            if result==SQLITE_DONE { break }
            guard result==SQLITE_ROW,
                  let rawID=sqlite3_column_text(statement,0),let rawStatus=sqlite3_column_text(statement,1) else { throw WorkloadError.unavailable }
            let id=String(cString:rawID),status=String(cString:rawStatus)
            guard UUID(uuidString:id) != nil,status=="inProgress" else { throw WorkloadError.unavailable }
            ids.append(id)
        }
        guard ids.count<=128 else { throw WorkloadError.unavailable }
        if ids.isEmpty { return 0 }
        let writers=try openWriters(home.appendingPathComponent("thread-writer-locks",isDirectory:true),ids)
        return Set(ids).intersection(writers).count
    }
}

// Parse only command names and exact candidate file paths. Never expose PIDs or IDs in the UI.
func parseWriterIDs(_ text:String, paths:[String:String]) -> Set<String> {
    var command="",result=Set<String>()
    for line in text.split(separator:"\n",omittingEmptySubsequences:false) {
        if line.hasPrefix("p") { command="" }
        else if line.hasPrefix("c") { command=String(line.dropFirst()) }
        else if line.hasPrefix("n"),command=="codex",let id=paths[String(line.dropFirst())] { result.insert(id) }
    }
    return result
}

private final class ProcessCapture {
    let lock=NSLock()
    var output=Data(),errors=Data()
    func set(_ data:Data, error:Bool) { lock.lock();defer{lock.unlock()};if error{errors=data}else{output=data} }
}

func liveWriterIDs(directory: URL, ids:[String]) throws -> Set<String> {
    guard FileManager.default.fileExists(atPath:directory.path) else { throw WorkloadError.unavailable }
    var paths:[String:String]=[:]
    for id in ids {
        guard UUID(uuidString:id) != nil else { throw WorkloadError.unavailable }
        let file=directory.appendingPathComponent(id+".lock")
        if FileManager.default.fileExists(atPath:file.path) { paths[file.path]=id }
    }
    if paths.isEmpty { return [] }
    let process=Process(),out=Pipe(),err=Pipe(),done=DispatchSemaphore(value:0)
    process.executableURL=URL(fileURLWithPath:"/usr/sbin/lsof")
    process.arguments=["-nP","-Fpcfn","--"]+paths.keys.sorted()
    process.standardOutput=out;process.standardError=err
    process.terminationHandler={_ in done.signal()}
    try process.run()
    // Drain both pipes concurrently, so even an unexpected diagnostic cannot deadlock the worker.
    let capture=ProcessCapture(),readers=DispatchGroup()
    for (pipe,isError) in [(out,false),(err,true)] {
        readers.enter()
        DispatchQueue.global(qos:.utility).async {
            let data=pipe.fileHandleForReading.readDataToEndOfFile()
            capture.set(data,error:isError);readers.leave()
        }
    }
    guard done.wait(timeout:.now()+3) == .success else {
        process.terminate()
        if done.wait(timeout:.now()+0.5) != .success { kill(process.processIdentifier,SIGKILL) }
        throw WorkloadError.unavailable
    }
    guard readers.wait(timeout:.now()+1) == .success else { throw WorkloadError.unavailable }
    capture.lock.lock();let data=capture.output,errors=capture.errors;capture.lock.unlock()
    guard process.terminationReason == .exit, [0,1].contains(process.terminationStatus),
          errors.isEmpty,data.count<1_048_576,let output=String(data:data,encoding:.utf8) else { throw WorkloadError.unavailable }
    // lsof legitimately exits 1 if some candidate handles are no longer open.
    return parseWriterIDs(output,paths:paths)
}

final class WorkloadMonitor {
    private let queue=DispatchQueue(label:"MechaPets.workload",qos:.utility)
    private var timer:DispatchSourceTimer?
    private var generation=0
    private let reader:WorkloadReader
    init(home:URL=WorkloadReader.defaultHome){reader=WorkloadReader(home:home)}
    // Start/stop and deliveries occur on the main thread; all filesystem work stays on the worker.
    func start(deliver:@escaping (WorkloadSnapshot)->Void) {
        stop();let current=generation
        let timer=DispatchSource.makeTimerSource(queue:queue)
        timer.schedule(deadline:.now(),repeating:2,leeway:.milliseconds(150))
        timer.setEventHandler { [weak self] in
            guard let self=self else{return}
            let snapshot=self.reader.sample()
            DispatchQueue.main.async { [weak self] in
                guard let self=self,self.generation==current else{return};deliver(snapshot)
            }
        }
        self.timer=timer;timer.resume()
    }
    func stop(){generation+=1;timer?.cancel();timer=nil}
    deinit{timer?.cancel()}
}
