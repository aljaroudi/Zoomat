import XCTest
import SwiftData
import UIKit
@testable import Zoomat

final class ZoomatCleanupTests: XCTestCase {
    @MainActor
    func testEventTimelinePartitionsCurrentAndUpcomingBeforePast() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 26, hour: 12
        )))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        let events = [
            Event(title: "Late tomorrow", date: tomorrow.addingTimeInterval(3_600)),
            Event(title: "Older past", date: now.addingTimeInterval(-7_200), expirationDate: now.addingTimeInterval(-6_000)),
            Event(title: "Soon", date: now.addingTimeInterval(600)),
            Event(title: "Active", date: now.addingTimeInterval(-600), expirationDate: now.addingTimeInterval(600)),
            Event(title: "Recent past", date: now.addingTimeInterval(-3_600), expirationDate: now.addingTimeInterval(-1_800)),
            Event(title: "Early tomorrow", date: tomorrow)
        ]

        let timeline = EventTimeline.partition(events, at: now)

        XCTAssertEqual(timeline.currentAndUpcoming.map(\.title), ["Active", "Soon", "Early tomorrow", "Late tomorrow"])
        XCTAssertEqual(timeline.past.map(\.title), ["Recent past", "Older past"])
        XCTAssertTrue(timeline.currentAndUpcoming[0].isActive(at: now))
    }

    func testContextualDatePolicyUsesRelativeDatesWithinSevenCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ar_SA")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Riyadh"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 26, hour: 23, minute: 30
        )))

        for offset in -7...7 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: now))
            XCTAssertTrue(ContextualDatePolicy.usesRelativeDate(for: date, relativeTo: now, calendar: calendar))
        }

        let eightDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -8, to: now))
        let inEightDays = try XCTUnwrap(calendar.date(byAdding: .day, value: 8, to: now))
        XCTAssertFalse(ContextualDatePolicy.usesRelativeDate(for: eightDaysAgo, relativeTo: now, calendar: calendar))
        XCTAssertFalse(ContextualDatePolicy.usesRelativeDate(for: inEightDays, relativeTo: now, calendar: calendar))
    }

    @MainActor
    func testEventUsesExpirationInsteadOfStartDateForEndedState() {
        let now = Date()
        let running = Event(
            title: "Running",
            date: now.addingTimeInterval(-60),
            expirationDate: now.addingTimeInterval(60)
        )
        let ended = Event(
            title: "Ended",
            date: now.addingTimeInterval(-120),
            expirationDate: now.addingTimeInterval(-60)
        )

        XCTAssertFalse(running.isEnded(at: now))
        XCTAssertTrue(ended.isEnded(at: now))
    }

    @MainActor
    func testEventDraftDefaultsToOneHourDuration() {
        let start = Date()
        var draft = EventDraft()
        draft.date = start

        XCTAssertEqual(draft.duration, 3_600)
        XCTAssertEqual(draft.expirationDate, start.addingTimeInterval(3_600))
        XCTAssertEqual(draft.defaultAdditionalGuestCount, 0)
    }

    @MainActor
    func testDeletingDisplayedInvitationDeletesThatInstance() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "Event", date: .now)
        let first = Invite(contact: nil, event: event, contactName: "First")
        let displayed = Invite(contact: nil, event: event, contactName: "Displayed")
        context.insert(event)
        context.insert(first)
        context.insert(displayed)
        try context.save()

        try displayed.deleteFromStore(in: context)

        let remaining = try context.fetch(FetchDescriptor<Invite>())
        XCTAssertEqual(remaining.map(\.id), [first.id])
    }

    @MainActor
    func testRepeatedScansRecordEveryCheckIn() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let event = Event(title: "Event", date: .now)
        let invite = Invite(contact: nil, event: event)
        context.insert(event)
        context.insert(invite)
        try context.save()

        XCTAssertEqual(try invite.recordCheckIn(in: context), 1)
        XCTAssertEqual(try invite.recordCheckIn(in: context), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CheckIn>()), 2)
    }

    @MainActor
    func testNamedInviteInheritsEventGuestAllowanceUntilOverridden() {
        let contact = Contact(name: "Guest")
        let event = Event(title: "Event", date: .now, defaultAdditionalGuestCount: 2)
        let invite = Invite(contact: contact, event: event)
        let blankInvite = Invite(contact: nil, event: event)

        XCTAssertEqual(invite.effectiveAdditionalGuestCount, 2)
        XCTAssertNil(blankInvite.effectiveAdditionalGuestCount)

        event.defaultAdditionalGuestCount = 3
        XCTAssertEqual(invite.effectiveAdditionalGuestCount, 3)

        invite.additionalGuestCountOverride = 1
        event.defaultAdditionalGuestCount = 4
        XCTAssertEqual(invite.effectiveAdditionalGuestCount, 1)

        invite.additionalGuestCountOverride = nil
        XCTAssertEqual(invite.effectiveAdditionalGuestCount, 4)
    }

    func testQRRectStaysInsideImageBounds() {
        let imageSize = CGSize(width: 1_200, height: 800)

        for point in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
            let rect = qrRect(
                in: imageSize,
                positionX: point.0,
                positionY: point.1,
                sizeFraction: 0.4
            )
            XCTAssertGreaterThanOrEqual(rect.minX, 0)
            XCTAssertGreaterThanOrEqual(rect.minY, 0)
            XCTAssertLessThanOrEqual(rect.maxX, imageSize.width)
            XCTAssertLessThanOrEqual(rect.maxY, imageSize.height)
        }
    }

    func testNormalizedQRPositionClampsToRenderedImageBounds() {
        let imageSize = CGSize(width: 1_200, height: 800)
        let center = normalizedQRPosition(
            in: imageSize,
            at: CGPoint(x: 600, y: 400),
            sizeFraction: 0.4
        )
        let topLeft = normalizedQRPosition(
            in: imageSize,
            at: CGPoint(x: -100, y: -100),
            sizeFraction: 0.4
        )
        let bottomRight = normalizedQRPosition(
            in: imageSize,
            at: CGPoint(x: 1_300, y: 900),
            sizeFraction: 0.4
        )
        let afterSizeIncrease = normalizedQRPosition(
            in: imageSize,
            at: CGPoint(x: bottomRight.x * imageSize.width, y: bottomRight.y * imageSize.height),
            sizeFraction: 0.8
        )

        XCTAssertEqual(center.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(center.y, 0.5, accuracy: 0.0001)
        XCTAssertEqual(topLeft.x, 160.0 / 1_200.0, accuracy: 0.0001)
        XCTAssertEqual(topLeft.y, 0.2, accuracy: 0.0001)
        XCTAssertEqual(bottomRight.x, 1_040.0 / 1_200.0, accuracy: 0.0001)
        XCTAssertEqual(bottomRight.y, 0.8, accuracy: 0.0001)
        XCTAssertEqual(afterSizeIncrease.x, 880.0 / 1_200.0, accuracy: 0.0001)
        XCTAssertEqual(afterSizeIncrease.y, 0.6, accuracy: 0.0001)
    }

    @MainActor
    func testInvitationOutputMatchesSourcePixelDimensions() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let source = UIGraphicsImageRenderer(
            size: CGSize(width: 1_200, height: 800),
            format: format
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 800))
        }

        let event = Event(title: "Event", date: .now, imageData: source.pngData())
        let invite = Invite(contact: nil, event: event)
        let output = try XCTUnwrap(invite.generateInvitationCard()?.cgImage)

        XCTAssertEqual(output.width, 1_200)
        XCTAssertEqual(output.height, 800)
    }

    @MainActor
    func testStoreReopenPreservesLegacyDataAndRelationships() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Legacy.store")
        let schema = Schema(DataSchema.models)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = container.mainContext
            let contact = Contact(name: "Legacy Contact")
            let event = Event(
                title: "Legacy Event",
                date: .now,
                expirationDate: Date.distantPast,
                defaultAdditionalGuestCount: 2
            )
            let invite = Invite(contact: contact, event: event, additionalGuestCountOverride: 1)
            context.insert(contact)
            context.insert(event)
            context.insert(invite)
            _ = try invite.recordCheckIn(in: context)
        }

        let reopened = try ModelContainer(for: schema, configurations: configuration)
        let context = reopened.mainContext
        let events = try context.fetch(FetchDescriptor<Event>())
        let contacts = try context.fetch(FetchDescriptor<Contact>())
        let invites = try context.fetch(FetchDescriptor<Invite>())
        let checkIns = try context.fetch(FetchDescriptor<CheckIn>())

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(invites.count, 1)
        XCTAssertEqual(checkIns.count, 1)
        XCTAssertEqual(events[0].expirationDate, Date.distantPast)
        XCTAssertEqual(events[0].defaultAdditionalGuestCount, 2)
        XCTAssertEqual(invites[0].contact?.name, "Legacy Contact")
        XCTAssertEqual(invites[0].additionalGuestCountOverride, 1)
        XCTAssertEqual(invites[0].effectiveAdditionalGuestCount, 1)
        XCTAssertEqual(checkIns[0].invite.id, invites[0].id)
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(DataSchema.models)
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }
}
