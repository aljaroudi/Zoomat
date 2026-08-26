import XCTest
import SwiftData
@testable import Zoomat

final class ScannerPassTests: XCTestCase {
    @MainActor
    func testRoundTripKeepsScanningFieldsAndExcludesPrivateData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = Event(
            title: "Launch Party",
            subtitle: "Doors at seven",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            expirationDate: Date(timeIntervalSince1970: 1_700_003_600),
            address: "Main Hall",
            imageData: Data("private-image".utf8)
        )
        let contact = Contact(name: "Guest", phone: "+966500000000", email: "private@example.com")
        let invite = Invite(contact: contact, event: event, maxCheckIns: 2)
        context.insert(contact)
        context.insert(event)
        context.insert(invite)
        _ = try invite.recordCheckIn(in: context)

        let original = ScannerPass(event: event)
        let data = try original.encodedData()
        let decoded = try ScannerPass.decode(data)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.invites.map(\.id), [invite.id])
        XCTAssertFalse(json.contains("+966500000000"))
        XCTAssertFalse(json.contains("private@example.com"))
        XCTAssertFalse(json.contains("private-image"))
        XCTAssertFalse(json.contains("checkIns"))
    }

    @MainActor
    func testDecoderRejectsUnsupportedMalformedAndOversizedPasses() throws {
        let unsupported = pass(version: 2)
        XCTAssertThrowsError(try ScannerPass.decode(try rawData(for: unsupported))) { error in
            XCTAssertEqual(error as? ScannerPassError, .unsupportedVersion(2))
        }

        XCTAssertThrowsError(try ScannerPass.decode(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? ScannerPassError, .invalidFile)
        }

        let oversized = Data(repeating: 0, count: ScannerPass.maximumFileSize + 1)
        XCTAssertThrowsError(try ScannerPass.decode(oversized)) { error in
            XCTAssertEqual(error as? ScannerPassError, .fileTooLarge)
        }
    }

    @MainActor
    func testDecoderRejectsDuplicateInvitesAndInvalidLimits() throws {
        let valid = pass()
        let duplicate = ScannerPass(
            event: valid.event,
            invites: [valid.invites[0], valid.invites[0]]
        )
        XCTAssertThrowsError(try ScannerPass.decode(try rawData(for: duplicate))) { error in
            XCTAssertEqual(error as? ScannerPassError, .duplicateInvite)
        }

        let invalidLimit = ScannerPass(
            event: valid.event,
            invites: [
                ScannerPass.InviteSnapshot(
                    id: UUID(),
                    created: .now,
                    displayName: "Guest",
                    maxCheckIns: 0
                )
            ]
        )
        XCTAssertThrowsError(try ScannerPass.decode(try rawData(for: invalidLimit))) { error in
            XCTAssertEqual(error as? ScannerPassError, .invalidCheckInLimit)
        }
    }

    @MainActor
    func testImportAndReimportUpdateSnapshotWithoutLosingLocalData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let original = pass()

        XCTAssertEqual(
            try ScannerPassImporter.importPass(original, into: context),
            ScannerPassImportResult(eventTitle: "Event", invitationCount: 1)
        )

        let importedInvite = try XCTUnwrap(context.fetch(FetchDescriptor<Invite>()).first)
        let importedEvent = importedInvite.event
        importedEvent.imageData = Data("local-image".utf8)
        let contact = Contact(name: "Local Contact", phone: "123")
        context.insert(contact)
        importedInvite.contact = contact
        _ = try importedInvite.recordCheckIn(in: context)

        let addedInviteID = UUID()
        let updated = ScannerPass(
            event: ScannerPass.EventSnapshot(
                id: original.event.id,
                title: "Updated Event",
                subtitle: "Updated details",
                date: original.event.date,
                expirationDate: original.event.expirationDate,
                address: "Updated Address"
            ),
            invites: [
                ScannerPass.InviteSnapshot(
                    id: importedInvite.id,
                    created: importedInvite.created,
                    displayName: "Updated Guest",
                    maxCheckIns: 3
                ),
                ScannerPass.InviteSnapshot(
                    id: addedInviteID,
                    created: .now,
                    displayName: "New Guest",
                    maxCheckIns: nil
                )
            ]
        )

        _ = try ScannerPassImporter.importPass(updated, into: context)
        _ = try ScannerPassImporter.importPass(updated, into: context)

        let events = try context.fetch(FetchDescriptor<Event>())
        let invites = try context.fetch(FetchDescriptor<Invite>())
        let refreshedInvite = try XCTUnwrap(invites.first { $0.id == importedInvite.id })
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(invites.count, 2)
        XCTAssertEqual(events[0].title, "Updated Event")
        XCTAssertEqual(events[0].imageData, Data("local-image".utf8))
        XCTAssertEqual(refreshedInvite.contact?.name, "Local Contact")
        XCTAssertEqual(refreshedInvite.contactName, "Updated Guest")
        XCTAssertEqual(refreshedInvite.maxCheckIns, 3)
        XCTAssertEqual(refreshedInvite.checkIns.count, 1)
        XCTAssertTrue(invites.contains { $0.id == addedInviteID })
    }

    @MainActor
    func testConflictingInviteRollsBackWholeImport() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existingEvent = Event(title: "Existing", date: .now)
        let existingInvite = Invite(contact: nil, event: existingEvent, contactName: "Existing Guest")
        context.insert(existingEvent)
        context.insert(existingInvite)
        try context.save()

        let incoming = ScannerPass(
            event: ScannerPass.EventSnapshot(
                id: UUID(),
                title: "Incoming",
                subtitle: "",
                date: .now,
                expirationDate: nil,
                address: nil
            ),
            invites: [
                ScannerPass.InviteSnapshot(
                    id: existingInvite.id,
                    created: .now,
                    displayName: "Collision",
                    maxCheckIns: nil
                )
            ]
        )

        XCTAssertThrowsError(try ScannerPassImporter.importPass(incoming, into: context)) { error in
            XCTAssertEqual(error as? ScannerPassError, .conflictingInvite)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Event>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Invite>()), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Event>()).first?.title, "Existing")
    }

    @MainActor
    func testIndependentPhonesKeepIndependentCheckInCounts() throws {
        let firstContainer = try makeContainer()
        let secondContainer = try makeContainer()
        let scannerPass = pass()

        _ = try ScannerPassImporter.importPass(scannerPass, into: firstContainer.mainContext)
        _ = try ScannerPassImporter.importPass(scannerPass, into: secondContainer.mainContext)

        let firstInvite = try XCTUnwrap(firstContainer.mainContext.fetch(FetchDescriptor<Invite>()).first)
        let secondInvite = try XCTUnwrap(secondContainer.mainContext.fetch(FetchDescriptor<Invite>()).first)
        XCTAssertEqual(try firstInvite.recordCheckIn(in: firstContainer.mainContext), .recorded(count: 1))
        XCTAssertEqual(try secondInvite.recordCheckIn(in: secondContainer.mainContext), .recorded(count: 1))
        XCTAssertEqual(firstInvite.checkIns.count, 1)
        XCTAssertEqual(secondInvite.checkIns.count, 1)
    }

    @MainActor
    private func pass(version: Int = ScannerPass.currentVersion) -> ScannerPass {
        ScannerPass(
            version: version,
            event: ScannerPass.EventSnapshot(
                id: UUID(),
                title: "Event",
                subtitle: "Details",
                date: Date(timeIntervalSince1970: 1_700_000_000),
                expirationDate: Date(timeIntervalSince1970: 1_700_003_600),
                address: "Venue"
            ),
            invites: [
                ScannerPass.InviteSnapshot(
                    id: UUID(),
                    created: Date(timeIntervalSince1970: 1_699_999_000),
                    displayName: "Guest",
                    maxCheckIns: 1
                )
            ]
        )
    }

    @MainActor
    private func rawData(for pass: ScannerPass) throws -> Data {
        try JSONEncoder().encode(pass)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(DataSchema.models)
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }
}
