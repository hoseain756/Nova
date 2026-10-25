package app.noor.mobile

import android.app.ActivityManager
import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.WindowManager
import android.view.PixelCopy
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.text.CueGroup
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/** Flutter owns navigation and session policy. This adapter owns one native decoder. */
@UnstableApi
class NovaMedia3Plugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var sink: EventChannel.EventSink? = null
    private var active: NativePlayer? = null
    private var nextId = 0L
    private var retirementFailed = false
    private var activity: Activity? = null
    private val imageWorker = Executors.newSingleThreadExecutor()
    private fun updateScreenOn() {
        if (active?.keepScreenOn == true) activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity; updateScreenOn() }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
    override fun onDetachedFromActivity() {
        activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        activity = null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        methods = MethodChannel(binding.binaryMessenger, "nova/player/media3")
        events = EventChannel(binding.binaryMessenger, "nova/player/media3/events")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        try { active?.close() } finally { active = null; imageWorker.shutdown() }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        active?.emitState()
        active?.emitTracks()
    }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (call.method == "create") {
                check(active == null && !retirementFailed) { "Native playback still owned" }
                val player = NativePlayer(++nextId)
                active = player
                result.success(mapOf("id" to player.id, "textureId" to player.surface.id()))
                return
            }
            val player = active
            val id = call.argument<Number>("id")?.toLong()
            if (player == null || id != player.id) {
                if (call.method == "close" && !retirementFailed) result.success(null)
                else result.error("stale_player", "Player is no longer active", null)
                return
            }
            if (call.method == "close") {
                try {
                    player.close()
                    active = null
                    updateScreenOn()
                    result.success(null)
                } catch (error: Exception) {
                    retirementFailed = true
                    result.error("retirement_failed", "Native playback did not retire", null)
                }
                return
            }
            player.command(call, result)
        } catch (error: Exception) {
            // Never send source URLs, request headers or provider error bodies to logs.
            result.error("media3_operation", error.javaClass.simpleName, null)
        }
    }

    private inner class NativePlayer(val id: Long) : Player.Listener {
        private val handler = Handler(Looper.getMainLooper())
        val surface: TextureRegistry.SurfaceProducer = binding.textureRegistry.createSurfaceProducer()
        private val context = binding.applicationContext
        private val http = DefaultHttpDataSource.Factory()
            .setUserAgent("NOVA")
            .setConnectTimeoutMs(15000)
            .setReadTimeoutMs(20000)
        private val data = DefaultDataSource.Factory(context, http)
        private val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        // Encoded sample budget, not total decoder/GPU memory. Tune only from device data.
        private val bufferBytes = (if (manager.isLowRamDevice) 24 else 48) * 1024 * 1024
        private val player = ExoPlayer.Builder(context, DefaultRenderersFactory(context).setEnableDecoderFallback(true))
            .setMediaSourceFactory(DefaultMediaSourceFactory(data))
            .setLoadControl(DefaultLoadControl.Builder()
                .setBufferDurationsMs(15000, 40000, 1000, 2500)
                .setTargetBufferBytes(bufferBytes)
                .setPrioritizeTimeOverSizeThresholds(false)
                .setBackBuffer(0, false)
                .build())
            .run {
                try { build() } catch (error: Exception) { surface.release(); throw error }
            }
        private var closed = false
        private var pending: MethodChannel.Result? = null
        private var openedAt = 0L
        private var firstFrameMs: Long? = null
        private var droppedFrames = 0
        private var failureCode: Int? = null
        private var videoWidth = 1
        private var videoHeight = 1
        private var videoAspect = 1.0
        private var rotationDegrees = 0
        private var cues: List<String> = emptyList()
        private var externalId: String? = null
        val keepScreenOn: Boolean get() = !closed && player.playWhenReady && failureCode == null &&
            (player.playbackState == Player.STATE_READY || player.playbackState == Player.STATE_BUFFERING)
        private val timeout = Runnable {
            pending?.error("open_timeout", "Media preparation timed out", null)
            pending = null
            player.pause()
        }
        private val ticker = object : Runnable {
            override fun run() {
                if (closed) return
                emitState()
                if (player.isPlaying || player.playbackState == Player.STATE_BUFFERING) {
                    handler.postDelayed(this, 250)
                }
            }
        }

        init {
            try {
                surface.setSize(1, 1)
                surface.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
                    override fun onSurfaceAvailable() {
                        if (!closed) player.setVideoSurface(surface.surface)
                    }
                    override fun onSurfaceCleanup() {
                        if (!closed) player.clearVideoSurface()
                    }
                })
                player.setVideoSurface(surface.surface)
                player.setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), true)
                player.setHandleAudioBecomingNoisy(true)
                player.addListener(this)
                player.addAnalyticsListener(object : AnalyticsListener {
                    override fun onDroppedVideoFrames(eventTime: AnalyticsListener.EventTime, count: Int, elapsedMs: Long) {
                        droppedFrames += count
                    }
                    override fun onRenderedFirstFrame(eventTime: AnalyticsListener.EventTime, output: Any, renderTimeMs: Long) {
                        if (firstFrameMs == null) firstFrameMs = SystemClock.elapsedRealtime() - openedAt
                        emitState()
                    }
                })
            } catch (error: Exception) {
                player.release()
                surface.release()
                throw error
            }
        }

        fun command(call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "open" -> {
                    check(pending == null)
                    failureCode = null
                    firstFrameMs = null
                    droppedFrames = 0
                    cues = emptyList()
                    externalId = null
                    openedAt = SystemClock.elapsedRealtime()
                    http.setDefaultRequestProperties(call.argument<Map<String, String>>("headers") ?: emptyMap())
                    player.playWhenReady = false
                    player.setMediaItem(MediaItem.fromUri(requireNotNull(call.argument<String>("url"))))
                    prepare(result)
                    return
                }
                "play" -> player.play()
                "pause" -> player.pause()
                "seek" -> {
                    check(player.isCurrentMediaItemSeekable)
                    player.seekTo(requireNotNull(call.argument<Number>("positionMs")).toLong().coerceAtLeast(0))
                    cues = emptyList()
                }
                "rate" -> player.setPlaybackSpeed(requireNotNull(call.argument<Number>("value")).toFloat().coerceIn(0.25f, 4f))
                "volume" -> player.volume = requireNotNull(call.argument<Number>("value")).toFloat().coerceIn(0f, 1f)
                "audio" -> selectTrack(C.TRACK_TYPE_AUDIO, requireNotNull(call.argument<String>("track")))
                "subtitle" -> {
                    selectTrack(C.TRACK_TYPE_TEXT, requireNotNull(call.argument<String>("track")))
                    cues = emptyList()
                }
                "externalSubtitle" -> {
                    check(pending == null)
                    val key = "nova-external"
                    val subtitle = MediaItem.SubtitleConfiguration.Builder(Uri.parse(requireNotNull(call.argument<String>("uri"))))
                        .setId(key)
                        .setMimeType(call.argument<String>("mime"))
                        .setLabel(call.argument<String>("title"))
                        .setLanguage(call.argument<String>("language"))
                        .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                        .build()
                    val item = requireNotNull(player.currentMediaItem).buildUpon()
                        .setSubtitleConfigurations(listOf(subtitle)).build()
                    externalId = key
                    player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
                        .clearOverridesOfType(C.TRACK_TYPE_TEXT)
                        .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false).build()
                    cues = emptyList()
                    player.setMediaItem(item, player.currentPosition)
                    prepare(result)
                    return
                }
                "state" -> Unit
                "capture" -> { capture(result); return }
                else -> { result.notImplemented(); return }
            }
            result.success(snapshot())
            emitState()
        }

        private fun prepare(result: MethodChannel.Result) {
            pending = result
            handler.removeCallbacks(timeout)
            handler.postDelayed(timeout, 30000)
            try { player.prepare() } catch (error: Exception) {
                pending = null
                handler.removeCallbacks(timeout)
                throw error
            }
        }

        private fun capture(result: MethodChannel.Result) {
            if (closed || firstFrameMs == null || videoWidth <= 1 || videoHeight <= 1) {
                result.success(null)
                return
            }
            val scale = minOf(1.0, 960.0 / videoWidth)
            val bitmap = Bitmap.createBitmap((videoWidth * scale).toInt().coerceAtLeast(1),
                (videoHeight * scale).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
            val rotation = rotationDegrees
            try {
                PixelCopy.request(surface.surface, bitmap, { status ->
                    if (status != PixelCopy.SUCCESS || closed || imageWorker.isShutdown) {
                        bitmap.recycle()
                        result.success(null)
                    } else {
                        imageWorker.execute {
                            val bytes = try {
                                ByteArrayOutputStream().use { output ->
                                    val oriented = if (rotation == 0) bitmap else Bitmap.createBitmap(
                                        bitmap, 0, 0, bitmap.width, bitmap.height,
                                        Matrix().apply { postRotate(rotation.toFloat()) }, true)
                                    try { oriented.compress(Bitmap.CompressFormat.JPEG, 80, output) }
                                    finally { if (oriented !== bitmap) oriented.recycle() }
                                    output.toByteArray()
                                }
                            } catch (_: Exception) { null } finally { bitmap.recycle() }
                            handler.post { result.success(bytes) }
                        }
                    }
                }, handler)
            } catch (_: Exception) {
                bitmap.recycle()
                result.success(null)
            }
        }

        private fun selectTrack(type: Int, key: String) {
            val builder = player.trackSelectionParameters.buildUpon().clearOverridesOfType(type)
                .setTrackTypeDisabled(type, key == "no")
            if (key != "auto" && key != "no") {
                val parts = key.split(":")
                require(parts.size == 2)
                val group = player.currentTracks.groups[parts[0].toInt()]
                val index = parts[1].toInt()
                require(group.type == type && index >= 0 && index < group.length && group.isTrackSupported(index))
                builder.setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, index))
            }
            if (type == C.TRACK_TYPE_TEXT) externalId = null
            player.trackSelectionParameters = builder.build()
        }

        override fun onTracksChanged(tracks: Tracks) {
            val target = externalId
            if (target != null) {
                tracks.groups.forEach { group ->
                    if (group.type == C.TRACK_TYPE_TEXT) {
                        for (i in 0 until group.length) {
                            if (group.getTrackFormat(i).id == target && !group.isTrackSelected(i)) {
                                player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
                                    .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i)).build()
                            }
                        }
                    }
                }
            }
            emitTracks()
        }

        fun emitTracks() {
            val rows = mutableListOf<Map<String, Any?>>()
            player.currentTracks.groups.forEachIndexed { groupIndex, group ->
                if (group.type == C.TRACK_TYPE_AUDIO || group.type == C.TRACK_TYPE_TEXT) {
                    for (i in 0 until group.length) {
                        if (!group.isTrackSupported(i)) continue
                        val format = group.getTrackFormat(i)
                        rows.add(mapOf("id" to "$groupIndex:$i", "type" to group.type,
                            "title" to format.label, "language" to format.language, "selected" to group.isTrackSelected(i)))
                    }
                }
            }
            sink?.success(mapOf("id" to id, "event" to "tracks", "tracks" to rows))
        }

        override fun onCues(cueGroup: CueGroup) {
            if (cueGroup.cues.any { it.bitmap != null }) {
                // The Flutter subtitle overlay consumes text. Auto can retry with mpv.
                failureCode = 7100
                player.pause()
                emitState()
                return
            }
            cues = cueGroup.cues.mapNotNull { it.text?.toString() }
            sink?.success(mapOf("id" to id, "event" to "cues", "cues" to cues))
        }

        override fun onVideoSizeChanged(size: VideoSize) {
            videoWidth = size.width.coerceAtLeast(1)
            videoHeight = size.height.coerceAtLeast(1)
            videoAspect = videoWidth.toDouble() * size.pixelWidthHeightRatio / videoHeight
            val rotation = if (surface.handlesCropAndRotation()) 0 else player.videoFormat?.rotationDegrees ?: 0
            rotationDegrees = if (rotation in listOf(0, 90, 180, 270)) rotation else 0
            surface.setSize(videoWidth, videoHeight)
            emitState()
        }

        override fun onPlayerError(error: PlaybackException) {
            failureCode = error.errorCode
            handler.removeCallbacks(timeout)
            pending?.error("media3_${error.errorCode}", error.errorCodeName, mapOf("errorCode" to error.errorCode))
            pending = null
            emitState()
        }

        override fun onEvents(player: Player, events: Player.Events) {
            if (closed) return
            if (player.playbackState == Player.STATE_READY && pending != null) {
                handler.removeCallbacks(timeout)
                pending?.success(snapshot())
                pending = null
                emitTracks()
            }
            handler.removeCallbacks(ticker)
            emitState()
            if (player.isPlaying || player.playbackState == Player.STATE_BUFFERING) handler.postDelayed(ticker, 250)
        }

        fun emitState() {
            if (!closed) { updateScreenOn(); sink?.success(snapshot()) }
        }
        private fun snapshot(): Map<String, Any?> = mapOf(
            "id" to id, "event" to "state", "ready" to (player.playbackState == Player.STATE_READY),
            "playing" to player.isPlaying, "buffering" to (player.playbackState == Player.STATE_BUFFERING),
            "completed" to (player.playbackState == Player.STATE_ENDED),
            "positionMs" to player.currentPosition.coerceAtLeast(0),
            "durationMs" to player.duration.coerceAtLeast(0), "bufferedMs" to player.bufferedPosition.coerceAtLeast(0),
            "seekable" to player.isCurrentMediaItemSeekable, "rate" to player.playbackParameters.speed.toDouble(),
            "volume" to player.volume.toDouble(), "width" to videoWidth, "height" to videoHeight,
            "aspect" to videoAspect, "rotationDegrees" to rotationDegrees, "errorCode" to failureCode, "cues" to cues,
            "firstFrameMs" to firstFrameMs, "droppedFrames" to droppedFrames, "bufferTargetBytes" to bufferBytes)

        fun close() {
            if (closed) return
            handler.removeCallbacksAndMessages(null)
            pending?.error("cancelled", "Player closed", null)
            pending = null
            player.removeListener(this)
            player.clearVideoSurface()
            // Do not free output or admit another decoder if release throws.
            player.release()
            closed = true
            surface.setCallback(null)
            surface.release()
        }
    }
}
