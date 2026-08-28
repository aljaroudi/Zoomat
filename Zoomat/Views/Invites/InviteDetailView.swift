//
//  InviteDetailView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct InviteDetailView: View {
    @Environment(\.openURL) private var openURL
    @Bindable var invite: Invite
    @State private var generatedCard: UIImage?
    @State private var showingShareSheet = false
    @State private var showingGuestAllowanceEditor = false
    @State private var showingAllowedEntriesEditor = false
    @State private var showingPhoneNumberPicker = false
    @State private var sharedImageURL: URL?
    @State private var sharedImageDirectory: URL?
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    var body: some View {
        List {
            if let card = generatedCard {
                Image(uiImage: card)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 12))
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .accessibilityLabel("Invitation card for \(invite.displayName)")
            } else {
                ProgressView("Generating invitation...")
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .listRowBackground(Color.clear)
            }

            Section("Guest") {
                if let contact = invite.contact {
                    NavigationLink(value: contact) {
                        Label(contact.name, systemImage: "person.fill")
                    }
                } else {
                    Label(invite.displayName, systemImage: "ticket")
                        .foregroundStyle(.secondary)
                }
            }

            if let additionalGuestCount = invite.effectiveAdditionalGuestCount {
                Section("Guest Allowance") {
                    LabeledContent(
                        "Additional Guests",
                        value: additionalGuestCount,
                        format: .number
                    )

                    LabeledContent("Setting") {
                        if invite.additionalGuestCountOverride == nil {
                            Text("Event Default")
                        } else {
                            Text("Custom")
                        }
                    }

                    Button("Edit Guest Allowance", systemImage: "person.2") {
                        showingGuestAllowanceEditor = true
                    }
                }
            }

            Section {
                LabeledContent(
                    "Allowed Entries",
                    value: invite.allowedEntryCount,
                    format: .number
                )
                LabeledContent(
                    "Entries Used",
                    value: "\(invite.checkIns.count.formatted()) / \(invite.allowedEntryCount.formatted())"
                )

                if invite.hasReachedEntryLimit {
                    Label("Entry limit reached", systemImage: "hand.raised.fill")
                        .foregroundStyle(.red)
                }

                Button("Edit Allowed Entries", systemImage: "number") {
                    showingAllowedEntriesEditor = true
                }
            } header: {
                Text("Allowed Entries")
            } footer: {
                Text("Allowed entries are the number of times this invitation code can be successfully scanned on one scanner phone.")
            }

            Section("Event") {
                Text(invite.event.title)

                if !invite.event.subtitle.isEmpty {
                    Text(invite.event.subtitle)
                        .foregroundStyle(.secondary)
                }

                Label(
                    invite.event.date.formatted(date: .long, time: .shortened),
                    systemImage: "calendar"
                )

                if let address = invite.event.address {
                    Label(address, systemImage: "location")
                }
            }

            Section("Entry History") {
                if invite.checkIns.isEmpty {
                    Label("No entries recorded", systemImage: "circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(invite.checkInsNewestFirst) { checkIn in
                        Label(
                            checkIn.created.formatted(date: .abbreviated, time: .shortened),
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle("Invitation")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Contact.self) { contact in
            ContactDetailView(contact: contact)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if generatedCard != nil {
                    Menu {
                        Button("Share Image", systemImage: "square.and.arrow.up", action: shareImage)
                        Button("Save to Photos", systemImage: "square.and.arrow.down", action: saveToPhotos)

                        if invite.contact != nil {
                            Button("Open WhatsApp Chat", systemImage: "message", action: openWhatsApp)
                        }
                    } label: {
                        Label("Share Invitation", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            generateCard()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let sharedImageURL {
                ShareSheet(items: [sharedImageURL])
            }
        }
        .onChange(of: showingShareSheet) { _, isPresented in
            if !isPresented { removeSharedImage() }
        }
        .onDisappear(perform: removeSharedImage)
        .sheet(isPresented: $showingGuestAllowanceEditor) {
            GuestAllowanceEditor(invite: invite)
        }
        .sheet(isPresented: $showingAllowedEntriesEditor) {
            AllowedEntriesEditor(invite: invite)
        }
        .confirmationDialog(
            "Choose a WhatsApp Number",
            isPresented: $showingPhoneNumberPicker,
            titleVisibility: .visible
        ) {
            ForEach(invite.contact?.phoneNumbers ?? [], id: \.self) { number in
                Button(number) { openWhatsApp(number: number) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Saved to Photos",
            isPresented: Binding(
                get: { savedMessage != nil },
                set: { if !$0 { savedMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(savedMessage ?? "")
        }
        .saveErrorAlert(message: $errorMessage)
    }

    private func generateCard() {
        Task { @MainActor in
            await Task.yield()
            generatedCard = invite.generateInvitationCard()
        }
    }

    private func shareImage() {
        removeSharedImage()
        guard let data = invite.generateInvitationCardWithMetadata() else {
            errorMessage = String(localized: "The invitation image could not be prepared.")
            return
        }

        do {
            let directory = FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: invitationFilename)
            try data.write(to: url, options: .atomic)
            sharedImageDirectory = directory
            sharedImageURL = url
            showingShareSheet = true
        } catch {
            removeSharedImage()
            errorMessage = error.localizedDescription
        }
    }

    private func saveToPhotos() {
        guard let data = invite.generateInvitationCardWithMetadata() else {
            errorMessage = String(localized: "The invitation image could not be prepared.")
            return
        }

        Task {
            do {
                try await InvitationPhotoSaver.save([
                    InvitationImageArtifact(data: data, filename: invitationFilename)
                ])
                savedMessage = String(localized: "Invitation image saved with the guest name in its caption.")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openWhatsApp() {
        guard let phoneNumbers = invite.contact?.phoneNumbers, !phoneNumbers.isEmpty else {
            errorMessage = String(localized: "Add an international phone number to this contact before opening WhatsApp.")
            return
        }

        if phoneNumbers.count == 1 {
            openWhatsApp(number: phoneNumbers[0])
        } else {
            showingPhoneNumberPicker = true
        }
    }

    private func openWhatsApp(number: String) {
        do {
            let url = try WhatsAppChatLink.url(for: number)
            openURL(url) { accepted in
                if !accepted {
                    errorMessage = String(localized: "WhatsApp could not be opened.")
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var invitationFilename: String {
        let safeName = invite.displayName.replacing("/", with: "-")
        return "\(safeName).jpg"
    }

    private func removeSharedImage() {
        if let sharedImageDirectory {
            try? FileManager.default.removeItem(at: sharedImageDirectory)
        }
        sharedImageDirectory = nil
        sharedImageURL = nil
    }
}

private struct GuestAllowanceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let invite: Invite
    @State private var usesEventDefault: Bool
    @State private var customAdditionalGuestCount: Int
    @State private var errorMessage: String?

    init(invite: Invite) {
        self.invite = invite
        _usesEventDefault = State(initialValue: invite.additionalGuestCountOverride == nil)
        _customAdditionalGuestCount = State(
            initialValue: invite.additionalGuestCountOverride ?? invite.event.defaultAdditionalGuestCount
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use Event Default", isOn: $usesEventDefault)

                    if usesEventDefault {
                        LabeledContent(
                            "Additional Guests",
                            value: invite.event.defaultAdditionalGuestCount,
                            format: .number
                        )
                    } else {
                        Stepper(value: $customAdditionalGuestCount, in: 0...Int.max) {
                            LabeledContent(
                                "Additional Guests",
                                value: customAdditionalGuestCount,
                                format: .number
                            )
                        }
                    }
                } footer: {
                    Text("Additional guests are people who may enter together with each successful scan. They do not use separate entries.")
                }
            }
            .navigationTitle("Guest Allowance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: saveAllowance)
                }
            }
            .saveErrorAlert(message: $errorMessage)
        }
    }

    private func saveAllowance() {
        invite.additionalGuestCountOverride = usesEventDefault ? nil : customAdditionalGuestCount

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct AllowedEntriesEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let invite: Invite
    @State private var allowedEntryCount: Int
    @State private var errorMessage: String?

    init(invite: Invite) {
        self.invite = invite
        _allowedEntryCount = State(initialValue: max(invite.allowedEntryCount, 1))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $allowedEntryCount, in: 1...Int.max) {
                        LabeledContent(
                            "Allowed Entries",
                            value: allowedEntryCount,
                            format: .number
                        )
                    }
                } footer: {
                    Text("Allowed entries are successful scans for this code on one scanner phone. Additional guests may enter together during each entry.")
                }
            }
            .navigationTitle("Allowed Entries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: saveAllowedEntries)
                }
            }
            .saveErrorAlert(message: $errorMessage)
        }
    }

    private func saveAllowedEntries() {
        invite.allowedEntryCount = max(allowedEntryCount, 1)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

// Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let container = previewContainer
    let invite = try! container.mainContext.fetch(FetchDescriptor<Invite>()).first!

    return NavigationStack {
        InviteDetailView(invite: invite)
    }
    .modelContainer(container)
}
