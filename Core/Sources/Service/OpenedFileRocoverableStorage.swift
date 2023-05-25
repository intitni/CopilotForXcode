import Foundation
import Preferences

@ServiceActor
final class OpenedFileRecoverableStorage {
    let projectRootURL: URL
    let userDefault = UserDefaults.shared
    let key = "OpenedFileRecoverableStorage"

    init(projectRootURL: URL) {
        self.projectRootURL = projectRootURL
    }

    func openFile(fileURL: URL) {
        var dict = userDefault.dictionary(forKey: key) ?? [:]
        var openedFiles = Set(dict[projectRootURL.path] as? [String] ?? [])
        openedFiles.insert(fileURL.path)
        dict[projectRootURL.path] = Array(openedFiles)
        userDefault.set(dict, forKey: key)
    }

    func closeFile(fileURL: URL) {
        var dict = userDefault.dictionary(forKey: key) ?? [:]
        var openedFiles = dict[projectRootURL.path] as? [String] ?? []
        openedFiles.removeAll(where: { $0 == fileURL.path })
        dict[projectRootURL.path] = openedFiles
        userDefault.set(dict, forKey: key)
    }

    var openedFiles: [URL] {
        let dict = userDefault.dictionary(forKey: key) ?? [:]
        let openedFiles = dict[projectRootURL.path] as? [String] ?? []
        return openedFiles.map { URL(fileURLWithPath: $0) }
    }
}

