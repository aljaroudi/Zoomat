//
//  CreateTemplateView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData
import PhotosUI

struct CreateTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var qrPositionX: Double = 0.5
    @State private var qrPositionY: Double = 0.5
    @State private var qrSize: Double = 100

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Information") {
                    TextField("Name", text: $name)

                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        if let imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Select Image", systemImage: "photo")
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
                            Text("X Position: \(qrPositionX, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: $qrPositionX, in: 0...1)
                        }

                        VStack(alignment: .leading) {
                            Text("Y Position: \(qrPositionY, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: $qrPositionY, in: 0...1)
                        }

                        if let imageData, let uiImage = UIImage(data: imageData) {
                            let minDimension = min(uiImage.size.width, uiImage.size.height)
                            let percentage = qrSize / minDimension

                            VStack(alignment: .leading) {
                                Text("Size: \(percentage, format: .percent.precision(.fractionLength(0)))")
                                    .font(.caption)
                                Slider(value: Binding(
                                    get: { percentage },
                                    set: { qrSize = $0 * minDimension }
                                ), in: 0.1...1.0)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTemplate()
                    }
                    .disabled(name.isEmpty || imageData == nil)
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

    private func createTemplate() {
        guard let imageData else { return }

        let template = Template(
            name: name,
            imageData: imageData,
            qrPositionX: qrPositionX,
            qrPositionY: qrPositionY,
            qrSize: qrSize
        )

        modelContext.insert(template)
        dismiss()
    }
}

struct EditTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var template: Template
    @State private var selectedImage: PhotosPickerItem?
    @State private var newImageData: Data?

    var displayImageData: Data {
        newImageData ?? template.imageData
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Information") {
                    TextField("Name", text: $template.name)

                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        if let uiImage = UIImage(data: displayImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Section("QR Code Position") {
                    VStack {
                        if let uiImage = UIImage(data: displayImageData) {
                            TemplatePreview(
                                image: uiImage,
                                qrPositionX: template.qrPositionX,
                                qrPositionY: template.qrPositionY,
                                qrSize: template.qrSize
                            )
                            .frame(height: 300)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("X Position: \(template.qrPositionX, format: .percent.precision(.fractionLength(0)))")
                            .font(.caption)
                        Slider(value: $template.qrPositionX, in: 0...1)
                    }

                    VStack(alignment: .leading) {
                        Text("Y Position: \(template.qrPositionY, format: .percent.precision(.fractionLength(0)))")
                            .font(.caption)
                        Slider(value: $template.qrPositionY, in: 0...1)
                    }

                    if let uiImage = UIImage(data: displayImageData) {
                        let minDimension = min(uiImage.size.width, uiImage.size.height)
                        let percentage = template.qrSize / minDimension

                        VStack(alignment: .leading) {
                            Text("Size: \(percentage, format: .percent.precision(.fractionLength(0)))")
                                .font(.caption)
                            Slider(value: Binding(
                                get: { percentage },
                                set: { template.qrSize = $0 * minDimension }
                            ), in: 0.1...1.0)
                        }
                    }
                }

                Section {
                    Button("Delete Template", role: .destructive) {
                        deleteTemplate()
                    }
                }
            }
            .navigationTitle("Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let newImageData {
                            template.imageData = newImageData
                        }
                        template.updated = Date()
                        dismiss()
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

    private func deleteTemplate() {
        modelContext.delete(template)
        dismiss()
    }
}

#Preview("Create") {
    CreateTemplateView()
        .modelContainer(previewContainer)
}

#Preview("Edit") {
    let container = previewContainer
    let template = Template(
        name: "Wedding Template",
        imageData: UIImage(named: "MockTemplate")!.pngData()!,
        qrPositionX: 0.5,
        qrPositionY: 0.5,
        qrSize: 100
    )
    container.mainContext.insert(template)

    return EditTemplateView(template: template)
        .modelContainer(container)
}
