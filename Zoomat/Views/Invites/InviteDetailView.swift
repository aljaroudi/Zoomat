//
//  InviteDetailView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct InviteDetailView: View {
    @Bindable var invite: Invite
    @State private var generatedCard: UIImage?
    @State private var showingShareSheet = false
    @State private var showingGuestAllowanceEditor = false

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

            Section("Status") {
                if invite.checkIns.isEmpty {
                    Label("Not checked in", systemImage: "circle")
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
                    Button("Share Invitation", systemImage: "square.and.arrow.up") {
                        showingShareSheet = true
                    }
                }
            }
        }
        .task {
            generateCard()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let card = generatedCard {
                ShareSheet(items: [card])
            }
        }
        .sheet(isPresented: $showingGuestAllowanceEditor) {
            GuestAllowanceEditor(invite: invite)
        }
    }

    private func generateCard() {
        Task { @MainActor in
            await Task.yield()
            generatedCard = invite.generateInvitationCard()
        }
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
                        Stepper(value: $customAdditionalGuestCount, in: 0...10) {
                            LabeledContent(
                                "Additional Guests",
                                value: customAdditionalGuestCount,
                                format: .number
                            )
                        }
                    }
                } footer: {
                    Text("This allowance is shown to the person scanning the invitation. Additional guests do not check in separately.")
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
