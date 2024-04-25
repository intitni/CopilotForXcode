/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Dispatch
import Foundation

#if canImport(Glibc)
@_exported import Glibc
#elseif canImport(Musl)
@_exported import Musl
#elseif os(Windows)
@_exported import CRT
@_exported import WinSDK
#else
@_exported import Darwin.C
#endif

public struct FileSystemError: Error, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Access to the path is denied.
        ///
        /// This is used when an operation cannot be completed because a component of
        /// the path cannot be accessed.
        ///
        /// Used in situations that correspond to the POSIX EACCES error code.
        case invalidAccess

        /// IO Error encoding
        ///
        /// This is used when an operation cannot be completed due to an otherwise
        /// unspecified IO error.
        case ioError(code: Int32)

        /// Is a directory
        ///
        /// This is used when an operation cannot be completed because a component
        /// of the path which was expected to be a file was not.
        ///
        /// Used in situations that correspond to the POSIX EISDIR error code.
        case isDirectory

        /// No such path exists.
        ///
        /// This is used when a path specified does not exist, but it was expected
        /// to.
        ///
        /// Used in situations that correspond to the POSIX ENOENT error code.
        case noEntry

        /// Not a directory
        ///
        /// This is used when an operation cannot be completed because a component
        /// of the path which was expected to be a directory was not.
        ///
        /// Used in situations that correspond to the POSIX ENOTDIR error code.
        case notDirectory

        /// Unsupported operation
        ///
        /// This is used when an operation is not supported by the concrete file
        /// system implementation.
        case unsupported

        /// An unspecific operating system error at a given path.
        case unknownOSError

        /// File or folder already exists at destination.
        ///
        /// This is thrown when copying or moving a file or directory but the destination
        /// path already contains a file or folder.
        case alreadyExistsAtDestination

        /// If an unspecified error occurs when trying to change directories.
        case couldNotChangeDirectory

        /// If a mismatch is detected in byte count when writing to a file.
        case mismatchedByteCount(expected: Int, actual: Int)
    }

    /// The kind of the error being raised.
    public let kind: Kind

    /// The absolute path to the file associated with the error, if available.
    public let path: AbsolutePath?

    public init(_ kind: Kind, _ path: AbsolutePath? = nil) {
        self.kind = kind
        self.path = path
    }
}

extension FileSystemError: CustomNSError {
    public var errorUserInfo: [String: Any] {
        return [NSLocalizedDescriptionKey: "\(self)"]
    }
}

public extension FileSystemError {
    init(errno: Int32, _ path: AbsolutePath) {
        switch errno {
        case EACCES:
            self.init(.invalidAccess, path)
        case EISDIR:
            self.init(.isDirectory, path)
        case ENOENT:
            self.init(.noEntry, path)
        case ENOTDIR:
            self.init(.notDirectory, path)
        case EEXIST:
            self.init(.alreadyExistsAtDestination, path)
        default:
            self.init(.ioError(code: errno), path)
        }
    }
}

/// Defines the file modes.
public enum FileMode: Sendable {
    public enum Option: Int, Sendable {
        case recursive
        case onlyFiles
    }

    case userUnWritable
    case userWritable
    case executable

    public func setMode(_ originalMode: Int16) -> Int16 {
        switch self {
        case .userUnWritable:
            // r-x rwx rwx
            return originalMode & 0o577
        case .userWritable:
            // -w- --- ---
            return originalMode | 0o200
        case .executable:
            // --x --x --x
            return originalMode | 0o111
        }
    }
}

/// Extended file system attributes that can applied to a given file path. See also
/// ``FileSystem/hasAttribute(_:_:)``.
public enum FileSystemAttribute: RawRepresentable {
    #if canImport(Darwin)
    case quarantine
    #endif

    public init?(rawValue: String) {
        switch rawValue {
        #if canImport(Darwin)
        case "com.apple.quarantine":
            self = .quarantine
        #endif
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        #if canImport(Darwin)
        case .quarantine:
            return "com.apple.quarantine"
        #endif
        }
    }
}

// FIXME: Design an asynchronous story?
//
/// Abstracted access to file system operations.
///
/// This protocol is used to allow most of the codebase to interact with a
/// natural filesystem interface, while still allowing clients to transparently
/// substitute a virtual file system or redirect file system operations.
///
/// - Note: All of these APIs are synchronous and can block.
public protocol FileSystem: Sendable {
    /// Check whether the given path exists and is accessible.
    @_disfavoredOverload
    func exists(_ path: AbsolutePath, followSymlink: Bool) -> Bool

    /// Check whether the given path is accessible and a directory.
    func isDirectory(_ path: AbsolutePath) -> Bool

