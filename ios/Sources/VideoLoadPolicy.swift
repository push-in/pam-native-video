struct VideoLoadRequest: Equatable {
    let source: String
    let drmScheme: Int64
    let drmCertificateUrl: String
    let drmLicenseUrl: String
    let drmContentId: String
    let drmAuthorization: String

    static let empty = VideoLoadRequest(source: "", drmScheme: 0)

    init(
        source: String,
        drmScheme: Int64,
        drmCertificateUrl: String = "",
        drmLicenseUrl: String = "",
        drmContentId: String = "",
        drmAuthorization: String = ""
    ) {
        self.source = source
        self.drmScheme = drmScheme
        self.drmCertificateUrl = drmCertificateUrl
        self.drmLicenseUrl = drmLicenseUrl
        self.drmContentId = drmContentId
        self.drmAuthorization = drmAuthorization
    }

    func transition(from previous: VideoLoadRequest) -> VideoLoadTransition {
        if source.isEmpty {
            return previous.source.isEmpty ? .unchanged : .clear
        }
        let unchanged = source == previous.source &&
            drmScheme == previous.drmScheme &&
            (drmScheme != PamVideoDrmScheme.fairPlay.rawValue || (
                drmCertificateUrl == previous.drmCertificateUrl &&
                drmLicenseUrl == previous.drmLicenseUrl &&
                drmContentId == previous.drmContentId &&
                drmAuthorization == previous.drmAuthorization
            ))
        return unchanged ? .unchanged : .load
    }
}

enum VideoLoadTransition: Int {
    case unchanged = 1
    case load = 2
    case clear = 3
}
