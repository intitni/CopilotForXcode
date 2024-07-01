import XCTest

@testable import SuggestionBasic

final class ModificationTests: XCTestCase {
    func test_nsmutablearray_deleting_an_element() {
        let a = NSMutableArray(array: ["a", "b", "c"])
        a.apply([.deleted(0...0)])
        XCTAssertEqual(a as! [String], ["b", "c"])
    }

    func test_nsmutablearray_deleting_all_element() {
        let a = NSMutableArray(array: ["a", "b", "c"])
        a.apply([.deleted(0...2)])
        XCTAssertEqual(a as! [String], [])
    }

    func test_nsmutablearray_deleting_too_much_element() {
        let a = NSMutableArray(array: ["a", "b", "c"])
        a.apply([.deleted(0...100)])
        XCTAssertEqual(a as! [String], [])
    }

    func test_nsmutablearray_inserting_elements() {
        let a = NSMutableArray(array: ["a", "b", "c"])
        a.apply([.inserted(0, ["y", "z"])])
        XCTAssertEqual(a as! [String], ["y", "z", "a", "b", "c"])
        a.apply([.inserted(1, ["0", "1"])])
        XCTAssertEqual(a as! [String], ["y", "0", "1", "z", "a", "b", "c"])
    }

    func test_nsmutablearray_inserting_elements_at_index_out_of_range() {
        let a = NSMutableArray(array: ["a", "b", "c"])
        a.apply([.inserted(1000, ["z"])])
        XCTAssertEqual(a as! [String], ["a", "b", "c", "z"])
    }
}
