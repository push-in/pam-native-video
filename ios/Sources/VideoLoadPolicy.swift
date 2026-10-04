struct VideoLoadRequest: Equatable {
    let source: String
    let drmScheme: Int64

    static let empty = VideoLoadRequest(source: "", drmScheme: 0)

    func transition(from previous: VideoLoadRequest) -> VideoLoadTransition {
        guard self != previous else { return .unchanged }
        return source.isEmpty ? .clear : .load
    }
}

enum VideoLoadTransition: Int {
    case unchanged = 1
    case load = 2
    case clear = 3
}