    /// Check whether the given path is accessible and a file.
    func isFile(_ path: AbsolutePath) -> Bool

    /// Check whether the given path is an accessible and executable file.
    func isExecutableFile(_ path: AbsolutePath) -> Bool

    /// Check whether the given path is accessible and is a symbolic link.
    func isSymlink(_ path: AbsolutePath) -> Bool

    /// Check whether the given path is accessible and readable.
    func isReadable(_ path: AbsolutePath) -> Bool

    /// Check whether the given path is accessible and writable.
    func isWritable(_ path: AbsolutePath) -> Bool

    /// Returns any known item replacement directories for a given path. These may be used by
    /// platform-specific
    /// libraries to handle atomic file system operations, such as deletion.
    func itemReplacementDirectories(for path: AbsolutePath) throws -> [AbsolutePath]

    @available(*, deprecated, message: "use `hasAttribute(_:_:)` instead")
    func hasQuarantineAttribute(_ path: AbsolutePath) -> Bool

    /// Returns `true` if a given path has an attribute with a given name applied when file system
    /// supports this
    /// attribute. Returns `false` if such attribute is not applied or it isn't supported.
    func hasAttribute(_ name: FileSystemAttribute, _ path: AbsolutePath) -> Bool

    // FIXME: Actual file system interfaces will allow more efficient access to
    // more data than just the name here.
    //
    /// Get the contents of the given directory, in an undefined order.
    func _getDirectoryContents(
        _ path: AbsolutePath,
        includingPropertiesForKeys: [URLResourceKey]?,
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [AbsolutePath]

    /// Get the current working directory (similar to `getcwd(3)`), which can be
    /// different for different (virtualized) implementations of a FileSystem.
    /// The current working directory can be empty if e.g. the directory became
    /// unavailable while the current process was still working in it.
    /// This follows the POSIX `getcwd(3)` semantics.
    @_disfavoredOverload
    var currentWorkingDirectory: AbsolutePath? { get }

    /// Change the current working directory.
    /// - Parameters:
    ///   - path: The path to the directory to change the current working directory to.
    func changeCurrentWorkingDirectory(to path: AbsolutePath) throws

    /// Get the home directory of current user
    @_disfavoredOverload
    var homeDirectory: AbsolutePath { get throws }

    /// Get the caches directory of current user
    @_disfavoredOverload
    var cachesDirectory: AbsolutePath? { get }

    /// Get the temp directory
    @_disfavoredOverload
    var tempDirectory: AbsolutePath { get throws }

    /// Create the given directory.
    func createDirectory(_ path: AbsolutePath) throws

    /// Create the given directory.
    ///
    /// - recursive: If true, create missing parent directories if possible.
    func createDirectory(_ path: AbsolutePath, recursive: Bool) throws

    /// Creates a symbolic link of the source path at the target path
    /// - Parameters:
    ///   - path: The path at which to create the link.
    ///   - destination: The path to which the link points to.
    ///   - relative: If `relative` is true, the symlink contents will be a relative path, otherwise
    /// it will be absolute.
    func createSymbolicLink(
        _ path: AbsolutePath,
        pointingAt destination: AbsolutePath,
        relative: Bool
    ) throws
    
    func data(_ path: AbsolutePath) throws -> Data
    
    // FIXME: This is obviously not a very efficient or flexible API.
    //
    /// Get the contents of a file.
    ///
    /// - Returns: The file contents as bytes, or nil if missing.
    func readFileContents(_ path: AbsolutePath) throws -> ByteString

    // FIXME: This is obviously not a very efficient or flexible API.
    //
    /// Write the contents of a file.
    func writeFileContents(_ path: AbsolutePath, bytes: ByteString) throws

    // FIXME: This is obviously not a very efficient or flexible API.
    //
    /// Write the contents of a file.
    func writeFileContents(_ path: AbsolutePath, bytes: ByteString, atomically: Bool) throws

    /// Recursively deletes the file system entity at `path`.
    ///
    /// If there is no file system entity at `path`, this function does nothing (in particular, this
    /// is not considered
    /// to be an error).
    func removeFileTree(_ path: AbsolutePath) throws

    /// Change file mode.
    func chmod(_ mode: FileMode, path: AbsolutePath, options: Set<FileMode.Option>) throws

    /// Returns the file info of the given path.
    ///
    /// The method throws if the underlying stat call fails.
    func getFileInfo(_ path: AbsolutePath) throws -> FileInfo

    /// Copy a file or directory.
    func copy(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws

    /// Move a file or directory.
    func move(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws

    /// Execute the given block while holding the lock.
    func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        blocking: Bool,
        _ body: () throws -> T
    ) throws -> T

    /// Execute the given block while holding the lock.
    func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        blocking: Bool,
        _ body: () async throws -> T
    ) async throws -> T
}

/// Convenience implementations (default arguments aren't permitted in protocol
/// methods).
public extension FileSystem {
    /// exists override with default value.
    @_disfavoredOverload
    func exists(_ path: AbsolutePath) -> Bool {
        return exists(path, followSymlink: true)
    }

