import CodeiumService
import Foundation
import GitHubCopilotService
import Logger

struct DependencyUpdater {
    init() {}
    
    enum EnterprisePortalError: Error {
        case badURL
        case invalidResponse
        case invalidData
    }
    
    func getVersion() async throws -> String {
        let enterprisePortalUrl = UserDefaults.shared.value(for: \.codeiumPortalUrl)
        let enterprisePortalVersionUrl = "\(enterprisePortalUrl)/api/version"
        
        guard let url = URL(string: enterprisePortalVersionUrl) else {throw EnterprisePortalError.badURL}
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw EnterprisePortalError.invalidResponse
        }
        
        if let version = String(data: data, encoding: .utf8) {
            return version
        } else {
            throw EnterprisePortalError.invalidData
        }
    }

    func update() {
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                let gitHubCopilot = GitHubCopilotInstallationManager()
                switch gitHubCopilot.checkInstallation() {
                case .notInstalled: break
                case .installed: break
                case .unsupported: break
                case .outdated:
                    taskGroup.addTask {
                        do {
                            for try await step in gitHubCopilot.installLatestVersion() {
                                let state = {
                                    switch step {
                                    case .downloading:
                                        return "Downloading"
                                    case .uninstalling:
                                        return "Uninstalling old version"
                                    case .decompressing:
                                        return "Decompressing"
                                    case .done:
                                        return "Done"
                                    }
                                }()
                                Logger.service
                                    .error("Update GitHub Copilot language server: \(state)")
                            }
                        } catch {
                            Logger.service.error(
                                "Update GitHub Copilot language server: \(error.localizedDescription)"
                            )
                        }
                    }
                }
                
                // Everytime on startup, access the latest version and update the value for the app
                do {
                    let enterpriseVersion = try await getVersion()
                    UserDefaults.shared.set(enterpriseVersion, forKey: "CodeiumEnterpriseVersion")
                } catch {
                    Logger.service.error(
                        "Error Fetching Enterprise Version from Portal URL"
                    )
                }
                
                let codeium = CodeiumInstallationManager()
                
                if !codeium.isEnterprise() {
                    switch codeium.checkInstallation() {
                    case .notInstalled: break
                    case .installed: break
                    case .unsupported: break
                    case .outdated:
                        taskGroup.addTask {
                            do {
                                for try await step in codeium.installLatestVersion() {
                                    let state = {
                                        switch step {
                                        case .downloading:
                                            return "Downloading"
                                        case .uninstalling:
                                            return "Uninstalling old version"
                                        case .decompressing:
                                            return "Decompressing"
                                        case .done:
                                            return "Done"
                                        }
                                    }()
                                    Logger.service.error("Update Codeium language server: \(state)")
                                }
                            } catch {
                                Logger.service.error(
                                    "Update Codeium language server: \(error.localizedDescription)"
                                )
                            }
                        }
                    }
                } else {
                    switch codeium.checkInstallation() {
                    case .notInstalled:
                        taskGroup.addTask {
                            do {
                                for try await step in codeium.installLatestVersion() {
                                    let state = {
                                        switch step {
                                        case .downloading:
                                            return "Downloading"
                                        case .uninstalling:
                                            return "Setting Up Files"
                                        case .decompressing:
                                            return "Decompressing"
                                        case .done:
                                            return "Done"
                                        }
                                    }()
                                    Logger.service.error("Update Codeium language server: \(state)")
                                }
                            } catch {
                                Logger.service.error(
                                    "Update Codeium language server: \(error.localizedDescription)"
                                )
                            }
                        }
                    case .installed: break
                    case .unsupported: break
                    case .outdated:
                        taskGroup.addTask {
                            do {
                                for try await step in codeium.installLatestVersion() {
                                    let state = {
                                        switch step {
                                        case .downloading:
                                            return "Downloading"
                                        case .uninstalling:
                                            return "Uninstalling old version"
                                        case .decompressing:
                                            return "Decompressing"
                                        case .done:
                                            return "Done"
                                        }
                                    }()
                                    Logger.service.error("Update Codeium language server: \(state)")
                                }
                            } catch {
                                Logger.service.error(
                                    "Update Codeium language server: \(error.localizedDescription)"
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

