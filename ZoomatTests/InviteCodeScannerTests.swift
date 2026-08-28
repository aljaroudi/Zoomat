import SwiftData
import XCTest
@testable import Zoomat

final class InviteCodeScannerTests: XCTestCase {
    @MainActor
    func testInvalidPayloadsNeverReachPersistence() throws {
        let store = FakeInviteCheckInStore()
        let processor = InviteCodeProcessor(store: store)
        let invalidPayloads = [
            "",
            "   \n",
            "not-a-uuid",
            "دعوة",
            String(repeating: "a", count: InviteCodeProcessor.maximumPayloadLength + 1)
        ]

        for payload in invalidPayloads {
            XCTAssertThrowsError(try processor.process(payload)) { error in
                XCTAssertEqual(error as? InviteCodeProcessingError, .invalidCode)
            }
        }

        XCTAssertEqual(store.recordCallCount, 0)
    }

    @MainActor
    func testWhitespaceWrappedUUIDIsAccepted() throws {
        let invitationID = UUID()
        let expected = ScannerCheckInResult(
            eventID: UUID(),
            invitationName: "Guest",
            eventTitle: "Event",
            additionalGuestCount: 2,
            allowedEntryCount: 3,
            checkInCount: 1
        )
        let store = FakeInviteCheckInStore(result: .success(expected))

        let result = try InviteCodeProcessor(store: store).process(" \n\(invitationID.uuidString)\t")

        XCTAssertEqual(result, expected)
        XCTAssertEqual(store.requestedIDs, [invitationID])
    }

    @MainActor
    func testKnownProcessingErrorsRemainTyped() {
        let store = FakeInviteCheckInStore(result: .failure(InviteCodeProcessingError.invitationNotFound))

        XCTAssertThrowsError(try InviteCodeProcessor(store: store).process(UUID().uuidString)) { error in
            XCTAssertEqual(error as? InviteCodeProcessingError, .invitationNotFound)
        }
    }

    @MainActor
    func testUnexpectedPersistenceFailureBecomesSafeCheckInError() {
        let store = FakeInviteCheckInStore(result: .failure(TestFailure.save))

        XCTAssertThrowsError(try InviteCodeProcessor(store: store).process(UUID().uuidString)) { error in
            XCTAssertEqual(error as? InviteCodeProcessingError, .checkInFailed)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    @MainActor
    func testRealStoreReturnsImmutableSnapshotAndRecordsEachDeliberateScan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = Event(
            title: "Event",
            date: .now,
            defaultAdditionalGuestCount: 2
        )
        let contact = Contact(name: "Guest")
        let invite = Invite(contact: contact, event: event, allowedEntryCount: 2)
        context.insert(contact)
        context.insert(event)
        context.insert(invite)
        try context.save()
        let processor = InviteCodeProcessor(context: context)

        let first = try processor.process(invite.id.uuidString)
        let second = try processor.process(invite.id.uuidString)

        XCTAssertEqual(first.invitationName, "Guest")
        XCTAssertEqual(first.eventTitle, "Event")
        XCTAssertEqual(first.additionalGuestCount, 2)
        XCTAssertEqual(first.allowedEntryCount, 2)
        XCTAssertEqual(first.checkInCount, 1)
        XCTAssertEqual(second.checkInCount, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CheckIn>()), 2)
    }

    @MainActor
    func testRealStoreRejectsEntryAfterLimitWithoutMutation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = Event(title: "Event", date: .now)
        let invite = Invite(contact: nil, event: event, allowedEntryCount: 1)
        context.insert(event)
        context.insert(invite)
        try context.save()
        let processor = InviteCodeProcessor(context: context)

        _ = try processor.process(invite.id.uuidString)