    /// Default implementation of createDirectory(_:)
    func createDirectory(_ path: AbsolutePath) throws {
        try createDirectory(path, recursive: false)
    }

    // Change file mode.
    func chmod(_ mode: FileMode, path: AbsolutePath) throws {
        try chmod(mode, path: path, options: [])
    }

    // Unless the file system type provides an override for this method, throw
    // if `atomically` is `true`, otherwise fall back to whatever implementation already exists.
    @_disfavoredOverload
    func writeFileContents(_ path: AbsolutePath, bytes: ByteString, atomically: Bool) throws {
        guard !atomically else {
            throw FileSystemError(.unsupported, path)
        }
        try writeFileContents(path, bytes: bytes)
    }

    /// Write to a file from a stream producer.
    @_disfavoredOverload
    func writeFileContents(_ path: AbsolutePath, body: (WritableByteStream) -> Void) throws {
        let contents = BufferedOutputByteStream()
        body(contents)
        try createDirectory(path.parentDirectory, recursive: true)
        try writeFileContents(path, bytes: contents.bytes)
    }

    func getFileInfo(_ path: AbsolutePath) throws -> FileInfo {
        throw FileSystemError(.unsupported, path)
    }

    func withLock<T>(on path: AbsolutePath, _ body: () throws -> T) throws -> T {
        return try withLock(on: path, type: .exclusive, body)
    }

    func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        _ body: () throws -> T
    ) throws -> T {
        return try withLock(on: path, type: type, blocking: true, body)
    }

    func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        blocking: Bool,
        _ body: () throws -> T
    ) throws -> T {
        throw FileSystemError(.unsupported, path)
    }

    func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        _ body: () async throws -> T
    ) async throws -> T {
        return try await withLock(on: path, type: type, blocking: true, body)
    }

    func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        blocking: Bool,
        _ body: () async throws -> T
    ) async throws -> T {
        throw FileSystemError(.unsupported, path)
    }

    func hasQuarantineAttribute(_: AbsolutePath) -> Bool { false }

    func hasAttribute(_: FileSystemAttribute, _: AbsolutePath) -> Bool { false }

    func itemReplacementDirectories(for path: AbsolutePath) throws -> [AbsolutePath] { [] }
}

/// Concrete FileSystem implementation which communicates with the local file system.
private struct LocalFileSystem: FileSystem {
    func isExecutableFile(_ path: AbsolutePath) -> Bool {
        // Our semantics doesn't consider directories.
        return (isFile(path) || isSymlink(path)) && FileManager.default
            .isExecutableFile(atPath: path.pathString)
    }

    func exists(_ path: AbsolutePath, followSymlink: Bool) -> Bool {
        if followSymlink {
            return FileManager.default.fileExists(atPath: path.pathString)
        }
        return (try? FileManager.default.attributesOfItem(atPath: path.pathString)) != nil
    }

