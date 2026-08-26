//
//  EventRowView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI

struct EventRowView: View {
    let event: Event
    var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.title)
                Spacer()
                if event.isEnded(at: now) {
                    Text("Ended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Label {
                    Text(event.invites.count, format: .number)
                } icon: {
                    Image(systemName: "person.2")
                }

                Label {
                    let checkIns = event.invites.reduce(0) { $0 + $1.checkIns.count }
                    Text(checkIns, format: .number)
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
