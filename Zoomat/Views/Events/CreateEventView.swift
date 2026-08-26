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
    var defaultAdditionalGuestCount = 0
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
        defaultAdditionalGuestCount = event.defaultAdditionalGuestCount
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
        event.defaultAdditionalGuestCount = defaultAdditionalGuestCount
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
    @ViewBuilder let footer: Footer

    init(
        draft: Binding<EventDraft>,
        errorMessage: Binding<String?>,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        _draft = draft
        _errorMessage = errorMessage
        self.footer = footer()
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $draft.title)
                TextField("Subtitle (optional)", text: $draft.subtitle)
                TextField("Address (optional)", text: $draft.address)
            }

            Section("Schedule") {
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
            }

            Section {
                Stepper(value: $draft.defaultAdditionalGuestCount, in: 0...10) {
                    LabeledContent(
                        "Additional Guests",
                        value: draft.defaultAdditionalGuestCount,
                        format: .number
                    )
                }
            } header: {
                Text("Guest Allowance")
            } footer: {
                Text("Shown during check-in for named invitations. Individual invitations can override this value.")
            }

            Section("Invitation Card") {
                let currentImageData = draft.imageData
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    if let currentImageData, let image = UIImage(data: currentImageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(.rect(cornerRadius: 8))
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

            footer
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
        Section {
            QRPlacementPreview(
                image: image,
                qrPositionX: $draft.qrPositionX,
                qrPositionY: $draft.qrPositionY,
                qrSize: draft.qrSize
            )
            .frame(height: 300)
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))

            LabeledContent("Size") {
                Slider(value: $draft.qrSize, in: 0.1...0.9) {
                    Text("Size")
                }
                .accessibilityValue(Text(draft.qrSize, format: .percent.precision(.fractionLength(0))))
            }

            Button("Center QR Code", systemImage: "scope") {
                draft.qrPositionX = 0.5
                draft.qrPositionY = 0.5
            }
        } header: {
            Text("QR Code")
        } footer: {
            Text("Drag the QR code on the preview to position it.")
        }
    }
}

private extension EventForm where Footer == EmptyView {
    init(draft: Binding<EventDraft>, errorMessage: Binding<String?>) {
        self.init(draft: draft, errorMessage: errorMessage) { EmptyView() }
    }
}

private struct QRPlacementPreview: View {
    let image: UIImage
    @Binding var qrPositionX: Double
    @Binding var qrPositionY: Double
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
            let interactionSide = max(rect.width, 44)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize.width, height: imageSize.height)
                    .offset(x: imageOffset.x, y: imageOffset.y)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)
                        .stroke(.orange, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)

                    Image(systemName: "qrcode")
                        .font(.system(size: rect.width * 0.3))
                        .foregroundStyle(.black)
                        .accessibilityHidden(true)
                }
                    .frame(width: interactionSide, height: interactionSide)
                    .contentShape(.rect)
                    .offset(
                        x: imageOffset.x + rect.midX - interactionSide / 2,
                        y: imageOffset.y + rect.midY - interactionSide / 2
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("qr-preview"))
                            .onChanged { value in
                                move(to: value.location, imageSize: imageSize, imageOffset: imageOffset)
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("QR Code Position")
                    .accessibilityValue(
                        "Horizontal \(qrPositionX, format: .percent.precision(.fractionLength(0))), vertical \(qrPositionY, format: .percent.precision(.fractionLength(0)))"
                    )
                    .accessibilityHint("Drag to reposition, or use the available actions.")
                    .accessibilityAction(named: "Move Left") {
                        move(byX: -0.05, y: 0, imageSize: imageSize)
                    }
                    .accessibilityAction(named: "Move Right") {
                        move(byX: 0.05, y: 0, imageSize: imageSize)
                    }
                    .accessibilityAction(named: "Move Up") {
                        move(byX: 0, y: -0.05, imageSize: imageSize)
                    }
                    .accessibilityAction(named: "Move Down") {
                        move(byX: 0, y: 0.05, imageSize: imageSize)
                    }
                    .accessibilityAction(named: "Center") {
                        qrPositionX = 0.5
                        qrPositionY = 0.5
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .coordinateSpace(name: "qr-preview")
            .onChange(of: qrSize) {
                move(byX: 0, y: 0, imageSize: imageSize)
            }
        }
    }

    private func move(to location: CGPoint, imageSize: CGSize, imageOffset: CGPoint) {
        let point = CGPoint(
            x: location.x - imageOffset.x,
            y: location.y - imageOffset.y
        )
        apply(normalizedQRPosition(in: imageSize, at: point, sizeFraction: qrSize))
    }

    private func move(byX deltaX: Double, y deltaY: Double, imageSize: CGSize) {
        let point = CGPoint(
            x: (qrPositionX + deltaX) * imageSize.width,
            y: (qrPositionY + deltaY) * imageSize.height
        )
        apply(normalizedQRPosition(in: imageSize, at: point, sizeFraction: qrSize))
    }

    private func apply(_ position: CGPoint) {
        qrPositionX = position.x
        qrPositionY = position.y
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
