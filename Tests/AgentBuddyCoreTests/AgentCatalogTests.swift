import XCTest
@testable import AgentBuddyCore

final class AgentCatalogTests: XCTestCase {
    func testHookAgentsSupported() {
        let byKind = Dictionary(uniqueKeysWithValues: AgentCatalog.all.map { ($0.kind, $0) })
        XCTAssertEqual(byKind[.claude]?.isSupported, true)
        XCTAssertEqual(byKind[.codex]?.isSupported, true)
        XCTAssertEqual(byKind[.cursor]?.isSupported, true)
    }

    func testSupportedAgentsAreSurfaced() {
        XCTAssertEqual(Set(AgentCatalog.all.map(\.kind)), [.claude, .codex, .cursor])
    }
}
