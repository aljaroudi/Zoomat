//
//  EventListView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

import SwiftUI
import SwiftData

struct EventListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.date, order: .reverse) private var events: [Event]
    @State private var showingCreateEvent = false

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Events",
            systemImage: "calendar.badge.plus",
            description: Text("Create your first event to start inviting people")
        )
    }

    private var eventList: some View {
        List {
            ForEach(events) { event in
                NavigationLink(value: event) {
                    EventRowView(event: event)
                }
            }
            .onDelete(perform: deleteEvents)
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
        }
    }

    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(events[index])
        }
    }
}

#Preview {
    NavigationStack {
        EventListView()
    }
    .modelContainer(previewContainer)
}
