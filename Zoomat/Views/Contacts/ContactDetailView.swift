//
//  ContactDetailView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var contact: Contact
    @State private var showingEditSheet = false

    var body: some View {
        List {
            Section("Contact Information") {
                LabeledContent("Name", value: contact.name)

                if let email = contact.email {
                    LabeledContent("Email", value: email)
                }

                ForEach(contact.phoneNumbers, id: \.self) { phone in
                    LabeledContent("Phone", value: phone)
                }
            }

            Section {
                ForEach(contact.invites) { invite in
                    NavigationLink(value: invite.event) {
                        VStack(alignment: .leading) {
                            Text(invite.event.title)
                                .font(.headline)
                            Text(invite.event.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if !invite.checkIns.isEmpty {
                                Label("\(invite.checkIns.count, format: .number) entries used", systemImage: "checkmark.circle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Events")
                    Spacer()
                    Text(contact.invites.count, format: .number)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(contact.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditContactView(contact: contact)
        }
    }
}

struct CreateContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var namesText = ""
    @State private var errorMessage: String?

    private var validNames: [String] {
        namesText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Names", text: $namesText, axis: .vertical)
                        .lineLimit(6...12)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Enter names")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add one name per line.")

                        if !validNames.isEmpty {
                            Text(validNamesCountText)
                        }
                    }
                }
            }
            .navigationTitle("New Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createContacts()
                    }
                    .disabled(validNames.isEmpty)
                }
            }
            .saveErrorAlert(message: $errorMessage)
        }
    }

    private var validNamesCountText: LocalizedStringResource {
        if validNames.count == 1 {
            "\(validNames.count, format: .number) contact"
        } else {
            "\(validNames.count, format: .number) contacts"
        }
    }

    private func createContacts() {
        for name in validNames {
            let contact = Contact(name: name)
            modelContext.insert(contact)
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

struct EditContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contact: Contact
    @State private var name: String
    @State private var email: String
    @State private var phoneNumbersText: String
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false

    init(contact: Contact) {
        self.contact = contact
        _name = State(initialValue: contact.name)
        _email = State(initialValue: contact.email ?? "")
        _phoneNumbersText = State(initialValue: contact.phoneNumbers.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    TextField("Email (optional)", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    TextField("Phone numbers (optional)", text: $phoneNumbersText, axis: .vertical)
                    .lineLimit(2...6)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.numbersAndPunctuation)
                }

                Section {
                    Button("Delete Contact", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: saveContact)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this contact and all linked invitations and recorded entries?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Contact", role: .destructive, action: deleteContact)
                Button("Cancel", role: .cancel) {}
            }
            .saveErrorAlert(message: $errorMessage)
        }
    }

    private func saveContact() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneNumbers = phoneNumbersText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        contact.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        contact.email = trimmedEmail.isEmpty ? nil : trimmedEmail
        contact.phoneNumbers = phoneNumbers

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteContact() {
        for invite in contact.invites {
            modelContext.delete(invite)
        }
        modelContext.delete(contact)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Detail") {
    let container = previewContainer
    let contact = try! container.mainContext.fetch(FetchDescriptor<Contact>()).first!

    return NavigationStack {
        ContactDetailView(contact: contact)
    }
    .modelContainer(container)
}

#Preview("Create") {
    CreateContactView()
        .modelContainer(previewContainer)
}

#Preview("Edit") {
    let container = previewContainer
    let contact = try! container.mainContext.fetch(FetchDescriptor<Contact>()).first!

    return EditContactView(contact: contact)
        .modelContainer(container)
}
