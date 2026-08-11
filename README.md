# PAM Native Video

Adaptive HLS/DASH and local video playback through Android Media3 and Apple AVPlayer. Decoder, buffering, controls and progress timing remain native rather than crossing the PHP bridge per frame.

```bash
pam add video
pam doctor
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

Features include adaptive HLS/DASH playback, embedded subtitle/audio tracks, native controls, autoplay, looping, mute/volume, deterministic seek commands, configurable progress events and sandboxed local files. Android dependencies are pinned to Media3 `1.9.3`; iOS uses AVFoundation/AVKit.

Platform support: Android API 26+, iOS 15+, PAM Native 0.6.x.


## What installation does

`pam add video` resolves the official compatible package, performs a non-mutating Composer preflight, updates the normal `composer.json` and `composer.lock`, refreshes generated native integration when required, and leaves the project ready for `pam doctor` validation.

Use `pam packages` to inspect availability and `pam remove video` to uninstall the capability safely. Direct Composer commands are an advanced interoperability path; PAM is the supported application workflow.

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

This package targets PAM Native `0.6.x`, Android API 26+, and iOS 15+ unless a platform-specific section above states a stricter requirement. Platform SDKs, credentials, entitlements, physical hardware, and store configuration remain application responsibilities.

- [PAM documentation](https://push-in.github.io/pam-docs/introduction/)
- [PAM Native overview](https://push-in.github.io/pam-docs/native/overview/)
- [Plugin and native capability model](https://push-in.github.io/pam-docs/native/plugins/)
- [Report an issue](https://github.com/push-in/pam-native-video/issues)

Security vulnerabilities should be reported through the repository security policy or GitHub private vulnerability reporting, not a public issue.
