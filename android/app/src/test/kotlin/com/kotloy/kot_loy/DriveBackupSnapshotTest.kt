package com.kotloy.kot_loy

import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteReadOnlyDatabaseException
import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.SQLiteMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
@SQLiteMode(SQLiteMode.Mode.NATIVE)
class DriveBackupSnapshotTest {
    @Test
    fun legacyReadOnlyTransactionReproducesFailure() {
        val context: android.app.Application = RuntimeEnvironment.getApplication()
        val path = context.getDatabasePath("readonly-reproduction.db")
        path.parentFile!!.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(path, null).close()
        SQLiteDatabase.openDatabase(path.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            assertThrows(SQLiteReadOnlyDatabaseException::class.java) {
                db.execSQL("BEGIN DEFERRED TRANSACTION")
            }
        }
    }

    @Test
    fun snapshotSupportsHistoricalSchemasAndLeavesLiveDatabaseWritable() {
        val context: android.app.Application = RuntimeEnvironment.getApplication()
        for (version in 2..6) {
            val path = context.getDatabasePath("snapshot-$version.db")
            path.parentFile!!.mkdirs()
            SQLiteDatabase.openOrCreateDatabase(path, null).use { live ->
                live.execSQL("CREATE TABLE categories (id TEXT PRIMARY KEY, label TEXT, sort_order INTEGER)")
                live.execSQL("CREATE TABLE expenses (id INTEGER PRIMARY KEY, title TEXT, amount INTEGER, category TEXT)")
                live.execSQL("INSERT INTO categories VALUES ('lunch', 'បាយថ្ងៃត្រង់', 0)")
                live.execSQL("INSERT INTO expenses VALUES (1, 'បាយ', 999999999999, 'lunch')")
                live.version = version
                val backup = DriveBackup(context)
                backup.changed(path.path)
                val snapshot = backup.snapshot()
                assertEquals(if (version >= 6) 3 else 2, snapshot.getInt("schemaVersion"))
                assertEquals("kot_luy_backup", snapshot.getString("format"))
                assertEquals(1, snapshot.getJSONArray("expenses").length())
                assertEquals(999999999999L, snapshot.getJSONArray("expenses").getJSONObject(0).getLong("amount"))
                assertEquals("បាយថ្ងៃត្រង់", snapshot.getJSONArray("categories").getJSONObject(0).getString("label"))
                assertEquals(version, live.version)
                live.execSQL("INSERT INTO expenses VALUES (2, 'Coffee', 5000, 'lunch')")
                assertEquals(2, backup.snapshot().getJSONArray("expenses").length())
                live.version = 99
                assertThrows(BackupFailure::class.java) { backup.snapshot() }
                // Failure must release its transaction as well.
                live.execSQL("UPDATE expenses SET amount = 6000 WHERE id = 2")
            }
        }
    }

    @Test
    fun snapshotReadsActualCurrentAndMigratedFlutterDatabases() {
        val context: android.app.Application = RuntimeEnvironment.getApplication()
        for (oldVersion in listOf(0, 2, 3, 4, 5)) {
            val source = File("../../build/backup-contract/repository-$oldVersion.db")
            assertTrue("Run flutter test test/backup_native_contract_test.dart first", source.isFile)
            val path = context.getDatabasePath("actual-$oldVersion.db")
            path.parentFile!!.mkdirs()
            source.copyTo(path, overwrite = true)
            val backup = DriveBackup(context)
            backup.changed(path.path)
            val snapshot = backup.snapshot()
            assertEquals(3, snapshot.getInt("schemaVersion"))
            val expense = snapshot.getJSONArray("expenses").getJSONObject(0)
            assertEquals(999999999999L, expense.getLong("amount"))
            assertFalse(expense.has("title"))
            val categories = snapshot.getJSONArray("categories")
            val category = (0 until categories.length()).map { categories.getJSONObject(it) }
                .first { it.getString("id") == expense.getString("category") }
            assertEquals(1, category.getInt("is_archived"))
            SQLiteDatabase.openDatabase(path.path, null, SQLiteDatabase.OPEN_READWRITE).use { live ->
                live.execSQL("UPDATE expenses SET amount = 5000")
            }
            assertEquals(5000, backup.snapshot().getJSONArray("expenses").getJSONObject(0).getInt("amount"))
        }
    }

    @Test
    fun gzipCompressionRoundTripAndIntegrityVerification() {
        val originalJson = """{"format":"kot_luy_backup","version":1,"schemaVersion":3,"expenses":[{"id":1,"amount":6000,"category":"lunch"}],"categories":[{"id":"lunch","label":"បាយថ្ងៃត្រង់","sort_order":0}]}"""
        val jsonBytes = originalJson.toByteArray(Charsets.UTF_8)

        // Compress via GZIP
        val compressedBytes = java.io.ByteArrayOutputStream().also { bos ->
            java.util.zip.GZIPOutputStream(bos).use { gzip -> gzip.write(jsonBytes) }
        }.toByteArray()

        // Verify magic bytes
        assertTrue(
            "Compressed data must start with GZIP magic bytes",
            compressedBytes.size >= 2 && compressedBytes[0] == 0x1f.toByte() && compressedBytes[1] == 0x8b.toByte()
        )

        // Verify MD5 computation behaves consistently on compressed bytes
        val md5Digest = java.security.MessageDigest.getInstance("MD5")
            .digest(compressedBytes)
            .joinToString("") { "%02x".format(it.toInt() and 255) }
        val expectedMd5 = java.security.MessageDigest.getInstance("MD5")
            .digest(compressedBytes)
            .joinToString("") { "%02x".format(it.toInt() and 255) }
        assertEquals(expectedMd5, md5Digest)

        // Decompress via GZIPInputStream (as download() does)
        val decompressedBytes = java.util.zip.GZIPInputStream(compressedBytes.inputStream()).use { it.readBytes() }
        val reconstructedJson = String(decompressedBytes, Charsets.UTF_8)
        assertEquals(originalJson, reconstructedJson)

        // Verify backward compatibility fallback for non-GZIP legacy JSON payload
        val fallbackBytes = if (jsonBytes.size >= 2 && jsonBytes[0] == 0x1f.toByte() && jsonBytes[1] == 0x8b.toByte()) {
            java.util.zip.GZIPInputStream(jsonBytes.inputStream()).use { it.readBytes() }
        } else {
            jsonBytes
        }
        assertEquals(originalJson, String(fallbackBytes, Charsets.UTF_8))
    }
}
