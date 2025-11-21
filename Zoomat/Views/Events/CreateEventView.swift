//
//  CreateEventView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData
import PhotosUI

enum EventDuration: String, CaseIterable, Identifiable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case oneDay
    case custom

    var id: String { rawValue }

    var timeInterval: TimeInterval? {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .oneDay: return 24 * 60 * 60
        case .custom: return nil
        }
    }

    var displayText: LocalizedStringKey {
        switch self {
        case .thirtyMinutes: "^[\(30) minute](inflect: true)"
        case .oneHour: "^[\(1) hour](inflect: true)"
        case .twoHours: "^[\(2) hour](inflect: true)"
        case .fourHours: "^[\(4) hour](inflect: true)"
        case .oneDay: "^[\(1) day](inflect: true)"
        case .custom: "Custom"
        }
    }
}

struct CreateEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subtitle = ""
    @State private var date = Date()
    @State private var address = ""
    @State private var hasExpiration = false
    @State private var selectedDuration: EventDuration = .oneHour
    @State private var customExpirationDate = Date()

    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var qrPositionX: Double = 0.5
    @State private var qrPositionY: Double = 0.5
    @State private var qrSize: Double = 0.3

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                    TextField("Subtitle (optional)", text: $subtitle)
                    DatePicker("Date", selection: $date)
                    TextField("Address (optional)", text: $address)
                }

                Section("Expiration") {
                    Toggle("Set expiration", isOn: $hasExpiration)

                    if hasExpiration {
                        Picker("Duration", selection: $selectedDuration) {
                            ForEach(EventDuration.allCases) { duration in
                                Text(duration.displayText).tag(duration)
                            }
                        }

                        if selectedDuration == .custom {
                            DatePicker("Expires at", selection: $customExpirationDate, in: date...)
                        }
                    }
                }

                Section("Invitation Card") {
                    let currentImageData = imageData
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        if let currentImageData, let uiImage = UIImage(data: currentImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Select Image (optional)", systemImage: "photo")
                        }
                    }
                }

                if imageData != nil {
                    Section("QR Code Position") {
                        VStack {
                            if let imageData, let uiImage = UIImage(data: imageData) {
                                TemplatePreview(
                                    image: uiImage,
                                    qrPositionX: qrPositionX,
                                    qrPositionY: qrPositionY,
                                    qrSize: qrSize
                                )
                                .frame(height: 300)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        VStack(alignment: .leading) {
                            Text("Horizontal Position: \(qrPositionX, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: $qrPositionX, in: 0...1)
                        }

                        VStack(alignment: .leading) {
                            Text("Vertical Position: \(qrPositionY, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: $qrPositionY, in: 0...1)
                        }

                        VStack(alignment: .leading) {
                            Text("Size: \(qrSize, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: $qrSize, in: 0.1...1.0)
                        }
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createEvent()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }

    private func createEvent() {
        let expirationDate: Date? = if hasExpiration {
            if selectedDuration == .custom {
                customExpirationDate
            } else if let interval = selectedDuration.timeInterval {
                date.addingTimeInterval(interval)
            } else {
                nil
            }
        } else {
            nil
        }

        let event = Event(
            title: title,
            subtitle: subtitle,
            date: date,
            expirationDate: expirationDate,
            address: address.isEmpty ? nil : address,
            imageData: imageData,
            qrPositionX: qrPositionX,
            qrPositionY: qrPositionY,
            qrSize: qrSize
        )
        modelContext.insert(event)
        try? modelContext.save()
        dismiss()
    }
}

struct EditEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var event: Event
    @State private var selectedImage: PhotosPickerItem?
    @State private var newImageData: Data?
    @State private var hasExpiration: Bool
    @State private var selectedDuration: EventDuration = .oneHour
    @State private var customExpirationDate: Date

    init(event: Event) {
        self.event = event
        _hasExpiration = State(initialValue: event.expirationDate != nil)
        _customExpirationDate = State(initialValue: event.expirationDate ?? Date())

        // Determine initial duration
        if let expiration = event.expirationDate {
            let duration = expiration.timeIntervalSince(event.date)
            if let matchingDuration = EventDuration.allCases.first(where: { $0.timeInterval == duration }) {
                _selectedDuration = State(initialValue: matchingDuration)
            } else {
                _selectedDuration = State(initialValue: .custom)
            }
        }
    }

    var displayImageData: Data? {
        newImageData ?? event.imageData
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $event.title)
                    TextField("Subtitle", text: $event.subtitle)
                    DatePicker("Date", selection: $event.date)
                    TextField("Address (optional)", text: Binding(
                        get: { event.address ?? "" },
                        set: { event.address = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Expiration") {
                    Toggle("Set expiration", isOn: $hasExpiration)

                    if hasExpiration {
                        Picker("Duration", selection: $selectedDuration) {
                            ForEach(EventDuration.allCases) { duration in
                                Text(duration.displayText).tag(duration)
                            }
                        }

                        if selectedDuration == .custom {
                            DatePicker("Expires at", selection: $customExpirationDate, in: event.date...)
                        }
                    }
                }

                Section("Invitation Card") {
                    let currentDisplayImageData = displayImageData
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        if let currentDisplayImageData, let uiImage = UIImage(data: currentDisplayImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Select Image (optional)", systemImage: "photo")
                        }
                    }

                    if displayImageData != nil {
                        Button("Remove Image", role: .destructive) {
                            newImageData = Data() // Empty data to signal removal
                        }
                    }
                }

                if displayImageData != nil && !displayImageData!.isEmpty {
                    Section("QR Code Position") {
                        VStack {
                            if let uiImage = UIImage(data: displayImageData!) {
                                TemplatePreview(
                                    image: uiImage,
                                    qrPositionX: event.qrPositionX,
                                    qrPositionY: event.qrPositionY,
                                    qrSize: event.qrSize
                                )
                                .frame(height: 300)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        VStack(alignment: .leading) {
                            Text("Horizontal Position: \(event.qrPositionX, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: $event.qrPositionX, in: 0...1)
                        }

                        VStack(alignment: .leading) {
                            Text("Vertical Position: \(event.qrPositionY, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: $event.qrPositionY, in: 0...1)
                        }

                        VStack(alignment: .leading) {
                            Text("Size: \(event.qrSize, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: $event.qrSize, in: 0.1...1.0)
                        }
                    }
                }

                Section {
                    Button("Delete Event", role: .destructive) {
                        deleteEvent()
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                    }
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        newImageData = data
                    }
                }
            }
        }
    }

    private func saveChanges() {
        if let newImageData {
            event.imageData = newImageData.isEmpty ? nil : newImageData
        }

        event.expirationDate = if hasExpiration {
            if selectedDuration == .custom {
                customExpirationDate
            } else if let interval = selectedDuration.timeInterval {
                event.date.addingTimeInterval(interval)
            } else {
                nil
            }
        } else {
            nil
        }

        event.updated = Date()
        try? modelContext.save()
        dismiss()
    }

    private func deleteEvent() {
        modelContext.delete(event)
        dismiss()
    }
}

struct TemplatePreview: View {
    let image: UIImage
    let qrPositionX: Double
    let qrPositionY: Double
    let qrSize: Double

    var body: some View {
        GeometryReader { geometry in
            let imageSize = image.size
            let scale = min(geometry.size.width / imageSize.width, geometry.size.height / imageSize.height)
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale

            // Calculate offset to center the image
            let offsetX = (geometry.size.width - scaledWidth) / 2
            let offsetY = (geometry.size.height - scaledHeight) / 2

            // Calculate QR size based on smallest dimension
            let minDimension = min(scaledWidth, scaledHeight)
            let qrPixelSize = minDimension * qrSize

            ZStack(alignment: .topLeading) {
                // Image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: scaledWidth, height: scaledHeight)
                    .offset(x: offsetX, y: offsetY)

                // QR code placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: qrPixelSize * 0.3))
                            .foregroundStyle(.white)
                    }
                    .frame(width: qrPixelSize, height: qrPixelSize)
                    .offset(
                        x: offsetX + (scaledWidth * qrPositionX) - (qrPixelSize / 2),
                        y: offsetY + (scaledHeight * qrPositionY) - (qrPixelSize / 2)
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }
}

#Preview("Create") {
    CreateEventView()
        .modelContainer(previewContainer)
}

#Preview("Edit") {
    @Previewable let container = previewContainer
    @Previewable let event: Event = Event.mock

    EditEventView(event: event)
        .modelContainer(container)
}
