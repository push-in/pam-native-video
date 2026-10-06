<!-- pam:product-page:start -->
<div align="center">

# PAM Native Video

**Adaptive streaming and native playback for serious media apps.**

Play HLS on iOS, HLS/DASH on Android, subtitles, tracks, DRM-ready sources, and picture-in-picture while decode and rendering stay native.

[![Latest version](https://img.shields.io/packagist/v/pushinbr/pam-native-video?style=flat-square&label=stable)](https://packagist.org/packages/pushinbr/pam-native-video)
[![CI](https://img.shields.io/github/actions/workflow/status/push-in/pam-native-video/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/push-in/pam-native-video/actions)
![PHP](https://img.shields.io/badge/PHP-8.5-777BB4?style=flat-square&logo=php&logoColor=white)
![Android](https://img.shields.io/badge/Android-API%2026%2B-3DDC84?style=flat-square&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-15%2B-000000?style=flat-square&logo=apple&logoColor=white)

**[Documentation](https://push-in.github.io/pam-docs/native/overview/) · [Quick start](#quick-start) · [What you can build](#what-you-can-build) · [PAM ecosystem](https://push-in.github.io/pam-docs/ecosystem/) · [Issues](https://github.com/push-in/pam-native-video/issues)**

</div>

---

## Why PAM Native Video

Play HLS on iOS, HLS/DASH on Android, subtitles, tracks, DRM-ready sources, and picture-in-picture while decode and rendering stay native. The public API is strictly typed for PHP 8.5; expensive or frame-sensitive work stays in Rust or the platform SDK instead of crossing the application boundary every frame.

| | |
| --- | --- |
| **Best for** | A focused capability you can add to any PAM Native application |
| **Native path** | Android Media3 · AVPlayer |
| **Application model** | Composer package + generated native integration |
| **Design rule** | Independent module; no feed, vertical, or application template bundled |

## What you can build

- Streaming and IPTV applications
- Social and editorial video
- Offline-aware playback with native controls and subtitles

## Quick start

Already have a PAM Native project? Add only this capability:

```bash
pam composer require pushinbr/pam-native-video
pam doctor --fix
```

New to PAM? Follow the **[five-minute PAM Native setup](https://push-in.github.io/pam-docs/native/overview/)** once, then return here. Your application stays a normal Composer project with a committed lockfile.
<!-- pam:product-page:end -->

## See it in action

This package is a horizontal playback primitive. It does not install a feed, social network, or
streaming application template.

Adaptive HLS and local video playback through Android Media3 and Apple AVPlayer; Android also supports DASH. Decoder, buffering, controls and progress timing remain native rather than crossing the PHP bridge per frame.

```bash
pam composer require pushinbr/pam-native-video
pam doctor --fix
```

```php
use Pam\Native\Video\VideoEventKind;
use Pam\Native\Video\VideoPlayer;
use Pam\Native\Video\VideoResizeMode;

return VideoPlayer::make('https://cdn.example.com/master.m3u8')
    ->autoPlay()
    ->controls()
    ->resizeMode(VideoResizeMode::Cover)
    ->onEvent(function (VideoEventKind $kind, array $event): void {
        // Progress: $event['positionMillis'], ['durationMillis'], ['bufferedMillis'].
    });
```

Protected playback supports Widevine and ClearKey on Android and FairPlay on iOS. An incompatible DRM scheme produces a native playback error instead of silently playing without DRM. License exchange runs inside the native player; credentials should be short-lived.

```php
use Pam\Native\Video\VideoDrmConfiguration;
use Pam\Native\Video\VideoDrmScheme;
use Pam\Native\Video\VideoPlayer;

return VideoPlayer::make('https://cdn.example.com/movie/master.m3u8')
    ->drm(new VideoDrmConfiguration(
        scheme: VideoDrmScheme::FairPlay,
        licenseUrl: 'https://license.example.com/fps',
        authorization: 'Bearer '.$shortLivedToken,
        contentId: 'movie-42',
        certificateUrl: 'https://license.example.com/fairplay.cer',
    ))
    ->subtitle('https://cdn.example.com/subtitles/pt-BR.vtt')
    ->preferredForwardBuffer(15_000)
    ->autoPlay();
```

Features include adaptive HLS playback, embedded subtitle/audio tracks, native controls, autoplay, looping, mute/volume, deterministic seek commands, configurable progress events and sandboxed local files. Android also supports DASH. External WebVTT, SRT and TTML subtitles are supported on both platforms; iOS loads at most 2 MiB and displays them in the AVKit content overlay. Embedded subtitles retain the platform's native track selection. Android dependencies are pinned to Media3 `1.9.3`; iOS uses AVFoundation/AVKit.

On macOS, run the focused subtitle, time and sandbox checks with `swiftc ios/Sources/ExternalSubtitles.swift ios/Sources/VideoSafety.swift tests/ios-subtitles/main.swift -o /tmp/pam-video-ios-check && /tmp/pam-video-ios-check`.

Platform support: Android API 26+, iOS 15+, PAM Native 0.8–1.x.

## What installation does

`pam composer require pushinbr/pam-native-video` installs the package through the project's normal `composer.json` and `composer.lock`. Run `pam doctor --fix` afterward to validate the environment and regenerate native integration when required. The package is a PAM Native plugin with one native view (`video.player`); nothing is added to `pam-native.json`.

Use `pam packages` to inspect direct installed Composer dependencies and `pam composer remove pushinbr/pam-native-video` to uninstall the capability.

- **Android:** no permissions besides network access. Dependencies:
  `androidx.media3:media3-exoplayer`, `-exoplayer-dash`, `-exoplayer-hls` and
  `-ui` `1.9.3`. When `pam-native-media`, `pam-native-audio` or
  `pam-native-media-editor` (Media3 `1.10.1`) are installed too, Gradle
  resolves every Media3 artifact to the newest requested version.
- **iOS:** frameworks `AVFoundation` and `AVKit`; no Info.plist keys. FairPlay
  needs a certificate and license server of your own.

## When to use it

The PAM Native core already ships `<MediaPlayer>` (`Pam\Native\UI\MediaPlayer`)
for feed, story and chat media; Zé Chat plays its gallery, story and editor
videos with it. Add this package when you need what the core player does not
do: DRM (Widevine, ClearKey, FairPlay), DASH on Android, external WebVTT/SRT/
TTML subtitles, bitrate caps, forward-buffer tuning and native transport
controls.

## API reference

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

## Production checklist

- Prefer adaptive HLS for both platforms; use DASH only for Android.
- Keep progress intervals coarse enough for the product experience.
- Pause or release playback when the owning screen loses visibility.
- Run `pam doctor`, `pam test`, and a signed release build on every supported platform.
- Exercise denial, cancellation, backgrounding, process restart, and offline behavior before release.

## Troubleshooting

- **Remote playback fails:** verify HTTPS, codec, manifest, and segment accessibility.
- **Seek appears ignored:** issue it as an intentional state revision, not every render.
- **Subtitles are absent:** inspect the embedded track, or check the external subtitle URL, format and 2 MiB iOS size limit.
- **Native integration is stale:** run `pam doctor --fix`, rebuild the native host, and inspect the first reported diagnostic.

## Compatibility and support

| `pushinbr/pam-native-video` | `pushinbr/pam-native` | Android | iOS |
| --- | --- | --- | --- |
| 0.4.x | `>=0.8.0 <2.0.0` (tested with 1.14.x) | API 26+, Media3 1.9.3 | 15+, external subtitles |
| 0.3.x | `>=0.8.0 <1.0.0` | API 26+ | 15+, no external subtitles |

This package targets PAM Native `0.8–1.x`, Android API 26+, and iOS 15+ unless a platform-specific section above states a stricter requirement. Platform SDKs, credentials, entitlements, physical hardware, and store configuration remain application responsibilities.

- [PAM documentation](https://push-in.github.io/pam-docs/introduction/)
- [PAM Native overview](https://push-in.github.io/pam-docs/native/overview/)
- [Plugin and native capability model](https://push-in.github.io/pam-docs/native/plugins/)
- [Report an issue](https://github.com/push-in/pam-native-video/issues)

Security vulnerabilities should be reported through the repository security policy or GitHub private vulnerability reporting, not a public issue.
