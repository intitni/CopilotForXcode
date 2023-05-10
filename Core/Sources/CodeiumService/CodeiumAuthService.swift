import Foundation
import KeychainAccess

public final class CodeiumAuthService {
    public init() {}
    let codeiumKeyKey = "codeiumKey"
    let keychain: Keychain = {
        let info = Bundle.main.infoDictionary
        return Keychain(
            service: info?["BUNDLE_IDENTIFIER_BASE"] as! String,
            accessGroup: "\(info?["APP_ID_PREFIX"] as! String)\(info?["BUNDLE_IDENTIFIER_BASE"] as! String).Shared"
        )
    }()

    var key: String? { try? keychain.getString(codeiumKeyKey) }

    public var isSignedIn: Bool { return key != nil }

    public func signIn(token: String) async throws {
        let key = try await generate(token: token)
        let info = Bundle.main.infoDictionary
        let keychain = Keychain(
            service: info?["BUNDLE_IDENTIFIER_BASE"] as! String,
            accessGroup: "\(info?["APP_ID_PREFIX"] as! String)\(info?["BUNDLE_IDENTIFIER_BASE"] as! String).Shared"
        )
        try keychain.set(key, key: codeiumKeyKey)
    }

    public func signOut() async throws {
        try keychain.remove(codeiumKeyKey)
    }

    struct GenerateKeyRequestBody: Codable {
        var firebase_id_token: String
    }

    struct GenerateKeyResponseBody: Codable {
        var api_key: String
    }

    struct GenerateKeyErrorResponseBody: Codable, Error, LocalizedError {
        var detail: String
        var errorDescription: String? { detail }
    }

    func generate(token: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.codeium.com/register_user/")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let requestBody = GenerateKeyRequestBody(firebase_id_token: token)
        let requestData = try JSONEncoder().encode(requestBody)
        request.httpBody = requestData
        let (data, _) = try await URLSession.shared.data(for: request)
        do {
            let response = try JSONDecoder().decode(GenerateKeyResponseBody.self, from: data)
            return response.api_key
        } catch {
            if let response = try? JSONDecoder()
                .decode(GenerateKeyErrorResponseBody.self, from: data)
            {
                throw response
            }
            throw error
        }
    }
}

