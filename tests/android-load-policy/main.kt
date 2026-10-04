package dev.pam.video

private fun expect(actual: VideoLoadTransition, wanted: VideoLoadTransition, description: String) {
    check(actual == wanted) { "$description: expected $wanted, got $actual" }
}

fun main() {
    val empty = VideoLoadRequest()
    expect(empty.transitionFrom(empty), VideoLoadTransition.UNCHANGED, "first empty update")
    expect(empty.copy(drmScheme = 1).transitionFrom(empty), VideoLoadTransition.UNCHANGED, "DRM without source")

    val first = VideoLoadRequest(source = "movie.mp4")
    expect(first.transitionFrom(empty), VideoLoadTransition.LOAD, "first media")
    expect(first.transitionFrom(first), VideoLoadTransition.UNCHANGED, "same media")
    expect(first.copy(drmAuthorization = "unused").transitionFrom(first), VideoLoadTransition.UNCHANGED, "credentials without DRM")
    expect(first.transitionFrom(empty, first), VideoLoadTransition.UNCHANGED, "repeated failed media")
    expect(first.copy(drmAuthorization = "unused").transitionFrom(empty, first), VideoLoadTransition.UNCHANGED, "irrelevant failed media change")
    expect(first.copy(subtitle = "new.vtt").transitionFrom(empty, first), VideoLoadTransition.LOAD, "retry after meaningful change")
    expect(first.copy(subtitle = "captions.vtt").transitionFrom(first), VideoLoadTransition.LOAD, "subtitle change")

    val drm = first.copy(drmScheme = 1, drmLicenseUrl = "https://license.example/key")
    expect(drm.transitionFrom(first), VideoLoadTransition.LOAD, "DRM activation")
    expect(drm.copy(drmScheme = 3).transitionFrom(drm), VideoLoadTransition.LOAD, "DRM scheme change")
    expect(drm.copy(drmLicenseUrl = "https://license.example/new").transitionFrom(drm), VideoLoadTransition.LOAD, "license URL change")
    expect(drm.copy(drmAuthorization = "Bearer token").transitionFrom(drm), VideoLoadTransition.LOAD, "license credentials change")
    expect(drm.copy(drmAuthorization = "Bearer token").transitionFrom(empty, drm), VideoLoadTransition.LOAD, "retry failed DRM after credentials change")
    expect(drm.copy(drmMultiSession = true).transitionFrom(drm), VideoLoadTransition.LOAD, "multi-session change")
    expect(first.transitionFrom(drm), VideoLoadTransition.LOAD, "DRM removal")

    expect(empty.transitionFrom(first), VideoLoadTransition.CLEAR, "source removal")
    expect(empty.copy(subtitle = "captions.vtt").transitionFrom(first), VideoLoadTransition.CLEAR, "source removal with subtitle")
    expect(empty.transitionFrom(empty), VideoLoadTransition.UNCHANGED, "repeated empty update")
    println("Android video load policy: 19 checks passed")
}
