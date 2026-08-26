import Foundation
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static let zoomatScannerPass = UTType(
        exportedAs: "com.aljaroudi.zoomat.scanner-pass",
        conformingTo: .json
    )
}

struct ScannerPass: Codable, Equatable {
    static let currentVersion = 1
    static let maximumFileSize = 10 * 1_024 * 1_024
    static let maximumInvites = 10_000

    let version: Int
    let event: EventSnapshot
    let invites: [InviteSnapshot]

    struct EventSnapshot: Codable, Equatable {
        let id: UUID
        let title: String
        let subtitle: String
        let date: Date
        let expirationDate: Date?
        let address: String?
    }

    struct InviteSnapshot: Codable, Equatable {
        let id: UUID
        let created: Date
        let displayName: String
        let maxCheckIns: Int?
    }

    init(version: Int = currentVersion, event: EventSnapshot, invites: [InviteSnapshot]) {
        self.version = version
        self.event = event
        self.invites = invites
    }

    @MainActor
    init(event: Event) {
        self.init(
            event: EventSnapshot(
                id: event.id,
                title: event.title,
                subtitle: event.subtitle,
                date: event.date,
                expirationDate: event.expirationDate,
                address: event.address
            ),
            invites: event.invites
                .sorted { $0.created < $1.created }
                .map {
                    InviteSnapshot(
                        id: $0.id,
                        created: $0.created,
                        displayName: $0.displayName,
                        maxCheckIns: $0.maxCheckIns
                    )
                }
        )
    }

    func encodedData() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumFileSize else {
            throw ScannerPassError.fileTooLarge
        }
        return data
    }

    static func decode(_ data: Data) throws -> ScannerPass {
        guard data.count <= maximumFileSize else {
            throw ScannerPassError.fileTooLarge
        }

        do {
            let decoder = JSONDecoder()
            let pass = try decoder.decode(ScannerPass.self, from: data)
            try pass.validate()
            return pass
        } catch let error as ScannerPassError {
            throw error
        } catch {
            throw ScannerPassError.invalidFile
        }
    }

    static func read(from url: URL) throws -> ScannerPass {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > maximumFileSize {
            throw ScannerPassError.fileTooLarge
        }

        return try decode(Data(contentsOf: url, options: .mappedIfSafe))
    }

    var suggestedFilename: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let safeTitle = event.title
            .components(separatedBy: allowed.inverted)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = safeTitle.isEmpty ? "Event" : String(safeTitle.prefix(80))
        return "\(filename).zoomatpass"
    }

    func validate() throws {
        guard version == Self.currentVersion else {
            throw ScannerPassError.unsupportedVersion(version)
        }
        guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !invites.isEmpty else {
            throw ScannerPassError.invalidFile
        }
        guard invites.count <= Self.maximumInvites else {
            throw ScannerPassError.tooManyInvites
        }

        var inviteIDs = Set<UUID>()
        for invite in invites {
            guard inviteIDs.insert(invite.id).inserted else {
                throw ScannerPassError.duplicateInvite
            }
            guard !invite.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ScannerPassError.invalidFile
            }
            if let maxCheckIns = invite.maxCheckIns, maxCheckIns < 1 {
                throw ScannerPassError.invalidCheckInLimit
            }
        }
    }
}

enum ScannerPassError: LocalizedError, Equatable {
    case invalidFile
    case unsupportedVersion(Int)
    case fileTooLarge
    case tooManyInvites
    case duplicateInvite
    case invalidCheckInLimit
    case conflictingInvite

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            "This is not a valid Zoomat scanner pass."
        case .unsupportedVersion:
            "This scanner pass requires a newer version of Zoomat."
        case .fileTooLarge:
            "This scanner pass is too large to import."
        case .tooManyInvites:
            "This scanner pass contains too many invitations."
        case .duplicateInvite:
            "This scanner pass contains duplicate invitations."
        case .invalidCheckInLimit:
            "This scanner pass contains an invalid check-in limit."
        case .conflictingInvite:
            "An invitation in this scanner pass belongs to another local event."
        }
    }
}

struct ScannerPassImportResult: Equatable {
    let eventTitle: String
    let invitationCount: Int
}

@MainActor
enum ScannerPassImporter {
    static func importPass(_ pass: ScannerPass, into context: ModelContext) throws -> ScannerPassImportResult {
        try pass.validate()
        let eventID = pass.event.id
        let eventDescriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == eventID })
        let allInvites = try context.fetch(FetchDescriptor<Invite>())
        var invitesByID = Dictionary(uniqueKeysWithValues: allInvites.map { ($0.id, $0) })

        let event: Event
        if let existingEvent = try context.fetch(eventDescriptor).first {
            event = existingEvent
            event.title = pass.event.title
            event.subtitle = pass.event.subtitle
            event.date = pass.event.date
            event.expirationDate = pass.event.expirationDate
            event.address = pass.event.address
            event.updated = .now
        } else {
            event = Event(
                title: pass.event.title,
                subtitle: pass.event.subtitle,
                date: pass.event.date,
                expirationDate: pass.event.expirationDate,
                address: pass.event.address
            )
            event.id = pass.event.id
            context.insert(event)
        }

        do {
            for snapshot in pass.invites {
                if let invite = invitesByID[snapshot.id] {
                    guard invite.event.id == event.id else {
                        throw ScannerPassError.conflictingInvite
                    }
                    invite.created = snapshot.created
                    invite.contactName = snapshot.displayName
                    invite.maxCheckIns = snapshot.maxCheckIns
                } else {
                    let invite = Invite(
                        contact: nil,
                        event: event,
                        contactName: snapshot.displayName,
                        maxCheckIns: snapshot.maxCheckIns
                    )
                    invite.id = snapshot.id
                    invite.created = snapshot.created
                    context.insert(invite)
                    invitesByID[snapshot.id] = invite
                }
            }

            try context.save()
            return ScannerPassImportResult(
                eventTitle: pass.event.title,
                invitationCount: pass.invites.count
            )
        } catch {
            context.rollback()
            throw error
        }
    }
}
