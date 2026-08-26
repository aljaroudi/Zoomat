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

            if let maxCheckIns = invite.maxCheckIns {
                Section("Check-in Limit") {
                    LabeledContent("Progress", value: "\(invite.checkIns.count) / \(maxCheckIns)")

                    if invite.hasReachedLimit {
                        Label("Maximum reached", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
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
    }

    private func generateCard() {
        Task { @MainActor in
            await Task.yield()
            generatedCard = invite.generateInvitationCard()
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
