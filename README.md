<!-- pam:product-page:start -->
<div align="center">

# PAM Native Video

**Adaptive streaming and native playback for serious media apps.**

Play HLS/DASH media, subtitles, tracks, DRM-ready sources, and picture-in-picture while decode and rendering stay native.

[![Latest version](https://img.shields.io/packagist/v/pushinbr/pam-native-video?style=flat-square&label=stable)](https://packagist.org/packages/pushinbr/pam-native-video)
[![CI](https://img.shields.io/github/actions/workflow/status/push-in/pam-native-video/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/push-in/pam-native-video/actions)
![PHP](https://img.shields.io/badge/PHP-8.5-777BB4?style=flat-square&logo=php&logoColor=white)
![Android](https://img.shields.io/badge/Android-API%2026%2B-3DDC84?style=flat-square&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-15%2B-000000?style=flat-square&logo=apple&logoColor=white)

**[Documentation](https://push-in.github.io/pam-docs/native/overview/) · [Quick start](#quick-start) · [What you can build](#what-you-can-build) · [PAM ecosystem](https://push-in.github.io/pam-docs/ecosystem/) · [Issues](https://github.com/push-in/pam-native-video/issues)**

</div>

---

## Why PAM Native Video

Play HLS/DASH media, subtitles, tracks, DRM-ready sources, and picture-in-picture while decode and rendering stay native. The public API is strictly typed for PHP 8.5; expensive or frame-sensitive work stays in Rust or the platform SDK instead of crossing the application boundary every frame.

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

Adaptive HLS/DASH and local video playback through Android Media3 and Apple AVPlayer. Decoder, buffering, controls and progress timing remain native rather than crossing the PHP bridge per frame.

```bash
pam composer require pushinbr/pam-native-video
pam doctor --fix
```

```php
use Pam\Native\Video\VideoPlayer;
use Pam\Native\Video\VideoResizeMode;

return VideoPlayer::make('https://cdn.example.com/master.m3u8')
    ->autoPlay()
    ->controls()
    ->resizeMode(VideoResizeMode::Cover)
    ->onEvent(function ($kind, array $event): void {});
```

Protected playback supports Widevine and ClearKey on Android and FairPlay on iOS. License exchange
runs inside the native player and credentials should always be short-lived.

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

Features include adaptive HLS/DASH playback, embedded subtitle/audio tracks, native controls, autoplay, looping, mute/volume, deterministic seek commands, configurable progress events and sandboxed local files. Android dependencies are pinned to Media3 `1.9.3`; iOS uses AVFoundation/AVKit.

Platform support: Android API 26+, iOS 15+, PAM Native 0.8.x.

## What installation does

`pam composer require pushinbr/pam-native-video` installs the package through the project's normal `composer.json` and `composer.lock`. Run `pam doctor --fix` afterward to validate the environment and regenerate native integration when required.

Use `pam packages` to inspect direct installed Composer dependencies and `pam composer remove pushinbr/pam-native-video` to uninstall the capability.

## API guide

| API | Responsibility |
| --- | --- |
| `VideoPlayer` | Render and control native adaptive or local playback. |
| `VideoResizeMode` | Choose contain, cover, or fill presentation. |
| `VideoEventKind` | Handle prepared, progress, completion, and failure events. |
| `VideoPlaybackState` | Track the normalized player lifecycle. |

All coded states, kinds, and variants are sequential integer-backed enums. Use enum cases in application code; do not depend on raw wire numbers.

## Production checklist

- Prefer adaptive HLS/DASH for variable networks.
- Keep progress intervals coarse enough for the product experience.
- Pause or release playback when the owning screen loses visibility.
- Run `pam doctor`, `pam test`, and a signed release build on every supported platform.
- Exercise denial, cancellation, backgrounding, process restart, and offline behavior before release.

## Troubleshooting

- **Remote playback fails:** verify HTTPS, codec, manifest, and segment accessibility.
- **Seek appears ignored:** issue it as an intentional state revision, not every render.
- **Subtitles are absent:** inspect the manifest track and selected native language.
- **Native integration is stale:** run `pam doctor --fix`, rebuild the native host, and inspect the first reported diagnostic.

## Compatibility and support

This package targets PAM Native `0.8.x`, Android API 26+, and iOS 15+ unless a platform-specific section above states a stricter requirement. Platform SDKs, credentials, entitlements, physical hardware, and store configuration remain application responsibilities.

- [PAM documentation](https://push-in.github.io/pam-docs/introduction/)
- [PAM Native overview](https://push-in.github.io/pam-docs/native/overview/)
- [Plugin and native capability model](https://push-in.github.io/pam-docs/native/plugins/)
- [Report an issue](https://github.com/push-in/pam-native-video/issues)

Security vulnerabilities should be reported through the repository security policy or GitHub private vulnerability reporting, not a public issue.
