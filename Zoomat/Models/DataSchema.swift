//
//  DataSchema.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import Foundation
import SwiftData
import CoreLocation
import SwiftUI

enum DataSchema: VersionedSchema {
    static var models: [any PersistentModel.Type] { [
        self.CheckIn.self,
        self.Contact.self,
        self.Event.self,
        self.Invite.self,
    ] }

    static let versionIdentifier = Schema.Version(2, 0, 0)

    @Model
    final class CheckIn: Identifiable {
        @Attribute(.unique) var id: UUID
        var created: Date

        var invite: Invite

        init(invite: Invite) {
            self.id = .init()
            self.created = .init()
            self.invite = invite
        }
    }

    @Model
    final class Contact: Identifiable {
        @Attribute(.unique) var id: UUID
        var created: Date

        var name: String
        var phone: String?
        var email: String?

        var invites: [Invite]

        init(name: String, phone: String? = nil, email: String? = nil) {
            self.id = .init()
            self.created = .init()
            self.name = name
            self.phone = phone
            self.email = email
            self.invites = []
        }

        static var mock: Self {
            .init(name: "John Doe", phone: "+1 123 456 789", email: "john@doe.com")
        }

    }

    @Model
    final class Event: Identifiable {
        @Attribute(.unique) var id: UUID
        var created: Date
        var updated: Date
        // What
        var title: String
        var subtitle: String
        // When
        var date: Date
        var expirationDate: Date?
        // Where
        var address: String?
        var latitude: Double?
        var longitude: Double?

        // Guest allowance for named invitations
        var defaultAdditionalGuestCount: Int = 0

        // Invitation Card Design
        @Attribute(.externalStorage) var imageData: Data?
        var qrPositionX: Double
        var qrPositionY: Double
        var qrSize: Double

        @Relationship(deleteRule: .cascade, inverse: \Invite.event)
        var invites: [Invite]

        init(title: String, subtitle: String = "", date: Date, expirationDate: Date? = nil, address: String? = nil, location: CLLocation? = nil, defaultAdditionalGuestCount: Int = 0, imageData: Data? = nil, qrPositionX: Double = 0.5, qrPositionY: Double = 0.5, qrSize: Double = 0.3) {
            self.id = .init()
            self.created = .init()
            self.updated = .init()
            self.title = title
            self.subtitle = subtitle
            self.date = date
            self.expirationDate = expirationDate
            self.address = address
            self.latitude = location?.coordinate.latitude
            self.longitude = location?.coordinate.longitude
            self.defaultAdditionalGuestCount = defaultAdditionalGuestCount
            self.imageData = imageData
            self.qrPositionX = qrPositionX
            self.qrPositionY = qrPositionY
            self.qrSize = qrSize
            self.invites = []
        }

        static var mock: Self {
            .init(title: "Test Event", subtitle: "This is my event", date: .now, address: "123 Main St")
        }

        func duplicate() -> Event {
            Event(
                title: "\(title) 2",
                subtitle: subtitle,
                date: date,
                expirationDate: expirationDate,
                address: address,
                location: latitude != nil && longitude != nil ? CLLocation(latitude: latitude!, longitude: longitude!) : nil,
                defaultAdditionalGuestCount: defaultAdditionalGuestCount,
                imageData: imageData,
                qrPositionX: qrPositionX,
                qrPositionY: qrPositionY,
                qrSize: qrSize
            )
        }

        var effectiveExpirationDate: Date {
            expirationDate ?? date.addingTimeInterval(3_600)
        }

        func isEnded(at now: Date) -> Bool {
            effectiveExpirationDate < now
        }

        func isActive(at now: Date) -> Bool {
            date <= now && !isEnded(at: now)
        }
    }

    @Model
    final class Invite: Identifiable {
        @Attribute(.unique) var id: UUID
        var created: Date

        // Who (now optional - backwards compatible)
        var contact: Contact?
        var contactName: String? // Store name when no contact is linked

        @Relationship(deleteRule: .cascade, inverse: \CheckIn.invite)
        var checkIns: [CheckIn]

        // What
        var event: Event

        // nil inherits the event default. Ignored for blank invitations.
        var additionalGuestCountOverride: Int?

        // How
        var qrToken: String { id.uuidString }

        init(contact: Contact?, event: Event, contactName: String? = nil, additionalGuestCountOverride: Int? = nil) {
            self.id = .init()
            self.created = .init()
            self.contact = contact
            self.contactName = contactName ?? contact?.name
            self.checkIns = []
            self.event = event
            self.additionalGuestCountOverride = additionalGuestCountOverride
        }

        // Convenience initializer for backwards compatibility
        convenience init(contact: Contact, event: Event) {
            self.init(contact: contact, event: event, contactName: nil, additionalGuestCountOverride: nil)
        }

        static var mock: Self {
            .init(contact: .mock, event: .mock)
        }

        var displayName: String {
            contactName ?? "General Invite"
        }

        var effectiveAdditionalGuestCount: Int? {
            guard contact != nil || additionalGuestCountOverride != nil else { return nil }
            return additionalGuestCountOverride ?? event.defaultAdditionalGuestCount
        }

        var additionalGuestAllowanceText: LocalizedStringResource? {
            guard let effectiveAdditionalGuestCount else { return nil }
            switch effectiveAdditionalGuestCount {
            case 0:
                return "No additional guests"
            case 1:
                return "\(effectiveAdditionalGuestCount, format: .number) additional guest"
            default:
                return "\(effectiveAdditionalGuestCount, format: .number) additional guests"
            }
        }

        var checkInsNewestFirst: [CheckIn] {
            checkIns.sorted { $0.created > $1.created }
        }

        @discardableResult
        func recordCheckIn(in context: ModelContext) throws -> Int {
            let newCount = checkIns.count + 1
            let checkIn = CheckIn(invite: self)
            context.insert(checkIn)

            do {
                try context.save()
                return newCount
            } catch {
                context.rollback()
                throw error
            }
        }

        func deleteFromStore(in context: ModelContext) throws {
            context.delete(self)
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }
}

struct EventTimelinePartition {
    let currentAndUpcoming: [Event]
    let past: [Event]
}

enum EventTimeline {
    static func partition(_ events: [Event], at now: Date) -> EventTimelinePartition {
        EventTimelinePartition(
            currentAndUpcoming: events
                .filter { !$0.isEnded(at: now) }
                .sorted { $0.date < $1.date },
            past: events
                .filter { $0.isEnded(at: now) }
                .sorted { $0.date > $1.date }
        )
    }
}

enum ContextualDatePolicy {
    nonisolated static func usesRelativeDate(
        for date: Date,
        relativeTo now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let start = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: start, to: target).day else {
            return false
        }
        return abs(days) <= 7
    }
}

// MARK: - Type Aliases
typealias CheckIn = DataSchema.CheckIn
typealias Contact = DataSchema.Contact
typealias Event = DataSchema.Event
typealias Invite = DataSchema.Invite

// MARK: - Preview Data
extension ModelContext {
    func insertSampleData() {
        let contact = Contact(name: "John Doe", phone: "+1 123 456 7890", email: "jdoe@acme.com")
        let event = Event(title: "Test Event", subtitle: "This is my event.", date: .now)
        let invite = Invite(contact: contact, event: event)

        insert(contact)
        insert(event)
        insert(invite)

        do {
            try save()
        } catch {
            assertionFailure("Could not save preview data: \(error)")
        }
    }
}

var previewContainer: ModelContainer {
    let schema = Schema(DataSchema.models)
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    container.mainContext.insertSampleData()
    return container
}
