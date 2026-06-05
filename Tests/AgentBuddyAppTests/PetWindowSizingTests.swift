import XCTest
@testable import agentbuddy

@MainActor
final class PetWindowSizingTests: XCTestCase {
    func testWindowSizeReservesSpaceForTallSessionCardAndChatBubble() {
        let size = PetController.windowSize(forPoint: 120, activeCount: 1)

        XCTAssertEqual(size.width, 358)
        XCTAssertGreaterThanOrEqual(size.height, 352)
    }

    func testWindowSizeReservesSpaceForMaximumVisibleSessionCards() {
        let size = PetController.windowSize(forPoint: 120, activeCount: 3)

        XCTAssertEqual(size.width, 358)
        XCTAssertGreaterThanOrEqual(size.height, 606)
    }
}
