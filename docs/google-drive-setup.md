# Kot Luy Google Drive setup

Verified in Google Cloud Console on 2026-09-06:

- Project: `kot-luy` (739180174091).
- Google Drive API enabled.
- Android OAuth client: `Kot Luy Android Test`.
- Client package and SHA-1 match the current development APK.
- Declared scope: `https://www.googleapis.com/auth/drive.appdata`.
- Audience: External, publishing status: Testing.
- Developer account added as a test user.

Public client metadata is recorded in `config/google-drive.json`. This is configuration documentation, not a working Drive integration. No client secret or user access token is stored. An Android client ID must not be used as a web/server client ID.

Each user must authorize their own Google account. Backups belong in that user's Drive Application Data folder (`appDataFolder`); the developer's account is not the backup destination for other users.

## Remaining work

- Implement the in-app account connection, manual upload, background backup, and restore flows.
- Verify authorization and upload/restore on a signed Android device build.
- Google currently reports incomplete branding and disables public publishing. The branding form has the app name and contact email, but no homepage, privacy-policy URL, or terms URL. Supply real public app pages and resolve Google's validation before public release; do not invent URLs.
- Add any additional test accounts before testing with them while the app is in Testing.
- Register the actual release/Play signing certificate when it differs from the current development certificate.
- Select the Android authorization implementation before creating any additional web/server client. A backend secret must never be bundled in the APK.

## Backup behavior agreed with the user

- Optional automatic backups, silent on success; manual Back up now with progress.
- Wi-Fi and mobile data allowed by default; queue offline work and retry.
- Back up changed data without blocking startup.
- Visible backup files with read-only content restrictions where supported. Owners can remove restrictions or delete their files; permanent owner-proof locking cannot be promised.
- Validate a consistent snapshot before restore and confirm before replacing local data.

Console: https://console.cloud.google.com/auth/clients?project=kot-luy
