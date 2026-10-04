# Changelog

## 0.4.0 - Unreleased

- Render external WebVTT, SRT and TTML subtitles on iOS through the AVKit content overlay. Subtitle loading is asynchronous, cancellable, and limited to 2 MiB, 10,000 cues and 2,048 UTF-8 bytes per TTML cue.
- Resolve each local video and subtitle path component before accepting it inside the iOS application sandbox. Reject XML entity declarations in TTML and require a successful HTTPS response for remote subtitles.
- Reuse the iOS progress observer when the interval does not change and handle indefinite or invalid playback times without integer conversion crashes.
- Reject unsupported DRM schemes on iOS with a native playback error; changing the scheme reloads the player, while an initial empty source stays idle.
- Reload Android media when DRM settings change, clear playback when the source becomes empty, and suppress repeated errors for the same invalid media request.
- Support PAM Native 1.x while retaining the existing 0.8–0.10 compatibility ranges. Document HLS support on both platforms and DASH support on Android.
- Add focused macOS Swift checks for subtitle parsing, size limits, invalid player times and sandbox paths, plus Android Kotlin load-policy checks.

## 0.3.1 - 2026-08-24

- Document the canonical Composer installation and removal workflow.

## 0.3.0 - 2026-08-23

- Add Widevine and ClearKey playback on Android and FairPlay playback on iOS.
- Add external subtitle configuration, playback rate, bitrate and buffer controls. Android rendered external subtitle files in this release; iOS rendering arrives in 0.4.0.
- Add PHPStan level 9 and plugin conformance checks.

## 0.2.0 - 2026-08-23

- Support PAM Native 0.8 on PHP 8.5 and adopt Apache 2.0 licensing.
- Add the ecosystem publication gate and installed dependency checks.

## 0.1.0 - 2026-08-01

- Initial public release of the documented PAM Native package contract.
- Add bounded input validation, sequential integer protocol enums, automated
  package tests, and PHP 8.4/8.5 continuous integration.
