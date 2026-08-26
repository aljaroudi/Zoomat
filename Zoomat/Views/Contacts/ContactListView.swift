//
//  ContactListView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData
import Contacts

struct ContactListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @State private var showingCreateContact = false
    @State private var showingImportContacts = false
    @State private var searchText = ""
    @State private var contactToDelete: Contact?
    @State private var errorMessage: String?

    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.name.localizedStandardContains(searchText) ||
            contact.email?.localizedStandardContains(searchText) == true ||
            contact.phone?.localizedStandardContains(searchText) == true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    emptyState
                } else if filteredContacts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    contactList
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingCreateContact = true
                        } label: {
                            Label("New Contact", systemImage: "person.badge.plus")
                        }

                        Button {
                            showingImportContacts = true
                        } label: {
                            Label("Import from Contacts", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("Add Contacts", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateContact) {
                CreateContactView()
            }
            .sheet(isPresented: $showingImportContacts) {
                ImportContactsView()
            }
            .confirmationDialog(
                "Delete this contact and all linked invitations and check-ins?",
                isPresented: Binding(
                    get: { contactToDelete != nil },
                    set: { if !$0 { contactToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Contact", role: .destructive, action: deleteContact)
                Button("Cancel", role: .cancel) { contactToDelete = nil }
            }
            .saveErrorAlert(message: $errorMessage)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Contacts", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("Add contacts manually or import from your device")
        } actions: {
            Button("Add Contact") { showingCreateContact = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var contactList: some View {
        List {
            ForEach(filteredContacts) { contact in
                NavigationLink(value: contact) {
                    ContactRowView(contact: contact)
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        contactToDelete = contact
                    }
                }
            }
        }
        .navigationDestination(for: Contact.self) { contact in
            ContactDetailView(contact: contact)
        }
    }

    private func deleteContact() {
        guard let contactToDelete else { return }
        for invite in contactToDelete.invites {
            modelContext.delete(invite)
        }
        modelContext.delete(contactToDelete)

        do {
            try modelContext.save()
            self.contactToDelete = nil
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name)
                .font(.headline)

            if let email = contact.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let phone = contact.phone {
                Text(phone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !contact.invites.isEmpty {
                Label(inviteCountText, systemImage: "ticket")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var inviteCountText: LocalizedStringResource {
        if contact.invites.count == 1 {
            "\(contact.invites.count, format: .number) invite"
        } else {
            "\(contact.invites.count, format: .number) invites"
        }
    }
}

#Preview {
    ContactListView()
        .modelContainer(previewContainer)
}
