import Foundation

let vtt = Data("""
WEBVTT

00:01.000 --> 00:02.000 align:center
Olá <b>mundo</b> &amp; PAM

00:02.500 --> 00:04.000
Segunda fala
""".utf8)
let webvtt = try ExternalSubtitles(data: vtt, pathExtension: "vtt")
precondition(webvtt.text(at: 999) == nil)
precondition(webvtt.text(at: 1_000) == "Olá mundo & PAM")
precondition(webvtt.text(at: 2_000) == nil)
precondition(webvtt.text(at: 3_000) == "Segunda fala")
let overlapping = try ExternalSubtitles(data: Data("""
WEBVTT

00:01.000 --> 00:04.000
Fala longa

00:02.000 --> 00:03.000
Fala curta
""".utf8), pathExtension: "vtt")
precondition(overlapping.text(at: 3_500) == "Fala longa")

let srt = Data("""
1
00:00:01,200 --> 00:00:02,400
Texto SRT
""".utf8)
let subrip = try ExternalSubtitles(data: srt, pathExtension: "srt")
precondition(subrip.text(at: 1_500) == "Texto SRT")

let ttml = Data("""
<?xml version="1.0" encoding="utf-8"?>
<tt xmlns="http://www.w3.org/ns/ttml"><body><div>
<p begin="00:00:01.000" end="00:00:02.000">Olá<br/>TTML</p>
</div></body></tt>
""".utf8)
let timedText = try ExternalSubtitles(data: ttml, pathExtension: "ttml")
precondition(timedText.text(at: 1_200) == "Olá\nTTML")
let entity = Data("""
<!DOCTYPE tt [<!ENTITY expanded "Unsafe">]>
<tt><body><p begin="00:00:01.000" end="00:00:02.000">&expanded;</p></body></tt>
""".utf8)
do {
    _ = try ExternalSubtitles(data: entity, pathExtension: "ttml")
    fatalError("Accepted TTML entity declaration")
} catch {}
let longCue = Data("<tt><body><p begin=\"00:00:01.000\" end=\"00:00:02.000\">\(String(repeating: "a", count: 2049))</p></body></tt>".utf8)
do {
    _ = try ExternalSubtitles(data: longCue, pathExtension: "ttml")
    fatalError("Accepted oversized TTML cue")
} catch {}
do {
    _ = try ExternalSubtitles(data: Data(repeating: 0, count: ExternalSubtitles.maximumBytes + 1), pathExtension: "vtt")
    fatalError("Accepted oversized subtitle")
} catch {}

precondition(VideoTime.milliseconds(.nan) == 0)
precondition(VideoTime.milliseconds(.infinity) == 0)
precondition(VideoTime.milliseconds(1.5) == 1_500)
precondition(VideoDrmPolicy.failureMessage(for: 0) == nil)
precondition(VideoDrmPolicy.failureMessage(for: PamVideoDrmScheme.fairPlay.rawValue) == nil)
precondition(VideoDrmPolicy.failureMessage(for: PamVideoDrmScheme.widevine.rawValue) != nil)
precondition(VideoDrmPolicy.failureMessage(for: PamVideoDrmScheme.clearKey.rawValue) != nil)
precondition(VideoDrmPolicy.failureMessage(for: 99) != nil)
let emptyVideo = VideoLoadRequest.empty
precondition(emptyVideo.transition(from: .empty) == .unchanged)
let protectedVideo = VideoLoadRequest(source: "https://cdn.example.test/a.m3u8", drmScheme: 2)
precondition(protectedVideo.transition(from: emptyVideo) == .load)
precondition(VideoLoadRequest(source: protectedVideo.source, drmScheme: 1).transition(from: protectedVideo) == .load)
precondition(emptyVideo.transition(from: protectedVideo) == .clear)
let fairPlayVideo = VideoLoadRequest(
    source: protectedVideo.source,
    drmScheme: PamVideoDrmScheme.fairPlay.rawValue,
    drmCertificateUrl: "https://license.example.test/certificate",
    drmLicenseUrl: "https://license.example.test/key",
    drmContentId: "movie-1",
    drmAuthorization: "Bearer original"
)
precondition(fairPlayVideo.transition(from: protectedVideo) == .load)
precondition(fairPlayVideo.transition(from: fairPlayVideo) == .unchanged)
let changedCertificate = VideoLoadRequest(
    source: fairPlayVideo.source, drmScheme: 2,
    drmCertificateUrl: "https://license.example.test/new",
    drmLicenseUrl: fairPlayVideo.drmLicenseUrl,
    drmContentId: fairPlayVideo.drmContentId,
    drmAuthorization: fairPlayVideo.drmAuthorization
)
let changedLicense = VideoLoadRequest(
    source: fairPlayVideo.source, drmScheme: 2,
    drmCertificateUrl: fairPlayVideo.drmCertificateUrl,
    drmLicenseUrl: "https://license.example.test/new",
    drmContentId: fairPlayVideo.drmContentId,
    drmAuthorization: fairPlayVideo.drmAuthorization
)
let changedContentId = VideoLoadRequest(
    source: fairPlayVideo.source, drmScheme: 2,
    drmCertificateUrl: fairPlayVideo.drmCertificateUrl,
    drmLicenseUrl: fairPlayVideo.drmLicenseUrl,
    drmContentId: "movie-2",
    drmAuthorization: fairPlayVideo.drmAuthorization
)
let changedAuthorization = VideoLoadRequest(
    source: fairPlayVideo.source, drmScheme: 2,
    drmCertificateUrl: fairPlayVideo.drmCertificateUrl,
    drmLicenseUrl: fairPlayVideo.drmLicenseUrl,
    drmContentId: fairPlayVideo.drmContentId,
    drmAuthorization: "Bearer renewed"
)
for changed in [changedCertificate, changedLicense, changedContentId, changedAuthorization] {
    precondition(changed.transition(from: fairPlayVideo) == .load)
}
let unprotectedVideo = VideoLoadRequest(source: fairPlayVideo.source, drmScheme: 0)
precondition(VideoLoadRequest(source: fairPlayVideo.source, drmScheme: 0, drmAuthorization: "unused")
    .transition(from: unprotectedVideo) == .unchanged)
precondition(VideoLoadRequest(source: "", drmScheme: 2, drmAuthorization: "unused")
    .transition(from: emptyVideo) == .unchanged)

let testRoot = FileManager.default.temporaryDirectory.appendingPathComponent("pam-video-path-\(UUID().uuidString)")
let sandbox = testRoot.appendingPathComponent("sandbox")
let outside = testRoot.appendingPathComponent("outside")
defer { try? FileManager.default.removeItem(at: testRoot) }
try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
try FileManager.default.createSymbolicLink(at: sandbox.appendingPathComponent("linked"), withDestinationURL: outside)
let safe = try VideoSandboxPath.resolve("subtitles/pt.vtt", under: sandbox)
precondition(safe.path.hasPrefix(sandbox.standardizedFileURL.resolvingSymlinksInPath().path + "/"))
for rejected in ["../outside/pt.vtt", "linked/pt.vtt", "/tmp/pt.vtt"] {
    do {
        _ = try VideoSandboxPath.resolve(rejected, under: sandbox)
        fatalError("Accepted escaping path: \(rejected)")
    } catch {}
}

print("34 iOS subtitle, DRM, time and sandbox checks passed")
