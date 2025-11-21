//
//  ExportInvitationsView.swift
//  Zoomat
//
//  Created by Mohammed on 11/21/25.
//

import SwiftUI
import SwiftData
import Photos

struct ExportInvitationsView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var selectedInviteIDs: Set<UUID>
    @State private var isGenerating = false
    @State private var generationProgress = 0
    @State private var saveSuccessCount = 0
    @State private var saveErrorCount = 0
    @State private var showingCompleted = false
    @State private var showingShareSheet = false
    @State private var shareImageURLs: [URL] = []

    init(event: Event) {
        self.event = event
        // Select all invites by default
        _selectedInviteIDs = State(initialValue: Set(event.invites.map { $0.id }))
    }

    var selectedInvites: [Invite] {
        event.invites.filter { selectedInviteIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isGenerating {
                    generatingView
                } else if showingCompleted {
                    completedView
                } else {
                    invitesList
                }
            }
            .navigationTitle("Export Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showingCompleted ? "Done" : "Cancel") {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }

                if !showingCompleted {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Export (\(selectedInviteIDs.count))") {
                            exportViaShare()
                        }
                        .disabled(selectedInviteIDs.isEmpty || isGenerating)
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if !shareImageURLs.isEmpty {
                    ShareSheet(items: shareImageURLs)
                }
            }
        }
    }

    private var invitesList: some View {
        List {
            Section {
                Button {
                    if selectedInviteIDs.count == event.invites.count {
                        selectedInviteIDs.removeAll()
                    } else {
                        selectedInviteIDs = Set(event.invites.map { $0.id })
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedInviteIDs.count == event.invites.count ? "checkmark.square.fill" : "square")
                            .foregroundStyle(.blue)
                        Text(selectedInviteIDs.count == event.invites.count ? "Deselect All" : "Select All")
                    }
                }
            }

            Section("Invitations") {
                ForEach(event.invites) { invite in
                    InviteSelectionRow(
                        invite: invite,
                        isSelected: selectedInviteIDs.contains(invite.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedInviteIDs.contains(invite.id) {
                            selectedInviteIDs.remove(invite.id)
                        } else {
                            selectedInviteIDs.insert(invite.id)
                        }
                    }
                }
            }

            Section {
                Text("Exported images will include invitation details in metadata, visible in iOS Photos app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: Double(generationProgress), total: Double(selectedInviteIDs.count)) {
                Text("Saving to Photos")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(generationProgress) / \(selectedInviteIDs.count)")
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

    private var completedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: saveErrorCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(saveErrorCount == 0 ? .green : .orange)

            VStack(spacing: 8) {
                Text("^[Saved \(saveSuccessCount) invitation](inflect: true)")
                    .font(.title3.bold())

                if saveErrorCount > 0 {
                    Text("\(saveErrorCount) failed to save")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func saveToPhotos() {
        // Check/request photo library permission
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        performSave()
                    }
                }
            }
        } else if status == .authorized || status == .limited {
            performSave()
        }
    }

    private func performSave() {
        isGenerating = true
        generationProgress = 0
        saveSuccessCount = 0
        saveErrorCount = 0

        Task {
            print("Starting to save \(selectedInvites.count) invitations")

            for (index, invite) in selectedInvites.enumerated() {
                await MainActor.run {
                    print("Processing invite \(index + 1)/\(selectedInvites.count): \(invite.displayName)")
                }

                // Generate invitation card with metadata (must be on main actor for SwiftData)
                let imageData = await MainActor.run {
                    invite.generateInvitationCardWithMetadata()
                }

                guard let imageData else {
                    await MainActor.run {
                        print("❌ Failed to generate image for \(invite.displayName)")
                        saveErrorCount += 1
                        generationProgress += 1
                    }
                    continue
                }

                print("✓ Generated image data: \(imageData.count) bytes")

                // Save to photo library with metadata using continuation
                print("Attempting to save to Photos...")
                let saveResult: Result<Void, Error> = await withCheckedContinuation { continuation in
                    PHPhotoLibrary.shared().performChanges({
                        print("Inside performChanges block")
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo, data: imageData, options: nil)
                        print("Added resource to request")
                    }, completionHandler: { success, error in
                        print("Completion handler called: success=\(success), error=\(String(describing: error))")
                        if success {
                            continuation.resume(returning: .success(()))
                        } else {
                            continuation.resume(returning: .failure(error ?? NSError(domain: "PhotoSave", code: -1)))
                        }
                    })
                }

                switch saveResult {
                case .success:
                    print("✓ Saved to Photos")
                    await MainActor.run {
                        saveSuccessCount += 1
                        generationProgress += 1
                    }
                case .failure(let error):
                    print("❌ Failed to save photo: \(error)")
                    await MainActor.run {
                        saveErrorCount += 1
                        generationProgress += 1
                    }
                }
            }

            print("Completed: \(saveSuccessCount) saved, \(saveErrorCount) failed")
            await MainActor.run {
                isGenerating = false
                showingCompleted = true
            }
        }
    }

    private func exportViaShare() {
        isGenerating = true
        generationProgress = 0
        shareImageURLs = []

        Task { @MainActor in
            print("Generating images for share sheet")

            // Create temporary directory for images
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            for (index, invite) in selectedInvites.enumerated() {
                // Generate invitation card with metadata
                if let imageData = invite.generateInvitationCardWithMetadata() {
                    // Save to temporary file with metadata preserved
                    let fileName = "\(invite.displayName.replacingOccurrences(of: "/", with: "-"))_\(index + 1).jpg"
                    let fileURL = tempDir.appendingPathComponent(fileName)

                    do {
                        try imageData.write(to: fileURL)
                        shareImageURLs.append(fileURL)
                        print("✓ Created file: \(fileName) with metadata")
                    } catch {
                        print("❌ Failed to write file: \(error)")
                    }
                }
                generationProgress += 1
            }

            print("Generated \(shareImageURLs.count) images with metadata")
            isGenerating = false

            if !shareImageURLs.isEmpty {
                showingShareSheet = true
            }
        }
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

                if let contact = invite.contact {
                    if let contactInfo = contact.phone ?? contact.email {
                        Text(contactInfo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
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
    let container = previewContainer
    let context = container.mainContext

    // Create sample event with invites
    let event = Event(
        title: "Sample Wedding",
        date: Date()
    )
    let contact1 = Contact(name: "John Doe", phone: "555-0100")
    let contact2 = Contact(name: "Jane Smith", email: "jane@example.com")
    let invite1 = Invite(contact: contact1, event: event)
    let invite2 = Invite(contact: contact2, event: event)

    context.insert(event)
    context.insert(contact1)
    context.insert(contact2)
    context.insert(invite1)
    context.insert(invite2)

    return ExportInvitationsView(event: event)
        .modelContainer(container)
}