    func isDirectory(_ path: AbsolutePath) -> Bool {
        var isDirectory: ObjCBool = false
        let exists: Bool = FileManager.default.fileExists(
            atPath: path.pathString,
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    func isFile(_ path: AbsolutePath) -> Bool {
        guard let path = try? resolveSymlinks(path) else {
            return false
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path.pathString)
        return attrs?[.type] as? FileAttributeType == .typeRegular
    }

    func isSymlink(_ path: AbsolutePath) -> Bool {
        let url = NSURL(fileURLWithPath: path.pathString)
        // We are intentionally using `NSURL.resourceValues(forKeys:)` here since it improves
        // performance on Darwin platforms.
        let result = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
        return (result?[.isSymbolicLinkKey] as? Bool) == true
    }

    func isReadable(_ path: AbsolutePath) -> Bool {
        FileManager.default.isReadableFile(atPath: path.pathString)
    }

    func isWritable(_ path: AbsolutePath) -> Bool {
        FileManager.default.isWritableFile(atPath: path.pathString)
    }

    func getFileInfo(_ path: AbsolutePath) throws -> FileInfo {
        let attrs = try FileManager.default.attributesOfItem(atPath: path.pathString)
        return FileInfo(attrs)
    }

    func hasAttribute(_ name: FileSystemAttribute, _ path: AbsolutePath) -> Bool {
        #if canImport(Darwin)
        let bufLength = getxattr(path.pathString, name.rawValue, nil, 0, 0, 0)

        return bufLength > 0
        #else
        return false
        #endif
    }

    var currentWorkingDirectory: AbsolutePath? {
        let cwdStr = FileManager.default.currentDirectoryPath

        #if _runtime(_ObjC)
        // The ObjC runtime indicates that the underlying Foundation has ObjC
        // interoperability in which case the return type of
        // `fileSystemRepresentation` is different from the Swift implementation
        // of Foundation.
        return try? AbsolutePath(validating: cwdStr)
        #else
        let fsr: UnsafePointer<Int8> = cwdStr.fileSystemRepresentation
        defer { fsr.deallocate() }

        return try? AbsolutePath(String(cString: fsr))
        #endif
    }

    func changeCurrentWorkingDirectory(to path: AbsolutePath) throws {
        guard isDirectory(path) else {
            throw FileSystemError(.notDirectory, path)
        }

        guard FileManager.default.changeCurrentDirectoryPath(path.pathString) else {
            throw FileSystemError(.couldNotChangeDirectory, path)
        }
    }

    var homeDirectory: AbsolutePath {
        get throws {
            return try AbsolutePath(validating: NSHomeDirectory())
        }
    }

    var cachesDirectory: AbsolutePath? {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            .flatMap { try? AbsolutePath(validating: $0.path) }
    }

    var tempDirectory: AbsolutePath {
        get throws {
            return try AbsolutePath(validating: NSTemporaryDirectory())
        }
    }

    func _getDirectoryContents(
        _ path: AbsolutePath,
        includingPropertiesForKeys: [URLResourceKey]?,
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [AbsolutePath] {
        return try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path.pathString),
            includingPropertiesForKeys: includingPropertiesForKeys,
            options: options
        ).compactMap { try? AbsolutePath(validating: $0.path) }
    }

    func createDirectory(_ path: AbsolutePath, recursive: Bool) throws {
        // Don't fail if path is already a directory.
        if isDirectory(path) { return }

        try FileManager.default.createDirectory(
            atPath: path.pathString,
            withIntermediateDirectories: recursive,
            attributes: [:]
        )
    }

    func createSymbolicLink(
        _ path: AbsolutePath,
        pointingAt destination: AbsolutePath,
        relative: Bool
    ) throws {
        let destString = relative ? destination.relative(to: path.parentDirectory)
            .pathString : destination.pathString
        try FileManager.default.createSymbolicLink(
            atPath: path.pathString,
            withDestinationPath: destString
        )
    }
    
    func data(_ path: AbsolutePath) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path.pathString))
    }

    func readFileContents(_ path: AbsolutePath) throws -> ByteString {
        // Open the file.
        guard let fp = fopen(path.pathString, "rb") else {
            throw FileSystemError(errno: errno, path)
        }
        defer { fclose(fp) }

        // Read the data one block at a time.
        let data = BufferedOutputByteStream()
        var tmpBuffer = [UInt8](repeating: 0, count: 1 << 12)
        while true {
            let n = fread(&tmpBuffer, 1, tmpBuffer.count, fp)
            if n < 0 {
                if errno == EINTR { continue }
                throw FileSystemError(.ioError(code: errno), path)
            }
            if n == 0 {
                let errno = ferror(fp)
                if errno != 0 {
                    throw FileSystemError(.ioError(code: errno), path)
                }
                break
            }
            data.send(tmpBuffer[0..<n])
        }

        return data.bytes
    }

    func writeFileContents(_ path: AbsolutePath, bytes: ByteString) throws {
        // Open the file.
        guard let fp = fopen(path.pathString, "wb") else {
            throw FileSystemError(errno: errno, path)
        }
        defer { fclose(fp) }

        // Write the data in one chunk.
        var contents = bytes.contents
        while true {
            let n = fwrite(&contents, 1, contents.count, fp)
            if n < 0 {
                if errno == EINTR { continue }
                throw FileSystemError(.ioError(code: errno), path)
            }
            if n != contents.count {
                throw FileSystemError(
                    .mismatchedByteCount(expected: contents.count, actual: n),
                    path
                )
            }
            break
        }
    }

    func writeFileContents(_ path: AbsolutePath, bytes: ByteString, atomically: Bool) throws {
        // Perform non-atomic writes using the fast path.
        if !atomically {
            return try writeFileContents(path, bytes: bytes)
        }

        try bytes.withData {
            try $0.write(to: URL(fileURLWithPath: path.pathString), options: .atomic)
        }
    }

    func removeFileTree(_ path: AbsolutePath) throws {
        do {
            try FileManager.default.removeItem(atPath: path.pathString)
        } catch let error as NSError {
            // If we failed because the directory doesn't actually exist anymore, ignore the error.
            if !(error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError) {
                throw error
            }
        }
    }

    func chmod(_ mode: FileMode, path: AbsolutePath, options: Set<FileMode.Option>) throws {
        guard exists(path) else { return }
        func setMode(path: String) throws {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            // Skip if only files should be changed.
            if options.contains(.onlyFiles) && attrs[.type] as? FileAttributeType != .typeRegular {
                return
            }

            // Compute the new mode for this file.
            let currentMode = attrs[.posixPermissions] as! Int16
            let newMode = mode.setMode(currentMode)
            guard newMode != currentMode else { return }
            try FileManager.default.setAttributes(
                [.posixPermissions: newMode],
                ofItemAtPath: path
            )
        }

        try setMode(path: path.pathString)
        guard isDirectory(path) else { return }

        guard let traverse = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path.pathString),
            includingPropertiesForKeys: nil
        ) else {
            throw FileSystemError(.noEntry, path)
        }

        if !options.contains(.recursive) {
            traverse.skipDescendants()
        }

        while let path = traverse.nextObject() {
            try setMode(path: (path as! URL).path)
        }
    }

    func copy(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
        guard exists(sourcePath) else { throw FileSystemError(.noEntry, sourcePath) }
        guard !exists(destinationPath)
        else { throw FileSystemError(.alreadyExistsAtDestination, destinationPath) }
        try FileManager.default.copyItem(at: sourcePath.asURL, to: destinationPath.asURL)
    }

    func move(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
        guard exists(sourcePath) else { throw FileSystemError(.noEntry, sourcePath) }
        guard !exists(destinationPath)
        else { throw FileSystemError(.alreadyExistsAtDestination, destinationPath) }
        try FileManager.default.moveItem(at: sourcePath.asURL, to: destinationPath.asURL)
    }

    func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        blocking: Bool,
        _ body: () throws -> T
    ) throws -> T {
        try FileLock.withLock(fileToLock: path, type: type, blocking: blocking, body: body)
    }

    func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        blocking: Bool,
        _ body: () async throws -> T
    ) async throws -> T {
        try await FileLock.withLock(fileToLock: path, type: type, blocking: blocking, body: body)
    }

    func itemReplacementDirectories(for path: AbsolutePath) throws -> [AbsolutePath] {
        let result = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: path.asURL,
            create: false
        )
        let path = try AbsolutePath(validating: result.path)
        // Foundation returns a path that is unique every time, so we return both that path, as well
        // as its parent.
        return [path, path.parentDirectory]
    }
}

