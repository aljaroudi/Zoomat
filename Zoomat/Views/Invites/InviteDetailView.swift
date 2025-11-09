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
        ScrollView {
            VStack(spacing: 20) {
                // Invitation Card Preview
                if let card = generatedCard {
                    Image(uiImage: card)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 10)
                } else {
                    ProgressView("Generating invitation...")
                        .frame(height: 400)
                }

                // Guest Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Guest Information")
                        .font(.headline)

                    LabeledContent("Name", value: invite.contact.name)

                    if let email = invite.contact.email {
                        LabeledContent("Email", value: email)
                    }

                    if let phone = invite.contact.phone {
                        LabeledContent("Phone", value: phone)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Event Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event")
                        .font(.headline)

                    Text(invite.event.title)
                        .font(.title2)

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
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Check-In Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Check-In Status")
                        .font(.headline)

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
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Share Button
                if let _ = generatedCard {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Invitation", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .navigationTitle("Invitation")
        .navigationBarTitleDisplayMode(.inline)
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
