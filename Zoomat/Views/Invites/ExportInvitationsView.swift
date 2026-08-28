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
    @State private var savedMessage: String?

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
                    Menu {
                        Button("Share Images", systemImage: "square.and.arrow.up") {
                            prepareInvitations(saveToPhotos: false)
                        }
                        Button("Save to Photos", systemImage: "square.and.arrow.down") {
                            prepareInvitations(saveToPhotos: true)
                        }
                    } label: {
                        Label(
                            "Export (\(selectedInviteIDs.count, format: .number))",
                            systemImage: "square.and.arrow.up"
                        )
                    }
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
                    .accessibilityAddTraits(selectedInviteIDs.contains(invite.id) ? .isSelected : [])
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
                Text("\(generationProgress, format: .number) of \(generationTotal, format: .number)")
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

    private func prepareInvitations(saveToPhotos: Bool) {
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
            var artifacts: [InvitationImageArtifact] = []
            for (index, invite) in invitations.enumerated() {
                defer { generationProgress += 1 }
                guard let imageData = invite.generateInvitationCardWithMetadata() else {
                    failures += 1
                    continue
                }

                let safeName = invite.displayName.replacing("/", with: "-")
                let filename = "\(safeName)_\(index + 1).jpg"
                artifacts.append(InvitationImageArtifact(data: imageData, filename: filename))

                guard !saveToPhotos else {
                    await Task.yield()
                    continue
                }

                let fileURL = directory.appendingPathComponent(filename)
                do {
                    try imageData.write(to: fileURL, options: .atomic)
                    shareImageURLs.append(fileURL)
                } catch {
                    failures += 1
                }
                await Task.yield()
            }

            isGenerating = false
            if saveToPhotos {
                do {
                    try await InvitationPhotoSaver.save(artifacts)
                    if failures == 0 {
                        savedMessage = String(
                            localized: "\(artifacts.count, format: .number) invitation images saved with guest names in their captions."
                        )
                    } else {
                        exportMessage = String(localized: "\(failures, format: .number) invitations could not be prepared.")
                    }
                } catch {
                    exportMessage = error.localizedDescription
                }
            } else if failures == 0 {
                showingShareSheet = true
            } else {
                exportMessage = String(localized: "\(failures, format: .number) invitations could not be prepared.")
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

                if let contact = invite.contact,
                   let contactInfo = contact.phoneNumbers.first ?? contact.email {
                    Text(contactInfo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if contact.phoneNumbers.count > 1 {
                        Text("+\(contact.phoneNumbers.count - 1, format: .number) more")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if invite.contact == nil {
                    Text("General admission")
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

#Preview {
    ExportInvitationsView(event: .mock)
        .modelContainer(previewContainer)
}