/// Concrete FileSystem implementation which simulates an empty disk.
public final class InMemoryFileSystem: FileSystem {
    /// Private internal representation of a file system node.
    /// Not thread-safe.
    private class Node {
        /// The actual node data.
        let contents: NodeContents

        init(_ contents: NodeContents) {
            self.contents = contents
        }

        /// Creates deep copy of the object.
        func copy() -> Node {
            return Node(contents.copy())
        }
    }

    /// Private internal representation the contents of a file system node.
    /// Not thread-safe.
    private enum NodeContents {
        case file(ByteString)
        case directory(DirectoryContents)
        case symlink(String)

        /// Creates deep copy of the object.
        func copy() -> NodeContents {
            switch self {
            case let .file(bytes):
                return .file(bytes)
            case let .directory(contents):
                return .directory(contents.copy())
            case let .symlink(path):
                return .symlink(path)
            }
        }
    }

    /// Private internal representation the contents of a directory.
    /// Not thread-safe.
    private final class DirectoryContents {
        var entries: [String: Node]

        init(entries: [String: Node] = [:]) {
            self.entries = entries
        }

        /// Creates deep copy of the object.
        func copy() -> DirectoryContents {
            let contents = DirectoryContents()
            for (key, node) in entries {
                contents.entries[key] = node.copy()
            }
            return contents
        }
    }

    /// The root node of the filesystem.
    private var root: Node

    /// Protects `root` and everything underneath it.
    /// FIXME: Using a single lock for this is a performance problem, but in
    /// reality, the only practical use for InMemoryFileSystem is for unit
    /// tests.
    private let lock = NSLock()
    /// A map that keeps weak references to all locked files.
    private var lockFiles = [AbsolutePath: WeakReference<DispatchQueue>]()
    /// Used to access lockFiles in a thread safe manner.
    private let lockFilesLock = NSLock()

