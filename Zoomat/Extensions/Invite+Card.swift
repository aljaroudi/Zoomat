//
//  Invite+Card.swift
//  Zoomat
//
//  Created by Mohammed on 11/9/25.
//

import SwiftUI

extension DataSchema.Invite {
    func generateInvitationCard(with template: DataSchema.Template) -> UIImage? {
        guard let templateImage = UIImage(data: template.imageData),
              let qrImage = self.generateQRCode()
        else { return nil }

        let renderer = UIGraphicsImageRenderer(size: templateImage.size)

        return renderer.image { context in
            // Draw template background
            templateImage.draw(in: .zero)

            // Calculate QR size based on percentage of smallest dimension
            let minDimension = min(templateImage.size.width, templateImage.size.height)
            let qrWidth = minDimension * template.qrSize

            // Calculate QR position (template uses normalized 0-1 coordinates)
            let qrX = templateImage.size.width * template.qrPositionX - qrWidth / 2
            let qrY = templateImage.size.height * template.qrPositionY - qrWidth / 2

            // Draw QR code
            qrImage.draw(in: CGRect(x: qrX, y: qrY, width: qrWidth, height: qrWidth))
        }
    }
}
