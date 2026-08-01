# PAM Native Video

Adaptive HLS/DASH and local video playback through Android Media3 and Apple AVPlayer. Decoder, buffering, controls and progress timing remain native rather than crossing the PHP bridge per frame.

```bash
composer require pushinbr/pam-native-video
pam mobile codegen
pam mobile ios:prepare
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
