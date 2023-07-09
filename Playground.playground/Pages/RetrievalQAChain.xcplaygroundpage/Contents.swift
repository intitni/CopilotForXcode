import LangChain
import OpenAIService
import PlaygroundSupport
import SwiftUI

let memory = ConversationChatGPTMemory(systemPrompt: "")
let chatGPTConfiguration = UserPreferenceChatGPTConfiguration().overriding {
    $0.temperature = 0.2
}

let embeddingConfiguration = UserPreferenceEmbeddingConfiguration().overriding()

struct FakeVectorStore: VectorStore {
    func add(_: [EmbeddedDocument]) async throws {}
    func set(_: [EmbeddedDocument]) async throws {}
    func clear() async throws {}
    func searchWithDistance(embeddings: [Float], count: Int) async throws
        -> [(document: Document, distance: Float)]
    {
        return [
            (
                document: .init(
                    pageContent: """
                    Snoopy is an anthropomorphic beagle[5] in the comic strip Peanuts by Charles M. Schulz. He can also be found in all of the Peanuts films and television specials. Since his debut on October 4, 1950, Snoopy has become one of the most recognizable and iconic characters in the comic strip and is considered more famous than Charlie Brown in some countries. The original drawings of Snoopy were inspired by Spike, one of Schulz's childhood dogs.
                    """,
                    metadata: [:]
                ),
                distance: 0.2
            ),
            (
                document: .init(
                    pageContent: """
                    Snoopy is a loyal, imaginative, and good-natured beagle who is prone to imagining fantasy lives, including being an author, a college student known as "Joe Cool", an attorney, and a World War I flying ace. He is perhaps best known in this last persona, wearing an aviator's helmet and goggles and a scarf while carrying a swagger stick (like a stereotypical British Army officer of World War I and II).
                    """,
                    metadata: [:]
                ),
                distance: 0.2
            ),
            (
                document: .init(
                    pageContent: """
                    Snoopy can be selfish, gluttonous and lazy at times, and occasionally mocks his owner, Charlie Brown. But on the whole, he shows great love, care, and loyalty for his owner (even though he cannot even remember his name and always refers to him as "the round-headed kid"). In the 1990s comic strips, he is obsessed with cookies, particularly the chocolate-chip variety. This, and other instances in which he indulges in large chocolate-based meals and snacks, shows resistance to theobromine unheard of in other dogs.
                    """,
                    metadata: [:]
                ),
                distance: 0.2
            ),
            (
                document: .init(
                    pageContent: """
                    First appearance    October 4, 1950 (comic strip)
                    Last appearance    February 13, 2000 (comic strip)
                    Created by    Charles M. Schulz
                    Voiced by
                    - Bill Melendez (1959–2008; 2015 archival recordings used in Peanuts Motion Comics, Snoopy's Grand Adventure,[1] and The Peanuts Movie)
                    - Bill Hinnant (1966; You're a Good Man, Charlie Brown)[2]
                    - Jim Campbell (1967; You're a Good Man, Charlie Brown)[3]
                    - Robert Towers (1985)
                    - Cam Clarke (1986–1989)
                    - Gerald Paradies (2002)[4]
                    - Andy Beall (2011)
                    - Dylan Jones (2018–present)
                    - Terry McGurrin (2019–present)
                    Aliases
                    - Joe Cool
                    - World Famous World War I Flying Ace
                    - The World's Greatest Writer
                    - The World Famous Attorney
                    - The World Famous Tennis Pro
                    Species    Dog (Beagle)
                    Gender    Male
                    Family
                    - Brothers: Spike, Andy, Olaf, Marbles, Rover
                    - Sisters: Belle, Molly
                    - Owner: Charlie Brown
                    - Sally Brown
                    - Lila (previously)
                    - Clara ("the annoying girl")
                    """,
                    metadata: [:]
                ),
                distance: 0.2
            ),
        ]
    }
}

let qa = RetrievalQAChain(
    vectorStore: FakeVectorStore(),
    embedding: OpenAIEmbedding(configuration: embeddingConfiguration),
    chatModelFactory: { OpenAIChat(configuration: chatGPTConfiguration, stream: false) }
)

let answer = try await qa.run("Who is the creator of Snoopy?")

PlaygroundPage.current.needsIndefiniteExecution = true