    /// Exclusive file system lock vended to clients through `withLock()`.
    /// Used to ensure that DispatchQueues are released when they are no longer in use.
    private struct WeakReference<Value: AnyObject> {
        weak var reference: Value?

        init(_ value: Value?) {
            reference = value
        }
    }

    public init() {
        root = Node(.directory(DirectoryContents()))
    }

    /// Creates deep copy of the object.
    public func copy() -> InMemoryFileSystem {
        return lock.withLock {
            let fs = InMemoryFileSystem()
            fs.root = root.copy()
            return fs
        }
    }

    /// Private function to look up the node corresponding to a path.
    /// Not thread-safe.
    private func getNode(_ path: AbsolutePath, followSymlink: Bool = true) throws -> Node? {
        func getNodeInternal(_ path: AbsolutePath) throws -> Node? {
            // If this is the root node, return it.
            if path.isRoot {
                return root
            }

            // Otherwise, get the parent node.
            guard let parent = try getNodeInternal(path.parentDirectory) else {
                return nil
            }

            // If we didn't find a directory, this is an error.
            guard case let .directory(contents) = parent.contents else {
                throw FileSystemError(.notDirectory, path.parentDirectory)
            }

            // Return the directory entry.
            let node = contents.entries[path.basename]

            switch node?.contents {
            case .directory, .file:
                return node
            case let .symlink(destination):
                let destination = try AbsolutePath(
                    validating: destination,
                    relativeTo: path.parentDirectory
                )
                return followSymlink ? try getNodeInternal(destination) : node
            case .none:
                return nil
            }
        }

        // Get the node that corresponds to the path.
        return try getNodeInternal(path)
    }

    // MARK: FileSystem Implementation

    public func exists(_ path: AbsolutePath, followSymlink: Bool) -> Bool {
        return lock.withLock {
            do {
                switch try getNode(path, followSymlink: followSymlink)?.contents {
                case .file, .directory, .symlink: return true
                case .none: return false
                }
            } catch {
                return false
            }
        }
    }

    public func isDirectory(_ path: AbsolutePath) -> Bool {
        return lock.withLock {
            do {
                if case .directory? = try getNode(path)?.contents {
                    return true
                }
                return false
            } catch {
                return false
            }
        }
    }

    public func isFile(_ path: AbsolutePath) -> Bool {
        return lock.withLock {
            do {
                if case .file? = try getNode(path)?.contents {
                    return true
                }
                return false
            } catch {
                return false
            }
        }
    }

    public func isSymlink(_ path: AbsolutePath) -> Bool {
        return lock.withLock {
            do {
                if case .symlink? = try getNode(path, followSymlink: false)?.contents {
                    return true
                }
                return false
            } catch {
                return false
            }
        }
    }

    public func isReadable(_ path: AbsolutePath) -> Bool {
        exists(path)
    }

    public func isWritable(_ path: AbsolutePath) -> Bool {
        exists(path)
    }

    public func isExecutableFile(_: AbsolutePath) -> Bool {
        // FIXME: Always return false until in-memory implementation
        // gets permission semantics.
        return false
    }

    /// Virtualized current working directory.
    public var currentWorkingDirectory: AbsolutePath? {
        return try? AbsolutePath(validating: "/")
    }

    public func changeCurrentWorkingDirectory(to path: AbsolutePath) throws {
        throw FileSystemError(.unsupported, path)
    }

    public var homeDirectory: AbsolutePath {
        get throws {
            // FIXME: Maybe we should allow setting this when creating the fs.
            return try AbsolutePath(validating: "/home/user")
        }
    }

    public var cachesDirectory: AbsolutePath? {
        return try? homeDirectory.appending(component: "caches")
    }

    public var tempDirectory: AbsolutePath {
        get throws {
            return try AbsolutePath(validating: "/tmp")
        }
    }

