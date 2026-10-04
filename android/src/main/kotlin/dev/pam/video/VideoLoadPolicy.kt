package dev.pam.video

internal data class VideoLoadRequest(
    val source: String = "",
    val subtitle: String = "",
    val drmScheme: Long = 0,
    val drmLicenseUrl: String = "",
    val drmAuthorization: String = "",
    val drmMultiSession: Boolean = false,
) {
    fun transitionFrom(previous: VideoLoadRequest): VideoLoadTransition {
        if (source.isEmpty()) {
            return if (previous.source.isEmpty()) VideoLoadTransition.UNCHANGED else VideoLoadTransition.CLEAR
        }
        val mediaUnchanged = source == previous.source &&
            subtitle == previous.subtitle &&
            drmScheme == previous.drmScheme &&
            (drmScheme == 0L || (
                drmLicenseUrl == previous.drmLicenseUrl &&
                    drmAuthorization == previous.drmAuthorization &&
                    drmMultiSession == previous.drmMultiSession
                ))
        return if (mediaUnchanged) VideoLoadTransition.UNCHANGED else VideoLoadTransition.LOAD
    }
}

internal enum class VideoLoadTransition { UNCHANGED, LOAD, CLEAR }
