import Foundation

/// Parse a stream that contains explanation followed by a code block.
public actor ExplanationThenCodeStreamParser {
    enum State {
        case explanation
        case code
        case codeOpening
        case codeClosing
    }

    public enum Fragment: Sendable {
        case explanation(String)
        case code(String)
    }

    struct Buffer {
        var content: String = ""
    }

    var _buffer: Buffer = .init()
    var isAtBeginning = true
    var buffer: String { _buffer.content }
    var state: State = .explanation
    let fullCodeDelimiter = "```"

    public init() {}

    private func appendBuffer(_ character: Character) {
        _buffer.content.append(character)
    }

    private func appendBuffer(_ content: String) {
        _buffer.content += content
    }

    private func resetBuffer() {
        _buffer.content = ""
    }

    func flushBuffer() -> String? {
        if buffer.isEmpty { return nil }
        guard let targetIndex = _buffer.content.lastIndex(where: { $0 != "`" && !$0.isNewline })
        else { return nil }
        let prefix = _buffer.content[...targetIndex]
        if prefix.isEmpty { return nil }
        let nextIndex = _buffer.content.index(
            targetIndex,
            offsetBy: 1,
            limitedBy: _buffer.content.endIndex
        ) ?? _buffer.content.endIndex

        if nextIndex == _buffer.content.endIndex {
            _buffer.content = ""
        } else {
            _buffer.content = String(
                _buffer.content[nextIndex...]
            )
        }

        // If we flushed something, we are no longer at the beginning
        isAtBeginning = false
        return String(prefix)
    }

    func flushBufferIfNeeded(into results: inout [Fragment]) {
        switch state {
        case .explanation:
            if let flushed = flushBuffer() {
                results.append(.explanation(flushed))
            }
        case .code:
            if let flushed = flushBuffer() {
                results.append(.code(flushed))
            }
        case .codeOpening, .codeClosing:
            break
        }
    }

    public func yield(_ fragment: String) -> [Fragment] {
        var results: [Fragment] = []

        func flushBuffer() {
            flushBufferIfNeeded(into: &results)
        }

        for character in fragment {
            switch state {
            case .explanation:
                func forceFlush() {
                    if !buffer.isEmpty {
                        isAtBeginning = false
                        results.append(.explanation(buffer))
                        resetBuffer()
                    }
                }

                switch character {
                case "`":
                    if let last = buffer.last, last == "`" || last.isNewline {
                        flushBuffer()
                        // if we are seeing the pattern of "\n`" or "``"
                        // that mean we may be hitting a code delimiter
                        appendBuffer(character)
                        let shouldOpenCodeBlock: Bool = {
                            guard buffer.hasSuffix(fullCodeDelimiter)
                            else { return false }
                            if isAtBeginning { return true }
                            let temp = String(buffer.dropLast(fullCodeDelimiter.count))
                            if let last = temp.last, last.isNewline {
                                return true
                            }
                            return false
                        }()
                        // if we meet a code delimiter while in explanation state,
                        // it means we are opening a code block
                        if shouldOpenCodeBlock {
                            results.append(.explanation(
                                String(buffer.dropLast(fullCodeDelimiter.count))
                                    .trimmingTrailingCharacters(in: .whitespacesAndNewlines)
                            ))
                            resetBuffer()
                            state = .codeOpening
                        }
                    } else {
                        // Otherwise, the backtick is probably part of the explanation.
                        forceFlush()
                        appendBuffer(character)
                    }
                case let char where char.isNewline:
                    // we keep the trailing new lines in case they are right
                    // ahead of the code block that should be ignored.
                    if let last = buffer.last, last.isNewline {
                        flushBuffer()
                        appendBuffer(character)
                    } else {
                        forceFlush()
                        appendBuffer(character)
                    }
                default:
                    appendBuffer(character)
                }
            case .code:
                func forceFlush() {
                    if !buffer.isEmpty {
                        isAtBeginning = false
                        results.append(.code(buffer))
                        resetBuffer()
                    }
                }

                switch character {
                case "`":
                    if let last = buffer.last, last == "`" || last.isNewline {
                        flushBuffer()
                        // if we are seeing the pattern of "\n`" or "``"
                        // that mean we may be hitting a code delimiter
                        appendBuffer(character)
                        let possibleClosingDelimiter: String? = {
                            guard buffer.hasSuffix(fullCodeDelimiter) else { return nil }
                            let temp = String(buffer.dropLast(fullCodeDelimiter.count))
                            if let last = temp.last, last.isNewline {
                                return "\(last)\(fullCodeDelimiter)"
                            }
                            return nil
                        }()
                        // if we meet a code delimiter while in code state,
                        // // it means we are closing the code block
                        if let possibleClosingDelimiter {
                            results.append(.code(
                                String(buffer.dropLast(possibleClosingDelimiter.count))
                            ))
                            resetBuffer()
                            appendBuffer(possibleClosingDelimiter)
                            state = .codeClosing
                        }
                    } else {
                        // Otherwise, the backtick is probably part of the code.
                        forceFlush()
                        appendBuffer(character)
                    }

                case let char where char.isNewline:
                    if let last = buffer.last, last.isNewline {
                        flushBuffer()
                        appendBuffer(character)
                    } else {
                        forceFlush()
                        appendBuffer(character)
                    }
                default:
                    appendBuffer(character)
                }
            case .codeOpening:
                // skip the code block fence
                if character.isNewline {
                    state = .code
                }
            case .codeClosing:
                appendBuffer(character)
                switch character {
                case "`":
                    let possibleClosingDelimiter: String? = {
                        guard buffer.hasSuffix(fullCodeDelimiter) else { return nil }
                        let temp = String(buffer.dropLast(fullCodeDelimiter.count))
                        if let last = temp.last, last.isNewline {
                            return "\(last)\(fullCodeDelimiter)"
                        }
                        return nil
                    }()
                    // if we meet another code delimiter while in codeClosing state,
                    // it means the previous code delimiter was part of the code
                    if let possibleClosingDelimiter {
                        results.append(.code(
                            String(buffer.dropLast(possibleClosingDelimiter.count))
                        ))
                        resetBuffer()
                        appendBuffer(possibleClosingDelimiter)
                    }
                default:
                    break
                }
            }
        }

        flushBuffer()

        return results
    }

    public func finish() -> [Fragment] {
        guard !buffer.isEmpty else { return [] }

        var results: [Fragment] = []
        switch state {
        case .explanation:
            results.append(
                .explanation(buffer.trimmingTrailingCharacters(in: .whitespacesAndNewlines))
            )
        case .code:
            results.append(.code(buffer))
        case .codeClosing:
            break
        case .codeOpening:
            break
        }
        resetBuffer()

        return results
    }
}

extension String {
    func trimmingTrailingCharacters(in characterSet: CharacterSet) -> String {
        guard !isEmpty else {
            return ""
        }
        var unicodeScalars = unicodeScalars
        while let scalar = unicodeScalars.last {
            if !characterSet.contains(scalar) {
                return String(unicodeScalars)
            }
            unicodeScalars.removeLast()
        }
        return ""
    }
}

