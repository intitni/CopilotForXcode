import Foundation
import XCTest

@testable import Keychain

class KeychainTests: XCTestCase {
    func test_scope_key() {
        let keychain = Keychain(scope: "scope")
        XCTAssertEqual(keychain.scopeKey("key"), "scope::key")
    }
    
    func test_escape_scope() {
        let keychain = Keychain(scope: "scope")
        XCTAssertEqual(keychain.escapeScope("scope::key"), "key")
    }
}
