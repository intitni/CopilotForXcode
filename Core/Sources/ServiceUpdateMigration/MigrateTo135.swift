import Foundation
import GitHubCopilotService

func migrateFromLowerThanOrEqualToVersion135() throws {
    // 0. Create the application support folder if it doesn't exist

    let urls = try GitHubCopilotBaseService.createFoldersIfNeeded()

    // 1. Move the undefined folder in application support into a sub folder called `GitHub
    // Copilot/support`

    let undefinedFolderURL = urls.applicationSupportURL.appendingPathComponent("undefined")
    var isUndefinedADirectory: ObjCBool = false
    let isUndefinedExisted = FileManager.default.fileExists(
        atPath: undefinedFolderURL.path,
        isDirectory: &isUndefinedADirectory
    )
    if isUndefinedExisted, isUndefinedADirectory.boolValue {
        try FileManager.default.moveItem(
            at: undefinedFolderURL,
            to: urls.supportURL.appendingPathComponent("undefined")
        )
    }

    // 2. Copy the GitHub copilot language service to `GitHub Copilot/executable`

    let copilotFolderURL = urls.executableURL.appendingPathComponent("copilot")
    var copilotIsFolder: ObjCBool = false
    let executable = Bundle.main.resourceURL?.appendingPathComponent("copilot")
    if let executable,
       FileManager.default.fileExists(atPath: executable.path, isDirectory: &copilotIsFolder),
       !FileManager.default.fileExists(atPath: copilotFolderURL.path)
    {
        try FileManager.default.copyItem(
            at: executable,
            to: urls.executableURL.appendingPathComponent("copilot")
        )
    }

    // 3. Use chmod to change the permission of the executable to 755

    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: copilotFolderURL.path
    )
}

