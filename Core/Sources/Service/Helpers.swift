import Foundation

extension FileManager {
    func fileIsDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

@discardableResult
func runAppleScript(_ appleScript: String) async throws -> String? {
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", appleScript]
    let outpipe = Pipe()
    task.standardOutput = outpipe
    try task.run()
    await Task.yield()
    task.waitUntilExit()
    if let data = try outpipe.fileHandleForReading.readToEnd(),
       let content = String(data: data, encoding: .utf8)
    {
        return content
    }
    return nil
}
