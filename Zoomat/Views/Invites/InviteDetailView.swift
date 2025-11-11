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
        VStack(spacing: 0) {
            // Invitation Card Preview
            if let card = generatedCard {
                Image(uiImage: card)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 10)
                    .padding()
            } else {
                ProgressView("Generating invitation...")
                    .frame(height: 400)
                    .padding()
            }

            Form {
                // Guest Info
                Section("Guest") {
                    NavigationLink {
                        ContactDetailView(contact: invite.contact)
                    } label: {
                        Label(invite.contact.name, systemImage: "person.fill")
                    }
                }

                // Event Info
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
                        ForEach(invite.checkIns) { checkIn in
                            Label(
                                checkIn.created.formatted(date: .abbreviated, time: .shortened),
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Invitation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if generatedCard != nil {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
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
        DispatchQueue.global(qos: .userInitiated).async {
            let card = invite.generateInvitationCard()
            DispatchQueue.main.async {
                generatedCard = card
            }
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
