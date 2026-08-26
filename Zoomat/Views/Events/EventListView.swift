//
//  EventListView.swift
//  Zoomat
//

import SwiftUI
import SwiftData

struct EventListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @State private var showingCreateEvent = false
    @State private var eventToDelete: Event?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                Group {
                    if events.isEmpty {
                        emptyState
                    } else {
                        eventList(now: timeline.date)
                    }
                }
            }
            .navigationTitle("Events")
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Event")
                }
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView()
            }
            .confirmationDialog(
                "Delete this event and all its invitations and check-ins?",
                isPresented: Binding(
                    get: { eventToDelete != nil },
                    set: { if !$0 { eventToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Event", role: .destructive, action: deleteEvent)
                Button("Cancel", role: .cancel) { eventToDelete = nil }
            }
            .saveErrorAlert(message: $errorMessage)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Events", systemImage: "calendar.badge.plus")
        } description: {
            Text("Create your first event to start inviting people")
        } actions: {
            Button("Create Event") { showingCreateEvent = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func eventList(now: Date) -> some View {
        List {
            ForEach(EventTimeline.groups(for: events, now: now), id: \.day) { group in
                Section(group.day.formatted(.dateTime.weekday(.wide).month(.wide).day())) {
                    ForEach(group.events) { event in
                        NavigationLink(value: event) {
                            EventRowView(event: event, now: now)
                        }
                        .swipeActions(allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                eventToDelete = event
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.grouped)
    }

    private func deleteEvent() {
        guard let eventToDelete else { return }
        modelContext.delete(eventToDelete)

        do {
            try modelContext.save()
            self.eventToDelete = nil
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EventListView()
        .modelContainer(previewContainer)
}
