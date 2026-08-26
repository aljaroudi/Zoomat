//
//  AddInvitesView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

enum InviteCreationMode {
    case fromContacts
    case blank
}

struct AddInvitesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contacts: [Contact]

    let event: Event

    @State private var mode: InviteCreationMode = .fromContacts
    @State private var selectedContactIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showingCreateContact = false

    // Blank invite settings
    @State private var blankInviteQuantity = 1
    @State private var blankInviteMaxCheckIns: Int? = 1
    @State private var hasMaxCheckIns = true

    var filteredContacts: [Contact] {
        // Filter out contacts already invited
        let alreadyInvited = Set(event.invites.compactMap { $0.contact?.id })
        let available = contacts.filter { !alreadyInvited.contains($0.id) }

        if searchText.isEmpty {
            return available
        }

        return available.filter { contact in
            contact.name.localizedStandardContains(searchText) ||
            contact.email?.localizedStandardContains(searchText) == true ||
            contact.phone?.localizedStandardContains(searchText) == true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Picker
                Picker("Mode", selection: $mode) {
                    Text("From Contacts").tag(InviteCreationMode.fromContacts)
                    Text("Blank Invites").tag(InviteCreationMode.blank)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on mode
                if mode == .fromContacts {
                    contactModeContent
                } else {
                    blankModeContent
                }
            }
            .navigationTitle("Add Invites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: addInvites) { confirmButtonLabel }
                    .disabled(!canAddInvites)
                }
            }
            .saveErrorAlert(message: $errorMessage)
            .sheet(isPresented: $showingCreateContact) {
                CreateContactView()
            }
        }
    }

    @ViewBuilder
    private var confirmButtonLabel: some View {
        switch mode {
        case .fromContacts:
            Text("Add (\(selectedContactIDs.count))")
        case .blank:
            Text("Create (\(blankInviteQuantity))")
        }
    }

    private var canAddInvites: Bool {
        switch mode {
        case .fromContacts:
            return !selectedContactIDs.isEmpty
        case .blank:
            return blankInviteQuantity > 0
        }
    }

    @ViewBuilder
    private var contactModeContent: some View {
        if contacts.isEmpty {
            emptyState
        } else if filteredContacts.isEmpty {
            noResultsState
        } else {
            contactList
                .searchable(text: $searchText, prompt: "Search contacts")
        }
    }

    @ViewBuilder
    private var blankModeContent: some View {
        Form {
            Section {
                Stepper("^[\(blankInviteQuantity) card](inflect: true)", value: $blankInviteQuantity, in: 1...100)
            } header: {
                Text("Quantity")
            } footer: {
                Text("The number of different invitation cards to create.")
            }

            Section {
                Toggle("Set maximum check-ins", isOn: $hasMaxCheckIns)

                if hasMaxCheckIns {
                    Stepper("Maximum: \(blankInviteMaxCheckIns ?? 1)", value: Binding(
                        get: { blankInviteMaxCheckIns ?? 1 },
                        set: { blankInviteMaxCheckIns = $0 }
                    ), in: 1...100)
                }
            } header: {
                Text("Check-in Limit")
            } footer: {
                Text("Blank invites are not linked to any contact and can be used for general admission.")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Contacts", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("Add contacts first to create invites")
        } actions: {
            Button("Add Contact") { showingCreateContact = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var noResultsState: some View {
        ContentUnavailableView.search(text: searchText)
    }

    private var contactList: some View {
        List {
            ForEach(filteredContacts) { contact in
                Button {
                    if selectedContactIDs.contains(contact.id) {
                        selectedContactIDs.remove(contact.id)
                    } else {
                        selectedContactIDs.insert(contact.id)
                    }
                } label: {
                    ContactSelectionRow(
                        contact: contact,
                        isSelected: selectedContactIDs.contains(contact.id)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Double-tap to select or deselect this contact")
                .accessibilityAddTraits(selectedContactIDs.contains(contact.id) ? .isSelected : [])
            }
        }
    }

    private func addInvites() {
        switch mode {
        case .fromContacts:
            for contactID in selectedContactIDs {
                guard let contact = contacts.first(where: { $0.id == contactID }) else {
                    continue
                }
                let invite = Invite(contact: contact, event: event)
                modelContext.insert(invite)
            }
        case .blank:
            let maxCheckIns = hasMaxCheckIns ? blankInviteMaxCheckIns : nil
            for i in 1...blankInviteQuantity {
                let invite = Invite(
                    contact: nil,
                    event: event,
                    contactName: "General Invite #\(event.invites.count + i)",
                    maxCheckIns: maxCheckIns
                )
                modelContext.insert(invite)
            }
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let phone = contact.phone {
                    Text(phone)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .orange : .secondary)
                .font(.title3)
        }
        .padding(.vertical, 6)
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
