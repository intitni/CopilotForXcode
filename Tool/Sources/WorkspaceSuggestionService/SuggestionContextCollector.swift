import Foundation
import SuggestionBasic
import SuggestionProvider
import Workspace

/// Builds the reference snippets that go into a suggestion request.
///
/// The custom-model service already advertises `acceptsRelevantCodeSnippets`, but nothing ever
/// filled that array, so the model only ever saw the file being edited. This collects two things
/// that the products people compare us to both rely on:
///
/// - Neighboring tabs: the most similar windows of the other opened files, scored with Jaccard
///   similarity the way GitHub Copilot does it. No index, no embeddings, no extra round trip.
/// - Recent edits: what the user changed in the last few rounds, which is the signal Cursor Tab
///   leans on to guess where the current edit is going.
@WorkspaceActor
final class SuggestionContextCollector {
    static let shared = SuggestionContextCollector()

    /// Reading and tokenizing every opened file on each keystroke would be wasteful, so a file is
    /// only re-read when its size or modification date changes.
    private struct CachedSource {
        var modificationDate: Date
        var size: Int
        var source: IndexedSnippetSource
    }

    private var sourceCache = [URL: CachedSource]()
    private var lastSeenLines = [URL: [String]]()
    private var recentEdits = [RecentEditHunk]()

    /// Files larger than this are generated code or data, not useful references.
    private let maximumFileSize = 256 * 1024
    private let maximumCandidateFiles = 12
    private let maximumRecentEdits = 3
    private let retrievalOptions = NeighboringSnippetRetriever.Options()

    func collectSnippets(
        for fileURL: URL,
        lines: [String],
        cursorPosition: CursorPosition,
        workspace: Workspace
    ) -> [RelevantCodeSnippet] {
        recordEdit(for: fileURL, lines: lines, projectRootURL: workspace.projectRootURL)

        let commentPrefix = CodeCommentStyle.prefix(forFileExtension: fileURL.pathExtension)
        var snippets = [RelevantCodeSnippet]()

        if let editSnippet = RecentEditSnippetBuilder.snippet(
            from: recentEdits,
            commentPrefix: commentPrefix,
            // Recent edits outrank retrieved code: they are about the change in progress.
            priority: retrievalOptions.maxSnippets + 1
        ) {
            snippets.append(editSnippet)
        }

        let query = NeighboringSnippetRetriever.queryTokens(
            currentLines: lines,
            cursorPosition: cursorPosition,
            options: retrievalOptions
        )
        snippets.append(contentsOf: NeighboringSnippetRetriever.retrieve(
            query: query,
            sources: indexedSources(excluding: fileURL, workspace: workspace),
            commentPrefix: commentPrefix,
            options: retrievalOptions
        ))

        return snippets
    }

    private func recordEdit(for fileURL: URL, lines: [String], projectRootURL: URL) {
        defer { lastSeenLines[fileURL] = lines }
        guard let previous = lastSeenLines[fileURL] else { return }
        guard let hunk = RecentEditDiff.hunk(
            filePath: relativePath(of: fileURL, in: projectRootURL),
            before: previous,
            after: lines
        ) else { return }

        // The trailing edit is usually the same one growing character by character; replacing it
        // keeps the history at "the last few distinct places the user touched".
        if let last = recentEdits.last, last.startLine == hunk.startLine,
           last.filePath == hunk.filePath
        {
            recentEdits[recentEdits.endIndex - 1] = hunk
        } else {
            recentEdits.append(hunk)
        }
        if recentEdits.count > maximumRecentEdits {
            recentEdits.removeFirst(recentEdits.count - maximumRecentEdits)
        }
    }

    private func indexedSources(
        excluding fileURL: URL,
        workspace: Workspace
    ) -> [IndexedSnippetSource] {
        // Filespaces only cover what this service process has seen, which is nothing right after
        // a restart. The persisted list of opened files fills that gap; it has no recency order,
        // so it goes last and only tops the list up.
        let recentlyEdited = workspace.filespaces.values
            .filter { $0.fileURL != fileURL && $0.isTextReadable }
            .sorted { $0.lastUpdateTime > $1.lastUpdateTime }
            .map(\.fileURL)
        let previouslyOpened = workspace.openedFileRecoverableStorage.openedFiles
            .filter { $0 != fileURL }

        var candidates = [URL]()
        var seen = Set<URL>()
        for url in recentlyEdited + previouslyOpened where seen.insert(url).inserted {
            candidates.append(url)
            if candidates.count >= maximumCandidateFiles { break }
        }

        pruneCaches(keeping: seen.union([fileURL]))

        return candidates.compactMap {
            indexedSource(for: $0, projectRootURL: workspace.projectRootURL)
        }
    }

    private func indexedSource(for fileURL: URL, projectRootURL: URL) -> IndexedSnippetSource? {
        guard let attributes = try? FileManager.default
            .attributesOfItem(atPath: fileURL.path),
            let size = attributes[.size] as? Int,
            size > 0, size <= maximumFileSize
        else { return nil }
        let modificationDate = attributes[.modificationDate] as? Date ?? .distantPast

        if let cached = sourceCache[fileURL],
           cached.size == size,
           cached.modificationDate == modificationDate
        {
            return cached.source
        }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: "\n").map { line -> String in
            line.hasSuffix("\r") ? String(line.dropLast()) : line
        }
        let source = NeighboringSnippetRetriever.index(
            filePath: relativePath(of: fileURL, in: projectRootURL),
            lines: lines,
            options: retrievalOptions
        )
        sourceCache[fileURL] = .init(
            modificationDate: modificationDate,
            size: size,
            source: source
        )
        return source
    }

    /// Keeps both caches bounded by the files that can still be picked as candidates, so a
    /// closed file's content and edit history are dropped without a separate eviction policy.
    private func pruneCaches(keeping fileURLs: Set<URL>) {
        sourceCache = sourceCache.filter { fileURLs.contains($0.key) }
        lastSeenLines = lastSeenLines.filter { fileURLs.contains($0.key) }
    }

    private func relativePath(of fileURL: URL, in projectRootURL: URL) -> String {
        let path = fileURL.path
        let root = projectRootURL.path
        guard root != "/", path.hasPrefix(root) else { return fileURL.lastPathComponent }
        return String(path.dropFirst(root.count))
    }
}
