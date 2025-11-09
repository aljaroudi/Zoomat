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

            templateImage.draw(in: .zero)

            let qrWidth = templateImage.size.width * template.qrSize
            let qrX = templateImage.size.width * template.qrPositionX - qrWidth / 2
            let qrY = templateImage.size.height * template.qrPositionY - qrWidth / 2

            qrImage.draw(in: CGRect(x: qrX, y: qrY, width: qrWidth, height: qrWidth))
        }
    }
}
