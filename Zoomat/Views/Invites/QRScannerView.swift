import SwiftUI
import SwiftData
import AVFoundation

struct QRScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var scanner = QRScanner()
    @State var checkInStatus: CheckInStatus = .waiting

    var body: some View {
        ZStack {
            // Camera preview as background
            QRScannerCameraView(scanner: scanner)
                .ignoresSafeArea()
                .blur(radius: 4)
                .opacity(0.3)

            // Status overlay
            VStack {
                Spacer()

                statusOverlay
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
            }
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

    @ViewBuilder
    private var statusOverlay: some View {
        switch checkInStatus {
        case .waiting:
            scanningView
        case .success(let invite):
            successView(invite: invite)
        case .alreadyCheckedIn(let invite, _):
            alreadyCheckedInView(invite: invite)
        case .failure(let reason):
            failureView(reason: reason)
        }
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            Text("Scanning for check-in code...")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func successView(invite: Invite) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text(invite.contact.name)
                    .font(.largeTitle)
                    .foregroundStyle(.white)

                Text(invite.event.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if invite.checkIns.count > 1 {
                Text("Check-in #\(invite.checkIns.count, format: .number)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

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
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.green)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func alreadyCheckedInView(invite: Invite) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text(invite.contact.name)
                    .font(.largeTitle)
                    .foregroundStyle(.white)

                Text("Already Checked In")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }

            if case .alreadyCheckedIn(_, let previousCount) = checkInStatus,
               previousCount > 0,
               let lastCheckIn = invite.checkIns.dropLast().last {
                VStack(spacing: 4) {
                    Text("Check-in #\(invite.checkIns.count, format: .number)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))

                    Text("Last check-in: \(lastCheckIn.created.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.vertical, 8)
            }

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
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.orange)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func failureView(reason: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Invalid Code")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

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
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.red)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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

        // Check status BEFORE adding new check-in
        let hadPreviousCheckIns = !invite.checkIns.isEmpty
        let previousCheckInCount = invite.checkIns.count

        // Create check-in (allow multiple check-ins)
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

enum CheckInStatus: Equatable {
    case waiting
    case success(invite: Invite)
    case alreadyCheckedIn(invite: Invite, previousCount: Int)
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        // Stop scanning to prevent multiple reads
        stopScanning()

        // Notify delegate
        onCodeScanned?(stringValue)
    }
}

#Preview("Scanning") {
    NavigationStack {
        QRScannerView()
    }
    .modelContainer(previewContainer)
}

#Preview("Success - First Check-In") {
    let container = previewContainer
    let context = container.mainContext

    let contact = Contact(name: "Alice Johnson", email: "alice@example.com")
    let event = Event(title: "Tech Conference 2024", subtitle: "Annual Meetup", date: .now)
    let invite = Invite(contact: contact, event: event)

    context.insert(contact)
    context.insert(event)
    context.insert(invite)

    var view = QRScannerView()
    view.checkInStatus = .success(invite: invite)

    return NavigationStack {
        view
    }
    .modelContainer(container)
}

#Preview("Already Checked In - 3rd Time") {
    let container = previewContainer
    let context = container.mainContext

    let contact = Contact(name: "Bob Smith", email: "bob@example.com")
    let event = Event(title: "Wedding Reception", subtitle: "Celebrating our union", date: .now)
    let invite = Invite(contact: contact, event: event)

    context.insert(contact)
    context.insert(event)
    context.insert(invite)

    // Add previous check-ins
    let checkIn1 = CheckIn(invite: invite)
    checkIn1.created = Date().addingTimeInterval(-3600 * 2) // 2 hours ago
    context.insert(checkIn1)

    let checkIn2 = CheckIn(invite: invite)
    checkIn2.created = Date().addingTimeInterval(-1800) // 30 minutes ago
    context.insert(checkIn2)

    let checkIn3 = CheckIn(invite: invite)
    context.insert(checkIn3)

    try? context.save()

    var view = QRScannerView()
    view.checkInStatus = .alreadyCheckedIn(invite: invite, previousCount: 2)

    return NavigationStack {
        view
    }
    .modelContainer(container)
}

#Preview("Already Checked In - 2nd Time") {
    let container = previewContainer
    let context = container.mainContext

    let contact = Contact(name: "Carol White", email: "carol@example.com")
    let event = Event(title: "Company Party", date: .now)
    let invite = Invite(contact: contact, event: event)

    context.insert(contact)
    context.insert(event)
    context.insert(invite)

    // Add previous check-in
    let checkIn1 = CheckIn(invite: invite)
    checkIn1.created = Date().addingTimeInterval(-2580) // 43 minutes ago
    context.insert(checkIn1)

    let checkIn2 = CheckIn(invite: invite)
    context.insert(checkIn2)

    try? context.save()

    var view = QRScannerView()
    view.checkInStatus = .alreadyCheckedIn(invite: invite, previousCount: 1)

    return NavigationStack {
        view
    }
    .modelContainer(container)
}

#Preview("Failure - Invalid Code") {
    var view = QRScannerView()
    view.checkInStatus = .failure(reason: "QR code format is invalid")

    return NavigationStack {
        view
    }
    .modelContainer(previewContainer)
}

#Preview("Failure - Not Found") {
    var view = QRScannerView()
    view.checkInStatus = .failure(reason: "Invite not found in system")

    return NavigationStack {
        view
    }
    .modelContainer(previewContainer)
}