    public func _getDirectoryContents(
        _ path: AbsolutePath,
        includingPropertiesForKeys: [URLResourceKey]?,
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [AbsolutePath] {
        return try lock.withLock {
            guard let node = try getNode(path) else {
                throw FileSystemError(.noEntry, path)
            }
            guard case let .directory(contents) = node.contents else {
                throw FileSystemError(.notDirectory, path)
            }

            // FIXME: Perhaps we should change the protocol to allow lazy behavior.
            return [String](contents.entries.keys).map {
                path.appending(component: $0)
            }
        }
    }

    /// Not thread-safe.
    private func _createDirectory(_ path: AbsolutePath, recursive: Bool) throws {
        // Ignore if client passes root.
        guard !path.isRoot else {
            return
        }
        // Get the parent directory node.
        let parentPath = path.parentDirectory
        guard let parent = try getNode(parentPath) else {
            // If the parent doesn't exist, and we are recursive, then attempt
            // to create the parent and retry.
            if recursive && path != parentPath {
                // Attempt to create the parent.
                try _createDirectory(parentPath, recursive: true)

                // Re-attempt creation, non-recursively.
                return try _createDirectory(path, recursive: false)
            } else {
                // Otherwise, we failed.
                throw FileSystemError(.noEntry, parentPath)
            }
        }

        // Check that the parent is a directory.
        guard case let .directory(contents) = parent.contents else {
            // The parent isn't a directory, this is an error.
            throw FileSystemError(.notDirectory, parentPath)
        }

        // Check if the node already exists.
        if let node = contents.entries[path.basename] {
            // Verify it is a directory.
            guard case .directory = node.contents else {
                // The path itself isn't a directory, this is an error.
                throw FileSystemError(.notDirectory, path)
            }

            // We are done.
            return
        }

        // Otherwise, the node does not exist, create it.
        contents.entries[path.basename] = Node(.directory(DirectoryContents()))
    }

    public func createDirectory(_ path: AbsolutePath, recursive: Bool) throws {
        return try lock.withLock {
            try _createDirectory(path, recursive: recursive)
        }
    }

    public func createSymbolicLink(
        _ path: AbsolutePath,
        pointingAt destination: AbsolutePath,
        relative: Bool
    ) throws {
        return try lock.withLock {
            // Create directory to destination parent.
            guard let destinationParent = try getNode(path.parentDirectory) else {
                throw FileSystemError(.noEntry, path.parentDirectory)
            }

            // Check that the parent is a directory.
            guard case let .directory(contents) = destinationParent.contents else {
                throw FileSystemError(.notDirectory, path.parentDirectory)
            }

            guard contents.entries[path.basename] == nil else {
                throw FileSystemError(.alreadyExistsAtDestination, path)
            }

            let destination = relative ? destination.relative(to: path.parentDirectory)
                .pathString : destination.pathString

            contents.entries[path.basename] = Node(.symlink(destination))
        }
    }
    
    public func data(_ path: AbsolutePath) throws -> Data {
        return try lock.withLock {
            // Get the node.
            guard let node = try getNode(path) else {
                throw FileSystemError(.noEntry, path)
            }

            // Check that the node is a file.
            guard case let .file(contents) = node.contents else {
                // The path is a directory, this is an error.
                throw FileSystemError(.isDirectory, path)
            }

            // Return the file contents.
            return contents.withData { $0 }
        }
    }

    public func readFileContents(_ path: AbsolutePath) throws -> ByteString {
        return try lock.withLock {
            // Get the node.
            guard let node = try getNode(path) else {
                throw FileSystemError(.noEntry, path)
            }

            // Check that the node is a file.
            guard case let .file(contents) = node.contents else {
                // The path is a directory, this is an error.
                throw FileSystemError(.isDirectory, path)
            }

            // Return the file contents.
            return contents
        }
    }

    public func writeFileContents(_ path: AbsolutePath, bytes: ByteString) throws {
        return try lock.withLock {
            // It is an error if this is the root node.
            let parentPath = path.parentDirectory
            guard path != parentPath else {
                throw FileSystemError(.isDirectory, path)
            }

            // Get the parent node.
            guard let parent = try getNode(parentPath) else {
                throw FileSystemError(.noEntry, parentPath)
            }

            // Check that the parent is a directory.
            guard case let .directory(contents) = parent.contents else {
                // The parent isn't a directory, this is an error.
                throw FileSystemError(.notDirectory, parentPath)
            }

            // Check if the node exists.
            if let node = contents.entries[path.basename] {
                // Verify it is a file.
                guard case .file = node.contents else {
                    // The path is a directory, this is an error.
                    throw FileSystemError(.isDirectory, path)
                }
            }

            // Write the file.
            contents.entries[path.basename] = Node(.file(bytes))
        }
    }

    public func writeFileContents(
        _ path: AbsolutePath,
        bytes: ByteString,
        atomically: Bool
    ) throws {
        // In memory file system's writeFileContents is already atomic, so ignore the parameter here
        // and just call the base implementation.
        try writeFileContents(path, bytes: bytes)
    }

    public func removeFileTree(_ path: AbsolutePath) throws {
        return lock.withLock {
            // Ignore root and get the parent node's content if its a directory.
            guard !path.isRoot,
                  let parent = try? getNode(path.parentDirectory),
                  case let .directory(contents) = parent.contents
            else {
                return
            }
            // Set it to nil to release the contents.
            contents.entries[path.basename] = nil
        }
    }

    public func chmod(_ mode: FileMode, path: AbsolutePath, options: Set<FileMode.Option>) throws {
        // FIXME: We don't have these semantics in InMemoryFileSystem.
    }

    /// Private implementation of core copying function.
    /// Not thread-safe.
    private func _copy(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
        // Get the source node.
        guard let source = try getNode(sourcePath) else {
            throw FileSystemError(.noEntry, sourcePath)
        }

        // Create directory to destination parent.
        guard let destinationParent = try getNode(destinationPath.parentDirectory) else {
            throw FileSystemError(.noEntry, destinationPath.parentDirectory)
        }

        // Check that the parent is a directory.
        guard case let .directory(contents) = destinationParent.contents else {
            throw FileSystemError(.notDirectory, destinationPath.parentDirectory)
        }

        guard contents.entries[destinationPath.basename] == nil else {
            throw FileSystemError(.alreadyExistsAtDestination, destinationPath)
        }

        contents.entries[destinationPath.basename] = source
    }

    public func copy(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
        return try lock.withLock {
            try _copy(from: sourcePath, to: destinationPath)
        }
    }

    public func move(from sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
        return try lock.withLock {
            // Get the source parent node.
            guard let sourceParent = try getNode(sourcePath.parentDirectory) else {
                throw FileSystemError(.noEntry, sourcePath.parentDirectory)
            }

            // Check that the parent is a directory.
            guard case let .directory(contents) = sourceParent.contents else {
                throw FileSystemError(.notDirectory, sourcePath.parentDirectory)
            }

            try _copy(from: sourcePath, to: destinationPath)

            contents.entries[sourcePath.basename] = nil
        }
    }

    public func withLock<T>(
        on path: AbsolutePath,
        type: FileLock.LockType,
        blocking: Bool,
        _ body: () throws -> T
    ) throws -> T {
        if !blocking {
            throw FileSystemError(.unsupported, path)
        }

        let resolvedPath: AbsolutePath = try lock.withLock {
            if case let .symlink(destination) = try getNode(path)?.contents {
                return try AbsolutePath(validating: destination, relativeTo: path.parentDirectory)
            } else {
                return path
            }
        }

        let fileQueue: DispatchQueue = lockFilesLock.withLock {
            if let queueReference = lockFiles[resolvedPath], let queue = queueReference.reference {
                return queue
            } else {
                let queue = DispatchQueue(
                    label: "org.swift.swiftpm.in-memory-file-system.file-queue",
                    attributes: .concurrent
                )
                lockFiles[resolvedPath] = WeakReference(queue)
                return queue
            }
        }

        return try fileQueue.sync(flags: type == .exclusive ? .barrier : .init(), execute: body)
    }
}

// Internal state of `InMemoryFileSystem` is protected with a lock in all of its `public` methods.
#if compiler(>=5.7)
extension InMemoryFileSystem: @unchecked Sendable {}
#else
extension InMemoryFileSystem: UnsafeSendable {}
#endif

private var _localFileSystem: FileSystem = LocalFileSystem()

/// Public access to the local FS proxy.
public var localFileSystem: FileSystem {
    return _localFileSystem
}

public extension FileSystem {
    /// Print the filesystem tree of the given path.
    ///
    /// For debugging only.
    func dumpTree(at path: AbsolutePath = .root) {
        print(".")
        do {
            try recurse(fs: self, path: path)
        } catch {
            print("\(error)")
        }
    }

