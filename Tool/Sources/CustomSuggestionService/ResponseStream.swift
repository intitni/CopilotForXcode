import Foundation

struct ResponseStream<Chunk>: AsyncSequence {
    func makeAsyncIterator() -> Stream.AsyncIterator {
        stream.makeAsyncIterator()
    }

    typealias Stream = AsyncThrowingStream<Chunk, Error>
    typealias AsyncIterator = Stream.AsyncIterator
    typealias Element = Chunk
    
    struct LineContent {
        let chunk: Chunk?
        let done: Bool
    }

    let stream: Stream

    init(result: URLSession.AsyncBytes, lineExtractor: @escaping (String) throws -> LineContent) {
        stream = AsyncThrowingStream<Chunk, Error> { continuation in
            let task = Task {
                do {
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        let content = try lineExtractor(line)
                        if let chunk = content.chunk {
                            continuation.yield(chunk)
                        }
                        
                        if content.done { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                    result.task.cancel()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                result.task.cancel()
            }
        }
    }
}

