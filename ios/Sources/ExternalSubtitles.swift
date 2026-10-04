import Foundation

struct SubtitleCue: Sendable {
    let startMillis: Int64
    let endMillis: Int64
    let text: String
}

struct ExternalSubtitles: Sendable {
    static let maximumBytes = 2 * 1024 * 1024
    fileprivate static let maximumCues = 10_000
    let cues: [SubtitleCue]
    private let maximumEndThroughCue: [Int64]

    init(data: Data, pathExtension: String) throws {
        guard data.count <= Self.maximumBytes else { throw SubtitleError.tooLarge }
        guard let source = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw SubtitleError.invalidEncoding
        }
        let parsed: [SubtitleCue]
        switch pathExtension.lowercased() {
        case "vtt", "srt": parsed = Self.parseText(source)
        case "ttml", "xml": parsed = try Self.parseTTML(data)
        default: throw SubtitleError.unsupportedFormat
        }
        guard !parsed.isEmpty, parsed.count <= Self.maximumCues else { throw SubtitleError.invalidCues }
        let sorted = parsed.sorted { $0.startMillis < $1.startMillis }
        cues = sorted
        var maximumEnd: Int64 = 0
        maximumEndThroughCue = sorted.map { cue in
            maximumEnd = max(maximumEnd, cue.endMillis)
            return maximumEnd
        }
    }

    func text(at milliseconds: Int64) -> String? {
        var lower = 0
        var upper = cues.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if cues[middle].startMillis <= milliseconds { lower = middle + 1 } else { upper = middle }
        }
        guard lower > 0 else { return nil }
        var index = lower - 1
        while true {
            let cue = cues[index]
            if cue.endMillis > milliseconds { return cue.text }
            guard index > 0, maximumEndThroughCue[index - 1] > milliseconds else { return nil }
            index -= 1
        }
    }

    static func load(from url: URL) async throws -> ExternalSubtitles {
        let data: Data
        if url.isFileURL {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var buffer = Data()
            while buffer.count <= maximumBytes {
                let count = min(64 * 1024, maximumBytes + 1 - buffer.count)
                let chunk = try handle.read(upToCount: count) ?? Data()
                if chunk.isEmpty { break }
                buffer.append(chunk)
            }
            data = buffer
        } else {
            guard url.scheme == "https" else { throw SubtitleError.invalidURL }
            let (bytes, response) = try await URLSession.shared.bytes(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  response.url?.scheme == "https" else {
                bytes.task.cancel()
                throw SubtitleError.httpFailure
            }
            guard response.expectedContentLength < 0 || response.expectedContentLength <= maximumBytes else {
                bytes.task.cancel()
                throw SubtitleError.tooLarge
            }
            var buffer = Data()
            buffer.reserveCapacity(min(maximumBytes, max(0, Int(response.expectedContentLength))))
            for try await byte in bytes {
                if Task.isCancelled { bytes.task.cancel(); throw CancellationError() }
                guard buffer.count < maximumBytes else { bytes.task.cancel(); throw SubtitleError.tooLarge }
                buffer.append(byte)
            }
            data = buffer
        }
        return try ExternalSubtitles(data: data, pathExtension: url.pathExtension)
    }

    private static func parseText(_ source: String) -> [SubtitleCue] {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
        var rows: [SubtitleCue] = []
        var block: [String] = []
        func flush() {
            defer { block.removeAll(keepingCapacity: true) }
            guard let index = block.firstIndex(where: { $0.contains("-->") }) else { return }
            let ends = block[index].components(separatedBy: "-->")
            guard ends.count == 2,
                  let start = timestamp(String(ends[0]).trimmingCharacters(in: .whitespaces)),
                  let endToken = ends[1].split(whereSeparator: \.isWhitespace).first,
                  let end = timestamp(String(endToken)), end > start else { return }
            let text = plainText(block.dropFirst(index + 1).joined(separator: "\n"))
            guard !text.isEmpty, rows.count < Self.maximumCues else { return }
            rows.append(SubtitleCue(startMillis: start, endMillis: end, text: text))
        }
        normalized.enumerateLines { value, _ in
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { flush() }
            else { block.append(value) }
        }
        flush()
        return rows
    }

    fileprivate static func timestamp(_ source: String) -> Int64? {
        let value = source.replacingOccurrences(of: ",", with: ".")
        if value.hasSuffix("ms"), let milliseconds = Int64(value.dropLast(2)), milliseconds >= 0 {
            return milliseconds
        }
        if value.hasSuffix("s"), let seconds = Double(value.dropLast()), seconds.isFinite,
           seconds >= 0, seconds < 3_600_000 { return Int64(seconds * 1000) }
        let parts = value.split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let secondsPart = parts[parts.count - 1].split(separator: ".", omittingEmptySubsequences: false)
        guard secondsPart.count <= 2, let seconds = Int64(secondsPart[0]), (0..<60).contains(seconds) else { return nil }
        let fraction: Int64
        if secondsPart.count == 2 {
            let digits = String(secondsPart[1].prefix(3))
            guard !digits.isEmpty, digits.allSatisfy(\.isNumber), let number = Int64(digits) else { return nil }
            fraction = number * (digits.count == 1 ? 100 : digits.count == 2 ? 10 : 1)
        } else { fraction = 0 }
        guard let minutes = Int64(parts[parts.count - 2]), (0..<60).contains(minutes) else { return nil }
        let hours: Int64? = parts.count == 3 ? Int64(parts[0]) : 0
        guard let hours, (0...1000).contains(hours) else { return nil }
        return ((hours * 60 + minutes) * 60 + seconds) * 1000 + fraction
    }

    private static func plainText(_ source: String) -> String {
        let withoutTags = source.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        return String(withoutTags.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines).prefix(2048))
    }

    private static func parseTTML(_ data: Data) throws -> [SubtitleCue] {
        let parser = XMLParser(data: data)
        let delegate = TTMLCueParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw SubtitleError.invalidCues }
        return delegate.cues
    }
}

private final class TTMLCueParser: NSObject, XMLParserDelegate {
    private(set) var cues: [SubtitleCue] = []
    private var start: Int64?
    private var end: Int64?
    private var content = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String]) {
        switch elementName.components(separatedBy: ":").last ?? "" {
        case "p":
            start = attributes["begin"].flatMap(ExternalSubtitles.timestamp)
            end = attributes["end"].flatMap(ExternalSubtitles.timestamp)
            if end == nil, let start, let duration = attributes["dur"].flatMap(ExternalSubtitles.timestamp) {
                end = start + duration
            }
            content = ""
        case "br": if start != nil { content += "\n" }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if start != nil { content += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        guard elementName.components(separatedBy: ":").last == "p" else { return }
        defer { start = nil; end = nil; content = "" }
        guard let start, let end, end > start else { return }
        let text = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2048))
        guard !text.isEmpty, cues.count < ExternalSubtitles.maximumCues else { return }
        cues.append(SubtitleCue(startMillis: start, endMillis: end, text: text))
    }
}

enum SubtitleError: Error {
    case tooLarge, invalidEncoding, invalidCues, unsupportedFormat, invalidURL, httpFailure
}
