import Foundation
import Photos

struct InvitationImageArtifact: Sendable {
    let data: Data
    let filename: String
}

enum InvitationPhotoSaveError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        String(localized: "Photo access is required to save invitations. Allow Zoomat to add photos in Settings.")
    }
}

enum InvitationPhotoSaver {
    static func save(_ artifacts: [InvitationImageArtifact]) async throws {
        let status = await authorizationStatus()
        guard status == .authorized || status == .limited else {
            throw InvitationPhotoSaveError.permissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            for artifact in artifacts {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = artifact.filename
                request.addResource(with: .photo, data: artifact.data, options: options)
            }
        }
    }

    private static func authorizationStatus() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}
