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
    @State private var scanner = QRScanner()
    @State private var scannedInvite: Invite?
    @State private var errorMessage: String?
    @State private var showingCheckInSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerCameraView(scanner: scanner)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    if let errorMessage {
                        Text(errorMessage)
                            .padding()
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding()
                    }
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                scanner.onCodeScanned = { code in
                    handleScannedCode(code)
                }
            }
            .alert("Check-In Successful", isPresented: $showingCheckInSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let invite = scannedInvite {
                    Text("\(invite.contact.name) checked in to \(invite.event.title)")
                }
            }
        }
    }

    private func handleScannedCode(_ code: String) {
        guard let uuid = UUID(uuidString: code) else {
            errorMessage = "Invalid QR code"
            return
        }

        // Find invite by ID
        let descriptor = FetchDescriptor<Invite>(
            predicate: #Predicate { $0.id == uuid }
        )

        guard let invite = try? modelContext.fetch(descriptor).first else {
            errorMessage = "Invite not found"
            return
        }

        // Check if already checked in
        if !invite.checkIns.isEmpty {
            errorMessage = "\(invite.contact.name) is already checked in"
            return
        }

        // Create check-in
        let checkIn = CheckIn(invite: invite)
        modelContext.insert(checkIn)

        scannedInvite = invite
        showingCheckInSuccess = true
    }
}

// QR Scanner Camera View
struct QRScannerCameraView: UIViewRepresentable {
    let scanner: QRScanner

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        scanner.setupCamera(on: view)
        scanner.startScanning()

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

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

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Notify delegate
        onCodeScanned?(stringValue)
    }
}

#Preview {
    QRScannerView()
        .modelContainer(previewContainer)
}
