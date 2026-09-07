import CodableWrappers
import Foundation

public struct TabbyModel: Codable, Equatable {
    public enum AuthorizationMode: String, Codable, CaseIterable {
        case none
        case bearerToken
        case basic
        case customHeaderField
    }

    @FallbackDecoding<EmptyString>
    public var url: String
    @FallbackDecoding<EmptyAuthorizationMode>
    public var authorizationMode: AuthorizationMode
    @FallbackDecoding<EmptyString>
    public var apiKeyName: String
    @FallbackDecoding<EmptyString>
    public var authorizationHeaderName: String
    @FallbackDecoding<EmptyString>
    public var username: String

    public init(
        url: String,
        authorizationMode: AuthorizationMode,
        apiKeyName: String,
        authorizationHeaderName: String,
        username: String
    ) {
        self.url = url
        self.authorizationMode = authorizationMode
        self.apiKeyName = apiKeyName
        self.authorizationHeaderName = authorizationHeaderName
        self.username = username
    }
}

public struct EmptyAuthorizationMode: FallbackValueProvider {
    public static var defaultValue: TabbyModel.AuthorizationMode { .none }
}

