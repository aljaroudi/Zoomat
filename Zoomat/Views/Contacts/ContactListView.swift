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

    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
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
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateContact) {
                CreateContactView()
            }
            .sheet(isPresented: $showingImportContacts) {
                ImportContactsView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Contacts",
            systemImage: "person.crop.circle.badge.plus",
            description: Text("Add contacts manually or import from your device")
        )
    }

    private var contactList: some View {
        List {
            ForEach(filteredContacts) { contact in
                NavigationLink(value: contact) {
                    ContactRowView(contact: contact)
                }
            }
            .onDelete(perform: deleteContacts)
        }
        .navigationDestination(for: Contact.self) { contact in
            ContactDetailView(contact: contact)
        }
    }

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredContacts[index])
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let phone = contact.phone {
                Text(phone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !contact.invites.isEmpty {
                Text("^[\(contact.invites.count) invite](inflect: true)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContactListView()
        .modelContainer(previewContainer)
}
