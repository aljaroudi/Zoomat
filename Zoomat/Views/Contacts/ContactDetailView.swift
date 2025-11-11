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

                if let phone = contact.phone {
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
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !invite.checkIns.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Checked In")
                                        .font(.caption2)
                                }
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

    private var validNames: [String] {
        namesText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter names (one per line)")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                TextEditor(text: $namesText)
                    .font(.body)
                    .autocapitalization(.words)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)

                if !validNames.isEmpty {
                    Text("^[\(validNames.count) contact](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                Spacer()
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
        }
    }

    private func createContacts() {
        for name in validNames {
            let contact = Contact(name: name)
            modelContext.insert(contact)
        }
        dismiss()
    }
}

struct EditContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var contact: Contact

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $contact.name)
                    TextField("Email (optional)", text: Binding(
                        get: { contact.email ?? "" },
                        set: { contact.email = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    TextField("Phone (optional)", text: Binding(
                        get: { contact.phone ?? "" },
                        set: { contact.phone = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                }

                Section {
                    Button("Delete Contact", role: .destructive) {
                        deleteContact()
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func deleteContact() {
        modelContext.delete(contact)
        dismiss()
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
