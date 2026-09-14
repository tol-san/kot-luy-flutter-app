# កត់លុយ • Kot Luy

<div align="center">

![Kot Luy Logo](assets/logo.png)

**A gentle, offline-first Khmer personal expense companion for Android and Web.**

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-v6_Schema-003B57?logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-green)](#)
[![Tests](https://img.shields.io/badge/Tests-75_Passed-brightgreen)](#-verification--testing)

</div>

---

## 📖 Overview

**កត់លុយ (Kot Luy)** is an intuitive, privacy-respecting expense tracking application tailored specifically for Cambodia. Built with Flutter, it features a native Khmer user interface, full Cambodian Riel (`៛`) accounting, warm sage-and-cream aesthetic palettes, custom SVG wallet companions, and high-performance local SQLite persistence.

Designed with an **offline-first and privacy-centric** philosophy, all financial records remain strictly on the device by default, with optional encrypted Google Drive cloud backup.

---

## ✨ Key Features

### 📊 Dashboard & Financial Insights
- **Overview Card**: Instantly see total period spending and percentage breakdowns.
- **Category Donut Chart**: Interactive, accessible breakdown powered by custom painters isolated with `RepaintBoundary` for zero-lag rendering.
- **Flexible Time Periods**:
  - ថ្ងៃនេះ (Today)
  - សប្ដាហ៍នេះ (This Week: Monday–Sunday)
  - ខែនេះ (This Month)
  - ទាំងអស់ (All-Time)

### 💸 Fast Expense Entry & Management
- **Quick-Amount Increment Chips**: Add `+1,000៛`, `+5,000៛`, `+10,000៛`, `+50,000៛`, and `+100,000៛` with a single tap.
- **Whole Riel Formatting**: Handles exact integer amounts up to `999,999,999,999 ៛`.
- **Live Clock Sync**: Automatically synchronizes the transaction time with the actual clock until manually adjusted.
- **Optional Single-Line Note**: Expandable note field (up to 50 characters) with fast toggle.
- **Debounced Instant Search**: Filter transactions by category or note in real time with 300ms debounce and in-memory caching.
- **Bulk Delete Mode**: Multi-select mode with "Select All", count badges, deletion confirmation, and safety progress overlays.

### 🏷️ Dynamic Category Management
- **Default Khmer Categories**: Preloaded with common Cambodian daily expenses (ម្ហូបអាហារ, កាហ្វេ, ធ្វើដំណើរ, ទិញទំនិញ, etc.).
- **Custom Categories**: Add new categories by name with automated pastel color assignment.
- **Reordering & Editing**: Drag-and-drop category ordering and inline renaming.
- **Archive & Restore**: Soft-archive unused categories while maintaining referential integrity with historical expense records.
- **In-Memory Caching**: Fast category lookup served by an in-memory cache that automatically invalidates on writes.

### 📄 Comprehensive PDF Reports & Statements
- **Customizable Export Periods**:
  - សប្ដាហ៍ (Current / Previous Week)
  - ខែ (Monthly statement for any calendar month)
  - ត្រីមាស (Quarterly: Q1, Q2, Q3, Q4)
  - ឆមាស (Semesters: S1, S2)
  - ឆ្នាំ (Full Annual Report)
- **Official Khmer Styling**: Includes date range headers, category summary table, itemized transaction list with notes, and totals formatted in Khmer words (`formatKhmerRielWords`).
- **Export Options**: In-app preview, direct printing, and device file download.
- **Large Dataset Warning**: Automatic notification banner when exporting periods with over 1,000 records.

### ☁️ Google Drive Cloud Backup & Restore
- **Privacy-First AppData Storage**: Backups are saved directly into the user's private Google Drive Application Data folder (`drive.appdata` scope)—invisible to third-party apps and separate from personal files.
- **GZIP Compression**: JSON backup payloads are compressed with GZIP, shrinking backup size by 80–90% (~20 MB JSON compresses to ~2–4 MB).
- **Backward Compatible**: Automatically detects GZIP magic bytes (`0x1F 0x8B`) and gracefully supports legacy uncompressed plain-text backups.
- **Silent Auto-Backup**: Automatically schedules background backups upon data mutation.
- **Integrity Verified**: Uses MD5 checksum verification before restoring data to ensure zero corruption.
- **Manual Snapshot Management**: Back up now on demand, inspect previous backups, and restore with confirmation safety checks.

### 🔔 Smart Reminders & Notifications
- **Daily Expense Reminder**: Customizable daily notification to remind users to log daily expenses.
- **Weekly & Monthly Summaries**: Scheduled summary notifications at 9:00 AM every Monday and 1st of the month.
- **Independent Controls**: Reminders can be individually toggled and configured.

---

## 🏗️ Architecture & Project Structure

```text
lib/
├── backup/                  # Google Drive backup client, snapshot models, and formatters
│   ├── backup_snapshot.dart
│   ├── drive_backup.dart
│   ├── drive_error_parser.dart
│   └── drive_formatters.dart
├── data/                    # SQLite database, schema migrations (v1 -> v6), and caching
│   └── expense_repository.dart
├── formatters/              # Khmer currency and number word formatting
│   └── khmer_number_words.dart
├── models/                  # Expense, category, and report period data models
│   ├── expense.dart
│   └── report_period.dart
├── pdf/                     # PDF generation, font loaders, text shaping, and file downloaders
│   ├── desktop_pdf_file_handler.dart
│   ├── expense_pdf_service.dart
│   ├── pdf_downloader.dart
│   └── pdf_font_asset_loader.dart
├── screens/                 # Core application screens and modal sheets
│   ├── category_management_sheet.dart
│   ├── detail_screen.dart
│   ├── drive_backup_sheet.dart
│   ├── expense_form.dart
│   ├── home_screen.dart
│   ├── pdf_export_sheet.dart
│   ├── reminder_settings_sheet.dart
│   └── startup_screen.dart
├── services/                # Local notification scheduling service
│   └── reminder_service.dart
├── theme.dart               # Sage and cream theme styling, colors, and typography
└── widgets/                 # Reusable UI components, charts, and backup widgets
    ├── backup/
    ├── home/
    ├── category_input_row.dart
    ├── category_picker_sheet.dart
    ├── expense_chart.dart
    └── riel_input_formatter.dart
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.47.0` (Dart `>= 3.13.0`)
- **Android SDK**: API level 24+ (Android 7.0 or higher)
- **Android Device or Emulator**

### Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/tol-san/kot-luy-flutter-app.git
   cd kot-luy-flutter-app
   ```

2. **Fetch dependencies:**
   ```sh
   flutter pub get
   ```

3. **Run on connected device/emulator:**
   ```sh
   flutter run
   ```

---

## 📦 Building for Production

### Android Release APK
Run the automated build script, which executes static analysis, unit tests, and native Android regression tests prior to generating split release APKs:

```powershell
./scripts/build-release.ps1
```

Generated APKs will be located in:
`build/app/outputs/flutter-apk/`

> [!NOTE]
> The default release configuration uses the local development signing key for direct installation. Configure your own release keystore in `android/key.properties` prior to Google Play Store publishing.

### Browser Preview (Web)
Kot Luy supports web previews using SQLite WASM with browser-local persistence:

```sh
# Setup SQLite WASM binaries
dart run sqflite_common_ffi_web:setup

# Run in Chrome
flutter run -d chrome

# Or build release web bundle
flutter build web --release
python -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

---

## 🧪 Verification & Testing

The project includes an automated test suite with **75 comprehensive tests** covering database migrations, file-backed SQLite transactions, UI widget rendering, PDF generation, Google Drive backup/restore contracts, notification services, and responsive viewports:

```sh
# Run code analysis
flutter analyze

# Execute all Flutter tests
flutter test

# Run native Android backup regression unit tests
cd android
./gradlew.bat :app:testDebugUnitTest
```

---

## 🔤 Typography & Assets

- **Khmer Fonts**: `Google Sans Khmer` and `Noto Sans Khmer` (SIL Open Font License).
- **English Fonts**: `Google Sans` (Regular, Medium, Bold).
- **Illustrations**: Custom-designed wallet character SVGs pre-compiled into binary vector graphics (`.vec`) for instant startup rendering.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
