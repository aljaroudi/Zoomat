//
//  CreateEventView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct CreateEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var templates: [DataSchema.Template]

    @State private var title = ""
    @State private var subtitle = ""
    @State private var date = Date()
    @State private var address = ""
    @State private var selectedTemplate: DataSchema.Template?

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                    TextField("Subtitle (optional)", text: $subtitle)
                    DatePicker("Date", selection: $date)
                    TextField("Address (optional)", text: $address)
                }

                Section("Template") {
                    if templates.isEmpty {
                        Text("No templates available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Template", selection: $selectedTemplate) {
                            Text("None").tag(nil as DataSchema.Template?)
                            ForEach(templates) { template in
                                Text(template.name).tag(template as DataSchema.Template?)
                            }
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
        }
    }

    private func createEvent() {
        let event = Event(
            title: title,
            subtitle: subtitle,
            date: date,
            address: address.isEmpty ? nil : address
        )
        event.template = selectedTemplate
        modelContext.insert(event)
        dismiss()
    }
}

struct EditEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var templates: [DataSchema.Template]

    @Bindable var event: DataSchema.Event

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

                Section("Template") {
                    if templates.isEmpty {
                        Text("No templates available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Template", selection: $event.template) {
                            Text("None").tag(nil as DataSchema.Template?)
                            ForEach(templates) { template in
                                Text(template.name).tag(template as DataSchema.Template?)
                            }
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
                        event.updated = Date()
                        dismiss()
                    }
                }
            }
        }
    }

    private func deleteEvent() {
        modelContext.delete(event)
        dismiss()
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
