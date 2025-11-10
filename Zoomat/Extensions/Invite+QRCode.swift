//
//  Invite+QRCode.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import UIKit
import CoreImage
import SwiftUI

extension Invite {
    /// Generates a QR code image for this invite
    func generateQRCode(size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
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

    /// Generates an invitation card by overlaying the QR code on the template
    func generateInvitationCard() -> UIImage? {
        guard let template = event.template else {
            // If no template, just return the QR code
            return generateQRCode()
        }

        guard let templateImage = UIImage(data: template.imageData) else {
            return nil
        }

        // Generate QR code at the template's specified size
        let qrSize = CGSize(width: template.qrSize, height: template.qrSize)
        guard let qrImage = generateQRCode(size: qrSize) else {
            return templateImage
        }

        // Create renderer with template size
        let renderer = UIGraphicsImageRenderer(size: templateImage.size)

        return renderer.image { context in
            // Draw template background
            templateImage.draw(at: .zero)

            // Calculate QR position (template uses normalized 0-1 coordinates)
            let qrX = templateImage.size.width * template.qrPositionX - template.qrSize / 2
            let qrY = templateImage.size.height * template.qrPositionY - template.qrSize / 2

            // Draw QR code
            let qrRect = CGRect(
                x: qrX,
                y: qrY,
                width: template.qrSize,
                height: template.qrSize
            )
            qrImage.draw(in: qrRect)
        }
    }
}
