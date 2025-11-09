//
//  AddInvitesView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct AddInvitesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contacts: [Contact]

    let event: Event

    @State private var selectedContactIDs: Set<UUID> = []
    @State private var searchText = ""

    var filteredContacts: [Contact] {
        // Filter out contacts already invited
        let alreadyInvited = Set(event.invites.map { $0.contact.id })
        let available = contacts.filter { !alreadyInvited.contains($0.id) }

        if searchText.isEmpty {
            return available
        }

        return available.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText) ||
            contact.email?.localizedCaseInsensitiveContains(searchText) == true ||
            contact.phone?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    emptyState
                } else if filteredContacts.isEmpty {
                    noResultsState
                } else {
                    contactList
                }
            }
            .navigationTitle("Add Invites")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedContactIDs.count))") {
                        addInvites()
                    }
                    .disabled(selectedContactIDs.isEmpty)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Contacts",
            systemImage: "person.crop.circle.badge.plus",
            description: Text("Add contacts first to create invites")
        )
    }

    private var noResultsState: some View {
        ContentUnavailableView.search(text: searchText)
    }

    private var contactList: some View {
        List {
            ForEach(filteredContacts) { contact in
                ContactSelectionRow(
                    contact: contact,
                    isSelected: selectedContactIDs.contains(contact.id)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedContactIDs.contains(contact.id) {
                        selectedContactIDs.remove(contact.id)
                    } else {
                        selectedContactIDs.insert(contact.id)
                    }
                }
            }
        }
    }

    private func addInvites() {
        for contactID in selectedContactIDs {
            guard let contact = contacts.first(where: { $0.id == contactID }) else {
                continue
            }
            let invite = Invite(contact: contact, event: event)
            modelContext.insert(invite)
        }

        dismiss()
    }
}

struct ContactSelectionRow: View {
    let contact: Contact
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)

                if let email = contact.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let phone = contact.phone {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.gray)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = previewContainer
    let context = container.mainContext

    // Create sample contacts
    let contact1 = Contact(name: "John Doe", phone: "555-0100", email: "john@example.com")
    let contact2 = Contact(name: "Jane Smith", email: "jane@example.com")
    context.insert(contact1)
    context.insert(contact2)

    // Create sample event
    let event = Event(
        title: "Sample Wedding",
        date: Date()
    )
    context.insert(event)

    return AddInvitesView(event: event)
        .modelContainer(container)
}
