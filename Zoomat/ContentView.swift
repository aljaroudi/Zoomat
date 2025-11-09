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
            EventListView()
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }

            ContactListView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2")
                }

            TemplateListView()
                .tabItem {
                    Label("Templates", systemImage: "photo.on.rectangle")
                }
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating QR Scanner Button
            Button {
                showingQRScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding()
        }
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
