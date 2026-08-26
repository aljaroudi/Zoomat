//
//  ExportInvitationsView.swift
//  Zoomat
//

import SwiftUI
import SwiftData

struct ExportInvitationsView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var selectedInviteIDs: Set<UUID>
    @State private var isGenerating = false
    @State private var generationProgress = 0
    @State private var generationTotal = 0
    @State private var showingShareSheet = false
    @State private var shareImageURLs: [URL] = []
    @State private var exportMessage: String?
    @State private var exportDirectory: URL?

    init(event: Event) {
        self.event = event
        _selectedInviteIDs = State(initialValue: Set(event.invites.map(\.id)))
    }

    private var selectedInvites: [Invite] {
        event.invites.filter { selectedInviteIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    generatingView
                } else {
                    invitesList
                }
            }
            .navigationTitle("Export Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .disabled(isGenerating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Export (\(selectedInviteIDs.count))", action: prepareInvitations)
                        .disabled(selectedInviteIDs.isEmpty || isGenerating)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareImageURLs)
            }
            .alert(
                "Export Incomplete",
                isPresented: Binding(
                    get: { exportMessage != nil },
                    set: { if !$0 { exportMessage = nil } }
                )
            ) {
                if !shareImageURLs.isEmpty {
                    Button("Share Available") { showingShareSheet = true }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(exportMessage ?? "Please try again.")
            }
            .onDisappear(perform: removeTemporaryFiles)
        }
    }

    private var invitesList: some View {
        List {
            Section {
                Button(action: toggleAll) {
                    Label(
                        selectedInviteIDs.count == event.invites.count ? "Deselect All" : "Select All",
                        systemImage: selectedInviteIDs.count == event.invites.count ? "checkmark.square.fill" : "square"
                    )
                }
            }

            Section("Invitations") {
                ForEach(event.invites.sorted { $0.created < $1.created }) { invite in
                    Button {
                        toggle(invite)
                    } label: {
                        InviteSelectionRow(
                            invite: invite,
                            isSelected: selectedInviteIDs.contains(invite.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Double-tap to select or deselect this invitation")
                }
            }

            Section {
                Text("Prepared images include invitation details in their metadata and are shared only through the destination you choose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var generatingView: some View {
        VStack {
            Spacer()
            ProgressView(value: Double(generationProgress), total: Double(generationTotal)) {
                Text("Preparing invitations")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(generationProgress) of \(generationTotal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func toggleAll() {
        if selectedInviteIDs.count == event.invites.count {
            selectedInviteIDs.removeAll()
        } else {
            selectedInviteIDs = Set(event.invites.map(\.id))
        }
    }

    private func toggle(_ invite: Invite) {
        if selectedInviteIDs.contains(invite.id) {
            selectedInviteIDs.remove(invite.id)
        } else {
            selectedInviteIDs.insert(invite.id)
        }
    }

    private func prepareInvitations() {
        let invitations = selectedInvites
        isGenerating = true
        generationProgress = 0
        generationTotal = invitations.count
        shareImageURLs = []
        removeTemporaryFiles()

        Task { @MainActor in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                exportDirectory = directory
            } catch {
                isGenerating = false
                exportMessage = error.localizedDescription
                return
            }

            var failures = 0
            for (index, invite) in invitations.enumerated() {
                defer { generationProgress += 1 }
                guard let imageData = invite.generateInvitationCardWithMetadata() else {
                    failures += 1
                    continue
                }

                let safeName = invite.displayName.replacingOccurrences(of: "/", with: "-")
                let fileURL = directory.appendingPathComponent("\(safeName)_\(index + 1).jpg")
                do {
                    try imageData.write(to: fileURL, options: .atomic)
                    shareImageURLs.append(fileURL)
                } catch {
                    failures += 1
                }
                await Task.yield()
            }

            isGenerating = false
            if failures == 0 {
                showingShareSheet = true
            } else {
                exportMessage = String(localized: "\(failures) invitations could not be prepared.")
            }
        }
    }

    private func removeTemporaryFiles() {
        guard let exportDirectory else { return }
        try? FileManager.default.removeItem(at: exportDirectory)
        self.exportDirectory = nil
    }
}

struct InviteSelectionRow: View {
    let invite: Invite
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.displayName)
                    .font(.headline)

                if let contact = invite.contact, let contactInfo = contact.phone ?? contact.email {
                    Text(contactInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if invite.contact == nil {
                    Text("General admission")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .gray)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExportInvitationsView(event: .mock)
        .modelContainer(previewContainer)
}
