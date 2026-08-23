package dev.pam.video

import android.content.Context
import android.net.Uri
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import dev.pam.nativeapp.protocol.WireMap
import dev.pam.nativeapp.protocol.WireValue
import dev.pam.nativeapp.views.NativeViewFactory
import java.io.File

@UnstableApi
class VideoPlayerFactory(private val applicationContext: Context) : NativeViewFactory {
    override fun create(context: Context, emit: (ByteArray) -> Unit): View = PamVideoView(context, emit)

    override fun update(view: View, properties: Map<String, WireValue>) {
        (view as PamVideoView).update(properties)
    }

    override fun release(view: View) { (view as PamVideoView).release() }

    private inner class PamVideoView(context: Context, private val emit: (ByteArray) -> Unit) : PlayerView(context), Player.Listener {
        private val exoPlayer = ExoPlayer.Builder(context).build()
        private var source = ""; private var subtitle = ""; private var seek = -1L; private var interval = 500L
        private var currentValues: Map<String, WireValue> = emptyMap()
        private val ticker = object : Runnable { override fun run() { emitProgress(); postDelayed(this, interval) } }
        init { player = exoPlayer; exoPlayer.addListener(this); post(ticker) }

        fun update(values: Map<String, WireValue>) {
            currentValues = values
            useController = values.flag("controls", true)
            exoPlayer.repeatMode = if (values.flag("loop", false)) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
            exoPlayer.volume = if (values.flag("muted", false)) 0f else values.decimal("volume", 1.0).toFloat().coerceIn(0f, 1f)
            resizeMode = when (values.integer("resizeMode", 1)) { 2L -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM; 3L -> AspectRatioFrameLayout.RESIZE_MODE_FILL; else -> AspectRatioFrameLayout.RESIZE_MODE_FIT }
            interval = values.integer("progressIntervalMillis", 500).coerceIn(100, 10_000)
            exoPlayer.setPlaybackSpeed(values.decimal("playbackRate", 1.0).toFloat().coerceIn(0.25f, 4f))
            val peakBitRate = values.integer("preferredPeakBitRate", 0).coerceAtLeast(0)
            exoPlayer.trackSelectionParameters = exoPlayer.trackSelectionParameters
                .buildUpon()
                .setMaxVideoBitrate(if (peakBitRate == 0L) Int.MAX_VALUE else peakBitRate.coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
                .build()
            val nextSource = values.text("source"); val nextSubtitle = values.text("subtitle")
            if (nextSource != source || nextSubtitle != subtitle) {
                source = nextSource; subtitle = nextSubtitle
                exoPlayer.setMediaItem(mediaItem(source, subtitle)); exoPlayer.prepare()
            }
            val requestedSeek = values.integer("positionMillis", 0)
            if (requestedSeek != seek) { seek = requestedSeek; if (requestedSeek > 0) exoPlayer.seekTo(requestedSeek) }
            exoPlayer.playWhenReady = values.flag("autoPlay", false)
        }

        private fun mediaItem(source: String, subtitle: String): MediaItem {
            val builder = MediaItem.Builder().setUri(resolve(source))
            val drmScheme = currentValues.integer("drmScheme", 0)
            if (drmScheme != 0L) {
                val uuid = when (drmScheme) {
                    1L -> C.WIDEVINE_UUID
                    3L -> C.CLEARKEY_UUID
                    else -> throw IllegalArgumentException("The selected DRM scheme is not supported on Android")
                }
                val licenseUrl = currentValues.text("drmLicenseUrl")
                require(licenseUrl.startsWith("https://")) { "DRM license URL must use HTTPS" }
                val drm = MediaItem.DrmConfiguration.Builder(uuid).setLicenseUri(licenseUrl)
                    .setMultiSession(currentValues.flag("drmMultiSession", false))
                val authorization = currentValues.text("drmAuthorization")
                if (authorization.isNotEmpty()) drm.setLicenseRequestHeaders(mapOf("Authorization" to authorization))
                builder.setDrmConfiguration(drm.build())
            }
            if (subtitle.isNotEmpty()) builder.setSubtitleConfigurations(listOf(MediaItem.SubtitleConfiguration.Builder(resolve(subtitle)).setMimeType(subtitleMime(subtitle)).setSelectionFlags(C.SELECTION_FLAG_DEFAULT).build()))
            return builder.build()
        }
        private fun resolve(source:String):Uri = if(source.startsWith("https://")) Uri.parse(source) else Uri.fromFile(sandboxFile(source))
        private fun sandboxFile(path:String):File{val root=applicationContext.filesDir.canonicalFile;val file=File(root,path).canonicalFile;require(file.path.startsWith(root.path+File.separator)){"Video path escapes app files"};return file}
        private fun subtitleMime(path:String)=when{path.endsWith(".vtt",true)->MimeTypes.TEXT_VTT;path.endsWith(".ttml",true)||path.endsWith(".xml",true)->MimeTypes.APPLICATION_TTML;else->MimeTypes.APPLICATION_SUBRIP}
        override fun onPlaybackStateChanged(state:Int){emit(mapOf("event" to WireValue.Integer(1),"state" to WireValue.Integer(when(state){Player.STATE_BUFFERING->2;Player.STATE_READY->3;Player.STATE_ENDED->4;else->1}))) }
        override fun onPlayerError(error:androidx.media3.common.PlaybackException){emit(mapOf("event" to WireValue.Integer(3),"state" to WireValue.Integer(5),"message" to WireValue.Text(error.message.orEmpty()))) }
        private fun emitProgress(){if(exoPlayer.playbackState==Player.STATE_IDLE)return;emit(mapOf("event" to WireValue.Integer(2),"positionMillis" to WireValue.Integer(exoPlayer.currentPosition.coerceAtLeast(0)),"durationMillis" to WireValue.Integer(exoPlayer.duration.coerceAtLeast(0)),"bufferedMillis" to WireValue.Integer(exoPlayer.bufferedPosition.coerceAtLeast(0))))}
        private fun emit(values:Map<String,WireValue>)=emit(WireMap.encode(values))
        fun release(){removeCallbacks(ticker);exoPlayer.removeListener(this);exoPlayer.release();player=null}
        private fun Map<String,WireValue>.text(key:String)=(get(key)as?WireValue.Text)?.value.orEmpty()
        private fun Map<String,WireValue>.flag(key:String,fallback:Boolean)=(get(key)as?WireValue.Flag)?.value?:fallback
        private fun Map<String,WireValue>.integer(key:String,fallback:Long)=(get(key)as?WireValue.Integer)?.value?:fallback
        private fun Map<String,WireValue>.decimal(key:String,fallback:Double)=when(val value=get(key)){is WireValue.Decimal->value.value;is WireValue.Integer->value.value.toDouble();else->fallback}
    }
}
