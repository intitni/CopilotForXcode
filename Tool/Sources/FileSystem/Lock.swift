import Foundation

public enum ProcessLockError: Error {
    case unableToAquireLock(errno: Int32)
}

extension ProcessLockError: CustomNSError {
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: "\(self)"]
    }
}

/// Provides functionality to acquire a lock on a file via POSIX's flock() method.
/// It can be used for things like serializing concurrent mutations on a shared resource
/// by multiple instances of a process. The `FileLock` is not thread-safe.
public final class FileLock {

    public enum LockType {
        case exclusive
        case shared
    }

    /// File descriptor to the lock file.
  #if os(Windows)
    private var handle: HANDLE?
  #else
    private var fileDescriptor: CInt?
  #endif

    /// Path to the lock file.
    private let lockFile: AbsolutePath

    /// Create an instance of FileLock at the path specified
    ///
    /// Note: The parent directory path should be a valid directory.
    internal init(at lockFile: AbsolutePath) {
        self.lockFile = lockFile
    }

    @available(*, deprecated, message: "use init(at:) instead")
    public convenience init(name: String, cachePath: AbsolutePath) {
        self.init(at: cachePath.appending(component: name + ".lock"))
    }

    /// Try to acquire a lock. This method will block until lock the already aquired by other process.
    ///
    /// Note: This method can throw if underlying POSIX methods fail.
    public func lock(type: LockType = .exclusive, blocking: Bool = true) throws {
      #if os(Windows)
        if handle == nil {
            let h: HANDLE = lockFile.pathString.withCString(encodedAs: UTF16.self, {
                CreateFileW(
                    $0,
                    UInt32(GENERIC_READ) | UInt32(GENERIC_WRITE),
                    UInt32(FILE_SHARE_READ) | UInt32(FILE_SHARE_WRITE),
                    nil,
                    DWORD(OPEN_ALWAYS),
                    DWORD(FILE_ATTRIBUTE_NORMAL),
                    nil
                )
            })
            if h == INVALID_HANDLE_VALUE {
                throw FileSystemError(errno: Int32(GetLastError()), lockFile)
            }
            self.handle = h
        }
        var overlapped = OVERLAPPED()
        overlapped.Offset = 0
        overlapped.OffsetHigh = 0
        overlapped.hEvent = nil
        var dwFlags = Int32(0)
        switch type {
        case .exclusive: dwFlags |= LOCKFILE_EXCLUSIVE_LOCK
        case .shared: break
        }
        if !blocking {
            dwFlags |= LOCKFILE_FAIL_IMMEDIATELY
        }
        if !LockFileEx(handle, DWORD(dwFlags), 0,
                       UInt32.max, UInt32.max, &overlapped) {
            throw ProcessLockError.unableToAquireLock(errno: Int32(GetLastError()))
        }
      #else
        // Open the lock file.
        if fileDescriptor == nil {
            let fd = open(lockFile.pathString, O_WRONLY | O_CREAT | O_CLOEXEC, 0o666)
            if fd == -1 {
                throw FileSystemError(errno: errno, lockFile)
            }
            self.fileDescriptor = fd
        }
        var flags = Int32(0)
        switch type {
        case .exclusive: flags = LOCK_EX
        case .shared: flags = LOCK_SH
        }
        if !blocking {
            flags |= LOCK_NB
        }
        // Aquire lock on the file.
        while true {
            if flock(fileDescriptor!, flags) == 0 {
                break
            }
            // Retry if interrupted.
            if errno == EINTR { continue }
            throw ProcessLockError.unableToAquireLock(errno: errno)
        }
      #endif
    }

    /// Unlock the held lock.
    public func unlock() {
      #if os(Windows)
        var overlapped = OVERLAPPED()
        overlapped.Offset = 0
        overlapped.OffsetHigh = 0
        overlapped.hEvent = nil
        UnlockFileEx(handle, 0, UInt32.max, UInt32.max, &overlapped)
      #else
        guard let fd = fileDescriptor else { return }
        flock(fd, LOCK_UN)
      #endif
    }

