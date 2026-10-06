# Video player demo

A one-screen PAM Native app for `pushinbr/pam-native-video`: adaptive HLS and a
progressive MP4 with native controls, revision-safe seek commands, playback
rate, resize mode, forward-buffer tuning, progress events and an optional
external subtitle (`StreamPlayer::SUBTITLE`).

```bash
cd example
pam composer install
pam doctor --fix
pam dev            # or: pam build
```

The app installs the released package from Packagist and streams public test
media (Mux and ExoPlayer samples). For DRM, add
`->drm(new VideoDrmConfiguration(...))` with your own license server.
