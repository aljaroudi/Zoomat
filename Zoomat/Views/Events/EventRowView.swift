//
//  EventRowView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI

struct EventRowView: View {
    let event: Event
    var now = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                if event.isActive(at: now) {
                    Label("Happening Now", systemImage: "dot.radiowaves.left.and.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.green)
                } else if event.isEnded(at: now) {
                    Label("Ended", systemImage: "clock.badge.xmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !event.subtitle.isEmpty {
                Text(event.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Label {
                HStack(spacing: 4) {
                    if ContextualDatePolicy.usesRelativeDate(for: event.date, relativeTo: now) {
                        Text(event.date, format: .relative(presentation: .named))
                    } else {
                        Text(event.date, format: .dateTime.month(.abbreviated).day().year())
                    }

                    Text(verbatim: "·")
                    Text(event.date, format: .dateTime.hour().minute())
                }
            } icon: {
                Image(systemName: "calendar")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let address = event.address, !address.isEmpty {
                Label(address, systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                Label(invitationCountText, systemImage: "person.2")
                Label(checkInCountText, systemImage: "checkmark.circle")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var checkInCount: Int {
        event.invites.reduce(0) { $0 + $1.checkIns.count }
    }

    private var invitationCountText: LocalizedStringResource {
        if event.invites.count == 1 {
            "\(event.invites.count, format: .number) invitation"
        } else {
            "\(event.invites.count, format: .number) invitations"
        }
    }

    private var checkInCountText: LocalizedStringResource {
        if checkInCount == 1 {
            "\(checkInCount, format: .number) check-in"
        } else {
            "\(checkInCount, format: .number) check-ins"
        }
    }
}

#Preview {
    EventRowView(event: .mock)
}
