import AVFoundation
import Foundation

final class FairPlayResourceLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    private let certificateURL: URL
    private let licenseURL: URL
    private let contentID: Data
    private let authorization: String

    init(certificateURL: URL, licenseURL: URL, contentID: String, authorization: String) {
        self.certificateURL = certificateURL
        self.licenseURL = licenseURL
        self.contentID = Data(contentID.utf8)
        self.authorization = authorization
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard loadingRequest.request.url?.scheme == "skd" else { return false }
        Task { [weak self, weak loadingRequest] in
            guard let self, let loadingRequest else { return }
            do {
                let certificate = try await fetch(url: certificateURL)
                let spc = try loadingRequest.streamingContentKeyRequestData(
                    forApp: certificate,
                    contentIdentifier: contentID,
                    options: nil
                )
                var request = URLRequest(url: licenseURL)
                request.httpMethod = "POST"
                request.httpBody = spc
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                if !authorization.isEmpty {
                    request.setValue(authorization, forHTTPHeaderField: "Authorization")
                }
                let (response, metadata) = try await URLSession.shared.data(for: request)
                guard let http = metadata as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw FairPlayError.licenseRejected
                }
                let ckc = Data(base64Encoded: response) ?? response
                loadingRequest.dataRequest?.respond(with: ckc)
                loadingRequest.finishLoading()
            } catch {
                loadingRequest.finishLoading(with: error)
            }
        }
        return true
    }

    private func fetch(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        if !authorization.isEmpty {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        let (data, metadata) = try await URLSession.shared.data(for: request)
        guard let http = metadata as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FairPlayError.certificateRejected
        }
        return data
    }
}

private enum FairPlayError: Error {
    case certificateRejected
    case licenseRejected
}