    deinit {
      #if os(Windows)
        guard let handle = handle else { return }
        CloseHandle(handle)
      #else
        guard let fd = fileDescriptor else { return }
        close(fd)
      #endif
    }

    /// Execute the given block while holding the lock.
    public func withLock<T>(type: LockType = .exclusive, blocking: Bool = true, _ body: () throws -> T) throws -> T {
        try lock(type: type, blocking: blocking)
        defer { unlock() }
        return try body()
    }

    /// Execute the given block while holding the lock.
    public func withLock<T>(type: LockType = .exclusive, blocking: Bool = true, _ body: () async throws -> T) async throws -> T {
        try lock(type: type, blocking: blocking)
        defer { unlock() }
        return try await body()
    }

    public static func prepareLock(
        fileToLock: AbsolutePath,
        at lockFilesDirectory: AbsolutePath? = nil
    ) throws -> FileLock {
        // unless specified, we use the tempDirectory to store lock files
        let lockFilesDirectory = try lockFilesDirectory ?? localFileSystem.tempDirectory
        if !localFileSystem.exists(lockFilesDirectory) {
            throw FileSystemError(.noEntry, lockFilesDirectory)
        }
        if !localFileSystem.isDirectory(lockFilesDirectory) {
            throw FileSystemError(.notDirectory, lockFilesDirectory)
        }
        // use the parent path to generate unique filename in temp
        var lockFileName = try (resolveSymlinks(fileToLock.parentDirectory)
                                .appending(component: fileToLock.basename))
                                .components.joined(separator: "_")
                                .replacingOccurrences(of: ":", with: "_") + ".lock"
#if os(Windows)
        // NTFS has an ARC limit of 255 codepoints
        var lockFileUTF16 = lockFileName.utf16.suffix(255)
        while String(lockFileUTF16) == nil {
            lockFileUTF16 = lockFileUTF16.dropFirst()
        }
        lockFileName = String(lockFileUTF16) ?? lockFileName
#else
        if lockFileName.hasPrefix(AbsolutePath.root.pathString) {
            lockFileName = String(lockFileName.dropFirst(AbsolutePath.root.pathString.count))
        }
        // back off until it occupies at most `NAME_MAX` UTF-8 bytes but without splitting scalars
        // (we might split clusters but it's not worth the effort to keep them together as long as we get a valid file name)
        var lockFileUTF8 = lockFileName.utf8.suffix(Int(NAME_MAX))
        while String(lockFileUTF8) == nil {
            // in practice this will only be a few iterations
            lockFileUTF8 = lockFileUTF8.dropFirst()
        }
        // we will never end up with nil since we have ASCII characters at the end
        lockFileName = String(lockFileUTF8) ?? lockFileName
#endif
        let lockFilePath = lockFilesDirectory.appending(component: lockFileName)

        return FileLock(at: lockFilePath)
    }

    public static func withLock<T>(
        fileToLock: AbsolutePath,
        lockFilesDirectory: AbsolutePath? = nil,
        type: LockType = .exclusive,
        blocking: Bool = true,
        body: () throws -> T
    ) throws -> T {
        let lock = try Self.prepareLock(fileToLock: fileToLock, at: lockFilesDirectory)
        return try lock.withLock(type: type, blocking: blocking, body)
    }

    public static func withLock<T>(
        fileToLock: AbsolutePath,
        lockFilesDirectory: AbsolutePath? = nil,
        type: LockType = .exclusive,
        blocking: Bool = true,
        body: () async throws -> T
    ) async throws -> T {
        let lock = try Self.prepareLock(fileToLock: fileToLock, at: lockFilesDirectory)
        return try await lock.withLock(type: type, blocking: blocking, body)
    }
}