    /// Write bytes to the path if the given contents are different.
    func writeIfChanged(path: AbsolutePath, bytes: ByteString) throws {
        try createDirectory(path.parentDirectory, recursive: true)

        // Return if the contents are same.
        if isFile(path), try readFileContents(path) == bytes {
            return
        }

        try writeFileContents(path, bytes: bytes)
    }

    func getDirectoryContents(
        at path: AbsolutePath,
        includingPropertiesForKeys: [URLResourceKey]? = nil,
        options: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [AbsolutePath] {
        return try _getDirectoryContents(
            path,
            includingPropertiesForKeys: includingPropertiesForKeys,
            options: options
        )
    }

    /// Helper method to recurse and print the tree.
    private func recurse(fs: FileSystem, path: AbsolutePath, prefix: String = "") throws {
        let contents = (try fs.getDirectoryContents(at: path)).map(\.basename)

        for (idx, entry) in contents.enumerated() {
            let isLast = idx == contents.count - 1
            let line = prefix + (isLast ? "└── " : "├── ") + entry
            print(line)

            let entryPath = path.appending(component: entry)
            if fs.isDirectory(entryPath) {
                let childPrefix = prefix + (isLast ? "    " : "│   ")
                try recurse(fs: fs, path: entryPath, prefix: String(childPrefix))
            }
        }
    }
}

