import Foundation
import Parsing

protocol RawSuggestionPostProcessingStrategy {
    func postProcess(rawSuggestion: String, infillPrefix: String, suffix: [String]) -> String
}

struct DefaultRawSuggestionPostProcessingStrategy: RawSuggestionPostProcessingStrategy {
    let codeWrappingTags: (opening: String, closing: String)?

    func postProcess(rawSuggestion: String, infillPrefix: String, suffix: [String]) -> String {
        var suggestion = extractSuggestion(from: rawSuggestion)
        removePrefix(from: &suggestion, infillPrefix: infillPrefix)
        removeSuffix(from: &suggestion, suffix: suffix)
        return infillPrefix + suggestion
    }

    func extractSuggestion(from response: String) -> String {
        let escapedMarkdownCodeBlock = removeLeadingAndTrailingMarkdownCodeBlockMark(from: response)
        if let tags = codeWrappingTags {
            let escapedTags = extractEnclosingSuggestion(
                from: escapedMarkdownCodeBlock,
                openingTag: tags.opening,
                closingTag: tags.closing
            )
            return escapedTags
        } else {
            return escapedMarkdownCodeBlock
        }
    }

    func removePrefix(from suggestion: inout String, infillPrefix: String) {
        if suggestion.hasPrefix(infillPrefix) {
            suggestion.removeFirst(infillPrefix.count)
        }
    }

    /// Window-mapping the lines in suggestion and the suffix to remove the common suffix.
    func removeSuffix(from suggestion: inout String, suffix: [String]) {
        let suggestionLines = suggestion.breakLines(appendLineBreakToLastLine: true)
        if let last = suggestionLines.last, let lastIndex = suffix.firstIndex(of: last) {
            var i = lastIndex - 1
            var j = suggestionLines.endIndex - 2
            while i >= 0, j >= 0, suffix[i] == suggestionLines[j] {
                i -= 1
                j -= 1
            }
            if i < 0 {
                let endIndex = max(j, 0)
                suggestion = suggestionLines[...endIndex].joined()
            }
        }
    }

    /// Extract suggestions that is enclosed in tags.
    fileprivate func extractEnclosingSuggestion(
        from response: String,
        openingTag: String,
        closingTag: String
    ) -> String {
        guard !openingTag.isEmpty, !closingTag.isEmpty else {
            return response
        }
        
        let case_openingTagAtTheStart_parseEverythingInsideTheTag = Parse(input: Substring.self) {
            openingTag

            OneOf { // parse until tags or the end
                Parse {
                    OneOf {
                        PrefixUpTo(openingTag)
                        PrefixUpTo(closingTag)
                    }
                    Skip {
                        Rest()
                    }
                }

                Rest()
            }
        }

        let case_noTagAtTheStart_parseEverythingBeforeTheTag = Parse(input: Substring.self) {
            OneOf {
                PrefixUpTo(openingTag)
                PrefixUpTo(closingTag)
            }

            Skip {
                Rest()
            }
        }

        let parser = Parse(input: Substring.self) {
            OneOf {
                case_openingTagAtTheStart_parseEverythingInsideTheTag
                case_noTagAtTheStart_parseEverythingBeforeTheTag
                Rest()
            }
        }

        var text = response[...]
        do {
            let suggestion = try parser.parse(&text)
            return String(suggestion)
        } catch {
            return response
        }
    }

    /// If the response starts with markdown code block, we should remove it.
    fileprivate func removeLeadingAndTrailingMarkdownCodeBlockMark(from response: String)
        -> String
    {
        let leadingMarkdownCodeBlockMarkParser = Parse(input: Substring.self) {
            Skip {
                Many {
                    OneOf {
                        " "
                        "\n"
                    }
                }
                "```"
            }
        }
        
        let messagePrefixingMarkdownCodeBlockMarkParser = Parse(input: Substring.self) {
            Skip {
                PrefixThrough(":")
                "\n```"
            }
        }
        
        let removePrefixMarkdownCodeBlockMark = Parse(input: Substring.self) {
            Skip {
                OneOf {
                    leadingMarkdownCodeBlockMarkParser
                    messagePrefixingMarkdownCodeBlockMarkParser
                }
                PrefixThrough("\n")
            }
            OneOf {
                Parse {
                    PrefixUpTo("```")
                    Skip { Rest() }
                }
                Rest()
            }
        }

        do {
            var response = response[...]
            let suggestion = try removePrefixMarkdownCodeBlockMark.parse(&response)
            return String(suggestion)
        } catch {
            return response
        }
    }
}

