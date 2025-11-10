//
//  TemplateListView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData
import PhotosUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Template.name) private var templates: [Template]
    @State private var showingCreateTemplate = false

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyState
                } else {
                    templateList
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateTemplate) {
                CreateTemplateView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Templates",
            systemImage: "photo.badge.plus",
            description: Text("Create invitation templates for your events")
        )
    }

    private var templateList: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 16)
            ], spacing: 16) {
                ForEach(templates) { template in
                    NavigationLink(value: template) {
                        TemplateCard(template: template)
                    }
                }
            }
            .padding()
        }
        .navigationDestination(for: Template.self) { template in
            TemplateDetailView(template: template)
        }
    }
}

struct TemplateCard: View {
    let template: Template

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let uiImage = UIImage(data: template.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(template.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("\(template.events.count) event\(template.events.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: Template
    @State private var showingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Template Preview
                if let uiImage = UIImage(data: template.imageData) {
                    TemplatePreview(
                        image: uiImage,
                        qrPositionX: template.qrPositionX,
                        qrPositionY: template.qrPositionY,
                        qrSize: template.qrSize
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)

                        LabeledContent("Name", value: template.name)
                        LabeledContent("QR X Position", value: "\(Int(template.qrPositionX * 100))%")
                        LabeledContent("QR Y Position", value: "\(Int(template.qrPositionY * 100))%")
                        LabeledContent("QR Size", value: "\(Int(template.qrSize * 100))%")
                    }

                    Divider()

                    // Events using this template
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Used in \(template.events.count) event\(template.events.count == 1 ? "" : "s")")
                            .font(.headline)

                        ForEach(template.events) { event in
                            NavigationLink(value: event) {
                                Text(event.title)
                            }
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTemplateView(template: template)
        }
    }
}

struct TemplatePreview: View {
    let image: UIImage
    let qrPositionX: Double
    let qrPositionY: Double
    let qrSize: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                // Calculate QR size based on smallest dimension of the preview
                let imageSize = image.size
                let scale = min(geometry.size.width / imageSize.width, geometry.size.height / imageSize.height)
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                let minDimension = min(scaledWidth, scaledHeight)
                let qrPixelSize = minDimension * qrSize

                // QR code placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: qrPixelSize * 0.3))
                            .foregroundStyle(.white)
                    }
                    .frame(width: qrPixelSize, height: qrPixelSize)
                    .position(
                        x: scaledWidth * qrPositionX,
                        y: scaledHeight * qrPositionY
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

#Preview("List") {
    TemplateListView()
        .modelContainer(previewContainer)
}

#Preview("Detail") {
    let container = previewContainer
    let template = Template(
        name: "Wedding Template",
        imageData: UIImage(named: "MockTemplate")!.pngData()!,
        qrPositionX: 0.5,
        qrPositionY: 0.5,
        qrSize: 0.3
    )
    container.mainContext.insert(template)

    return NavigationStack {
        TemplateDetailView(template: template)
    }
    .modelContainer(container)
}
