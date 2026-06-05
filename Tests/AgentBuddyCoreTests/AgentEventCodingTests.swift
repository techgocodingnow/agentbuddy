import XCTest
@testable import AgentBuddyCore

final class AgentEventCodingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100)

    func testRoundTripsUsage() throws {
        let event = AgentEvent(
            sessionId: "s", agentKind: .claude, eventName: "Stop",
            project: "/p", message: "done", timestamp: now,
            usage: ContextUsage(usedTokens: 82_720, limitTokens: 200_000)
        )
        let data = try EventCoding.encoder.encode(event)
        let decoded = try EventCoding.decoder.decode(AgentEvent.self, from: data)
        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.usage?.percentLeft, 59)
    }

    func testDecodesLegacyEventWithoutUsage() throws {
        // Older daemons/queued events have no "usage" key; it must decode as nil.
        let json = #"{"sessionId":"s","agentKind":"claude","eventName":"Stop","timestamp":100}"#
        let decoded = try EventCoding.decoder.decode(AgentEvent.self, from: Data(json.utf8))
        XCTAssertNil(decoded.usage)
        XCTAssertEqual(decoded.sessionId, "s")
    }
}
