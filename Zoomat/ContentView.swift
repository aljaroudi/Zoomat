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
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating QR Scanner Button
            Button {
                showingQRScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding()
            .accessibilityLabel("Scan Invitation")
            .accessibilityHint("Opens the camera to record a check-in")
        }
        .fullScreenCover(isPresented: $showingQRScanner) {
            NavigationStack {
                QRScannerView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
