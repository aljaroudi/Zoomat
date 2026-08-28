import Foundation

enum WhatsAppChatLinkError: LocalizedError, Equatable {
    case internationalNumberRequired

    var errorDescription: String? {
        String(localized: "WhatsApp requires a phone number with an international country code, such as +966.")
    }
}

enum WhatsAppChatLink {
    nonisolated static func url(for rawNumber: String) throws -> URL {
        let trimmed = rawNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let internationalDigits: Substring

        if trimmed.hasPrefix("+") {
            internationalDigits = trimmed.dropFirst()
        } else if trimmed.hasPrefix("00") {
            internationalDigits = trimmed.dropFirst(2)
        } else {
            throw WhatsAppChatLinkError.internationalNumberRequired
        }

        var digits = ""
        for character in internationalDigits {
            if let value = character.wholeNumberValue {
                digits.append(String(value))
            } else if character.isWhitespace || "-().".contains(character) {
                continue
            } else {
                throw WhatsAppChatLinkError.internationalNumberRequired
            }
        }

        guard (4...15).contains(digits.count),
              let url = URL(string: "https://wa.me/\(digits)") else {
            throw WhatsAppChatLinkError.internationalNumberRequired
        }

        return url
    }
}
