package app.noor.mobile

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** System-owned direct-file downloads survive closing the Flutter activity. */
internal object NativeDownloads {
    private const val channelName = "nova/downloads"
    private val fileName = Regex("^[0-9a-fA-F-]{36}\\.(mp4|mkv|webm|avi|mov|m4v)$")

    fun register(context: Context, messenger: BinaryMessenger) {
        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        MethodChannel(messenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "enqueue" -> {
                        val url = call.argument<String>("url") ?: error("Missing URL")
                        val title = call.argument<String>("title") ?: "NOVA"
                        val name = call.argument<String>("fileName") ?: error("Missing name")
                        require(fileName.matches(name)) { "Invalid download name" }
                        val uri = Uri.parse(url)
                        require(uri.scheme == "https" || uri.scheme == "http")
                        require(!uri.host.isNullOrBlank())
                        val request = DownloadManager.Request(uri)
                            .setTitle(title.take(120))
                            .setNotificationVisibility(
                                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                            )
                            .setDestinationInExternalFilesDir(context, null, "nova_downloads/$name")
                        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                        for ((key, value) in headers) {
                            require(!key.contains('\r') && !key.contains('\n'))
                            require(!value.contains('\r') && !value.contains('\n'))
                            request.addRequestHeader(key, value)
                        }
                        result.success(manager.enqueue(request))
                    }
                    "query" -> {
                        val id = (call.argument<Number>("id") ?: error("Missing id")).toLong()
                        manager.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
                            if (!cursor.moveToFirst()) {
                                result.success(null)
                            } else {
                                fun number(column: String): Long =
                                    cursor.getLong(cursor.getColumnIndexOrThrow(column))
                                result.success(mapOf(
                                    "status" to number(DownloadManager.COLUMN_STATUS),
                                    "received" to number(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
                                    "total" to number(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                                ))
                            }
                        }
                    }
                    "remove" -> {
                        val id = (call.argument<Number>("id") ?: error("Missing id")).toLong()
                        result.success(manager.remove(id))
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("download", error.message ?: "Download operation failed", null)
            }
        }
    }
}
