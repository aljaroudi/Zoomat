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

        // Calculate QR size based on percentage of smallest dimension
        let minDimension = min(eventImage.size.width, eventImage.size.height)
        let qrWidth = minDimension * event.qrSize
        let qrSize = CGSize(width: qrWidth, height: qrWidth)

        guard let qrImage = generateQRCode(size: qrSize) else {
            return eventImage
        }

        // Create renderer with event image size
        let renderer = UIGraphicsImageRenderer(size: eventImage.size)

        return renderer.image { context in
            // Draw event image background
            eventImage.draw(at: .zero)

            // Calculate QR position (event uses normalized 0-1 coordinates)
            let qrX = eventImage.size.width * event.qrPositionX - qrWidth / 2
            let qrY = eventImage.size.height * event.qrPositionY - qrWidth / 2

            // Draw QR code
            let qrRect = CGRect(
                x: qrX,
                y: qrY,
                width: qrWidth,
                height: qrWidth
            )
            qrImage.draw(in: qrRect)
        }
    }

    /// Generates an invitation card with embedded metadata (readable in iOS Photos app)
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
