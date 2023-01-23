import CryptoKit
import Dispatch
import Foundation

/// Check that a file is changed.
public actor FileChangeChecker {
    let url: URL
    var checksum: Data?

    public init(fileURL: URL) async {
        url = fileURL
        checksum = getChecksum()
    }

    public func checkIfChanged() -> Bool {
        guard let newChecksum = getChecksum() else { return false }
        return newChecksum != checksum
    }

    func getChecksum() -> Data? {
        let bufferSize = 16 * 1024
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        var md5 = CryptoKit.Insecure.MD5()
        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if !data.isEmpty {
                md5.update(data: data)
                return true // Continue
            } else {
                return false // End of file
            }
        }) {}

        let data = Data(md5.finalize())

        return data
    }
}
