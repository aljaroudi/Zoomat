import SwiftUI
import SwiftData
import Contacts

struct ImportContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var deviceContacts: [CNContact] = []
    @State private var selectedContacts: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return deviceContacts
        }
        return deviceContacts.filter { contact in
            "\(contact.givenName) \(contact.familyName)".localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading contacts...")
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Access Denied",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else if deviceContacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts Found",
                        systemImage: "person.crop.circle"
                    )
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
                    Button("Import (\(selectedContacts.count))") {
                        importSelectedContacts()
                    }
                    .disabled(selectedContacts.isEmpty)
                }
            }
            .task {
                await loadContacts()
            }
        }
    }
    
    private var contactsList: some View {
        List(filteredContacts, id: \.identifier, selection: $selectedContacts) { contact in
            DeviceContactRow(contact: contact)
        }
        .environment(\.editMode, .constant(.active))
    }
    
    private func loadContacts() async {
        isLoading = true
        defer { isLoading = false }
        
        let store = CNContactStore()
        
        // Request access
        do {
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else {
                errorMessage = "Contact access is required to import contacts. Please enable it in Settings."
                return
            }
        } catch {
            errorMessage = "Failed to access contacts: \(error.localizedDescription)"
            return
        }
        
        // Fetch contacts
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        do {
            var contacts: [CNContact] = []
            try store.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }
            deviceContacts = contacts.sorted { 
                "\($0.givenName) \($0.familyName)" < "\($1.givenName) \($1.familyName)"
            }
        } catch {
            errorMessage = "Failed to load contacts: \(error.localizedDescription)"
        }
    }
    
    private func importSelectedContacts() {
        for identifier in selectedContacts {
            guard let cnContact = deviceContacts.first(where: { $0.identifier == identifier }) else {
                continue
            }
            
            let name = "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
            let email = cnContact.emailAddresses.first?.value as String?
            let phone = cnContact.phoneNumbers.first?.value.stringValue
            
            let contact = Contact(name: name, phone: phone, email: email)
            modelContext.insert(contact)
        }
        
        dismiss()
    }
}

struct DeviceContactRow: View {
    let contact: CNContact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(contact.givenName) \(contact.familyName)")
                .font(.headline)
            
            if let email = contact.emailAddresses.first?.value as String? {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let phone = contact.phoneNumbers.first?.value.stringValue {
                Text(phone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ImportContactsView()
        .modelContainer(previewContainer)
}
