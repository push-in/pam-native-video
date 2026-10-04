enum PamVideoDrmScheme: Int64 {
    case widevine = 1
    case fairPlay = 2
    case clearKey = 3
}

enum VideoDrmPolicy {
    static func failureMessage(for rawScheme: Int64) -> String? {
        if rawScheme == 0 || PamVideoDrmScheme(rawValue: rawScheme) == .fairPlay { return nil }
        return "DRM scheme \(rawScheme) is unavailable on iOS; use FairPlay."
    }
}
