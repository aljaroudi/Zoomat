//
//  EventDetailView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: Event
    @State private var showingEditSheet = false
    @State private var showingAddInvites = false

    var body: some View {
        List {
            detailsSection
            templateSection
            invitesSection
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingAddInvites) {
            AddInvitesView(event: event)
        }
        .navigationDestination(for: Invite.self) { invite in
            InviteDetailView(invite: invite)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Date", value: event.date, format: .dateTime)

            if !event.subtitle.isEmpty {
                LabeledContent("Subtitle", value: event.subtitle)
            }

            if let address = event.address {
                LabeledContent("Location", value: address)
            }
        }
    }

    private var templateSection: some View {
        Section("Invitation Template") {
            if let template = event.template {
                HStack {
                    if let uiImage = UIImage(data: template.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text(template.name)
                            .font(.headline)
                        Text("QR Size: \(template.qrSize, format: .percent.precision(.fractionLength(0)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Button("Select Template") {
                    // TODO: Template selection
                }
            }
        }
    }

    private var invitesSection: some View {
        Section {
            ForEach(event.invites) { invite in
                NavigationLink(value: invite) {
                    InviteRowView(invite: invite)
                }
            }
            .onDelete(perform: deleteInvites)

            Button {
                showingAddInvites = true
            } label: {
                Label("Add Invites", systemImage: "person.badge.plus")
            }
        } header: {
            HStack {
                Text("Invites")
                Spacer()
                Text("\(event.invites.count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deleteInvites(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(event.invites[index])
        }
    }
}

struct InviteRowView: View {
    let invite: Invite

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(invite.contact.name)
                    .font(.headline)

                if let email = invite.contact.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !invite.checkIns.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    let container = previewContainer
    let context = container.mainContext
    let event = Event(
        title: "Sample Wedding",
        subtitle: "Join us for our special day",
        date: Date(),
        address: "Grand Hotel, NYC"
    )
    context.insert(event)

    return NavigationStack {
        EventDetailView(event: event)
    }
    .modelContainer(container)
}
