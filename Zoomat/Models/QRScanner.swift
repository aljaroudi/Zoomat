@preconcurrency import AVFoundation
import Observation
import OSLog
import UIKit

enum QRScannerSessionEvent: Equatable {
    case ready
    case code(String)
    case denied
    case unavailable
    case failed(String)
}

@Observable
@MainActor
final class QRScanner: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Zoomat",
        category: "QRScanner"
    )

    private let sessionQueue = DispatchQueue(label: "com.zooma.qr-scanner")
    private var captureSession: AVCaptureSession?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var previewView: UIView?
    private var notificationObservers: [NSObjectProtocol] = []
    private(set) var generation: UInt64 = 0
    private var isProcessing = false
    private var isActive = true
    private var isSuspended = true
    private var wantsScanning = true

    private(set) var cameraState: CameraState = .loading
    var onCodeScanned: ((String) -> Void)?

    func setupCamera(on view: UIView) {
        guard isActive else { return }
        previewView = view
        beginSession()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera(on: view, generation: generation)
        case .notDetermined:
            let requestedGeneration = generation
            AVCaptureDevice.requestAccess(for: .video) { [weak self, weak view] granted in
                Task { @MainActor in
                    guard let self,
                          let view,
                          self.isActive,
                          self.generation == requestedGeneration else { return }
                    if granted {
                        self.configureCamera(on: view, generation: requestedGeneration)
                    } else {
                        self.handle(.denied, generation: requestedGeneration)
                    }
                }
            }
        case .denied, .restricted:
            handle(.denied, generation: generation)
        @unknown default:
            handle(
                .failed(String(localized: "Unknown camera authorization state.")),
                generation: generation
            )
        }
    }

    func retryCameraSetup() {
        guard let previewView, isActive else { return }
        teardownSession()
        setupCamera(on: previewView)
    }

    func updatePreviewFrame(to bounds: CGRect) {
        previewLayer?.frame = bounds
    }

    func startScanning() {
        guard isActive else { return }
        wantsScanning = true
        isProcessing = false
        guard !isSuspended,
              cameraState == .ready,
              let session = captureSession else { return }
        start(session)
    }

    func stopScanning() {
        wantsScanning = false
        if let captureSession { stop(captureSession) }
    }

    func setSuspended(_ suspended: Bool) {
        guard isActive, isSuspended != suspended else { return }
        isSuspended = suspended
        if suspended {
            if let captureSession { stop(captureSession) }
        } else if wantsScanning,
                  cameraState == .ready,
                  let captureSession {
            start(captureSession)
        }
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        wantsScanning = false
        isProcessing = true
        generation &+= 1
        onCodeScanned = nil
        teardownSession()
        previewView = nil
        Self.logger.info("Scanner deactivated")
    }

    func handle(_ event: QRScannerSessionEvent, generation eventGeneration: UInt64) {
        guard isActive, eventGeneration == generation else {
            Self.logger.debug("Ignored stale scanner event")
            return
        }

        switch event {
        case .ready:
            cameraState = .ready
            if wantsScanning, !isSuspended, let captureSession {
                start(captureSession)
            }
        case .code(let value):
            guard wantsScanning, !isSuspended, !isProcessing, cameraState == .ready else {
                Self.logger.debug("Ignored duplicate scanner callback")
                return
            }
            isProcessing = true
            wantsScanning = false
            if let captureSession { stop(captureSession) }
            onCodeScanned?(value)
        case .denied:
            wantsScanning = false
            cameraState = .denied
            Self.logger.error("Camera permission denied")
        case .unavailable:
            wantsScanning = false
            cameraState = .unavailable
            Self.logger.error("Camera unavailable")
        case .failed(let message):
            wantsScanning = false
            cameraState = .failed(message)
            if let captureSession { stop(captureSession) }
            Self.logger.error("Camera entered recoverable failure state")
        }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        Task { @MainActor [weak self, weak output] in
            guard let self, output === self.metadataOutput else { return }
            self.handle(.code(value), generation: self.generation)
        }
    }

    private func beginSession() {
        generation &+= 1
        cameraState = .loading
        isProcessing = false
        wantsScanning = true
        Self.logger.info("Configuring scanner session")
    }

    private func configureCamera(on view: UIView, generation: UInt64) {
        guard isActive, self.generation == generation else { return }
        guard let device = AVCaptureDevice.default(for: .video) else {
            handle(.unavailable, generation: generation)
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()
            let session = AVCaptureSession()

            session.beginConfiguration()
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                handle(
                    .failed(String(localized: "The camera could not be configured.")),
                    generation: generation
                )
                return
            }

            session.addInput(input)
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)

            guard output.availableMetadataObjectTypes.contains(.qr) else {
                session.commitConfiguration()
                handle(
                    .failed(String(localized: "This camera cannot scan QR codes.")),
                    generation: generation
                )
                return
            }

            output.metadataObjectTypes = [.qr]
            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.frame = view.bounds
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)

            captureSession = session
            metadataOutput = output
            previewLayer = layer
            observe(session, generation: generation)
            handle(.ready, generation: generation)
        } catch {
            handle(
                .failed(String(localized: "The camera could not be configured.")),
                generation: generation
            )
        }
    }

    private func observe(_ session: AVCaptureSession, generation: UInt64) {
        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(
                forName: .AVCaptureSessionRuntimeError,
                object: session,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handle(
                        .failed(String(localized: "The camera stopped unexpectedly. Please try again.")),
                        generation: generation
                    )
                }
            },
            center.addObserver(
                forName: .AVCaptureSessionWasInterrupted,
                object: session,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handle(
                        .failed(String(localized: "The camera was interrupted. Please try again.")),
                        generation: generation
                    )
                }
            }
        ]
    }

    private func teardownSession() {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers.removeAll()
        metadataOutput?.setMetadataObjectsDelegate(nil, queue: nil)
        metadataOutput = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        if let captureSession { stop(captureSession) }
        captureSession = nil
    }

    private func start(_ session: AVCaptureSession) {
        sessionQueue.async {
            if !session.isRunning { session.startRunning() }
        }
    }

    private func stop(_ session: AVCaptureSession) {
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }
}
