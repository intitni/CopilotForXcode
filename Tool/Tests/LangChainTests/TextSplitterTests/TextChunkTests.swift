import Foundation
import XCTest

@testable import LangChain

class TextChunkTests: XCTestCase {
    func test_merging_overlapping_text_chunks() {
        let chunk1 = TextChunk(text: "abc", startUTF16Offset: 0, endUTF16Offset: 3)
        let chunk2 = TextChunk(text: "cdef", startUTF16Offset: 2, endUTF16Offset: 6)
        let mergedChunk = chunk1.merged(with: chunk2)
        XCTAssertEqual(mergedChunk?.text, "abcdef")
        XCTAssertEqual(mergedChunk?.startUTF16Offset, 0)
        XCTAssertEqual(mergedChunk?.endUTF16Offset, 6)
    }
    
    func test_merging_adjacent_text_chunks() {
        let chunk1 = TextChunk(text: "abc", startUTF16Offset: 0, endUTF16Offset: 3)
        let chunk2 = TextChunk(text: "def", startUTF16Offset: 3, endUTF16Offset: 6)
        let mergedChunk = chunk1.merged(with: chunk2)
        XCTAssertEqual(mergedChunk?.text, "abcdef")
        XCTAssertEqual(mergedChunk?.startUTF16Offset, 0)
        XCTAssertEqual(mergedChunk?.endUTF16Offset, 6)
    }
    
    func test_merging_overlapping_text_chunks_reversed_order() {
        let chunk1 = TextChunk(text: "abc", startUTF16Offset: 0, endUTF16Offset: 3)
        let chunk2 = TextChunk(text: "cdef", startUTF16Offset: 2, endUTF16Offset: 6)
        let mergedChunk = chunk2.merged(with: chunk1)
        XCTAssertEqual(mergedChunk?.text, "abcdef")
        XCTAssertEqual(mergedChunk?.startUTF16Offset, 0)
        XCTAssertEqual(mergedChunk?.endUTF16Offset, 6)
    }
    
    func test_merging_adjacent_text_chunks_reversed_order() {
        let chunk1 = TextChunk(text: "abc", startUTF16Offset: 0, endUTF16Offset: 3)
        let chunk2 = TextChunk(text: "def", startUTF16Offset: 3, endUTF16Offset: 6)
        let mergedChunk = chunk2.merged(with: chunk1)
        XCTAssertEqual(mergedChunk?.text, "abcdef")
        XCTAssertEqual(mergedChunk?.startUTF16Offset, 0)
        XCTAssertEqual(mergedChunk?.endUTF16Offset, 6)
    }
    
    func test_do_not_merge_non_overlapping_text_chunks() {
        let chunk1 = TextChunk(text: "abc", startUTF16Offset: 0, endUTF16Offset: 3)
        let chunk2 = TextChunk(text: "def", startUTF16Offset: 4, endUTF16Offset: 7)
        let mergedChunk = chunk1.merged(with: chunk2)
        XCTAssertNil(mergedChunk)
    }
}
