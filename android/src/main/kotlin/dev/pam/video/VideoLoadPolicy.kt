package dev.pam.video

internal data class VideoLoadRequest(
    val source: String = "",
    val subtitle: String = "",
    val drmScheme: Long = 0,
    val drmLicenseUrl: String = "",
    val drmAuthorization: String = "",
    val drmMultiSession: Boolean = false,
) {
    fun transitionFrom(previous: VideoLoadRequest, lastFailed: VideoLoadRequest? = null): VideoLoadTransition {
        if (source.isEmpty()) {
            return if (previous.source.isEmpty()) VideoLoadTransition.UNCHANGED else VideoLoadTransition.CLEAR
        }
        if (lastFailed != null && sameMediaAs(lastFailed)) return VideoLoadTransition.UNCHANGED
        return if (sameMediaAs(previous)) VideoLoadTransition.UNCHANGED else VideoLoadTransition.LOAD
    }

    private fun sameMediaAs(other: VideoLoadRequest): Boolean =
        source == other.source &&
            subtitle == other.subtitle &&
            drmScheme == other.drmScheme &&
            (drmScheme == 0L || (
                drmLicenseUrl == other.drmLicenseUrl &&
                    drmAuthorization == other.drmAuthorization &&
                    drmMultiSession == other.drmMultiSession
                ))
}

internal enum class VideoLoadTransition { UNCHANGED, LOAD, CLEAR }
