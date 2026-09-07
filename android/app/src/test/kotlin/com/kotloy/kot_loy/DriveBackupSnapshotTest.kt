package com.kotloy.kot_loy

import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteReadOnlyDatabaseException
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
    fun snapshotSupportsBothSchemasAndLeavesLiveDatabaseWritable() {
        val context: android.app.Application = RuntimeEnvironment.getApplication()
        for (version in 2..3) {
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
                assertEquals(2, snapshot.getInt("schemaVersion"))
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
}
