//
//  QRScannerView.swift
//  Zoomat
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct QRScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allInvites: [Invite]
    @State private var scanner = QRScanner()
    @State private var checkInStatus: CheckInStatus = .waiting
    @State private var currentEventID: UUID?
    @State private var showingScannerPassImporter = false
    @State private var scannerPassAlertTitle = ""
    @State private var scannerPassMessage: String?

    var body: some View {
        ZStack {
            QRScannerCameraView(scanner: scanner)
                .ignoresSafeArea()
                .opacity(0.45)

            statusOverlay
                .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("Check In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Import Scanner Pass", systemImage: "square.and.arrow.down") {
                    scanner.stopScanning()
                    showingScannerPassImporter = true
                }
            }
        }
        .onAppear {
            scanner.onCodeScanned = handleScannedCode
            scanner.setSuspended(scenePhase != .active)
        }
        .onDisappear {
            scanner.deactivate()
        }
        .onChange(of: checkInStatus) { _, status in
            if case .waiting = status {
                scanner.startScanning()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            scanner.setSuspended(phase != .active)
        }
        .sensoryFeedback(trigger: checkInStatus) { _, status in
            switch status {
            case .recorded:
                .success
            case .failure:
                .error
            case .waiting:
                nil
            }
        }
        .fileImporter(
            isPresented: $showingScannerPassImporter,
            allowedContentTypes: [.zoomatScannerPass],
            allowsMultipleSelection: false,
            onCompletion: handleScannerPassSelection
        )
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
    }

    private var eventStats: (invitations: Int, checkIns: Int, unused: Int)? {
        guard let currentEventID else { return nil }
        let invitations = allInvites.filter { $0.event.id == currentEventID }
        return (
            invitations.count,
            invitations.reduce(0) { $0 + $1.checkIns.count },
            invitations.filter(\.checkIns.isEmpty).count
        )
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch checkInStatus {
        case .waiting:
            switch scanner.cameraState {
            case .loading:
                cameraMessage("Preparing Camera", systemImage: "camera", showRetry: false)
            case .ready:
                scanningView
            case .denied:
                cameraMessage(
                    "Camera Access Denied",
                    description: String(localized: "Allow camera access in Settings to scan invitations."),
                    systemImage: "camera.fill.badge.xmark",
                    showRetry: true
                )
            case .unavailable:
                cameraMessage(
                    "Camera Unavailable",
                    description: String(localized: "A camera is required to scan invitations."),
                    systemImage: "camera.fill.badge.ellipsis",
                    showRetry: true
                )
            case .failed(let message):
                cameraMessage(
                    "Camera Setup Failed",
                    description: message,
                    systemImage: "exclamationmark.triangle",
                    showRetry: true
                )
            }
        case .recorded(let result):
            resultView(
                result: result,
                title: "Check-in #\(result.checkInCount, format: .number) recorded on this phone",
                systemImage: "checkmark.circle.fill",
                color: .green
            )
        case .failure(let title, let reason):
            failureView(title: title, reason: reason)
        }
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()

            if let eventStats {
                statsBar(stats: eventStats)
                    .padding(.bottom, 20)
            }

            Image(systemName: "qrcode.viewfinder")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text("Scanning for check-in code...")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func resultView(
        result: ScannerCheckInResult,
        title: LocalizedStringKey,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(spacing: 24) {
            if let eventStats {
                statsBar(stats: eventStats)
            }

            Spacer()

            Text(result.invitationName)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.65)
                .foregroundStyle(.white)
                .padding(.horizontal)

            if let allowanceText = additionalGuestAllowanceText(for: result.additionalGuestCount) {
                Label {
                    Text(allowanceText)
                        .font(.headline)
                } icon: {
                    Image(systemName: "person.2")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            }

            Image(systemName: systemImage)
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(result.eventTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            continueButton(color: color)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .background(color.opacity(0.65))
    }

    private func failureView(title: String, reason: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text(reason)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()
            continueButton(color: .red)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .background(.red.opacity(0.65))
    }

    private func continueButton(color: Color) -> some View {
        Button("Continue Scanning") {
            checkInStatus = .waiting
        }
        .font(.headline)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding()
        .background(.white)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func cameraMessage(
        _ title: LocalizedStringKey,
        description: String? = nil,
        systemImage: String,
        showRetry: Bool
    ) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description { Text(description) }
        } actions: {
            if showRetry {
                Button("Try Again") { scanner.retryCameraSetup() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func statsBar(stats: (invitations: Int, checkIns: Int, unused: Int)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On This Phone")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatsBadge(label: "Invitations", value: stats.invitations, color: .blue)
                StatsBadge(label: "Check-ins", value: stats.checkIns, color: .green)
                StatsBadge(label: "Unused", value: stats.unused, color: .orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func handleScannedCode(_ code: String) {
        do {
            let result = try InviteCodeProcessor(context: modelContext).process(code)
            currentEventID = result.eventID
            checkInStatus = .recorded(result)
            UIAccessibility.post(
                notification: .announcement,
                argument: recordedAnnouncement(for: result)
            )
        } catch let error as InviteCodeProcessingError {
            showFailure(title: error.title, reason: error.localizedDescription)
        } catch {
            let fallback = InviteCodeProcessingError.checkInFailed
            showFailure(title: fallback.title, reason: fallback.localizedDescription)
        }
    }

    private func handleScannerPassSelection(_ selection: Result<[URL], Error>) {
        defer {
            if case .waiting = checkInStatus {
                scanner.startScanning()
            }
        }

        do {
            guard let url = try selection.get().first else { return }
            let pass = try ScannerPass.read(from: url)
            let result = try ScannerPassImporter.importPass(pass, into: modelContext)
            currentEventID = pass.event.id
            checkInStatus = .waiting
            scannerPassAlertTitle = String(localized: "Scanner Pass Imported")
            scannerPassMessage = String(
                localized: "\(result.eventTitle) is ready with \(result.invitationCount, format: .number) invitations. Counts are stored only on this phone."
            )
        } catch let error as CocoaError where error.code == .userCancelled {
            return
        } catch {
            scannerPassAlertTitle = String(localized: "Couldn’t Import Scanner Pass")
            scannerPassMessage = error.localizedDescription
        }
    }

    private func showFailure(title: String, reason: String) {
        checkInStatus = .failure(title: title, reason: reason)
        UIAccessibility.post(notification: .announcement, argument: reason)
    }

    private func recordedAnnouncement(for result: ScannerCheckInResult) -> String {
        guard let additionalGuestCount = result.additionalGuestCount else {
            return String(localized: "Check-in #\(result.checkInCount, format: .number) recorded on this phone")
        }

        switch additionalGuestCount {
        case 0:
            return String(localized: "Check-in #\(result.checkInCount, format: .number) recorded on this phone. No additional guests.")
        case 1:
            return String(localized: "Check-in #\(result.checkInCount, format: .number) recorded on this phone. \(additionalGuestCount, format: .number) additional guest allowed.")
        default:
            return String(localized: "Check-in #\(result.checkInCount, format: .number) recorded on this phone. \(additionalGuestCount, format: .number) additional guests allowed.")
        }
    }

    private func additionalGuestAllowanceText(for count: Int?) -> LocalizedStringResource? {
        guard let count else { return nil }
        switch count {
        case 0:
            return "No additional guests"
        case 1:
            return "\(count, format: .number) additional guest"
        default:
            return "\(count, format: .number) additional guests"
        }
    }
}

struct StatsBadge: View {
    let label: LocalizedStringKey
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value, format: .number)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

enum CheckInStatus: Equatable {
    case waiting
    case recorded(ScannerCheckInResult)
    case failure(title: String, reason: String)
}

enum CameraState: Equatable {
    case loading
    case ready
    case denied
    case unavailable
    case failed(String)
}

struct QRScannerCameraView: UIViewRepresentable {
    let scanner: QRScanner

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        scanner.setupCamera(on: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        scanner.updatePreviewFrame(to: uiView.bounds)
    }

    func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        scanner.deactivate()
    }
}

#Preview {
    NavigationStack { QRScannerView() }
        .modelContainer(previewContainer)
}
