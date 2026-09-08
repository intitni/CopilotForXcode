#if DEBUG
import Foundation

/// Debug 包主可执行文件是 stub，代码在 `<name>.debug.dylib`；指纹取 dylib 的 (mtime, size)。
enum ExecutableFingerprint {
    static func current() -> String {
        guard let executableURL = Bundle.main.executableURL else { return "" }
        let dylibPath = executableURL.path + ".debug.dylib"
        let path = FileManager.default.fileExists(atPath: dylibPath) ? dylibPath : executableURL.path
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return path
        }
        let mtime = attributes[.modificationDate] as? Date
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let mtimeBits = mtime.map { String($0.timeIntervalSince1970.bitPattern) } ?? "0"
        return "\(mtimeBits)-\(size)"
    }
}
#endif