        XCTAssertThrowsError(try processor.process(invite.id.uuidString)) { error in
            XCTAssertEqual(error as? InviteCodeProcessingError, .entryLimitReached(1))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CheckIn>()), 1)

        invite.allowedEntryCount = 2
        try context.save()
        let raisedLimitResult = try processor.process(invite.id.uuidString)
        XCTAssertEqual(raisedLimitResult.checkInCount, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CheckIn>()), 2)
    }

    @MainActor
    func testUnknownInvitationDoesNotMutateStore() throws {
        let container = try makeContainer()
        let context = container.mainContext

        XCTAssertThrowsError(
            try InviteCodeProcessor(context: context).process(UUID().uuidString)
        ) { error in
            XCTAssertEqual(error as? InviteCodeProcessingError, .invitationNotFound)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CheckIn>()), 0)
    }

    @MainActor
    func testDuplicateCallbacksProduceOnlyOneScanUntilExplicitRestart() {
        let scanner = QRScanner()
        var scannedCodes: [String] = []
        scanner.onCodeScanned = { scannedCodes.append($0) }

        let generation = scanner.generation
        scanner.setSuspended(false)
        scanner.handle(.ready, generation: generation)
        scanner.handle(.code("first"), generation: generation)
        scanner.handle(.code("duplicate"), generation: generation)

        XCTAssertEqual(scannedCodes, ["first"])

        scanner.startScanning()
        scanner.handle(.code("second"), generation: generation)
        XCTAssertEqual(scannedCodes, ["first", "second"])
    }

    @MainActor
    func testEventsFromAnotherSessionGenerationAreIgnored() {
        let scanner = QRScanner()
        var scannedCodes: [String] = []
        scanner.onCodeScanned = { scannedCodes.append($0) }

        let currentGeneration = scanner.generation
        let staleGeneration = currentGeneration &+ 1
        scanner.setSuspended(false)

        scanner.handle(.ready, generation: staleGeneration)
        scanner.handle(.code("stale"), generation: staleGeneration)
        scanner.handle(.failed("stale failure"), generation: staleGeneration)
        XCTAssertEqual(scanner.cameraState, .loading)
        XCTAssertTrue(scannedCodes.isEmpty)

        scanner.handle(.ready, generation: currentGeneration)
        XCTAssertEqual(scanner.cameraState, .ready)
        scanner.handle(.code("current"), generation: currentGeneration)
        XCTAssertEqual(scannedCodes, ["current"])
    }

    @MainActor
    func testCameraFailuresBecomeRecoverableStates() {
        let failureCases: [(QRScannerSessionEvent, CameraState)] = [
            (.denied, .denied),
            (.unavailable, .unavailable),
            (.failed("Configuration failed"), .failed("Configuration failed")),
            (.failed("Runtime failure"), .failed("Runtime failure")),
            (.failed("Interrupted"), .failed("Interrupted"))
        ]

        for (event, expectedState) in failureCases {
            let scanner = QRScanner()
            scanner.handle(event, generation: scanner.generation)
            XCTAssertEqual(scanner.cameraState, expectedState)
        }
    }

    @MainActor
    func testPauseAndDeactivationRejectCallbacks() {
        let scanner = QRScanner()
        var scanCount = 0
        scanner.onCodeScanned = { _ in scanCount += 1 }

        let generation = scanner.generation
        scanner.setSuspended(false)
        scanner.handle(.ready, generation: generation)
        scanner.setSuspended(true)
        scanner.handle(.code("paused"), generation: generation)
        scanner.deactivate()
        scanner.handle(.code("late"), generation: generation)

        XCTAssertEqual(scanCount, 0)
    }

    @MainActor
    func testRepeatedDuplicateCallbacksStaySingleShot() {
        let scanner = QRScanner()
        var scanCount = 0
        scanner.onCodeScanned = { _ in scanCount += 1 }
        let generation = scanner.generation
        scanner.setSuspended(false)
        scanner.handle(.ready, generation: generation)

        for index in 0..<1_000 {
            scanner.startScanning()
            scanner.handle(.code("accepted-\(index)"), generation: generation)
            scanner.handle(.code("duplicate-\(index)"), generation: generation)
        }

        XCTAssertEqual(scanCount, 1_000)
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

@MainActor
private final class FakeInviteCheckInStore: InviteCheckInStoring {
    var result: Result<ScannerCheckInResult, Error>
    private(set) var requestedIDs: [UUID] = []
    var recordCallCount: Int { requestedIDs.count }

    init(
        result: Result<ScannerCheckInResult, Error> = .failure(
            InviteCodeProcessingError.invitationNotFound
        )
    ) {
        self.result = result
    }

    func recordCheckIn(for invitationID: UUID) throws -> ScannerCheckInResult {
        requestedIDs.append(invitationID)
        return try result.get()
    }
}

private enum TestFailure: Error {
    case save
}
