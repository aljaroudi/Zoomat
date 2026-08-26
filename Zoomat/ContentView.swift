//
//  ContentView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingQRScanner = false
    @State private var scannerPassAlertTitle = ""
    @State private var scannerPassMessage: String?

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
        .onOpenURL(perform: importScannerPass)
        .alert(
            scannerPassAlertTitle,
            isPresented: Binding(
                get: { scannerPassMessage != nil },
                set: { if !$0 { scannerPassMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scannerPassMessage ?? "")
        }
        .tint(.orange)
    }

    private func importScannerPass(from url: URL) {
        do {
            let pass = try ScannerPass.read(from: url)
            let result = try ScannerPassImporter.importPass(pass, into: modelContext)
            scannerPassAlertTitle = String(localized: "Scanner Pass Imported")
            scannerPassMessage = String(
                localized: "\(result.eventTitle) is ready with \(result.invitationCount, format: .number) invitations. Counts are stored only on this phone."
            )
        } catch {
            scannerPassAlertTitle = String(localized: "Couldn’t Import Scanner Pass")
            scannerPassMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
