import Preferences
import XCTest

final class SuggestionFeatureProviderTests: XCTestCase {
    func test_customModel_rawValue_is_1000() {
        XCTAssertEqual(BuiltInSuggestionFeatureProvider.customModel.rawValue, 1000)
        XCTAssertEqual(BuiltInSuggestionFeatureProvider(rawValue: 1000), .customModel)
        XCTAssertNil(BuiltInSuggestionFeatureProvider(rawValue: 2))
    }

    func test_suggestionFeatureProvider_roundTrip_builtInCustomModel() throws {
        let provider = SuggestionFeatureProvider.builtIn(.customModel)
        XCTAssertEqual(SuggestionFeatureProvider(rawValue: provider.rawValue), provider)

        let encoded = try JSONEncoder().encode(BuiltInSuggestionFeatureProvider.customModel)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "1000")

        XCTAssertThrowsError(
            try JSONDecoder().decode(BuiltInSuggestionFeatureProvider.self, from: Data("2".utf8))
        )
    }
}
