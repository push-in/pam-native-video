import Foundation

enum VideoTime {
    static func milliseconds(_ seconds: Double) -> Int64 {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let value = seconds * 1000
        return value >= Double(Int64.max) ? Int64.max : Int64(value)
    }
}

enum VideoSandboxPath {
    static func resolve(_ path: String, under rootURL: URL) throws -> URL {
        guard !path.isEmpty, path.utf8.count <= 8192, !path.contains("\0"),
              !path.hasPrefix("/"), !path.contains("://") else {
            throw VideoSafetyError.invalidPath
        }
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        var target = root
        for component in path.split(separator: "/", omittingEmptySubsequences: false) {
            guard !component.isEmpty, component != ".", component != ".." else {
                throw VideoSafetyError.invalidPath
            }
            target = target.appendingPathComponent(String(component)).resolvingSymlinksInPath()
            guard target.path.hasPrefix(root.path + "/") else { throw VideoSafetyError.invalidPath }
        }
        return target
    }
}

private enum VideoSafetyError: Error { case invalidPath }
