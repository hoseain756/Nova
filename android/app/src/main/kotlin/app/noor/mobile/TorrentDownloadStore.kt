package app.noor.mobile

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Private durable queue. Tracker/source hints are encrypted with Android Keystore. */
internal object TorrentDownloadStore {
    private const val alias = "nova.torrent.downloads.v1"
    private val ids = Regex("^[0-9a-fA-F-]{36}$")
    private val names = Regex("^[0-9a-fA-F-]{36}\\.(mp4|mkv|webm|avi|mov|m4v)$")
    private var cached: JSONObject? = null
    private var encryptionKey: SecretKey? = null
    // Keystore keys are not backed up; do not restore ciphertext without its key.
    private fun file(context: Context) = AtomicFile(File(context.noBackupFilesDir, "nova-torrent-downloads.enc"))
    private fun key(): SecretKey {
        encryptionKey?.let { return it }
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { encryptionKey = it; return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey().also { encryptionKey = it }
    }
    private fun read(context: Context): JSONObject {
        cached?.let { return JSONObject(it.toString()) }
        val saved = file(context)
        if (!saved.baseFile.exists() && !File(saved.baseFile.path + ".bak").exists()) return JSONObject()
        val bytes = saved.openRead().use { it.readBytes() }
        require(bytes.size > 28)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return JSONObject(String(cipher.doFinal(bytes, 12, bytes.size - 12), Charsets.UTF_8)).also {
            cached = JSONObject(it.toString())
        }
    }
    private fun write(context: Context, value: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val bytes = cipher.iv + cipher.doFinal(value.toString().toByteArray(Charsets.UTF_8))
        val saved = file(context)
        val output = saved.startWrite()
        try { output.write(bytes); saved.finishWrite(output); cached = JSONObject(value.toString()) }
        catch (error: Exception) { saved.failWrite(output); throw error }
    }
    @Synchronized fun get(context: Context, id: String): JSONObject? = read(context).optJSONObject(id)
    @Synchronized fun update(context: Context, id: String, action: (JSONObject) -> Unit) {
        val rows = read(context)
        val row = rows.optJSONObject(id) ?: return
        action(row)
        write(context, rows)
    }
    @Synchronized fun enqueue(context: Context, row: JSONObject) {
        val id = row.getString("id")
        require(ids.matches(id) && names.matches(row.getString("fileName")))
        require(row.getString("fileName").startsWith("$id."))
        val source = row.getJSONObject("source")
        require(source.getString("magnet").startsWith("magnet:?"))
        val rows = read(context)
        val old = rows.optJSONObject(id)
        check(old == null || old.optString("status") !in listOf("queued", "downloading", "complete"))
        row.put("status", "queued").put("received", 0).put("total", 0).remove("error")
        rows.put(id, row)
        write(context, rows)
    }
    @Synchronized fun next(context: Context): JSONObject? {
        val rows = read(context)
        return rows.keys().asSequence().map { rows.getJSONObject(it) }
            .filter { it.optString("status") in listOf("queued", "downloading") }
            .minByOrNull { it.optLong("createdAt") }
    }
    @Synchronized fun remove(context: Context, id: String) {
        require(ids.matches(id))
        val rows = read(context)
        rows.remove(id)
        write(context, rows)
    }
    fun destination(context: Context, row: JSONObject): File {
        val name = row.getString("fileName")
        require(names.matches(name) && name.startsWith("${row.getString("id")}."))
        val root = File(requireNotNull(context.getExternalFilesDir(null)), "nova_downloads").apply { mkdirs() }.canonicalFile
        return File(root, name).also { require(it.canonicalFile.parentFile == root) }
    }
    fun workspace(context: Context, id: String): File {
        require(ids.matches(id))
        val root = File(context.noBackupFilesDir, "nova-torrent-jobs").apply { mkdirs() }.canonicalFile
        return File(root, id).also { require(it.canonicalFile.parentFile == root); it.mkdirs() }
    }
    /** Only this job's validated staging directory; never follows a foreign path. */
    fun cleanWorkspace(context: Context, id: String) {
        val root = File(context.noBackupFilesDir, "nova-torrent-jobs").canonicalFile
        val work = workspace(context, id)
        require(work.canonicalFile.parentFile == root && work.name == id)
        fun erase(file: File) {
            require(file.canonicalPath == work.canonicalPath || file.canonicalPath.startsWith(work.canonicalPath + File.separator))
            if (file.isDirectory) file.listFiles()?.forEach { erase(it) }
            check(!file.exists() || file.delete())
        }
        erase(work)
    }
}
