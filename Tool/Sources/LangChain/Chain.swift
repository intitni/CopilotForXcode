import Foundation

public protocol Chain {
    associatedtype Input
    associatedtype Output
    func callLogic(_ input: Input, callbackManagers: [CallbackManager]) async throws -> Output
    func parseOutput(_ output: Output) -> String
}

public extension Chain {
    typealias ChainDidStart = CallbackEvents.ChainDidStart<Self>
    typealias ChainDidEnd = CallbackEvents.ChainDidEnd<Self>

    func run(_ input: Input, callbackManagers: [CallbackManager] = []) async throws -> String {
        let output = try await call(input, callbackManagers: callbackManagers)
        return parseOutput(output)
    }

    func call(_ input: Input, callbackManagers: [CallbackManager] = []) async throws -> Output {
        callbackManagers
            .send(CallbackEvents.ChainDidStart(info: (type: Self.self, input: input)))
        defer {
            callbackManagers
                .send(CallbackEvents.ChainDidEnd(info: (type: Self.self, input: input)))
        }
        return try await callLogic(input, callbackManagers: callbackManagers)
    }
}

public extension CallbackEvents {
    struct ChainDidStart<T: Chain>: CallbackEvent {
        public let info: (type: T.Type, input: T.Input)
    }

    struct ChainDidEnd<T: Chain>: CallbackEvent {
        public let info: (type: T.Type, input: T.Input)
    }
}

public struct SimpleChain<Input, Output>: Chain {
    let block: (Input) async throws -> Output
    let parseOutputBlock: (Output) -> String

    public init(
        block: @escaping (Input) async throws -> Output,
        parseOutput: @escaping (Output) -> String = { String(describing: $0) }
    ) {
        self.block = block
        parseOutputBlock = parseOutput
    }

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager]
    ) async throws -> Output {
        return try await block(input)
    }

    public func parseOutput(_ output: Output) -> String {
        return parseOutputBlock(output)
    }
}

public struct ConnectedChain<A: Chain, B: Chain>: Chain where B.Input == A.Output {
    public typealias Input = A.Input
    public typealias Output = (B.Output, A.Output)

    public let chainA: A
    public let chainB: B

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager] = []
    ) async throws -> Output {
        let a = try await chainA.call(input, callbackManagers: callbackManagers)
        let b = try await chainB.call(a, callbackManagers: callbackManagers)
        return (b, a)
    }

    public func parseOutput(_ output: Output) -> String {
        chainB.parseOutput(output.0)
    }
}

public struct PairedChain<A: Chain, B: Chain>: Chain {
    public typealias Input = (A.Input, B.Input)
    public typealias Output = (A.Output, B.Output)

    public let chainA: A
    public let chainB: B

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager] = []
    ) async throws -> Output {
        async let a = chainA.call(input.0, callbackManagers: callbackManagers)
        async let b = chainB.call(input.1, callbackManagers: callbackManagers)
        return try await (a, b)
    }

    public func parseOutput(_ output: (A.Output, B.Output)) -> String {
        [chainA.parseOutput(output.0), chainB.parseOutput(output.1)].joined(separator: "\n")
    }
}

public struct MappedChain<A: Chain, NewOutput>: Chain {
    public typealias Input = A.Input
    public typealias Output = NewOutput

    public let chain: A
    public let map: (A.Output) -> NewOutput

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager]
    ) async throws -> Output {
        let output = try await chain.call(input, callbackManagers: callbackManagers)
        return map(output)
    }

    public func parseOutput(_ output: Output) -> String {
        String(describing: output)
    }
}

public extension Chain {
    func pair<C: Chain>(with another: C) -> PairedChain<Self, C> {
        PairedChain(chainA: self, chainB: another)
    }

    func chain<C: Chain>(to another: C) -> ConnectedChain<Self, C> {
        ConnectedChain(chainA: self, chainB: another)
    }

    func map<NewOutput>(_ map: @escaping (Output) -> NewOutput) -> MappedChain<Self, NewOutput> {
        MappedChain(chain: self, map: map)
    }
}

