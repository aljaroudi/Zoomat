//
//  CreateEventView.swift
//  Zoomat
//

import SwiftUI
import SwiftData
import PhotosUI

struct EventDraft {
    var title = ""
    var subtitle = ""
    var date = Date()
    var duration: TimeInterval = 3_600
    var address = ""
    var imageData: Data?
    var qrPositionX = 0.5
    var qrPositionY = 0.5
    var qrSize = 0.3

    init() {}

    init(event: Event) {
        title = event.title
        subtitle = event.subtitle
        date = event.date
        duration = max(event.effectiveExpirationDate.timeIntervalSince(event.date), 900)
        address = event.address ?? ""
        imageData = event.imageData
        qrPositionX = event.qrPositionX
        qrPositionY = event.qrPositionY
        qrSize = min(max(event.qrSize, 0.1), 0.9)
        clampPosition()
    }

    mutating func clampPosition() {
        let halfSize = qrSize / 2
        qrPositionX = min(max(qrPositionX, halfSize), 1 - halfSize)
        qrPositionY = min(max(qrPositionY, halfSize), 1 - halfSize)
    }

    var expirationDate: Date {
        date.addingTimeInterval(duration)
    }

    func apply(to event: Event) {
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        event.date = date
        event.expirationDate = expirationDate
        event.address = address.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        event.imageData = imageData
        event.qrPositionX = qrPositionX
        event.qrPositionY = qrPositionY
        event.qrSize = qrSize
        event.updated = .now
    }
}

struct CreateEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft = EventDraft()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            EventForm(draft: $draft, errorMessage: $errorMessage)
                .navigationTitle("New Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) { dismiss() }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create", action: createEvent)
                            .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .saveErrorAlert(message: $errorMessage)
        }
    }

    private func createEvent() {
        let event = Event(title: draft.title, date: draft.date)
        draft.apply(to: event)
        modelContext.insert(event)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct EditEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var draft: EventDraft
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false

    init(event: Event) {
        self.event = event
        _draft = State(initialValue: EventDraft(event: event))
    }

    var body: some View {
        NavigationStack {
            EventForm(draft: $draft, errorMessage: $errorMessage) {
                Section {
                    Button("Delete Event", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: saveChanges)
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this event and all its invitations and check-ins?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Event", role: .destructive, action: deleteEvent)
                Button("Cancel", role: .cancel) {}
            }
            .saveErrorAlert(message: $errorMessage)
        }
    }

    private func saveChanges() {
        draft.apply(to: event)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEvent() {
        modelContext.delete(event)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct EventForm<Footer: View>: View {
    @Binding var draft: EventDraft
    @Binding var errorMessage: String?
    @State private var selectedImage: PhotosPickerItem?
    @ViewBuilder let footer: () -> Footer

    init(
        draft: Binding<EventDraft>,
        errorMessage: Binding<String?>,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        _draft = draft
        _errorMessage = errorMessage
        self.footer = footer
    }

    var body: some View {
        Form {
            Section("Event Details") {
                TextField("Title", text: $draft.title)
                TextField("Subtitle (optional)", text: $draft.subtitle)
                DatePicker("Date", selection: $draft.date)
                Stepper(value: $draft.duration, in: 900...Double(Int.max), step: 900) {
                    LabeledContent(
                        "Duration",
                        value: Duration.seconds(draft.duration).formatted(
                            .units(allowed: [.hours, .minutes], width: .wide)
                        )
                    )
                }
                LabeledContent("Expires", value: draft.expirationDate, format: .dateTime)
                TextField("Address (optional)", text: $draft.address)
            }

            Section("Invitation Card") {
                let currentImageData = draft.imageData
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    if let currentImageData, let image = UIImage(data: currentImageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Label("Select Image (optional)", systemImage: "photo")
                    }
                }

                if draft.imageData != nil {
                    Button("Remove Image", role: .destructive) {
                        selectedImage = nil
                        draft.imageData = nil
                    }
                }
            }

            if let imageData = draft.imageData, let image = UIImage(data: imageData) {
                qrSection(image: image)
            }

            footer()
        }
        .onChange(of: selectedImage) { _, item in
            Task {
                guard let item else { return }
                do {
                    draft.imageData = try await item.loadTransferable(type: Data.self)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func qrSection(image: UIImage) -> some View {
        Section("QR Code Position") {
            TemplatePreview(
                image: image,
                qrPositionX: draft.qrPositionX,
                qrPositionY: draft.qrPositionY,
                qrSize: draft.qrSize
            )
            .frame(height: 300)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            LabeledContent("Horizontal Position") {
                Slider(value: positionBinding(for: \.qrPositionX), in: positionRange)
                    .accessibilityLabel("Horizontal Position")
                    .accessibilityValue(Text(draft.qrPositionX, format: .percent.precision(.fractionLength(0))))
            }

            LabeledContent("Vertical Position") {
                Slider(value: positionBinding(for: \.qrPositionY), in: positionRange)
                    .accessibilityLabel("Vertical Position")
                    .accessibilityValue(Text(draft.qrPositionY, format: .percent.precision(.fractionLength(0))))
            }

            LabeledContent("Size") {
                Slider(value: $draft.qrSize, in: 0.1...0.9) {
                    Text("Size")
                }
                .accessibilityValue(Text(draft.qrSize, format: .percent.precision(.fractionLength(0))))
                .onChange(of: draft.qrSize) { _, _ in draft.clampPosition() }
            }
        }
    }

    private var positionRange: ClosedRange<Double> {
        let halfSize = draft.qrSize / 2
        return halfSize...(1 - halfSize)
    }

    private func positionBinding(for keyPath: WritableKeyPath<EventDraft, Double>) -> Binding<Double> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }
}

private extension EventForm where Footer == EmptyView {
    init(draft: Binding<EventDraft>, errorMessage: Binding<String?>) {
        self.init(draft: draft, errorMessage: errorMessage) { EmptyView() }
    }
}

struct TemplatePreview: View {
    let image: UIImage
    let qrPositionX: Double
    let qrPositionY: Double
    let qrSize: Double

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / image.size.width,
                geometry.size.height / image.size.height
            )
            let imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let imageOffset = CGPoint(
                x: (geometry.size.width - imageSize.width) / 2,
                y: (geometry.size.height - imageSize.height) / 2
            )
            let rect = qrRect(
                in: imageSize,
                positionX: qrPositionX,
                positionY: qrPositionY,
                sizeFraction: qrSize
            )

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize.width, height: imageSize.height)
                    .offset(x: imageOffset.x, y: imageOffset.y)

                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.35))
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: rect.width * 0.3))
                            .foregroundStyle(.white)
                    }
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: imageOffset.x + rect.minX, y: imageOffset.y + rect.minY)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview("Create") {
    CreateEventView()
        .modelContainer(previewContainer)
}

#Preview("Edit") {
    @Previewable let container = previewContainer
    @Previewable let event = Event.mock

    EditEventView(event: event)
        .modelContainer(container)
}
