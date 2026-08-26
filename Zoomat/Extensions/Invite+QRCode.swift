//
//  Invite+QRCode.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import UIKit
import CoreImage
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

nonisolated func qrRect(
    in imageSize: CGSize,
    positionX: Double,
    positionY: Double,
    sizeFraction: Double
) -> CGRect {
    let minimumDimension = min(imageSize.width, imageSize.height)
    let side = minimumDimension * min(max(sizeFraction, 0.1), 1)
    let proposedX = imageSize.width * min(max(positionX, 0), 1) - side / 2
    let proposedY = imageSize.height * min(max(positionY, 0), 1) - side / 2

    return CGRect(
        x: min(max(proposedX, 0), max(imageSize.width - side, 0)),
        y: min(max(proposedY, 0), max(imageSize.height - side, 0)),
        width: side,
        height: side
    )
}

nonisolated func normalizedQRPosition(
    in imageSize: CGSize,
    at point: CGPoint,
    sizeFraction: Double
) -> CGPoint {
    guard imageSize.width > 0, imageSize.height > 0 else {
        return CGPoint(x: 0.5, y: 0.5)
    }

    let side = min(imageSize.width, imageSize.height) * min(max(sizeFraction, 0.1), 1)
    let centerX = min(max(point.x, side / 2), imageSize.width - side / 2)
    let centerY = min(max(point.y, side / 2), imageSize.height - side / 2)

    return CGPoint(x: centerX / imageSize.width, y: centerY / imageSize.height)
}

extension Invite {
    /// Generates a QR code image for this invite
    private func generateQRCode(size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        let data = qrToken.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up (QR codes generate small by default)
        let transform = CGAffineTransform(
            scaleX: size.width / ciImage.extent.width,
            y: size.height / ciImage.extent.height
        )
        let scaledImage = ciImage.transformed(by: transform)

        // Convert to UIImage with proper rendering
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Generates an invitation card by overlaying the QR code on the event image
    func generateInvitationCard() -> UIImage? {
        guard let imageData = event.imageData,
              let eventImage = UIImage(data: imageData) else {
            // If no image, just return the QR code
            return generateQRCode()
        }

        let rect = qrRect(
            in: eventImage.size,
            positionX: event.qrPositionX,
            positionY: event.qrPositionY,
            sizeFraction: event.qrSize
        )

        guard let qrImage = generateQRCode(size: rect.size) else {
            return eventImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: eventImage.size, format: format)

        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            eventImage.draw(at: .zero)
            context.cgContext.interpolationQuality = .none
            qrImage.draw(in: rect)
        }
    }

    /// Generates an invitation card with metadata preserved when the image is shared.
    func generateInvitationCardWithMetadata() -> Data? {
        guard let image = generateInvitationCard(),
              let cgImage = image.cgImage else {
            return nil
        }

        // Create metadata dictionary
        let metadata: [String: Any] = [
            kCGImagePropertyIPTCDictionary as String: [
                kCGImagePropertyIPTCCaptionAbstract as String: displayName,
                kCGImagePropertyIPTCKeywords as String: [event.title, "Zoomat Invitation"],
                kCGImagePropertyIPTCCreatorContactInfo as String: "Zoomat"
            ],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifUserComment as String: "Invitation for \(displayName) - \(event.title)"
            ]
        ]

        // Create image data with metadata
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }
}
