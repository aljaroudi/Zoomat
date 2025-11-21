//
//  QRScannerView.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct QRScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allInvites: [Invite]
    @State private var scanner = QRScanner()
    @State var checkInStatus: CheckInStatus = .waiting
    @State private var currentEventId: UUID?

    var body: some View {
        ZStack {
            // Camera preview as background
            QRScannerCameraView(scanner: scanner)
                .ignoresSafeArea()
                .opacity(0.4)

            // Status overlay - full screen
            statusOverlay
                .ignoresSafeArea()
        }
        .navigationTitle("Check In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            scanner.onCodeScanned = { code in
                handleScannedCode(code)
            }
        }
        .onChange(of: checkInStatus) { oldValue, newValue in
            // Resume scanning after showing result
            if case .waiting = newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scanner.startScanning()
                }
            }
        }
    }

    private var eventStats: (total: Int, checkedIn: Int, remaining: Int)? {
        guard let eventId = currentEventId else {
            return nil
        }

        let eventInvites = allInvites.filter { $0.event.id == eventId }
        let total = eventInvites.count
        let checkedIn = eventInvites.filter { !$0.checkIns.isEmpty }.count
        let remaining = total - checkedIn

        return (total, checkedIn, remaining)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch checkInStatus {
        case .waiting:
            scanningView
        case .success(let invite):
            successView(invite: invite)
        case .alreadyCheckedIn(let invite, _):
            alreadyCheckedInView(invite: invite)
        case .maxReached(let invite):
            maxReachedView(invite: invite)
        case .failure(_):
            failureView()
        }
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()

            // Show stats if we have a current event
            if let stats = eventStats {
                statsBar(stats: stats)
                    .padding(.bottom, 20)
            }

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            Text("Scanning for check-in code...")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Material.ultraThin)
    }

    private func successView(invite: Invite) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 80)

            // Show stats at top
            if let stats = eventStats {
                statsBar(stats: stats)
                    .padding(.bottom, 20)
            }

            // Contact name at top
            Text(invite.displayName)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)

            Spacer()

            // Center content
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                Text(invite.event.title)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Button at bottom
            Button {
                checkInStatus = .waiting
            } label: {
                Text("Continue Scanning")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .background(.green.opacity(0.6))
    }

    private func alreadyCheckedInView(invite: Invite) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 80)

            // Show stats at top
            if let stats = eventStats {
                statsBar(stats: stats)
                    .padding(.bottom, 20)
            }

            // Contact name at top
            Text(invite.displayName)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)

            Spacer()

            // Center content
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                Text("Already Checked In")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.95))

                if case .alreadyCheckedIn(_, let previousCount) = checkInStatus,
                   previousCount > 0,
                   let lastCheckIn = invite.checkIns.dropLast().last {
                    // x minutes ago ago
                    Text(lastCheckIn.created.formatted(.relative(presentation: .named)))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Spacer()

            // Button at bottom
            Button {
                checkInStatus = .waiting
            } label: {
                Text("Continue Scanning")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .background(.orange.opacity(0.6))
    }

    private func maxReachedView(invite: Invite) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 80)

            // Show stats at top
            if let stats = eventStats {
                statsBar(stats: stats)
                    .padding(.bottom, 20)
            }

            // Contact name at top
            Text(invite.displayName)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)

            Spacer()

            // Center content
            VStack(spacing: 20) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                Text("Maximum Reached")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.95))

                if let maxCheckIns = invite.maxCheckIns {
                    Text("^[\(maxCheckIns) check-in](inflect: true) allowed")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Spacer()

            // Button at bottom
            Button {
                checkInStatus = .waiting
            } label: {
                Text("Continue Scanning")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .background(.red.opacity(0.6))
    }

    private func failureView() -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Center content
            VStack(spacing: 20) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                Text("Invalid Code")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Button at bottom
            Button {
                checkInStatus = .waiting
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .background(.red.opacity(0.6))
    }

    @ViewBuilder
    private func statsBar(stats: (total: Int, checkedIn: Int, remaining: Int)) -> some View {
        HStack(spacing: 20) {
            StatsBadge(
                label: "Total",
                value: stats.total,
                color: .blue
            )

            StatsBadge(
                label: "Checked In",
                value: stats.checkedIn,
                color: .green
            )

            StatsBadge(
                label: "Remaining",
                value: stats.remaining,
                color: .orange
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func handleScannedCode(_ code: String) {
        guard let uuid = UUID(uuidString: code) else {
            checkInStatus = .failure(reason: "QR code format is invalid")
            return
        }

        // Find invite by ID
        let descriptor = FetchDescriptor<Invite>(
            predicate: #Predicate { $0.id == uuid }
        )

        guard let invite = try? modelContext.fetch(descriptor).first else {
            checkInStatus = .failure(reason: "Invite not found")
            return
        }

        // Track current event for stats
        currentEventId = invite.event.id

        // Check if max limit already reached BEFORE adding new check-in
        if invite.hasReachedLimit {
            // Haptic feedback for error
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)

            checkInStatus = .maxReached(invite: invite)
            return
        }

        // Check status BEFORE adding new check-in
        let hadPreviousCheckIns = !invite.checkIns.isEmpty
        let previousCheckInCount = invite.checkIns.count

        // Create check-in (allow multiple check-ins up to limit)
        let checkIn = CheckIn(invite: invite)
        modelContext.insert(checkIn)

        // Try to save to ensure the relationship is updated
        try? modelContext.save()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show appropriate status based on PREVIOUS state
        if hadPreviousCheckIns {
            checkInStatus = .alreadyCheckedIn(invite: invite, previousCount: previousCheckInCount)
        } else {
            checkInStatus = .success(invite: invite)
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
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

enum CheckInStatus: Equatable {
    case waiting
    case success(invite: Invite)
    case alreadyCheckedIn(invite: Invite, previousCount: Int)
    case maxReached(invite: Invite)
    case failure(reason: String)
}

// MARK: - QR Scanner Camera View
struct QRScannerCameraView: UIViewRepresentable {
    let scanner: QRScanner

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        scanner.setupCamera(on: view)
        scanner.startScanning()

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        DispatchQueue.main.async {
            scanner.updatePreviewFrame(to: uiView.bounds)
        }
    }

    func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        scanner.stopScanning()
    }
}

// QR Scanner Class
@Observable
class QRScanner: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isProcessing = false
    var onCodeScanned: ((String) -> Void)?

    func setupCamera(on view: UIView) {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()

        guard session.canAddOutput(metadataOutput) else {
            return
        }

        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.captureSession = session
        self.previewLayer = previewLayer
    }

    func updatePreviewFrame(to bounds: CGRect) {
        previewLayer?.frame = bounds
    }

    func startScanning() {
        isProcessing = false
        captureSession?.startRunning()
    }

    func stopScanning() {
        captureSession?.stopRunning()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Prevent duplicate scans
        guard !isProcessing else { return }

        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        // Mark as processing and stop scanning immediately
        isProcessing = true
        stopScanning()

        // Notify delegate
        onCodeScanned?(stringValue)
    }
}

#Preview {
    NavigationStack {
        QRScannerView()
    }
    .modelContainer(previewContainer)
}
