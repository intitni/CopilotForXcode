import Configs
import Foundation
import Keychain

public final class CodeiumAuthService {
    public init() {}
    let codeiumKeyKey = "codeiumAuthKey"
    let keychain = Keychain()

    var key: String? { try? keychain.get(codeiumKeyKey) }

    public var isSignedIn: Bool { return key != nil }

    public func signIn(token: String) async throws {
        let key = try await generate(token: token)
        try keychain.update(key, key: codeiumKeyKey)
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
        var registerUserUrl = URL(string: "https://api.codeium.com/register_user/")
        let apiUrl = UserDefaults.shared.value(for: \.codeiumApiUrl)
        if UserDefaults.shared.value(for: \.codeiumEnterpriseMode), apiUrl != "" {
            registerUserUrl =
                URL(string: apiUrl + "/exa.seat_management_pb.SeatManagementService/RegisterUser")
        }

        var request = URLRequest(url: registerUserUrl!)
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

