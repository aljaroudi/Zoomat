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
    @State private var showingCalendarEditor = false
    @State private var showingExportInvitations = false
    @State private var inviteToDelete: Invite?
    @State private var errorMessage: String?

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
                        showingExportInvitations = true
                    } label: {
                        Label("Export All Invitations", systemImage: "square.and.arrow.up.on.square")
                    }
                    .disabled(event.invites.isEmpty)

                    Button {
                        showingCalendarEditor = true
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus")
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
        .sheet(isPresented: $showingExportInvitations) {
            ExportInvitationsView(event: event)
        }
        .sheet(isPresented: $showingCalendarEditor) {
            EventEditViewController(isPresented: $showingCalendarEditor, event: event)
        }
        .navigationDestination(for: Invite.self) { invite in
            InviteDetailView(invite: invite)
        }
        .confirmationDialog(
            "Delete this invitation and all its check-ins?",
            isPresented: Binding(
                get: { inviteToDelete != nil },
                set: { if !$0 { inviteToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Invitation", role: .destructive, action: deleteInvite)
            Button("Cancel", role: .cancel) { inviteToDelete = nil }
        }
        .saveErrorAlert(message: $errorMessage)
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
            LabeledContent(
                "Duration",
                value: Duration.seconds(event.effectiveExpirationDate.timeIntervalSince(event.date)).formatted(
                    .units(allowed: [.hours, .minutes], width: .wide)
                )
            )
            LabeledContent("Expires", value: event.effectiveExpirationDate, format: .dateTime)

            if event.isEnded(at: .now) {
                LabeledContent("Status") {
                    Text("Ended")
                        .foregroundStyle(.secondary)
                }
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
            ForEach(event.invites.sorted { $0.created < $1.created }) { invite in
                NavigationLink(value: invite) {
                    InviteRowView(invite: invite)
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        inviteToDelete = invite
                    }
                }
            }

            Button {
                showingAddInvites = true
            } label: {
                Label("Add Invites", systemImage: "person.badge.plus")
            }
        } header: {
            HStack {
                Text("Invitations")
                Spacer()
                Text(event.invites.count, format: .number)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deleteInvite() {
        guard let inviteToDelete else { return }

        do {
            try inviteToDelete.deleteFromStore(in: modelContext)
            self.inviteToDelete = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func duplicateEvent() {
        let duplicate = event.duplicate()
        modelContext.insert(duplicate)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct InviteRowView: View {
    let invite: Invite

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.displayName)
                    .font(.headline)

                if let contact = invite.contact {
                    if let contactInfo = contact.phone ?? contact.email {
                        Text(contactInfo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("General admission")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let maxCheckIns = invite.maxCheckIns {
                    Text("\(invite.checkIns.count) of \(maxCheckIns) check-ins")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(invite.checkIns.count) check-ins")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if invite.hasReachedLimit {
                Text("Maximum reached")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
