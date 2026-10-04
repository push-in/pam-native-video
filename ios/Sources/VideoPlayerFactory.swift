import AVFoundation
import AVKit
import Foundation
import PamNative
import UIKit

public final class VideoPlayerFactory: NativeViewFactory, @unchecked Sendable {
    public init() {}
    public func create(context: AnyObject?, emit: @escaping (Data) -> Void) -> UIView { VideoContainerView(emit: emit) }
    public func update(view: UIView, properties: [String: WireValue]) { (view as? VideoContainerView)?.update(properties) }
    public func release(view: UIView) { (view as? VideoContainerView)?.releasePlayer() }
}

private final class VideoContainerView: UIView, @unchecked Sendable {
    private let controller = AVPlayerViewController()
    private let player = AVPlayer()
    private let emit: (Data) -> Void
    private let subtitleBackground = UIView()
    private let subtitleLabel = UILabel()
    private var loadRequest = VideoLoadRequest.empty
    private var subtitle = ""
    private var subtitleTrack: ExternalSubtitles?
    private var subtitleTask: Task<Void, Never>?
    private var subtitleObserver: Any?
    private var requestedSeek: Int64 = -1
    private var lastAutoPlay: Bool?
    private var lastRate: Float = 1
    private var loops = false
    private var periodic: Any?
    private var progressInterval: Int64 = -1
    private var endToken: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var fairPlay: FairPlayResourceLoader?
    private var released = false

