import Foundation

final class FileSaveWatcher {
    let url: URL
    var fileHandle: FileHandle?
    var source: DispatchSourceFileSystemObject?
    var changeHandler: () -> Void = {}

    init(fileURL: URL) {
        url = fileURL
        startup()
    }

    deinit {
        source?.cancel()
    }

    func startup() {
        if let source = source {
            source.cancel()
        }

        fileHandle = try? FileHandle(forReadingFrom: url)
        if let fileHandle = fileHandle {
            source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileHandle.fileDescriptor,
                eventMask: .link,
                queue: .main
            )

            source?.setEventHandler { [weak self] in
                self?.changeHandler()
                self?.startup()
            }

            source?.resume()
        }
    }
}
