package com.kotloy.kot_loy

import android.accounts.Account
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import androidx.work.*
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import com.google.android.gms.tasks.Tasks
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class BackupFailure(val code: String) : Exception(code)

/** No server secrets or OAuth tokens are persisted. Google Play services caches grants. */
class DriveBackup(private val context: Context) {
    companion object {
        const val SCOPE = "https://www.googleapis.com/auth/drive.file"
        const val FORMAT = "kot_luy_backup"
        const val LIMIT = 20 * 1024 * 1024
        val lock = ReentrantLock()
    }
    private val prefs = context.getSharedPreferences("kot_luy_drive", Context.MODE_PRIVATE)
    private val work get() = WorkManager.getInstance(context)
    private val email get() = prefs.getString("email", null)

    fun status(): Map<String, Any?> = mapOf(
        "email" to email,
        "automatic" to prefs.getBoolean("automatic", false),
        "wifiOnly" to prefs.getBoolean("wifiOnly", false),
        "lastSuccess" to prefs.getLong("lastSuccess", 0),
        "lastError" to prefs.getString("lastError", null),
        "queued" to prefs.getBoolean("queued", false),
        "lastCount" to prefs.getInt("lastCount", 0),
    )

    fun connected(account: String) = lock.withLock {
        if (account != email) {
            work.cancelAllWorkByTag("kot_luy_drive")
            val path = prefs.getString("path", null)
            val device = prefs.getString("device", UUID.randomUUID().toString())
            prefs.edit().clear().putString("path", path).putString("device", device)
                .putString("email", account).apply()
        }
        prefs.edit().remove("lastError").apply()
    }

    fun disconnect() = lock.withLock {
        work.cancelAllWorkByTag("kot_luy_drive")
        prefs.edit().remove("email").remove("folder").remove("lastHash")
            .remove("lastSuccess").remove("lastError").remove("lastCount")
            .putBoolean("automatic", false).putBoolean("queued", false).apply()
    }

    fun changed(path: String) {
        val file = File(path).canonicalFile
        require(file.path.startsWith(File(context.applicationInfo.dataDir).canonicalPath + File.separator))
        prefs.edit().putString("path", file.path).apply()
        if (email != null && prefs.getBoolean("automatic", false)) {
            schedulePeriodic()
            enqueue(false)
        }
    }

    fun configure(automatic: Boolean, wifiOnly: Boolean) = lock.withLock {
        prefs.edit().putBoolean("automatic", automatic).putBoolean("wifiOnly", wifiOnly).apply()
        work.cancelUniqueWork("kot_luy_periodic")
        work.cancelUniqueWork("kot_luy_changes")
        prefs.edit().putBoolean("queued", false).apply()
        if (automatic && email != null) {
            schedulePeriodic()
            enqueue(false)
        }
    }

    private fun constraints() = Constraints.Builder()
        .setRequiredNetworkType(if (prefs.getBoolean("wifiOnly", false)) NetworkType.UNMETERED else NetworkType.CONNECTED)
        .build()

