//
//  ContentView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingQRScanner = false

    var body: some View {
        TabView {
            EventListView(showingQRScanner: $showingQRScanner)
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }

            ContactListView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2")
                }
        }
        .fullScreenCover(isPresented: $showingQRScanner) {
            NavigationStack {
                QRScannerView()
            }
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
