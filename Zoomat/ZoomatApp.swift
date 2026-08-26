//
//  ZoomatApp.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData

@main
struct ZoomatApp: App {
    private let modelContainerResult: Result<ModelContainer, Error>

    init() {
        let schema = Schema(DataSchema.models)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainerResult = .success(
                try ModelContainer(for: schema, configurations: [modelConfiguration])
            )
        } catch {
            modelContainerResult = .failure(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch modelContainerResult {
            case .success(let container):
                ContentView()
                    .modelContainer(container)
            case .failure(let error):
                ContentUnavailableView {
                    Label("Data Couldn’t Be Opened", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your data was left unchanged. Close and reopen Zoomat to try again.\n\n\(error.localizedDescription)")
                }
                .padding()
            }
        }
    }
}
