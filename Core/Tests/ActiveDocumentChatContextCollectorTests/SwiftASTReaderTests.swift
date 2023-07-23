import Foundation
import SuggestionModel
import XCTest

@testable import ActiveDocumentChatContextCollector

final class SwiftASTReaderTests: XCTestCase {
    func editorInformation(code: String) -> EditorInformation {
        .init(
            editorContent: .init(
                content: code,
                lines: code.components(separatedBy: "\n"),
                selections: [],
                cursorPosition: .outOfScope,
                lineAnnotations: []
            ),
            selectedContent: "",
            selectedLines: [],
            documentURL: URL(fileURLWithPath: ""),
            projectURL: URL(fileURLWithPath: ""),
            relativePath: "",
            language: .builtIn(.swift)
        )
    }
    
    func test_selecting_a_line_inside_the_function_the_scope_should_be_the_function() {
        let code = """
        public struct A: B, C {
            @ViewBuilder private func f(_ a: String) -> String {
                let a = 1
                let b = 2
                let c = 3
                let d = 4
                let e = 5
            }
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 4, character: 0),
            end: CursorPosition(line: 4, character: 13)
        )
        let context = SwiftASTReader().contextContainingRange(
            range,
            editorInformation: editorInformation(code: code)
        )
        XCTAssertEqual(
            context.scope,
            .scope(
                signature: "@ViewBuilder private func f(_ a: String) -> String",
                range: .init(start: .init(line: 1, character: 4), end: .init(line: 7, character: 5))
            )
        )
    }
    
    func test_selecting_a_function_inside_a_struct_the_scope_should_be_the_struct() {
        let code = """
        @MainActor
        public struct A: B, C {
            func f() {
                let a = 1
                let b = 2
                let c = 3
                let d = 4
                let e = 5
            }
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 7, character: 5)
        )
        let context = SwiftASTReader().contextContainingRange(
            range,
            editorInformation: editorInformation(code: code)
        )
        XCTAssertEqual(
            context.scope,
            .scope(
                signature: "@MainActor public struct A: B, C",
                range: .init(start: .init(line: 0, character: 0), end: .init(line: 9, character: 1))
            )
        )
    }
    
    func test_selecting_a_variable_inside_a_class_the_scope_should_be_the_class() {
        let code = """
        @MainActor final public class A: P<B, C, D>, K {
            var a = 1
            var b = 2
            var c = 3
            var d = 4
            var e = 5
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 1, character: 9)
        )
        let context = SwiftASTReader().contextContainingRange(
            range,
            editorInformation: editorInformation(code: code)
        )
        XCTAssertEqual(
            context.scope,
            .scope(
                signature: "@MainActor final public class A: P<B, C, D>, K",
                range: .init(start: .init(line: 0, character: 0), end: .init(line: 6, character: 1))
            )
        )
    }
    
    func test_selecting_a_function_inside_a_protocol_the_scope_should_be_the_protocol() {
        let code = """
        public protocol A: Hashable {
            func f()
            func g()
            func h()
            func i()
            func j()
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 1, character: 9)
        )
        let context = SwiftASTReader().contextContainingRange(
            range,
            editorInformation: editorInformation(code: code)
        )
        XCTAssertEqual(
            context.scope,
            .scope(
                signature: "public protocol A: Hashable",
                range: .init(start: .init(line: 0, character: 0), end: .init(line: 6, character: 1))
            )
        )
    }
    
    func test_selecting_a_variable_inside_an_extension_the_scope_should_be_the_extension() {
        let code = """
        private extension A: Equatable {
            var a = 1
            var b = 2
            var c = 3
            var d = 4
            var e = 5
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 1, character: 9)
        )
        let context = SwiftASTReader().contextContainingRange(
            range,
            editorInformation: editorInformation(code: code)
        )
        XCTAssertEqual(
            context.scope,
            .scope(
                signature: "private extension A: Equatable",
                range: .init(start: .init(line: 0, character: 0), end: .init(line: 6, character: 1))
            )
        )
    }
    
    func test_selecting_a_static_function_from_an_actor_the_scope_should_be_the_actor() {
        let code = """
        @gloablActor
        public actor A {
            static func f() {}
            static func g() {}
            static func h() {}
            static func i() {}
            static func j() {}
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 2, character: 9)
        )
        let context = SwiftASTReader().contextContainingRange(
            range,
            editorInformation: editorInformation(code: code)
        )
        XCTAssertEqual(
            context.scope,
            .scope(
                signature: "@gloablActor public actor A",
                range: .init(start: .init(line: 0, character: 0), end: .init(line: 7, character: 1))
            )
        )
    }
    
    func test_selecting_a_case_inside_an_enum_the_scope_should_be_the_enum() {
        let code = """
        @MainActor
        public
        indirect enum A {
            case a
            case b
            case c
            case d
            case e
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 3, character: 0),
            end: CursorPosition(line: 3, character: 9)
        )
        let context = SwiftASTReader().contextContainingRange(
            range,
            editorInformation: editorInformation(code: code)
        )
        XCTAssertEqual(
            context.scope,
            .scope(
                signature: "@MainActor public indirect enum A",
                range: .init(start: .init(line: 0, character: 0), end: .init(line: 8, character: 1))
            )
        )
    }
    
    func test_selecting_a_line_inside_computed_variable_the_scope_should_be_the_variable() {
        let code = """
        struct A {
            @SomeWrapper public private(set) var a: Int {
                let a = 1
                let b = 2
                let c = 3
                let d = 4
                let e = 5
            }
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 2, character: 9)
        )
        let context = SwiftASTReader().contextContainingRange(
            range,
            editorInformation: editorInformation(code: code)
        )
        XCTAssertEqual(
            context.scope,
            .scope(
                signature: "@SomeWrapper public private(set) var a: Int",
                range: .init(start: .init(line: 1, character: 0), end: .init(line: 7, character: 1))
            )
        )
    }
    
    func test_selecting_a_line_in_freestanding_macro_the_scope_should_be_the_macro() {
        
    }
}

