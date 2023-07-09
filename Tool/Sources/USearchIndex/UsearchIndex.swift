import Foundation
import ObjectiveCExceptionHandling
import USearch

public typealias USearchLabel = USearch.USearchLabel
public typealias USearchScalar = USearch.USearchScalar
public typealias USearchMetric = USearch.USearchMetric

/// It provides a simplified interface for `USearch.USearchIndex`.
public actor USearchIndex {
    let index: USearch.USearchIndex

    enum State {
        case initialized
        case loaded
        case viewing
    }

    var state: State = .initialized

    public init(
        metric: USearchMetric,
        dimensions: UInt32,
        connectivity: UInt32,
        quantization: USearchScalar
    ) {
        index = USearch.USearchIndex.make(
            metric: metric,
            dimensions: dimensions,
            connectivity: connectivity,
            quantization: quantization
        )
        state = .initialized
    }

    enum Error: Swift.Error, LocalizedError {
        case indexNotFound
        case alreadyLoaded
        case mutationNotAllowedInViewingIndex
        case invalidVectorSize
        case exception(Swift.Error)
        
        var errorDescription: String? {
            switch self {
            case .indexNotFound:
                return "Can not find the index file."
            case .alreadyLoaded:
                return "Index already loaded."
            case .mutationNotAllowedInViewingIndex:
                return "Mutation not allowed in viewing index."
            case .invalidVectorSize:
                return "Invalid vector size."
            case .exception(let error):
                return error.localizedDescription
            }
        }
    }

    public func load(path: String) throws {
        guard state != .loaded else { throw Error.alreadyLoaded }
        guard FileManager.default.fileExists(atPath: path) else {
            throw Error.indexNotFound
        }
        do {
            try ObjcExceptionHandler.catchException {
                self.index.load(path: path)
            }
        } catch {
            throw Error.exception(error)
        }
        state = .loaded
    }

    public func view(path: String) throws {
        guard state != .loaded else { throw Error.alreadyLoaded }
        guard FileManager.default.fileExists(atPath: path) else {
            throw Error.indexNotFound
        }
        do {
            try ObjcExceptionHandler.catchException {
                self.index.view(path: path)
            }
        } catch {
            throw Error.exception(error)
        }
        state = .viewing
    }

    public func save(path: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        }
        do {
            try ObjcExceptionHandler.catchException {
                self.index.save(path: path)
            }
        } catch {
            throw Error.exception(error)
        }
    }

    public func clear() throws {
        guard state != .viewing else { throw Error.mutationNotAllowedInViewingIndex }
        do {
            try ObjcExceptionHandler.catchException {
                self.index.clear()
            }
        } catch {
            throw Error.exception(error)
        }
    }

    public func add(label: USearchLabel, vector: [Float]) throws {
        guard state != .viewing else { throw Error.mutationNotAllowedInViewingIndex }

        guard vector.count == index.dimensions else {
            throw Error.invalidVectorSize
        }

        if index.count + 1 >= index.capacity {
            index.reserve(UInt32(index.count + 1))
        }

        do {
            try ObjcExceptionHandler.catchException {
                self.index.add(label: label, vector: vector[...])
            }
        } catch {
            throw Error.exception(error)
        }
    }

    public func set(items: [(label: USearchLabel, vector: [Float])]) throws {
        guard state != .viewing else { throw Error.mutationNotAllowedInViewingIndex }

        try clear()
        index.reserve(UInt32(items.count))

        do {
            try ObjcExceptionHandler.catchException {
                for item in items {
                    self.index.add(label: item.label, vector: item.vector[...])
                }
            }
        } catch {
            throw Error.exception(error)
        }
    }

    public func search(
        vector: [Float],
        count: Int
    ) throws -> [(label: USearchLabel, distance: Float)] {
        guard vector.count == index.dimensions else { throw Error.invalidVectorSize }

        do {
            var result: ([USearch.USearchIndex.Label], [Float]) = ([], [])
            try ObjcExceptionHandler.catchException {
                result = self.index.search(vector: vector[...], count: count)
            }
            return zip(result.0, result.1).map { ($0, $1) }
        } catch {
            throw Error.exception(error)
        }
    }
}

