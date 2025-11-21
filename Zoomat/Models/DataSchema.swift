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

        static func loadMock(into context: ModelContext) {
            let count = try? context.fetchCount(FetchDescriptor<Self>())
            guard let count, count == 0 else { return }
            let contact = Self.mock
            context.insert(contact)
            try? context.save()
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

        // Invitation Card Design
        @Attribute(.externalStorage) var imageData: Data?
        var qrPositionX: Double
        var qrPositionY: Double
        var qrSize: Double

        @Relationship(deleteRule: .cascade, inverse: \Invite.event)
        var invites: [Invite]

        init(title: String, subtitle: String = "", date: Date, expirationDate: Date? = nil, address: String? = nil, location: CLLocation? = nil, imageData: Data? = nil, qrPositionX: Double = 0.5, qrPositionY: Double = 0.5, qrSize: Double = 0.3) {
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
            self.imageData = imageData
            self.qrPositionX = qrPositionX
            self.qrPositionY = qrPositionY
            self.qrSize = qrSize
            self.invites = []
        }

        static var mock: Self {
            .init(title: "Test Event", subtitle: "This is my event", date: .now, address: "123 Main St")
        }

        static func loadMock(into context: ModelContext) {
            let count = try? context.fetchCount(FetchDescriptor<Self>())
            guard let count, count == 0 else { return }
            let contact = Self.mock
            context.insert(contact)
            try? context.save()
        }

        func duplicate() -> Event {
            Event(
                title: "\(title) 2",
                subtitle: subtitle,
                date: date,
                expirationDate: expirationDate,
                address: address,
                location: latitude != nil && longitude != nil ? CLLocation(latitude: latitude!, longitude: longitude!) : nil,
                imageData: imageData,
                qrPositionX: qrPositionX,
                qrPositionY: qrPositionY,
                qrSize: qrSize
            )
        }

        var relativeDate: String {
            Calendar.current.startOfDay(for: self.date).formatted(.relative(presentation: .named))
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

        // Check-in limits (nil = unlimited - backwards compatible)
        var maxCheckIns: Int?

        // How
        var qrToken: String { id.uuidString }

        init(contact: Contact?, event: Event, contactName: String? = nil, maxCheckIns: Int? = nil) {
            self.id = .init()
            self.created = .init()
            self.contact = contact
            self.contactName = contactName ?? contact?.name
            self.checkIns = []
            self.event = event
            self.maxCheckIns = maxCheckIns
        }

        // Convenience initializer for backwards compatibility
        convenience init(contact: Contact, event: Event) {
            self.init(contact: contact, event: event, contactName: nil, maxCheckIns: nil)
        }

        static var mock: Self {
            .init(contact: .mock, event: .mock)
        }

        static func loadMock(into context: ModelContext) {
            let count = try? context.fetchCount(FetchDescriptor<Self>())
            guard let count, count == 0 else { return }
            let contact = Self.mock
            context.insert(contact)
            try? context.save()
        }

        var displayName: String {
            contactName ?? "General Invite"
        }

        var hasReachedLimit: Bool {
            guard let maxCheckIns else { return false }
            return checkIns.count >= maxCheckIns
        }
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

        try? save()
    }
}

var previewContainer: ModelContainer {
    let schema = Schema(DataSchema.models)
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    container.mainContext.insertSampleData()
    return container
}
