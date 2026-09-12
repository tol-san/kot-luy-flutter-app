package com.kotloy.kot_loy

import android.accounts.Account
import android.accounts.AccountManager
import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import android.os.Build
import android.os.Bundle
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import android.content.ContentValues
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "kot_luy/drive_backup"
        private const val PDF_CHANNEL = "kot_luy/pdf_storage"
        private const val SETTINGS_CHANNEL = "kot_luy/app_settings"
        private const val RC_CHOOSE_ACCOUNT = 9001
        private const val RC_AUTHORIZE = 9002
    }

    private lateinit var driveBackup: DriveBackup
    private val executor = Executors.newSingleThreadExecutor()
    private var pendingConnectResult: MethodChannel.Result? = null
    private var pendingSelectedAccount: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }
        driveBackup = DriveBackup(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!::driveBackup.isInitialized) {
            driveBackup = DriveBackup(applicationContext)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> {
                    result.success(driveBackup.status())
                }
                "connect" -> {
                    val currentEmail = (driveBackup.status()["email"] as? String)
                    pendingConnectResult = result
                    if (!currentEmail.isNullOrEmpty()) {
                        pendingSelectedAccount = currentEmail
                        requestDriveAuthorization(currentEmail)
                    } else {
                        val intent = AccountManager.newChooseAccountIntent(
                            null,
                            null,
                            arrayOf("com.google"),
                            null,
                            null,
                            null,
                            null
                        )
                        startActivityForResult(intent, RC_CHOOSE_ACCOUNT)
                    }
                }
                "disconnect" -> {
                    driveBackup.disconnect()
                    result.success(driveBackup.status())
                }
                "configure" -> {
                    val automatic = call.argument<Boolean>("automatic") ?: false
                    val wifiOnly = call.argument<Boolean>("wifiOnly") ?: false
                    driveBackup.configure(automatic, wifiOnly)
                    result.success(driveBackup.status())
                }
                "backup" -> {
                    executor.execute {
                        try {
                            driveBackup.upload(force = true)
                            runOnUiThread {
                                result.success(driveBackup.status())
                            }
                        } catch (e: Exception) {
                            val code = (e as? BackupFailure)?.code ?: "failed"
                            runOnUiThread {
                                result.error(code, e.message, null)
                            }
                        }
                    }
                }
                "list" -> {
                    executor.execute {
                        try {
                            val list = driveBackup.list()
                            runOnUiThread {
                                result.success(list)
                            }
                        } catch (e: Exception) {
                            val code = (e as? BackupFailure)?.code ?: "failed"
                            runOnUiThread {
                                result.error(code, e.message, null)
                            }
                        }
                    }
                }
                "download" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("invalid", "Missing backup id", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val data = driveBackup.download(id)
                            runOnUiThread {
                                result.success(data)
                            }
                        } catch (e: Exception) {
                            val code = (e as? BackupFailure)?.code ?: "failed"
                            runOnUiThread {
                                result.error(code, e.message, null)
                            }
                        }
                    }
                }
                "changed" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            driveBackup.changed(path)
                        } catch (_: Exception) {}
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PDF_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val filename = call.argument<String>("filename")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (filename == null || bytes == null) {
                        result.error("invalid_arguments", "filename and bytes are required", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val res = savePdfToDownloads(filename, bytes)
                            runOnUiThread {
                                result.success(res)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("save_failed", e.message, null)
                            }
                        }
                    }
                }
                "openPdf" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("invalid_arguments", "uri is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val opened = openPdf(uriString)
                        result.success(opened)
                    } catch (e: Exception) {
                        result.error("open_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    val intent = Intent().apply {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            action = "android.settings.APP_NOTIFICATION_SETTINGS"
                            putExtra("app_package", packageName)
                            putExtra("app_uid", applicationInfo.uid)
                        }
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("failed", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestDriveAuthorization(accountName: String) {
        val request = AuthorizationRequest.builder()
            .setAccount(Account(accountName, "com.google"))
            .setRequestedScopes(listOf(Scope(DriveBackup.SCOPE)))
            .build()
        Identity.getAuthorizationClient(this).authorize(request)
            .addOnSuccessListener { result ->
                if (result.hasResolution()) {
                    val pendingIntent = result.pendingIntent
                    if (pendingIntent != null) {
                        try {
                            startIntentSenderForResult(
                                pendingIntent.intentSender,
                                RC_AUTHORIZE,
                                null,
                                0,
                                0,
                                0
                            )
                            return@addOnSuccessListener
                        } catch (e: IntentSender.SendIntentException) {
                            val pending = pendingConnectResult
                            pendingConnectResult = null
                            pendingSelectedAccount = null
                            pending?.error("intent_failed", e.message, null)
                            return@addOnSuccessListener
                        }
                    }
                }
                driveBackup.connected(accountName)
                val pending = pendingConnectResult
                pendingConnectResult = null
                pendingSelectedAccount = null
                pending?.success(driveBackup.status())
            }
            .addOnFailureListener { e ->
                val pending = pendingConnectResult
                pendingConnectResult = null
                pendingSelectedAccount = null
                pending?.error("auth_failed", e.message, null)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RC_CHOOSE_ACCOUNT) {
            val pending = pendingConnectResult
            if (resultCode != Activity.RESULT_OK || data == null) {
                pendingConnectResult = null
                pending?.error("cancelled", "Account selection cancelled", null)
                return
            }
            val accountName = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
            if (accountName.isNullOrEmpty()) {
                pendingConnectResult = null
                pending?.error("no_account", "No account selected", null)
                return
            }
            pendingSelectedAccount = accountName
            requestDriveAuthorization(accountName)
        } else if (requestCode == RC_AUTHORIZE) {
            val pending = pendingConnectResult
            pendingConnectResult = null
            val account = pendingSelectedAccount
            pendingSelectedAccount = null
            if (pending == null) return

            if (resultCode != Activity.RESULT_OK) {
                pending.error("auth_denied", "Google Drive authorization was not granted", null)
                return
            }
            if (account != null) {
                driveBackup.connected(account)
                pending.success(driveBackup.status())
            } else {
                pending.error("no_account", "Account information missing", null)
            }
        }
    }

    private fun savePdfToDownloads(filename: String, bytes: ByteArray): Map<String, String> {
        val resolver = applicationContext.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw IOException("Failed to create download record in MediaStore")

            try {
                resolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                } ?: throw IOException("Failed to open output stream for download")

                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }

            var finalName = filename
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    finalName = cursor.getString(0) ?: filename
                }
            }

            return mapOf(
                "uri" to uri.toString(),
                "name" to finalName,
                "path" to "Downloads/$finalName"
            )
        } else {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) {
                dir.mkdirs()
            }
            val file = File(dir, filename)
            file.writeBytes(bytes)

            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.DATA, file.absolutePath)
            }
            val uri = resolver.insert(MediaStore.Files.getContentUri("external"), contentValues)
                ?: Uri.fromFile(file)

            return mapOf(
                "uri" to uri.toString(),
                "name" to filename,
                "path" to file.absolutePath
            )
        }
    }

    private fun openPdf(uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            val chooser = Intent.createChooser(intent, "បើកឯកសារ PDF")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }
}
