package com.video.pilipro

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.source.SingleSampleMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File

@OptIn(UnstableApi::class)
class NativePlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private lateinit var textureRegistry: TextureRegistry

    private var player: ExoPlayer? = null
    // Use SurfaceProducer for proper buffer management with Impeller
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var surface: Surface? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Subtitle tracking
    private var currentHeaders: Map<String, String>? = null

    // SimpleCache singleton
    companion object {
        private var simpleCache: SimpleCache? = null
        private const val CACHE_SIZE_BYTES: Long = 512 * 1024 * 1024 // 512MB cache
        private const val CACHE_DIR_NAME = "exoplayer_cache"

        @Synchronized
        fun getSimpleCache(context: Context): SimpleCache {
            if (simpleCache == null) {
                val cacheDir = File(context.cacheDir, CACHE_DIR_NAME)
                val evictor = LeastRecentlyUsedCacheEvictor(CACHE_SIZE_BYTES)
                val databaseProvider = StandaloneDatabaseProvider(context)
                simpleCache = SimpleCache(cacheDir, evictor, databaseProvider)
            }
            return simpleCache!!
        }

        @Synchronized
        fun releaseSimpleCache() {
            simpleCache?.release()
            simpleCache = null
        }
    }

    // Periodic position update
    private val positionUpdateRunnable = object : Runnable {
        override fun run() {
            sendPositionUpdate()
            mainHandler.postDelayed(this, 200)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        textureRegistry = binding.textureRegistry

        methodChannel = MethodChannel(binding.binaryMessenger, "com.pilipro/native_player")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.pilipro/native_player/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        disposePlayer()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                val videoUrl = call.argument<String>("videoUrl")
                val audioUrl = call.argument<String?>("audioUrl")
                val headers = call.argument<Map<String, String>?>("headers")
                currentHeaders = headers
                val textureId = createPlayer(videoUrl!!, audioUrl, headers)
                result.success(textureId)
            }

            "setSubtitleTrack" -> {
                val id = call.argument<String>("id")
                val title = call.argument<String>("title")
                val language = call.argument<String>("language")
                val uri = call.argument<Boolean>("uri") ?: false
                val data = call.argument<Boolean>("data") ?: false
                setSubtitleTrack(id, title, language, uri, data)
                result.success(null)
            }

            "play" -> {
                player?.play()
                result.success(null)
            }

            "pause" -> {
                player?.pause()
                result.success(null)
            }

            "seekTo" -> {
                val position = call.argument<Number>("position")!!.toLong()
                player?.seekTo(position)
                result.success(null)
            }

            "setPlaybackSpeed" -> {
                val speed = call.argument<Double>("speed")!!.toFloat()
                player?.setPlaybackSpeed(speed)
                result.success(null)
            }

            "setVolume" -> {
                val volume = call.argument<Double>("volume")!!.toFloat()
                player?.volume = volume
                result.success(null)
            }

            "setLooping" -> {
                val looping = call.argument<Boolean>("looping")!!
                player?.repeatMode =
                    if (looping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
                result.success(null)
            }

            "setVideoTrackEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")!!
                setVideoTrackEnabled(enabled)
                result.success(null)
            }

            "dispose" -> {
                disposePlayer()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun createPlayer(
        videoUrl: String,
        audioUrl: String?,
        headers: Map<String, String>?
    ): Long {
        // Dispose previous player and surface
        // Must release both to ensure proper texture recreation when switching videos
        disposePlayer()

        // Create new SurfaceProducer for each player instance
        // This ensures proper buffer lifecycle and prevents texture conflicts
        surfaceProducer = textureRegistry.createSurfaceProducer()
        surface = surfaceProducer!!.surface

        // HTTP data source factory with custom headers
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
        if (!headers.isNullOrEmpty()) {
            httpDataSourceFactory.setDefaultRequestProperties(headers)
        }

        // Cache data source factory with SimpleCache
        val cacheDataSourceFactory = CacheDataSource.Factory()
            .setCache(getSimpleCache(context))
            .setUpstreamDataSourceFactory(httpDataSourceFactory)
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)

        // Load control: min buffer 5s, max buffer 50s
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                /* minBufferMs = */ 5_000,
                /* maxBufferMs = */ 50_000,
                /* bufferForPlaybackMs = */ 2_500,
                /* bufferForPlaybackAfterRebufferMs = */ 5_000
            )
            .build()

        // Track selector with codec preference: AV1 > HEVC > AVC (hardware decode first)
        val trackSelector = DefaultTrackSelector(context).apply {
            parameters = buildUponParameters()
                .setPreferredVideoMimeTypes(
                    "video/av01",   // AV1
                    "video/hevc",   // HEVC / H.265
                    "video/avc"     // AVC / H.264
                )
                .build()
        }

        // Build ExoPlayer
        val exoPlayer = ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setTrackSelector(trackSelector)
            .build()

        // Use setVideoSurface with proper null checks
        exoPlayer.setVideoSurface(surface)

        // Build media source(s) using cache
        val videoSource: MediaSource = ProgressiveMediaSource.Factory(cacheDataSourceFactory)
            .createMediaSource(MediaItem.fromUri(Uri.parse(videoUrl)))

        if (!audioUrl.isNullOrEmpty()) {
            val audioSource: MediaSource =
                ProgressiveMediaSource.Factory(cacheDataSourceFactory)
                    .createMediaSource(MediaItem.fromUri(Uri.parse(audioUrl)))
            exoPlayer.setMediaSource(MergingMediaSource(videoSource, audioSource))
        } else {
            exoPlayer.setMediaSource(videoSource)
        }

        // Listeners
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                val state = when (playbackState) {
                    Player.STATE_IDLE -> "idle"
                    Player.STATE_BUFFERING -> "buffering"
                    Player.STATE_READY -> "ready"
                    Player.STATE_ENDED -> "ended"
                    else -> "unknown"
                }
                sendEvent(
                    mapOf(
                        "type" to "playbackState",
                        "state" to state
                    )
                )

                // 当视频准备好时，主动获取并发送视频尺寸
                if (playbackState == Player.STATE_READY) {
                    val videoSize = exoPlayer.videoSize
                    if (videoSize.width > 0 && videoSize.height > 0) {
                        // SurfaceProducer handles buffer size automatically
                        sendEvent(
                            mapOf(
                                "type" to "videoSize",
                                "width" to videoSize.width,
                                "height" to videoSize.height
                            )
                        )
                    }
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                sendEvent(
                    mapOf(
                        "type" to "isPlaying",
                        "value" to isPlaying
                    )
                )
            }

            override fun onPlayerError(error: PlaybackException) {
                val errorMsg = when (error.errorCode) {
                    PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED ->
                        "Network connection failed"

                    PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT ->
                        "Network connection timeout"

                    PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS ->
                        "Bad HTTP status: ${error.message}"

                    PlaybackException.ERROR_CODE_DECODER_INIT_FAILED ->
                        "Decoder initialization failed"

                    PlaybackException.ERROR_CODE_DECODING_FAILED ->
                        "Decoding failed"

                    PlaybackException.ERROR_CODE_AUDIO_TRACK_INIT_FAILED ->
                        "Audio track initialization failed"

                    else -> error.message ?: "Unknown error (${error.errorCode})"
                }
                sendEvent(
                    mapOf(
                        "type" to "error",
                        "error" to errorMsg,
                        "errorCode" to error.errorCode
                    )
                )
            }

            override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
                // SurfaceProducer handles buffer size automatically, no need for manual sizing
                sendEvent(
                    mapOf(
                        "type" to "videoSize",
                        "width" to videoSize.width,
                        "height" to videoSize.height
                    )
                )
            }
        })

        exoPlayer.prepare()
        player = exoPlayer

        // Start position updates
        mainHandler.post(positionUpdateRunnable)

        return surfaceProducer!!.id()
    }

    private fun sendPositionUpdate() {
        val p = player ?: return
        if (p.playbackState == Player.STATE_IDLE) return
        sendEvent(
            mapOf(
                "type" to "position",
                "position" to p.currentPosition,
                "duration" to p.duration.coerceAtLeast(0),
                "buffered" to p.bufferedPosition
            )
        )
    }

    private fun sendEvent(data: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(data)
        }
    }

    private fun setVideoTrackEnabled(enabled: Boolean) {
        val p = player ?: return
        val params = p.trackSelectionParameters.buildUpon()
        if (enabled) {
            params.setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, false)
        } else {
            params.setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, true)
        }
        p.trackSelectionParameters = params.build()
    }

    private fun setSubtitleTrack(
        id: String?,
        title: String?,
        language: String?,
        uri: Boolean,
        data: Boolean
    ) {
        // Subtitles are now rendered by the Flutter overlay.
        // This method is intentionally a no-op.
    }
    private fun disposePlayer() {
        releaseExoPlayer()
        releaseSurface()
    }

    private fun releaseExoPlayer() {
        mainHandler.removeCallbacks(positionUpdateRunnable)
        // Important: Clear surface from player BEFORE releasing player
        // This ensures buffers are returned to the queue
        player?.setVideoSurface(null)
        player?.release()
        player = null
    }

    private fun releaseSurface() {
        // SurfaceProducer manages the surface internally, just release it
        surface?.release()
        surface = null
        // Release the SurfaceProducer which properly handles buffer lifecycle
        surfaceProducer?.release()
        surfaceProducer = null
    }
}
