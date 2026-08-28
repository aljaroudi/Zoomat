import Foundation
import OSLog
import SwiftData

struct ScannerCheckInResult: Equatable {
    let eventID: UUID
    let invitationName: String
    let eventTitle: String
    let additionalGuestCount: Int?
    let checkInCount: Int
}

enum InviteCodeProcessingError: LocalizedError, Equatable {
    case invalidCode
    case invitationNotFound
    case checkInFailed

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            String(localized: "QR code format is invalid.")
        case .invitationNotFound:
            String(localized: "Invitation not found.")
        case .checkInFailed:
            String(localized: "The check-in could not be saved. Please try again.")
        }
    }

    var title: String {
        switch self {
        case .invalidCode, .invitationNotFound:
            String(localized: "Invalid Code")
        case .checkInFailed:
            String(localized: "Couldn’t Record Check-In")
        }
    }
}

@MainActor
protocol InviteCheckInStoring {
    func recordCheckIn(for invitationID: UUID) throws -> ScannerCheckInResult
}

@MainActor
struct SwiftDataInviteCheckInStore: InviteCheckInStoring {
    let context: ModelContext

    func recordCheckIn(for invitationID: UUID) throws -> ScannerCheckInResult {
        let descriptor = FetchDescriptor<Invite>(
            predicate: #Predicate { $0.id == invitationID }
        )

        let invite: Invite
        do {
            guard let storedInvite = try context.fetch(descriptor).first else {
                throw InviteCodeProcessingError.invitationNotFound
            }
            invite = storedInvite
        } catch let error as InviteCodeProcessingError {
            throw error
        } catch {
            throw InviteCodeProcessingError.checkInFailed
        }

        let eventID = invite.event.id
        let invitationName = invite.displayName
        let eventTitle = invite.event.title
        let additionalGuestCount = invite.effectiveAdditionalGuestCount

        do {
            let count = try invite.recordCheckIn(in: context)
            return ScannerCheckInResult(
                eventID: eventID,
                invitationName: invitationName,
                eventTitle: eventTitle,
                additionalGuestCount: additionalGuestCount,
                checkInCount: count
            )
        } catch {
            throw InviteCodeProcessingError.checkInFailed
        }
    }
}

@MainActor
struct InviteCodeProcessor {
    static let maximumPayloadLength = 64

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Zoomat",
        category: "InviteCodeProcessor"
    )

    private let store: any InviteCheckInStoring

    init(context: ModelContext) {
        store = SwiftDataInviteCheckInStore(context: context)
    }

    init(store: any InviteCheckInStoring) {
        self.store = store
    }

    func process(_ payload: String) throws -> ScannerCheckInResult {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPayload.isEmpty,
              trimmedPayload.utf8.count <= Self.maximumPayloadLength,
              let invitationID = UUID(uuidString: trimmedPayload) else {
            Self.logger.notice("Rejected invalid invite-code payload")
            throw InviteCodeProcessingError.invalidCode
        }

        do {
            return try store.recordCheckIn(for: invitationID)
        } catch let error as InviteCodeProcessingError {
            Self.logger.error("Invite-code processing failed: \(String(describing: error), privacy: .public)")
            throw error
        } catch {
            Self.logger.error("Invite-code processing failed with an unexpected persistence error")
            throw InviteCodeProcessingError.checkInFailed
        }
    }
}
