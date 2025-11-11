//
//  EventListView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct EventListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.date, order: .reverse) private var events: [Event]
    @State private var showingCreateEvent = false

    var groupedEvents: [String : [Event]] {
        Dictionary(grouping: events, by: \.relativeDate)
    }

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

    private var sortedHeaders: [String] {
        // Map headers to their earliest event date for proper sorting
        let headerDates = Dictionary(uniqueKeysWithValues:
                                        groupedEvents.map { header, events in
            (header, events.map(\.date).max() ?? .distantPast)
        }
        )

        return headerDates.sorted { $0.value > $1.value }.map { $0.key }
    }


    private var eventList: some View {
        List {
            ForEach(sortedHeaders, id: \.self) { date in
                Section(date.localizedCapitalized) {
                    ForEach(groupedEvents[date] ?? []) { event in
                        NavigationLink(value: event) {
                            EventRowView(event: event)
                        }
                    }
                    .onDelete { offsets in
                        deleteEvents(at: offsets, for: date)
                    }
                }
            }
        }
        .listStyle(.grouped)
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
        }
    }

    private func deleteEvents(at offsets: IndexSet, for date: String) {
        let eventsForDate = groupedEvents[date] ?? []
        for index in offsets {
            modelContext.delete(eventsForDate[index])
        }
    }
}

#Preview {
    NavigationStack {
        EventListView()
    }
    .modelContainer(previewContainer)
}
