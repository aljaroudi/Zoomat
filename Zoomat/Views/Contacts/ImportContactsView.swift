import SwiftUI
import SwiftData
import Contacts

struct ImportContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var deviceContacts: [CNContact] = []
    @State private var selectedContacts: Set<String> = []
    @State private var isLoading = false
    @State private var accessErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var searchText = ""
    
    var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return deviceContacts
        }
        return deviceContacts.filter { contact in
            contact.zoomatDisplayName.localizedStandardContains(searchText) ||
            contact.emailAddresses.contains { ($0.value as String).localizedStandardContains(searchText) } ||
            contact.phoneNumbers.contains { $0.value.stringValue.localizedStandardContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading contacts...")
                } else if let accessErrorMessage {
                    ContentUnavailableView(
                        "Access Denied",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(accessErrorMessage)
                    )
                } else if deviceContacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts Found",
                        systemImage: "person.crop.circle"
                    )
                } else if filteredContacts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    contactsList
                }
            }
            .navigationTitle("Import Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import (\(selectedContacts.count, format: .number))") {
                        importSelectedContacts()
                    }
                    .disabled(selectedContacts.isEmpty)
                }
            }
            .task {
                await loadContacts()
            }
            .saveErrorAlert(message: $saveErrorMessage)
        }
    }
    
    private var contactsList: some View {
        List(filteredContacts, id: \.identifier) { contact in
            let isSelected = selectedContacts.contains(contact.identifier)

            Button {
                if isSelected {
                    selectedContacts.remove(contact.identifier)
                } else {
                    selectedContacts.insert(contact.identifier)
                }
            } label: {
                DeviceContactRow(contact: contact, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double-tap to select or deselect this contact")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
    
    private func loadContacts() async {
        isLoading = true
        defer { isLoading = false }
        
        let store = CNContactStore()
        
        // Request access
        do {
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else {
                accessErrorMessage = "Contact access is required to import contacts. Please enable it in Settings."
                return
            }
        } catch {
            accessErrorMessage = "Failed to access contacts: \(error.localizedDescription)"
            return
        }
        
        // Fetch contacts
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        do {
            var contacts: [CNContact] = []
            try store.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }
            deviceContacts = contacts.sorted { 
                $0.zoomatDisplayName.localizedStandardCompare($1.zoomatDisplayName) == .orderedAscending
            }
        } catch {
            accessErrorMessage = "Failed to load contacts: \(error.localizedDescription)"
        }
    }
    
    private func importSelectedContacts() {
        for identifier in selectedContacts {
            guard let cnContact = deviceContacts.first(where: { $0.identifier == identifier }) else {
                continue
            }
            
            let name = cnContact.zoomatDisplayName
            let email = cnContact.emailAddresses.first?.value as String?
            let phoneNumbers = cnContact.phoneNumbers.map(\.value.stringValue)
            
            let contact = Contact(
                name: name,
                phone: phoneNumbers.first,
                additionalPhoneNumbers: Array(phoneNumbers.dropFirst()),
                email: email
            )
            modelContext.insert(contact)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Failed to import contacts: \(error.localizedDescription)"
        }
    }
}

struct DeviceContactRow: View {
    let contact: CNContact
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.zoomatDisplayName)
                    .font(.headline)

                if let email = contact.emailAddresses.first?.value as String? {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                    Text(phone.value.stringValue)
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

private extension CNContact {
    var zoomatDisplayName: String {
        CNContactFormatter.string(from: self, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

#Preview {
    ImportContactsView()
        .modelContainer(previewContainer)
}
