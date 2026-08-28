import XCTest
@testable import Zoomat

final class SharingTests: XCTestCase {
    func testWhatsAppLinkAcceptsInternationalFormats() throws {
        XCTAssertEqual(
            try WhatsAppChatLink.url(for: "+966 50-123-4567").absoluteString,
            "https://wa.me/966501234567"
        )
        XCTAssertEqual(
            try WhatsAppChatLink.url(for: "00966 50 123 4567").absoluteString,
            "https://wa.me/966501234567"
        )
        XCTAssertEqual(
            try WhatsAppChatLink.url(for: "+٩٦٦ ٥٠ ١٢٣ ٤٥٦٧").absoluteString,
            "https://wa.me/966501234567"
        )
    }

    func testWhatsAppLinkRejectsLocalAndMalformedNumbers() {
        for number in ["0501234567", "+12", "+not-a-number"] {
            XCTAssertThrowsError(try WhatsAppChatLink.url(for: number)) { error in
                XCTAssertEqual(error as? WhatsAppChatLinkError, .internationalNumberRequired)
            }
        }
    }
}
