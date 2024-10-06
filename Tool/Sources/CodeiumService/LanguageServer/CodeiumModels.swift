import Foundation
import JSONRPC
import LanguageServerProtocol
import SuggestionBasic

struct CodeiumCompletion: Codable {
    var completionId: String
    var text: String
    var prefix: String?
    var stop: String?
//    var score: Double
//    var tokens: [UInt64]
//    var decodedTokens: [String]
//    var probabilities: [Double]
//    var adjustedProbabilities: [Double]
//    var generatedLength: Int
}

struct CodeiumCompletionItem: Codable {
    var completion: CodeiumCompletion
    var suffix: Suffix?
    var range: Range
    var source: CompletionSource
    var completionParts: [CompletionPart]?
}

struct Suffix: Codable {
    /// Text to insert after the cursor when accepting the completion.
    var text: String
    /// Cursor position delta (as signed offset) from the end of the inserted
    /// completion (including the suffix).
    var deltaCursorOffset: String
}

struct Range: Codable {
    var startOffset: String?
    var endOffset: String?
    var startPosition: DocumentPosition?
    var endPosition: DocumentPosition?
}

enum CompletionSource: String, Codable {
    case unspecified = "COMPLETION_SOURCE_UNSPECIFIED"
    case typingAsSuggested = "COMPLETION_SOURCE_TYPING_AS_SUGGESTED"
    case cache = "COMPLETION_SOURCE_CACHE"
    case network = "COMPLETION_SOURCE_NETWORK"
}

/// Represents a contiguous part of the completion text that is not
/// already in the document.
struct CompletionPart: Codable {
    enum CompletionPartType: String, Codable {
        case unspecified = "COMPLETION_PART_TYPE_UNSPECIFIED"
        /// Single-line completion parts that appear within an existing line of text.
        case inline = "COMPLETION_PART_TYPE_INLINE"
        /// Possibly multi-line completion parts that appear below an existing line of text.
        case block = "COMPLETION_PART_TYPE_BLOCK"
        /// Like COMPLETION_PART_TYPE_INLINE, but overwrites the existing text.
        case inline_mask = "COMPLETION_PART_TYPE_INLINE_MASK"
    }

    var text: String
    /// Offset in the original document where the part starts. For block
    /// parts, this is always the end of the line before the block.
    var offset: String
    var type: CompletionPartType
    /// The section of the original line that came before this part. Only valid for
    /// COMPLETION_PART_TYPE_INLINE.
    var prefix: String?
    /// In the case of COMPLETION_PART_TYPE_BLOCK, represents the line it is below.
    var line: String?
}

struct CodeiumDocument: Codable {
    var absolute_path_migrate_me_to_uri: String
    var text: String
    // Language ID provided by the editor.
    var editor_language: String
    // Language enum standardized across editors.
    var language: CodeiumSupportedLanguage
    // Measured in number of UTF-8 bytes.
    //    var cursor_offset: UInt64?
    // May be present instead of cursor_offset.
    var cursor_position: DocumentCursorPosition?
    // \n or \r\n, if known.
    var line_ending: String = "\n"
}

struct DocumentPosition: Codable {
    /// 0-indexed. Measured in UTF-8 bytes.
    var row: String?
    /// 0-indexed. Measured in UTF-8 bytes.
    var col: String?
}

struct DocumentCursorPosition: Codable {
    /// 0-indexed. Measured in UTF-8 bytes.
    var row: Int
    /// 0-indexed. Measured in UTF-8 bytes.
    var col: Int
}

struct CodeiumEditorOptions: Codable {
    var tab_size: Int
    var insert_spaces: Bool
}

struct Metadata: Codable {
    var ide_name: String
    var ide_version: String
//    var extension_name: String
    var extension_version: String
    var api_key: String

    /// UID identifying a single session for the given user.
    var session_id: String

    /// Used purely in language server to cancel in flight requests.
    /// If request_id is 0, then the request is not cancelable.
    /// This should be a strictly monotonically increasing number
    /// for the duration of a session.
    var request_id: UInt64
}

enum CodeiumState: String, Codable {
    case unspecified = "CODEIUM_STATE_UNSPECIFIED"
    case inactive = "CODEIUM_STATE_INACTIVE"
    case processing = "CODEIUM_STATE_PROCESSING"
    case success = "CODEIUM_STATE_SUCCESS"
    case warning = "CODEIUM_STATE_WARNING"
    case error = "CODEIUM_STATE_ERROR"
}

struct State: Codable {
    var state: CodeiumState
    var message: String
}

