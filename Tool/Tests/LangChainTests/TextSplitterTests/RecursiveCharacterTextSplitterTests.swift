import XCTest

@testable import LangChain

final class RecursiveCharacterTextSplitterTests: XCTestCase {
    func test_split_text() async throws {
        let splitter = RecursiveCharacterTextSplitter(
            separators: ["\n\n", "\n", " ", ""],
            chunkSize: 100,
            chunkOverlap: 20
        )

        let text = """
        Madam Speaker, Madam Vice President, our First Lady and Second Gentleman. Members of Congress and the Cabinet. Justices of the Supreme Court. My fellow Americans.
        """

        let result = try await splitter.split(text: text)

        XCTAssertEqual(result, [
            "Madam Speaker, Madam Vice President, our First Lady and Second Gentleman. Members of Congress and",
            "of Congress and the Cabinet. Justices of the Supreme Court. My fellow Americans.",
        ])
    }

    func test_split_swift_code() async throws {
        let splitter = RecursiveCharacterTextSplitter(
            separatorSet: .swift,
            chunkSize: 100,
            chunkOverlap: 20
        )

        let code = """
        protocol Animal {
            var name: String { get }
            var legs: Int { get }
            func makeSound()
        }

        @MainActor
        private class Dog: Animal {
            var name: String
            var legs: Int
            init(name: String, legs: Int) {
                self.name = name
                self.legs = legs
            }
            func makeSound() {
                print("Woof!")
            }
        }

        final class Cat: Animal {
            var name: String
            var legs: Int
            init(name: String, legs: Int) {
                self.name = name
                self.legs = legs
            }
            func makeSound() {
                print("Meow!")
            }
        }
        """

        let result = try await splitter.split(text: code)
        XCTAssertEqual(
            result,
            ["protocol Animal {\n    var name: String { get }\n    var legs: Int { get }\n    func makeSound()\n}\n",
             "\n@MainActor",
             "\nprivate class Dog: Animal {\n    var name: String\n    var legs: Int\n    init(name: String, legs:",
             "String, legs: Int) {\n        self.name = name\n        self.legs = legs\n    }\n    func makeSound()",
             "func makeSound() {\n        print(\"Woof!\")\n    }\n}\n",
             "\nfinal class Cat: Animal {\n    var name: String\n    var legs: Int\n    init(name: String, legs: Int)",
             "String, legs: Int) {\n        self.name = name\n        self.legs = legs\n    }\n    func makeSound()",
             "func makeSound() {\n        print(\"Meow!\")\n    }\n}"]
        )
    }
}

