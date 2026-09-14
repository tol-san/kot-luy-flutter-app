# Kot Luy Google Drive Setup & Implementation

## 1. Google Cloud Console Configuration

Verified in Google Cloud Console on 2026-09-06:

- **Project**: `kot-luy` (`739180174091`)
- **API**: Google Drive API (v3) enabled
- **Android OAuth Client**: `Kot Luy Android Test`
- **Application ID**: `com.kotloy.kot_loy`
- **Development SHA-1**: `E2:28:94:C0:34:10:0F:F4:35:2C:2E:05:78:EE:71:19:DC:8F:C7:6F`
- **Declared Scope**: `https://www.googleapis.com/auth/drive.appdata`
- **Audience**: External, Publishing status: Testing
- **Client Metadata**: Configured in `config/google-drive.json` (no secrets or user tokens stored)

Console: https://console.cloud.google.com/auth/clients?project=kot-luy

---

## 2. Implemented Architecture & Native Engine

The Google Drive backup system is fully implemented using native Android Kotlin (`DriveBackup.kt` and `MainActivity.kt`) bridged to Flutter via `MethodChannel('kot_luy/drive_backup')`.

### Privacy & Storage Model
- Backups are stored in the user's private **Google Drive Application Data folder** (`appDataFolder`).
- Files are completely hidden from regular Google Drive file lists and third-party applications.
- Backups belong strictly to each user's authenticated Google account; no centralized backend or server secret is used.

### Compression & Payloads
- **Format**: `kot_luy_backup`
- **Payload**: Compact JSON compressed via **GZIP** (`GZIPOutputStream`), reducing payload size by 80–90% (~20 MB JSON compresses to ~2–4 MB).
- **MIME Type**: `application/gzip` with `Content-Encoding: gzip`.
- **Backward Compatibility**: Automatically inspects the first two bytes for GZIP magic header (`0x1F 0x8B`). Decompresses GZIP if matched, or falls back to UTF-8 plain-text parsing for legacy uncompressed backups.

### Native Android WorkManager Automation
Background synchronization is managed through Android `WorkManager`:
1. **Change-Triggered Sync (`kot_luy_changes`)**:
   - Enqueued with a 60-second debounce delay whenever local SQLite records change (`changed` method).
   - Skips redundant uploads if the SHA-256 hash of table contents matches the last uploaded snapshot (`lastHash`).
2. **Periodic Sync (`kot_luy_periodic`)**:
   - `PeriodicWorkRequest` scheduled every 6 hours when automatic backup is enabled.
3. **Manual Backup (`kot_luy_manual`)**:
   - Immediate `OneTimeWorkRequest` triggered by the user's "Back up now" action, with real-time UI progress feedback.
4. **Network Constraints**:
   - Configurable in settings: Wi-Fi only (`NetworkType.UNMETERED`) or Mobile + Wi-Fi (`NetworkType.CONNECTED`).

### Integrity & Retention Policy
- **SHA-256 Content Hashing**: Compares database snapshot content before upload to prevent unnecessary network transfers.
- **MD5 Checksum Verification**: Computes and matches MD5 digest on both upload and download to guarantee zero data corruption.
- **Snapshot Retention**: Automatically retains the latest 5 verified snapshots per device. Older snapshots for that device are moved to trash (`trashed = true`). Other devices' snapshots remain untouched.
- **Atomic SQLite Restore**: Restores data inside a non-exclusive SQLite transaction, validating schema versions and repairing legacy category data before committing.

---

## 3. UI & Flutter Integration

Located in `lib/screens/drive_backup_sheet.dart` and `lib/widgets/backup/`:
- **Account Connection Card (`DriveAccountCard`)**: Google Sign-In with native account picker dialog (`AccountManager.newChooseAccountIntent`).
- **Settings Card (`DriveSettingsCard`)**: Toggles for Automatic Backup and Wi-Fi Only transfers.
- **Manual Backup Card (`DriveManualBackupCard`)**: "Back up now" button, last backup timestamp, and total backed-up transaction count.
- **Snapshot List (`DriveSnapshotsSection`)**: Lists remote snapshots with timestamps, file sizes, and a safe confirmation dialog before restoring into the local database.
- **Loading Skeleton (`DriveBackupSkeleton`)**: Smooth scoped shimmer while fetching status.

---

## 4. Production Release Checklist

Before releasing to the Google Play Store:

1. **Register Release SHA-1**:
   - When generating a release build with a production keystore (configured in `android/key.properties`), extract the release SHA-1 certificate fingerprint:
     ```sh
     keytool -list -v -keystore <release-keystore-path>
     ```
   - Add a new Android OAuth client with the production SHA-1 in Google Cloud Console.
2. **Google OAuth Consent Screen Verification**:
   - Add public application URLs: Application Homepage, Privacy Policy URL, and Terms of Service URL.
   - Submit the OAuth consent screen for verification before changing status from **Testing** to **In production**.
3. **Test Users**:
   - While the app remains in **Testing** status, add testers' Google email accounts to the Test Users list in Google Cloud Console.
