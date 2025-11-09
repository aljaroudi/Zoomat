//
//  EventRowView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI

struct EventRowView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading) {
            Text(event.title)
                .font(.headline)

            Text(event.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label(event.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")

                if let address = event.address {
                    Label(address, systemImage: "location")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Label {
                    Text(event.invites.count, format: .number)
                } icon: {
                    Image(systemName: "person.2")
                }

                Label {
                    let checkedIn = event.invites.filter { !$0.checkIns.isEmpty }.count
                    Text(checkedIn, format: .number)
                } icon: {
                    Image(systemName: "checkmark.circle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    EventRowView(event: .mock)
}
