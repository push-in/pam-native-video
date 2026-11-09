# PAM Native Video API reference

Moved out of the README; nothing was removed.

All classes live in `Pam\Native\Video`.

### `VideoPlayer` (`Renderable`, immutable)

| Method | Description |
| --- | --- |
| `make(string $source)` | HTTPS URL (HLS, DASH on Android, progressive) or a relative sandbox path. |
| `autoPlay(bool = true)`, `controls(bool = true)` (default on), `loop(bool = true)`, `muted(bool = true)`, `volume(float)` (0–1) | Playback. |
| `seekTo(int $milliseconds)` | Seek command; a new value seeks once (keep it in state, do not recompute it every render). |
| `resizeMode(VideoResizeMode)` | `Contain` (default), `Cover`, `Fill`. |
| `progressEvery(int $milliseconds)` | Progress event interval, 100–10000 ms (default 500). |
| `playbackRate(float)` | 0.25–4. |
| `preferredPeakBitRate(int $bitsPerSecond)`, `preferredForwardBuffer(int $milliseconds)` (0–120000) | Adaptive streaming hints. |
| `subtitle(string $source)` | External WebVTT, SRT or TTML (HTTPS or sandbox path). |
| `drm(VideoDrmConfiguration)` | Protected playback. |
| `onEvent(Closure(VideoEventKind, array) $handler)` | Native events. |
| `toElement(): Element` | A `CustomView` of kind `video.player`; style it to give it a size. |

### Events

| `VideoEventKind` | Payload keys |
| --- | --- |
| `State = 1` | `state` (`VideoPlaybackState` value) |
| `Progress = 2` | `positionMillis`, `durationMillis`, `bufferedMillis` |
| `Error = 3` | `state` (`Failed`), `message` |
| `Tracks = 4` | Reserved; not emitted by 0.4 |

`VideoPlaybackState`: `Idle = 1`, `Buffering = 2`, `Ready = 3`, `Ended = 4`,
`Failed = 5`. Convert with `VideoPlaybackState::tryFrom((int) $event['state'])`.

### `VideoDrmConfiguration` (readonly)

`(VideoDrmScheme $scheme, string $licenseUrl, string $authorization = '', string $contentId = '', string $certificateUrl = '', bool $multiSession = false)`;
`properties()`. License and certificate URLs must be HTTPS; FairPlay needs
`contentId` and `certificateUrl`; `authorization` ≤ 8192 bytes, `contentId`
≤ 2048. `VideoDrmScheme`: `Widevine = 1`, `FairPlay = 2`, `ClearKey = 3`
(Widevine/ClearKey on Android, FairPlay on iOS).

### Errors

`InvalidArgumentException` for non-HTTPS URLs, empty or oversized sources and
DRM configurations that break the rules above. Playback problems (network,
codec, DRM, unsupported scheme on a platform) arrive as `Error` events with a
message; a repeated error for the same request is reported once.
