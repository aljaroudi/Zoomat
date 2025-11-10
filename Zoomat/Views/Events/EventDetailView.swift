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
    @State private var showingDuplicateAlert = false

    var body: some View {
        List {
            if event.imageData != nil {
                imageSection
            }
            detailsSection
            invitesSection
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        duplicateEvent()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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

    private var imageSection: some View {
        Section("Invitation Card") {
            if let imageData = event.imageData, let uiImage = UIImage(data: imageData) {
                HStack {
                    Spacer()
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                    Spacer()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Date", value: event.date, format: .dateTime)

            if let expirationDate = event.expirationDate {
                LabeledContent("Expires", value: expirationDate, format: .dateTime)
            }

            if !event.subtitle.isEmpty {
                LabeledContent("Subtitle", value: event.subtitle)
            }

            if let address = event.address {
                LabeledContent("Location", value: address)
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
        try? modelContext.save()
    }

    private func duplicateEvent() {
        let duplicate = event.duplicate()
        modelContext.insert(duplicate)
        try? modelContext.save()
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