    private fun schedulePeriodic() {
        val request = PeriodicWorkRequest.Builder(DriveBackupWorker::class.java, 6, TimeUnit.HOURS)
            .setConstraints(constraints()).setInputData(workDataOf("account" to email))
            .addTag("kot_luy_drive").build()
        work.enqueueUniquePeriodicWork("kot_luy_periodic", ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun enqueue(manual: Boolean) {
        if (email == null) throw BackupFailure("connect")
        prefs.edit().putBoolean("queued", true).apply()
        val request = OneTimeWorkRequest.Builder(DriveBackupWorker::class.java)
            .setConstraints(constraints())
            .setInitialDelay(if (manual) 0 else 60, TimeUnit.SECONDS)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .setInputData(workDataOf("account" to email, "manual" to manual))
            .addTag("kot_luy_drive").build()
        work.enqueueUniqueWork(if (manual) "kot_luy_manual" else "kot_luy_changes", ExistingWorkPolicy.KEEP, request)
    }

    private fun token(): String {
        val account = email ?: throw BackupFailure("connect")
        try {
            val result = Tasks.await(Identity.getAuthorizationClient(context).authorize(
                AuthorizationRequest.builder().setAccount(Account(account, "com.google"))
                    .setRequestedScopes(listOf(Scope(SCOPE))).build()
            ), 15, TimeUnit.SECONDS)
            if (!result.hasResolution() && !result.accessToken.isNullOrEmpty()) {
                return result.accessToken!!
            }
        } catch (_: Exception) {
            // Fall back to GoogleAuthUtil if Identity client has no cached token
        }
        try {
            return GoogleAuthUtil.getToken(context, Account(account, "com.google"), "oauth2:$SCOPE")
        } catch (e: Exception) {
            throw BackupFailure("reconnect")
        }
    }

    private fun request(token: String, path: String, method: String = "GET", body: ByteArray? = null,
                        type: String = "application/json; charset=UTF-8"): ByteArray {
        val connection = URI("https://www.googleapis.com/$path").toURL().openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15000
            connection.readTimeout = 30000
            connection.setRequestProperty("Authorization", "Bearer $token")
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", type)
                connection.setFixedLengthStreamingMode(body.size)
                connection.outputStream.use { it.write(body) }
            }
            val status = connection.responseCode
            if (status !in 200..299) {
                val error = connection.errorStream?.use { String(it.readNBytes(8192), Charsets.UTF_8) }.orEmpty()
                if (status == 401) {
                    try {
                        Identity.getAuthorizationClient(context).clearToken(ClearTokenRequest.builder().setToken(token).build())
                    } catch (_: Exception) {}
                    try {
                        GoogleAuthUtil.clearToken(context, token)
                    } catch (_: Exception) {}
                }
                throw BackupFailure(when {
                    status == 401 -> "reconnect"
                    error.contains("storageQuotaExceeded") -> "quota"
                    status == 429 || status >= 500 -> "network"
                    status == 403 -> "permission"
                    status == 404 -> "missing"
                    else -> "drive"
                })
            }
            return connection.inputStream.use {
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val read = it.read(buffer)
                    if (read < 0) break
                    if (out.size() + read > LIMIT) throw BackupFailure("too_large")
                    out.write(buffer, 0, read)
                }
                out.toByteArray()
            }
        } finally { connection.disconnect() }
    }

    private fun json(token: String, path: String, method: String = "GET", data: JSONObject? = null): JSONObject =
        JSONObject(String(request(token, path, method, data?.toString()?.toByteArray(Charsets.UTF_8)), Charsets.UTF_8))
    private fun enc(value: String) = URLEncoder.encode(value, "UTF-8")
    private fun digest(bytes: ByteArray, algorithm: String) = MessageDigest.getInstance(algorithm)
        .digest(bytes).joinToString("") { "%02x".format(it.toInt() and 255) }

    private fun folder(token: String): String {
        val query = "trashed = false and mimeType = 'application/vnd.google-apps.folder' and appProperties has { key='kotLuyFolder' and value='1' }"
        val files = json(token, "drive/v3/files?q=${enc(query)}&fields=files(id)&pageSize=100").getJSONArray("files")
        if (files.length() > 0) return files.getJSONObject(0).getString("id")
        return json(token, "drive/v3/files?fields=id", "POST", JSONObject()
            .put("name", "Kot Luy Backups").put("mimeType", "application/vnd.google-apps.folder")
            .put("appProperties", JSONObject().put("kotLuyFolder", "1"))).getString("id")
    }

    private fun rows(db: SQLiteDatabase, table: String, order: String): JSONArray {
        val result = JSONArray()
        db.rawQuery("SELECT * FROM $table ORDER BY $order", null).use { cursor ->
            while (cursor.moveToNext()) {
                val row = JSONObject()
                for (i in 0 until cursor.columnCount) {
                    row.put(cursor.getColumnName(i), when (cursor.getType(i)) {
                        Cursor.FIELD_TYPE_INTEGER -> cursor.getLong(i)
                        Cursor.FIELD_TYPE_NULL -> JSONObject.NULL
                        else -> cursor.getString(i)
                    })
                }
                result.put(row)
            }
        }
        return result
    }

    private fun snapshot(): JSONObject {
        val path = prefs.getString("path", null) ?: throw BackupFailure("database")
        SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            db.execSQL("BEGIN DEFERRED TRANSACTION")
            try {
                if (db.version != 2) throw BackupFailure("database")
                return JSONObject().put("format", FORMAT).put("version", 1).put("schemaVersion", 2)
                    .put("createdAt", System.currentTimeMillis())
                    .put("expenses", rows(db, "expenses", "id ASC"))
                    .put("categories", rows(db, "categories", "sort_order ASC, id ASC"))
            } finally { db.execSQL("ROLLBACK") }
        }
    }

    fun upload(force: Boolean, expectedAccount: String? = email) = lock.withLock {
        if (expectedAccount == null || email != expectedAccount) return@withLock
        if (!force && !prefs.getBoolean("automatic", false)) return@withLock
        try {
            val data = snapshot()
            val contentHash = digest((data.getJSONArray("expenses").toString() + data.getJSONArray("categories").toString()).toByteArray(Charsets.UTF_8), "SHA-256")
            if (!force && contentHash == prefs.getString("lastHash", null)) {
                prefs.edit().putBoolean("queued", false).remove("lastError").apply()
                return@withLock
            }
            val token = token()
            val device = prefs.getString("device", null) ?: UUID.randomUUID().toString().also {
                prefs.edit().putString("device", it).apply()
            }
            val bytes = data.toString(2).toByteArray(Charsets.UTF_8)
            if (bytes.size > LIMIT - 8192) throw BackupFailure("too_large")
            val stamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(Date())
            val properties = JSONObject().put("format", FORMAT).put("device", device).put("state", "pending")
            val metadata = JSONObject().put("name", "Kot Luy $stamp ${device.take(8)}.json")
                .put("mimeType", "text/plain").put("parents", JSONArray().put(folder(token)))
                .put("description", "Kot Luy expense backup. Restore using Kot Luy. Do not edit.")
                .put("appProperties", properties)
            val boundary = "kot_luy_${UUID.randomUUID()}"
            val head = "--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n--$boundary\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n"
            val payload = head.toByteArray(Charsets.UTF_8) + bytes + "\r\n--$boundary--\r\n".toByteArray()
            val uploaded = JSONObject(String(request(token, "upload/drive/v3/files?uploadType=multipart&fields=id,md5Checksum", "POST", payload, "multipart/related; boundary=$boundary"), Charsets.UTF_8))
            val id = uploaded.getString("id")
            if (uploaded.optString("md5Checksum") != digest(bytes, "MD5")) throw BackupFailure("integrity")
            properties.put("state", "complete")
            val sealed = json(token, "drive/v3/files/$id?fields=id,contentRestrictions,appProperties", "PATCH",
                JSONObject().put("appProperties", properties).put("contentRestrictions", JSONArray().put(
                    JSONObject().put("readOnly", true).put("ownerRestricted", true)
                        .put("reason", "Kot Luy backup — restore from the app"))))
            if (sealed.optJSONArray("contentRestrictions")?.optJSONObject(0)?.optBoolean("readOnly") != true) throw BackupFailure("lock")
            prefs.edit().putString("lastHash", contentHash).putLong("lastSuccess", System.currentTimeMillis())
                .putInt("lastCount", data.getJSONArray("expenses").length()).remove("lastError").putBoolean("queued", false).apply()
            // Retain five verified snapshots per device; other devices are untouched.
            try {
                val old = listFiles(token).filter { it.optJSONObject("appProperties")?.optString("device") == device }
                old.drop(5).forEach { json(token, "drive/v3/files/${it.getString("id")}?fields=id", "PATCH", JSONObject().put("trashed", true)) }
            } catch (_: Exception) { /* Retention failure must not invalidate a verified backup. */ }
        } catch (e: Exception) {
            prefs.edit().putString("lastError", (e as? BackupFailure)?.code ?: "network").apply()
            throw e
        }
    }

    private fun listFiles(token: String): List<JSONObject> {
        val query = "trashed = false and appProperties has { key='format' and value='$FORMAT' } and appProperties has { key='state' and value='complete' }"
        val result = mutableListOf<JSONObject>()
        var page = ""
        do {
            val response = json(token, "drive/v3/files?q=${enc(query)}&orderBy=createdTime%20desc&pageSize=100&fields=nextPageToken,files(id,name,createdTime,size,md5Checksum,appProperties)&pageToken=${enc(page)}")
            val files = response.getJSONArray("files")
            for (i in 0 until files.length()) result.add(files.getJSONObject(i))
            page = response.optString("nextPageToken")
        } while (page.isNotEmpty() && result.size < 500)
        return result
    }

    fun list(): List<Map<String, Any?>> = lock.withLock {
        listFiles(token()).map { mapOf("id" to it.getString("id"), "name" to it.getString("name"),
            "createdTime" to it.optString("createdTime"), "size" to it.optString("size")) }
    }

    fun download(id: String): String = lock.withLock {
        if (!Regex("[A-Za-z0-9_-]+").matches(id)) throw BackupFailure("invalid")
        val token = token()
        val file = json(token, "drive/v3/files/$id?fields=id,size,md5Checksum,appProperties")
        val props = file.optJSONObject("appProperties")
        if (props?.optString("format") != FORMAT || props.optString("state") != "complete") throw BackupFailure("invalid")
        if (file.optString("size").toLongOrNull()?.let { it > LIMIT } == true) throw BackupFailure("too_large")
        val bytes = request(token, "drive/v3/files/$id?alt=media")
        if (file.optString("md5Checksum") != digest(bytes, "MD5")) throw BackupFailure("integrity")
        String(bytes, Charsets.UTF_8)
    }

    fun clearQueue() { prefs.edit().putBoolean("queued", false).apply() }
}

class DriveBackupWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val drive = DriveBackup(applicationContext)
        return try {
            drive.upload(inputData.getBoolean("manual", false), inputData.getString("account"))
            Result.success()
        } catch (e: Exception) {
            val code = (e as? BackupFailure)?.code ?: "network"
            if (code == "network" && runAttemptCount < 5) Result.retry()
            else { drive.clearQueue(); Result.failure() }
        }
    }
}
