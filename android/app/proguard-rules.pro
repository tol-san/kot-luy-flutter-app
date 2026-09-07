# ProGuard / R8 rules for Kot Luy

# Keep Flutter wrapper and engine classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter deferred components / Play Store split application dependencies
-dontwarn com.google.android.play.core.**

# Sqflite: keep plugin classes and avoid R8 missing class warnings
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Application-specific classes (MainActivity, DriveBackupWorker, etc.)
-keep class com.kotloy.kot_loy.** { *; }
