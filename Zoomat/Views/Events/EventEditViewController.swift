//
//  EventEditViewController.swift
//  Zoomat
//
//  Created by Mohammed on 11/11/25.
//

import SwiftUI
import EventKit
import EventKitUI

struct EventEditViewController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let event: Event
    
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let eventStore = EKEventStore()
        let ekEvent = EKEvent(eventStore: eventStore)
        
        // Pre-populate event details
        ekEvent.title = event.title
        ekEvent.startDate = event.date
        ekEvent.endDate = event.expirationDate ?? event.date.addingTimeInterval(3600) // Default to 1 hour if no expiration
        ekEvent.notes = event.subtitle.isEmpty ? nil : event.subtitle
        ekEvent.location = event.address
        
        // Create the event edit view controller
        let eventEditViewController = EKEventEditViewController()
        eventEditViewController.event = ekEvent
        eventEditViewController.eventStore = eventStore
        eventEditViewController.editViewDelegate = context.coordinator
        
        return eventEditViewController
    }
    
    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    class Coordinator: NSObject, EKEventEditViewDelegate {
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }
        
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            isPresented = false
        }
    }
}

