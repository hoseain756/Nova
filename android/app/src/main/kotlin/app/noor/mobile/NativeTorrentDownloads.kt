package app.noor.mobile

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

/** Bridge passes durable jobs to a service, never a Flutter localhost stream. */
internal object NativeTorrentDownloads {
    private val operations = Executors.newSingleThreadExecutor()
    @Volatile private var requestedStartAt = 0L
    fun register(activity: Activity, messenger: BinaryMessenger) {
        val context = activity.applicationContext
        val main = Handler(Looper.getMainLooper())
        MethodChannel(messenger, "nova/torrent_downloads").setMethodCallHandler { call, result ->
            if (call.method == "notificationPermission") {
                if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4102)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            operations.execute {
                try {
                    val id = requireNotNull(call.argument<String>("id"))
                    val value: Any? = when (call.method) {
                        "enqueue" -> {
                            val row = JSONObject().put("id", id)
                                .put("title", call.argument<String>("title") ?: "NOVA")
                                .put("fileName", requireNotNull(call.argument<String>("fileName")))
                                .put("english", call.argument<Boolean>("english") ?: false)
                                .put("labels", JSONObject(call.argument<Map<String, String>>("labels") ?: emptyMap<String, String>()))
                                .put("createdAt", System.currentTimeMillis())
                                .put("source", JSONObject(requireNotNull(call.argument<Map<String, Any?>>("source"))))
                            TorrentDownloadStore.enqueue(context, row)
                            try {
                                requestedStartAt = SystemClock.elapsedRealtime()
                                val intent = Intent(context, NovaTorrentDownloadService::class.java)
                                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
                            } catch (error: Exception) {
                                TorrentDownloadStore.update(context, id) { it.put("status", "failed").put("error", "backgroundLimit") }
                                throw error
                            }
                            null
                        }
                        "query" -> {
                            val previous = TorrentDownloadStore.get(context, id)
                            if (previous?.optString("status") in listOf("queued", "downloading") &&
                                !NovaTorrentDownloadService.running &&
                                NovaTorrentDownloadService.activeId == null &&
                                SystemClock.elapsedRealtime() - requestedStartAt > 15000) {
                                TorrentDownloadStore.update(context, id) { it.put("status", "failed").put("error", "interrupted") }
                            }
                            val row = TorrentDownloadStore.get(context, id)
                            if (row == null) null else mapOf(
                                "status" to row.optString("status"), "received" to row.optLong("received"),
                                "total" to row.optLong("total"), "error" to row.optString("error").ifEmpty { null })
                        }
                        "cancel", "remove" -> {
                            TorrentDownloadStore.update(context, id) {
                                if (it.optString("status") != "complete") it.put("status", "cancelled").remove("error")
                            }
                            NovaTorrentDownloadService.awaitRetired(id)
                            if (call.method == "remove") {
                                TorrentDownloadStore.cleanWorkspace(context, id)
                                TorrentDownloadStore.remove(context, id)
                                context.getSystemService(android.app.NotificationManager::class.java).cancel(id, 4101)
                            }
                            null
                        }
                        else -> throw IllegalArgumentException("Unknown download operation")
                    }
                    main.post { result.success(value) }
                } catch (_: Exception) {
                    main.post { result.error("torrent_download", "Download operation could not finish", null) }
                }
            }
        }
    }
}
