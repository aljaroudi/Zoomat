//
//  QRScannerView.swift
//  Zoomat
//

import SwiftUI
import SwiftData
@preconcurrency import AVFoundation

struct QRScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allInvites: [Invite]
    @State private var scanner = QRScanner()
    @State private var checkInStatus: CheckInStatus = .waiting
    @State private var currentEventID: UUID?

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
        }
        .onAppear {
            scanner.onCodeScanned = handleScannedCode
        }
        .onDisappear {
            scanner.deactivate()
        }
        .onChange(of: checkInStatus) { _, status in
            if case .waiting = status {
                scanner.startScanning()
            }
        }
        .sensoryFeedback(trigger: checkInStatus) { _, status in
            switch status {
            case .recorded:
                .success
            case .maximumReached, .failure:
                .error
            case .waiting:
                nil
            }
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
                    showRetry: false
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
        case .recorded(let invite, let count):
            resultView(
                invite: invite,
                title: "Check-in #\(count) recorded",
                systemImage: "checkmark.circle.fill",
                color: .green
            )
        case .maximumReached(let invite):
            resultView(
                invite: invite,
                title: "Maximum Reached",
                systemImage: "hand.raised.fill",
                color: .red
            )
        case .failure(let reason):
            failureView(reason: reason)
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

    private func resultView(invite: Invite, title: LocalizedStringKey, systemImage: String, color: Color) -> some View {
        VStack(spacing: 24) {
            if let eventStats {
                statsBar(stats: eventStats)
            }

            Spacer()

            Text(invite.displayName)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.65)
                .foregroundStyle(.white)
                .padding(.horizontal)

            Image(systemName: systemImage)
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(invite.event.title)
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

    private func failureView(reason: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text("Invalid Code")
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
        HStack(spacing: 12) {
            StatsBadge(label: "Invitations", value: stats.invitations, color: .blue)
            StatsBadge(label: "Check-ins", value: stats.checkIns, color: .green)
            StatsBadge(label: "Unused", value: stats.unused, color: .orange)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func handleScannedCode(_ code: String) {
        guard let id = UUID(uuidString: code) else {
            showFailure("QR code format is invalid.")
            return
        }

        let descriptor = FetchDescriptor<Invite>(predicate: #Predicate { $0.id == id })
        do {
            guard let invite = try modelContext.fetch(descriptor).first else {
                showFailure("Invitation not found.")
                return
            }

            currentEventID = invite.event.id
            switch try invite.recordCheckIn(in: modelContext) {
            case .recorded(let count):
                checkInStatus = .recorded(invite: invite, count: count)
                UIAccessibility.post(
                    notification: .announcement,
                    argument: String(localized: "Check-in #\(count) recorded")
                )
            case .maximumReached:
                checkInStatus = .maximumReached(invite: invite)
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Maximum Reached"))
            }
        } catch {
            showFailure(error.localizedDescription)
        }
    }

    private func showFailure(_ reason: String) {
        checkInStatus = .failure(reason: reason)
        UIAccessibility.post(notification: .announcement, argument: reason)
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
    case recorded(invite: Invite, count: Int)
    case maximumReached(invite: Invite)
    case failure(reason: String)
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

@Observable
@MainActor
final class QRScanner: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private let sessionQueue = DispatchQueue(label: "com.zooma.qr-scanner")
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var previewView: UIView?
    private var isProcessing = false
    private var isActive = true

    private(set) var cameraState: CameraState = .loading
    var onCodeScanned: ((String) -> Void)?

    func setupCamera(on view: UIView) {
        guard isActive else { return }
        previewView = view
        cameraState = .loading

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera(on: view)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self, weak view] granted in
                DispatchQueue.main.async {
                    guard let self, let view, self.isActive else { return }
                    granted ? self.configureCamera(on: view) : (self.cameraState = .denied)
                }
            }
        case .denied, .restricted:
            cameraState = .denied
        @unknown default:
            cameraState = .failed(String(localized: "Unknown camera authorization state."))
        }
    }

    func retryCameraSetup() {
        guard let previewView else { return }
        isActive = true
        stopScanning()
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        setupCamera(on: previewView)
    }

    private func configureCamera(on view: UIView) {
        guard isActive else { return }
        guard let device = AVCaptureDevice.default(for: .video) else {
            cameraState = .unavailable
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()
            let session = AVCaptureSession()

            guard session.canAddInput(input), session.canAddOutput(output) else {
                cameraState = .failed(String(localized: "The camera could not be configured."))
                return
            }

            session.addInput(input)
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.frame = view.bounds
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)

            captureSession = session
            previewLayer = layer
            cameraState = .ready
            startScanning()
        } catch {
            cameraState = .failed(error.localizedDescription)
        }
    }

    func updatePreviewFrame(to bounds: CGRect) {
        previewLayer?.frame = bounds
    }

    func startScanning() {
        guard isActive, cameraState == .ready, let session = captureSession else { return }
        isProcessing = false
        sessionQueue.async {
            if !session.isRunning { session.startRunning() }
        }
    }

    func stopScanning() {
        guard let session = captureSession else { return }
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        onCodeScanned = nil
        stopScanning()
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        previewView = nil
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        Task { @MainActor [weak self] in
            self?.processScannedValue(value)
        }
    }

    private func processScannedValue(_ value: String) {
        guard isActive, !isProcessing else { return }
        isProcessing = true
        stopScanning()
        onCodeScanned?(value)
    }
}

#Preview {
    NavigationStack { QRScannerView() }
        .modelContainer(previewContainer)
}
