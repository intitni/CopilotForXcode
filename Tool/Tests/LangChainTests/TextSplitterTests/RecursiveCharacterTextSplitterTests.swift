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
            .init(
                text: "Madam Speaker, Madam Vice President, our First Lady and Second Gentleman. Members of Congress and",
                startUTF16Offset: 0,
                endUTF16Offset: 97
            ),
            .init(
                text: " of Congress and the Cabinet. Justices of the Supreme Court. My fellow Americans.",
                startUTF16Offset: 81,
                endUTF16Offset: 162
            ),
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
            [
                .init(
                    text: "protocol Animal {\n    var name: String { get }\n    var legs: Int { get }\n    func makeSound()\n}\n",
                    startUTF16Offset: 0,
                    endUTF16Offset: 96
                ),
                .init(
                    text: "\n@MainActor",
                    startUTF16Offset: 96,
                    endUTF16Offset: 107
                ),
                .init(
                    text: "\nprivate class Dog: Animal {\n    var name: String\n    var legs: Int\n    init(name: String, legs:",
                    startUTF16Offset: 107,
                    endUTF16Offset: 203
                ),
                .init(
                    text: " String, legs: Int) {\n        self.name = name\n        self.legs = legs\n    }\n    func makeSound()",
                    startUTF16Offset: 189,
                    endUTF16Offset: 287
                ),
                .init(
                    text: "    func makeSound() {\n        print(\"Woof!\")\n    }\n}\n",
                    startUTF16Offset:267,
                    endUTF16Offset: 321
                ),
                .init(
                    text: "\nfinal class Cat: Animal {\n    var name: String\n    var legs: Int\n    init(name: String, legs: Int)",
                    startUTF16Offset: 321,
                    endUTF16Offset: 420
                ),
                .init(
                    text: " String, legs: Int) {\n        self.name = name\n        self.legs = legs\n    }\n    func makeSound()",
                    startUTF16Offset: 401,
                    endUTF16Offset: 499
                ),
                .init(
                    text: "    func makeSound() {\n        print(\"Meow!\")\n    }\n}",
                    startUTF16Offset: 479,
                    endUTF16Offset: 532
                ),
            ]
        )
    }
}

