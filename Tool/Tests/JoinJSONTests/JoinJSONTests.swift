import Foundation

import XCTest
@testable import JoinJSON

final class JoinJSONTests: XCTestCase {
    var sut: JoinJSON!
    
    override func setUp() {
        super.setUp()
        sut = JoinJSON()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_join_two_valid_json_strings() throws {
        let json1 = """
        {"name": "John"}
        """
        let json2 = """
        {"age": 30}
        """
        
        let result = sut.join(json1, with: json2)
        let dict = try JSONSerialization.jsonObject(with: result) as? [String: Any]
        
        XCTAssertEqual(dict?["name"] as? String, "John")
        XCTAssertEqual(dict?["age"] as? Int, 30)
    }
    
    func test_join_with_invalid_json_returns_first_data() {
        let json1 = """
        {"name": "John"}
        """
        let invalidJSON = "invalid json"
        
        let result = sut.join(json1, with: invalidJSON)
        XCTAssertEqual(result, json1.data(using: .utf8))
    }
    
    func test_join_with_overlapping_keys_prefers_second_value() throws {
        let json1 = """
        {"name": "John", "age": 25}
        """
        let json2 = """
        {"age": 30}
        """
        
        let result = sut.join(json1, with: json2)
        let dict = try JSONSerialization.jsonObject(with: result) as? [String: Any]
        
        XCTAssertEqual(dict?["name"] as? String, "John")
        XCTAssertEqual(dict?["age"] as? Int, 30)
    }
    
    func test_join_with_data_input() throws {
        let data1 = """
        {"name": "John"}
        """.data(using: .utf8)!
        
        let data2 = """
        {"age": 30}
        """.data(using: .utf8)!
        
        let result = sut.join(data1, with: data2)
        let dict = try JSONSerialization.jsonObject(with: result) as? [String: Any]
        
        XCTAssertEqual(dict?["name"] as? String, "John")
        XCTAssertEqual(dict?["age"] as? Int, 30)
    }
}