    init(emit: @escaping (Data) -> Void) {
        self.emit = emit
        super.init(frame: .zero)
        controller.player = player
        controller.view.frame = bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(controller.view)
        configureSubtitleLabel()
        endToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, let item = notification.object as? AVPlayerItem,
                  item === self.player.currentItem else { return }
            if self.loops {
                self.player.seek(to: .zero)
                self.player.play()
            } else {
                self.send(["event": .integer(1), "state": .integer(4)])
            }
        }
    }

    required init?(coder: NSCoder) { nil }

    func update(_ values: [String: WireValue]) {
        guard !released else { return }
        let nextSource = values.text("source")
        let nextDrmScheme = values.integer("drmScheme", 0)
        let nextRequest = VideoLoadRequest(source: nextSource, drmScheme: nextDrmScheme)
        let transition = nextRequest.transition(from: loadRequest)
        let sourceChanged = transition != .unchanged
        if sourceChanged {
            loadRequest = nextRequest
        }
        if transition == .load {
            load(nextSource, values)
        } else if transition == .clear {
            statusObservation = nil
            fairPlay = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        let nextSubtitle = values.text("subtitle")
        if nextSubtitle != subtitle {
            subtitle = nextSubtitle
            loadSubtitle(nextSubtitle)
        }
        controller.showsPlaybackControls = values.flag("controls", true)
        controller.videoGravity = whenResize(values.integer("resizeMode", 1))
        player.isMuted = values.flag("muted", false)
        player.volume = Float(values.decimal("volume", 1)).clamped
        let seek = values.integer("positionMillis", 0)
        if seek != requestedSeek {
            requestedSeek = seek
            if seek > 0 { player.seek(to: CMTime(value: seek, timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero) }
        }
        let requestedRate = values.decimal("playbackRate", 1)
        let rate = Float(requestedRate.isFinite ? max(0.25, min(4, requestedRate)) : 1)
        let autoPlay = values.flag("autoPlay", false)
        if sourceChanged || lastAutoPlay != autoPlay || rate != lastRate {
            if autoPlay { player.playImmediately(atRate: rate) }
            else if sourceChanged || lastAutoPlay == true { player.pause() }
            else if player.rate > 0 { player.rate = rate }
            lastAutoPlay = autoPlay
            lastRate = rate
        }
        player.currentItem?.preferredPeakBitRate = Double(max(0, values.integer("preferredPeakBitRate", 0)))
        player.currentItem?.preferredForwardBufferDuration = Double(max(0, min(120_000, values.integer("preferredForwardBufferMillis", 0)))) / 1000
        configureTicker(values.integer("progressIntervalMillis", 500))
        loops = values.flag("loop", false)
        player.actionAtItemEnd = loops ? .none : .pause
    }

    private func configureSubtitleLabel() {
        subtitleBackground.isHidden = true
        subtitleBackground.isUserInteractionEnabled = false
        subtitleBackground.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        subtitleBackground.layer.cornerRadius = 4
        subtitleBackground.layer.masksToBounds = true
        subtitleBackground.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.isUserInteractionEnabled = false
        subtitleLabel.numberOfLines = 4
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .white
        subtitleLabel.font = .preferredFont(forTextStyle: .headline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        let overlay = controller.contentOverlayView ?? controller.view!
        overlay.addSubview(subtitleBackground)
        subtitleBackground.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            subtitleBackground.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 16),
            subtitleBackground.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -16),
            subtitleBackground.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            subtitleBackground.bottomAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            subtitleLabel.leadingAnchor.constraint(equalTo: subtitleBackground.leadingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(equalTo: subtitleBackground.trailingAnchor, constant: -8),
            subtitleLabel.topAnchor.constraint(equalTo: subtitleBackground.topAnchor, constant: 4),
            subtitleLabel.bottomAnchor.constraint(equalTo: subtitleBackground.bottomAnchor, constant: -4),
        ])
    }

    private func loadSubtitle(_ value: String) {
        subtitleTask?.cancel()
        subtitleTask = nil
        subtitleTrack = nil
        subtitleLabel.text = nil
        subtitleBackground.isHidden = true
        configureSubtitleTicker()
        guard !value.isEmpty else { return }
        let url: URL
        do {
            if value.hasPrefix("https://") {
                guard let remote = URL(string: value), remote.scheme == "https", remote.host != nil else {
                    throw SubtitleError.invalidURL
                }
                url = remote
            } else {
                url = try sandboxURL(value)
            }
        } catch {
            subtitleFailure("Invalid subtitle source")
            return
        }
        subtitleTask = Task.detached(priority: .utility) { [weak self] in
            do {
                let track = try await ExternalSubtitles.load(from: url)
                guard !Task.isCancelled else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.released, self.subtitle == value else { return }
                    self.subtitleTrack = track
                    self.configureSubtitleTicker()
                    self.renderSubtitle()
                }
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.released, self.subtitle == value else { return }
                    self.subtitleFailure("Subtitle unavailable: \(error)")
                }
            }
        }
    }

    private func configureSubtitleTicker() {
        if subtitleTrack == nil {
            if let subtitleObserver { player.removeTimeObserver(subtitleObserver); self.subtitleObserver = nil }
            return
        }
        guard subtitleObserver == nil else { return }
        subtitleObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 100, timescale: 1000), queue: .main
        ) { [weak self] _ in self?.renderSubtitle() }
    }

    private func renderSubtitle() {
        let text = subtitleTrack?.text(at: VideoTime.milliseconds(player.currentTime().seconds))
        guard subtitleLabel.text != text else { return }
        subtitleLabel.text = text
        subtitleBackground.isHidden = text == nil
    }

    private func load(_ source: String, _ values: [String: WireValue]) {
        statusObservation = nil
        player.replaceCurrentItem(with: nil)
        fairPlay = nil
        let drmScheme = values.integer("drmScheme", 0)
        if let message = VideoDrmPolicy.failureMessage(for: drmScheme) {
            failure(message)
            return
        }
        let url: URL
        if source.hasPrefix("https://") {
            guard let remote = URL(string: source), remote.scheme == "https", remote.host != nil else {
                failure("Invalid video URL")
                return
            }
            url = remote
        } else {
            do { url = try sandboxURL(source) }
            catch { failure(String(describing: error)); return }
        }
        let item: AVPlayerItem
        if drmScheme == PamVideoDrmScheme.fairPlay.rawValue {
            guard let certificate = URL(string: values.text("drmCertificateUrl")),
                  let license = URL(string: values.text("drmLicenseUrl")),
                  certificate.scheme == "https", license.scheme == "https",
                  !values.text("drmContentId").isEmpty else {
                failure("Invalid FairPlay configuration")
                return
            }
            let asset = AVURLAsset(url: url)
            let loader = FairPlayResourceLoader(
                certificateURL: certificate, licenseURL: license,
                contentID: values.text("drmContentId"), authorization: values.text("drmAuthorization")
            )
            asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "dev.pam.video.fairplay"))
            fairPlay = loader
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, item === self.player.currentItem else { return }
                switch item.status {
                case .readyToPlay: self.send(["event": .integer(1), "state": .integer(3)])
                case .failed: self.failure(item.error?.localizedDescription ?? "Playback failed")
                default: self.send(["event": .integer(1), "state": .integer(2)])
                }
            }
        }
        player.replaceCurrentItem(with: item)
    }

    private func configureTicker(_ milliseconds: Int64) {
        let interval = max(100, min(10_000, milliseconds))
        guard interval != progressInterval else { return }
        if let periodic { player.removeTimeObserver(periodic); self.periodic = nil }
        progressInterval = interval
        periodic = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: interval, timescale: 1000), queue: .main
        ) { [weak self] _ in
            guard let self, self.player.currentItem != nil else { return }
            let duration = self.player.currentItem?.duration.seconds ?? 0
            let buffered = self.player.currentItem?.loadedTimeRanges.last?.timeRangeValue.end.seconds ?? 0
            self.send([
                "event": .integer(2),
                "positionMillis": .integer(VideoTime.milliseconds(self.player.currentTime().seconds)),
                "durationMillis": .integer(VideoTime.milliseconds(duration)),
                "bufferedMillis": .integer(VideoTime.milliseconds(buffered)),
            ])
        }
    }

    private func whenResize(_ value: Int64) -> AVLayerVideoGravity {
        switch value { case 2: return .resizeAspectFill; case 3: return .resize; default: return .resizeAspect }
    }

    private func sandboxURL(_ path: String) throws -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return try VideoSandboxPath.resolve(path, under: root)
    }

    private func failure(_ message: String) {
        send(["event": .integer(3), "state": .integer(5), "message": .text(String(message.prefix(1024)))])
    }

    private func subtitleFailure(_ message: String) {
        let state: Int64 = player.currentItem?.status == .readyToPlay ? 3 : 2
        send(["event": .integer(3), "state": .integer(state), "message": .text(String(message.prefix(1024)))])
    }

    private func send(_ values: [String: WireValue]) {
        if let data = try? WireMap.encode(values) { emit(data) }
    }

    func releasePlayer() {
        guard !released else { return }
        released = true
        subtitleTask?.cancel()
        subtitleTask = nil
        subtitleTrack = nil
        if let subtitleObserver { player.removeTimeObserver(subtitleObserver); self.subtitleObserver = nil }
        if let periodic { player.removeTimeObserver(periodic); self.periodic = nil }
        progressInterval = -1
        if let endToken { NotificationCenter.default.removeObserver(endToken); self.endToken = nil }
        statusObservation = nil
        fairPlay = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    deinit { releasePlayer() }
}

private extension Dictionary where Key == String, Value == WireValue {
    func text(_ key: String) -> String { if case let .text(value)? = self[key] { return value }; return "" }
    func flag(_ key: String, _ fallback: Bool) -> Bool { if case let .flag(value)? = self[key] { return value }; return fallback }
    func integer(_ key: String, _ fallback: Int64) -> Int64 { if case let .integer(value)? = self[key] { return value }; return fallback }
    func decimal(_ key: String, _ fallback: Double) -> Double {
        switch self[key] { case let .decimal(value)?: return value; case let .integer(value)?: return Double(value); default: return fallback }
    }
}

private extension Float { var clamped: Float { isFinite ? min(1, max(0, self)) : 1 } }
