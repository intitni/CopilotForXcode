import LanguageServerProtocol
import XCTest

@testable import GitHubCopilotService

final class FileExtensionToLanguageIdentifierTests: XCTestCase {
    func test_no_conflicts_in_map() {
        var dict = [String: [String]]()
        for languageId in LanguageIdentifier.allCases {
            for e in languageId.fileExtensions {
                if dict[e] == nil {
                    dict[e] = []
                }
                dict[e]?.append(languageId.rawValue)
            }
        }

        let confilicts = dict.filter { $0.value.count > 1 }
        XCTAssertEqual(confilicts, [:])
    }
}
