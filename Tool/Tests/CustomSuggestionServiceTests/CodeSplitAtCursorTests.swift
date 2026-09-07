import Foundation
import AIModel
import XCTest

@testable import CustomSuggestionService

class CodeSplitAtCursorTests: XCTestCase {
    func test_split_at_the_end_of_a_file() {
        let code = """
        func mergeSort<T: Comparable>(_ array: [T]) -> [T] {
            guard array.count > 1 else { return array }
            let middle = array.count / 2
            let left = mergeSort(Array(array[..<middle]))
            let right = mergeSort(Array(array[middle...]))
            return merge(left, right)
        }
        """
        let lines = code.breakLines()
        let (previousLines, nextLines) = CustomSuggestionCoordinator.split(
            code: code,
            lines: lines,
            at: .init(line: 6, character: 1)
        )
        XCTAssertEqual(previousLines, lines)
        XCTAssertEqual(nextLines, [])
    }
    
    func test_split_in_the_middle() {
        let code = """
        func mergeSort<T: Comparable>(_ array: [T]) -> [T] {
            guard array.count > 1 else { return array }
            let middle = array.count / 2
            let left = mergeSort(Array(array[..<middle]))
            let right = mergeSort(Array(array[middle...]))
            return merge(left, right)
        }
        """
        let lines = code.breakLines()
        let (previousLines, nextLines) = CustomSuggestionCoordinator.split(
            code: code,
            lines: lines,
            at: .init(line: 2, character: 14)
        )
        XCTAssertEqual(previousLines, Array(lines[0...1]) + ["    let middle"])
        XCTAssertEqual(nextLines, [" = array.count / 2\n"] + Array(lines[3...]))
    }
    
    func test_split_right_before_line_break() {
        let code = """
        func mergeSort<T: Comparable>(_ array: [T]) -> [T] {
            guard array.count > 1 else { return array }
            let middle = array.count / 2
            let left = mergeSort(Array(array[..<middle]))
            let right = mergeSort(Array(array[middle...]))
            return merge(left, right)
        }
        """
        let lines = code.breakLines()
        let (previousLines, nextLines) = CustomSuggestionCoordinator.split(
            code: code,
            lines: lines,
            at: .init(line: 2, character: 32)
        )
        XCTAssertEqual(previousLines, Array(lines[0...1]) + ["    let middle = array.count / 2"])
        XCTAssertEqual(nextLines, ["\n"] + Array(lines[3...]))
    }
    
    func test_split_empty_file() {
        let code = ""
        let lines = code.breakLines()
        let (previousLines, nextLines) = CustomSuggestionCoordinator.split(
            code: code,
            lines: lines,
            at: .init(line: 0, character: 0)
        )
        XCTAssertEqual(previousLines, [])
        XCTAssertEqual(nextLines, [])
    }
    
    func test_split_at_out_of_scope_position() {
        let code = """
        func mergeSort<T: Comparable>(_ array: [T]) -> [T] {
            guard array.count > 1 else { return array }
            let middle = array.count / 2
            let left = mergeSort(Array(array[..<middle]))
            let right = mergeSort(Array(array[middle...]))
            return merge(left, right)
        }
        """
        let lines = code.breakLines()
        let (previousLines, nextLines) = CustomSuggestionCoordinator.split(
            code: code,
            lines: lines,
            at: .init(line: lines.endIndex, character: 0)
        )
        XCTAssertEqual(previousLines, lines)
        XCTAssertEqual(nextLines, [])
    }
}

