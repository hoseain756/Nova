package app.noor.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import com.frostwire.jlibtorrent.AnnounceEntry
import com.frostwire.jlibtorrent.Priority
import com.frostwire.jlibtorrent.SessionManager
import com.frostwire.jlibtorrent.SessionParams
import com.frostwire.jlibtorrent.SettingsPack
import com.frostwire.jlibtorrent.Sha1Hash
import com.frostwire.jlibtorrent.TorrentHandle
import com.frostwire.jlibtorrent.TorrentInfo
import com.frostwire.jlibtorrent.swig.add_torrent_params
import com.frostwire.jlibtorrent.swig.error_code
import org.json.JSONObject
import java.io.File
import java.io.ByteArrayOutputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import java.util.concurrent.CancellationException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Activity-independent, single-transfer queue; no Flutter engine is required. */
class NovaTorrentDownloadService : Service() {
    companion object {
        const val CHANNEL = "nova_torrent_progress"
        const val FINISHED_CHANNEL = "nova_download_finished"
        private const val NOTIFICATION = 4100
        @Volatile var activeId: String? = null
            private set
        @Volatile var running = false
            private set
        internal val completionMonitor = Object()
        fun awaitRetired(id: String) {
            val deadline = SystemClock.elapsedRealtime() + 90000
            synchronized(completionMonitor) {
                while (activeId == id) {
                    check(SystemClock.elapsedRealtime() < deadline) { "Download is still stopping" }
                    completionMonitor.wait(250)
                }
            }
        }
    }
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    @Volatile private var stopping = false
    private var pumping = false
    private var lastStartId = 0
    private val notifications get() = getSystemService(NotificationManager::class.java)
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            notifications.createNotificationChannel(NotificationChannel(CHANNEL, "NOVA downloads / تنزيلات NOVA", NotificationManager.IMPORTANCE_LOW))
            notifications.createNotificationChannel(NotificationChannel(FINISHED_CHANNEL, "NOVA completed downloads / اكتمال التنزيل", NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lastStartId = startId
        running = true
        val notification = notification(null, false)
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(NOTIFICATION, notification)
        pump()
        return START_STICKY
    }
    private fun pump() {
        if (pumping || stopping) return
        pumping = true
        worker.execute {
            val wake = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "NOVA:TorrentDownload")
            try {
                wake.acquire(TimeUnit.HOURS.toMillis(6))
                while (!stopping) {
                    activeId?.let { awaitRetired(it) }
                    val row = TorrentDownloadStore.next(this) ?: break
                    val id = row.getString("id")
                    activeId = id
                    try { download(row) }
                    catch (_: CancellationException) { /* Durable cancellation already recorded. */ }
                    catch (_: InterruptedException) { /* Process/service retirement retains pieces. */ }
                    catch (error: Exception) {
                        runCatching { TorrentDownloadStore.update(this, id) {
                            if (it.optString("status") != "cancelled") {
                                it.put("status", "failed").put("error", if (error is java.io.IOException) "storage" else "network")
                            }
                        } }.onFailure { stopping = true }
                        runCatching { postFinished(id) }
                    } finally {
                        synchronized(completionMonitor) { activeId = null; completionMonitor.notifyAll() }
                    }
                }
            } catch (_: Exception) {
                stopping = true
            } finally {
                if (wake.isHeld) wake.release()
                main.post {
                    pumping = false
                    if (!stopping && runCatching { TorrentDownloadStore.next(this) != null }.getOrDefault(false)) pump()
                    else {
                        running = false
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelfResult(lastStartId)
                    }
                }
            }
        }
    }
    private fun checkActive(id: String) {
        if (stopping || Thread.currentThread().isInterrupted) throw InterruptedException()
        if (TorrentDownloadStore.get(this, id)?.optString("status") !in listOf("queued", "downloading")) throw CancellationException()
    }
    private fun magnetHash(magnet: String): String {
        val error = error_code()
        val parsed = add_torrent_params.parse_magnet_uri(magnet, error)
        require(error.value() == 0)
        return Sha1Hash(parsed.getInfo_hashes().get_best()).toHex()
    }
    private fun metadata(session: SessionManager, magnet: String, hash: String, work: File, id: String): TorrentInfo {
        val cached = File(work, "metadata.torrent")
        fun decode(bytes: ByteArray): TorrentInfo? = try {
            TorrentInfo.bdecode(bytes).takeIf { it.isValid && it.infoHashV1().toHex().equals(hash, true) }
        } catch (_: Exception) { null }
        if (cached.exists()) decode(cached.readBytes())?.let { return it }
        // Same metadata bootstrap as NOVA streaming, with a strict size/timeout bound.
        try {
            val connection = URL("https://itorrents.org/torrent/${hash.uppercase()}.torrent").openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = 8000; connection.readTimeout = 8000
                if (connection.responseCode == 200) {
                    val bytes = connection.inputStream.use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(16384)
                        while (output.size() <= 8 * 1024 * 1024) {
                            checkActive(id)
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                    if (bytes.size <= 8 * 1024 * 1024) decode(bytes)?.let { cached.writeBytes(bytes); return it }
                }
            } finally { connection.disconnect() }
        } catch (_: Exception) { /* Retry through the swarm. */ }
        repeat(2) {
            checkActive(id)
            val bytes = session.fetchMagnet(magnet, 20, work)
            if (bytes != null) decode(bytes)?.let { cached.writeBytes(bytes); return it }
        }
        error("metadata_timeout")
    }
    private fun download(row: JSONObject) {
        val id = row.getString("id")
        checkActive(id)
        val source = row.getJSONObject("source")
        val magnet = source.getString("magnet")
        val hash = magnetHash(magnet)
        val work = TorrentDownloadStore.workspace(this, id)
        val destination = TorrentDownloadStore.destination(this, row)
        val partial = File(destination.path + ".part")
        val session = SessionManager()
        var stopped = false
        try {
            checkActive(id)
            TorrentDownloadStore.update(this, id) { it.put("status", "downloading").remove("error") }
            val settings = SettingsPack().apply {
                listenInterfaces("0.0.0.0:0,[::]:0")
                setEnableDht(true)
                setDhtBootstrapNodes("dht.libtorrent.org:25401,router.bittorrent.com:6881,dht.transmissionbt.com:6881")
                anonymousMode(false); activeDownloads(1); activeSeeds(0); connectionsLimit(80)
            }
            session.start(SessionParams(settings))
            if (!session.isDhtRunning) session.startDht()
            val info = metadata(session, magnet, hash, work, id)
            checkActive(id)
            val files = info.files()
            val videos = (0 until info.numFiles()).filter { files.fileName(it).lowercase().matches(Regex(".*\\.(mp4|mkv|webm|avi|mov|m4v)$")) }
            val requested = source.optInt("fileIndex", -1)
            val wanted = source.optString("filename").replace('\\', '/').substringAfterLast('/')
            val index = requested.takeIf { it in videos }
                ?: videos.firstOrNull { files.fileName(it).equals(wanted, true) }
                ?: videos.maxByOrNull { files.fileSize(it) } ?: error("no_video_file")
            for (i in 0 until info.numFiles()) {
                require(File(work, files.filePath(i)).canonicalPath.startsWith(work.canonicalPath + File.separator))
            }
            val size = files.fileSize(index)
            require(size > 0)
            session.download(info, work) // Added paused; set file priorities BEFORE resuming.
            var handle: TorrentHandle? = null
            val deadline = SystemClock.elapsedRealtime() + 15000
            while (handle == null && SystemClock.elapsedRealtime() < deadline) {
                checkActive(id)
                handle = session.find(Sha1Hash(hash))?.takeIf { it.isValid }
                if (handle == null) Thread.sleep(200)
            }
            val torrent = requireNotNull(handle)
            val priorities = Priority.array(Priority.IGNORE, info.numFiles())
            priorities[index] = Priority.FOUR
            torrent.prioritizeFiles(priorities)
            for (match in Regex("(?:[?&])tr=([^&]+)").findAll(magnet)) {
                try { torrent.addTracker(AnnounceEntry(URLDecoder.decode(match.groupValues[1], "UTF-8"))) } catch (_: Exception) { }
            }
            torrent.resume()
            torrent.forceReannounce(0, -1, TorrentHandle.IGNORE_MIN_INTERVAL)
            val first = (files.fileOffset(index) / info.pieceLength()).toInt()
            val last = ((files.fileOffset(index) + size - 1) / info.pieceLength()).toInt()
            while (true) {
                checkActive(id)
                val bytes = torrent.fileProgress().getOrNull(index)?.coerceIn(0, size) ?: 0
                TorrentDownloadStore.update(this, id) { it.put("received", bytes).put("total", size) }
                try { notifications.notify(NOTIFICATION, notification(TorrentDownloadStore.get(this, id), false)) }
                catch (_: SecurityException) { /* Transfer may continue if notifications are denied. */ }
                if (bytes == size && (first..last).all { torrent.havePiece(it) }) break
                Thread.sleep(1500)
            }
            torrent.pause()
            session.stop() // Await libtorrent/disk retirement before moving or exposing the file.
            stopped = true
            checkActive(id)
            val video = File(work, files.filePath(index))
            check(video.length() == size && videoSignature(video))
            if (!video.renameTo(partial)) {
                video.inputStream().use { input -> partial.outputStream().use { output ->
                    val buffer = ByteArray(256 * 1024)
                    while (true) { checkActive(id); val count = input.read(buffer); if (count < 0) break; output.write(buffer, 0, count) }
                    output.fd.sync()
                } }
            }
            checkActive(id)
            check(partial.length() == size && partial.renameTo(destination))
            TorrentDownloadStore.update(this, id) {
                if (it.optString("status") == "cancelled") { destination.delete(); throw CancellationException() }
                it.put("status", "complete").put("received", size).put("total", size).remove("error")
            }
            try { TorrentDownloadStore.cleanWorkspace(this, id) } catch (_: Exception) { /* Valid completed file remains available. */ }
            postFinished(id)
        } finally {
            if (!stopped) session.stop()
            if (partial.exists()) partial.delete()
        }
    }
    private fun videoSignature(file: File): Boolean = RandomAccessFile(file, "r").use {
        if (it.length() < 16) return false
        val bytes = ByteArray(12); it.readFully(bytes)
        val marker = String(bytes, 4, 4, Charsets.US_ASCII)
        marker in listOf("ftyp", "moov", "mdat") ||
            (bytes[0] == 0x1a.toByte() && bytes[1] == 0x45.toByte() && bytes[2] == 0xdf.toByte() && bytes[3] == 0xa3.toByte()) ||
            (String(bytes, 0, 4, Charsets.US_ASCII) == "RIFF" && String(bytes, 8, 4, Charsets.US_ASCII) in listOf("AVI ", "AVIX"))
    }
    private fun notification(row: JSONObject?, finished: Boolean): Notification {
        val title = row?.optString("title")?.take(120) ?: "NOVA"
        val complete = row?.optString("status") == "complete"
        val textKey = if (!finished) "downloadInBackground" else if (complete) "downloadCompleteNotification" else "downloadStoppedNotification"
        val text = row?.optJSONObject("labels")?.optString(textKey)?.takeIf { it.isNotBlank() } ?: "NOVA"
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, if (finished) FINISHED_CHANNEL else CHANNEL) else Notification.Builder(this)
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val content = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        builder.setSmallIcon(R.drawable.ic_stat_nova).setContentTitle(title).setContentText(text)
            .setContentIntent(content).setOnlyAlertOnce(!finished).setAutoCancel(finished).setOngoing(!finished)
        if (!finished) {
            val total = row?.optLong("total") ?: 0
            val received = row?.optLong("received") ?: 0
            builder.setProgress(100, if (total > 0) (received.toDouble() / total * 100).toInt().coerceIn(0, 100) else 0, total == 0L)
        }
        return builder.build()
    }
    private fun postFinished(id: String) {
        val row = TorrentDownloadStore.get(this, id) ?: return
        if (row.optString("status") == "cancelled") return
        try { notifications.notify(id, 4101, notification(row, true)) } catch (_: SecurityException) { /* User disabled notifications. */ }
    }
    override fun onTimeout(startId: Int, fgsType: Int) {
        stopping = true
        activeId?.let { id ->
            TorrentDownloadStore.update(this, id) { it.put("status", "failed").put("error", "backgroundLimit") }
            postFinished(id)
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    override fun onDestroy() {
        stopping = true
        running = false
        worker.shutdownNow()
        super.onDestroy()
    }
}
