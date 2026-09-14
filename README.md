# កត់លុយ • Kot Luy

<div align="center">

![Kot Luy Logo](assets/logo.png)

**A gentle, offline-first Khmer personal expense companion for Android and Web.**

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-Schema_v6-003B57?logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-green)](#)
[![Tests](https://img.shields.io/badge/Tests-75_Passed-brightgreen)](#-testing--verification)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#-license)

</div>

---

## 📖 Overview

**កត់លុយ (Kot Luy)** is an offline-first personal expense tracker developed with Flutter, designed specifically for Cambodia. It combines an authentic Khmer user interface, whole Cambodian Riel (`៛`) accounting, a gentle sage-and-cream aesthetic, and high-performance local SQLite persistence.

All records are stored locally on the user's device by default. For cloud backup, Kot Luy integrates directly with Google Drive's hidden Application Data folder using native Android WorkManager, GZIP compression, and SHA-256/MD5 cryptographic integrity verification.

---

## ✨ Features (Verified in Code)

### 📊 Dashboard & Period Analytics
- **Live Spending Breakdown**: Shows total spending in Cambodian Riel (`riel()` formatter) and percentage distribution.
- **Accessible Donut Chart (`ExpenseChart`)**: Custom canvas donut painter isolated with `RepaintBoundary` to prevent unnecessary repaints during scrolling, showing the number of active categories in the center.
- **Configurable Period Filter**:
  - `ថ្ងៃនេះ` (Today)
  - `សប្ដាហ៍នេះ` (This Week: Monday–Sunday)
  - `ខែនេះ` (This Month)
  - `ទាំងអស់` (All-Time)
- **Report Section**: Toggleable detailed report view breaking down spending totals and percentages by category.

### 💸 Fast Expense Entry & Transaction Management
- **Quick-Amount Increment Chips**: Add `+500 ៛`, `+1,000 ៛`, `+2,000 ៛`, `+3,000 ៛`, `+5,000 ៛`, or `+10,000 ៛` in a single tap, with a dedicated `សម្អាត` (Clear) button.
- **Riel Input Formatter**: Supports integer amounts from `1` to `999,999,999,999 ៛` with formatted thousand separators.
- **Live Clock Synchronization**: Real-time timer updates transaction date and time to the current clock until custom date/time is selected.
- **Optional Single-Line Note**: Expandable note field (max `50` characters, `Expense.maxNoteLength`) with clean toggle.
- **Debounced Instant Search**: 300ms debounced search filtering by category name or note, backed by an in-memory filter cache.
- **Bulk Delete Mode**: Multi-select mode with select-all, item count badge, confirmation dialog, and touch-blocking deletion progress overlay.

### 🏷️ Dynamic Category Management
- **5 Default Categories**: Preloaded in `ExpenseCategory.values`:
  - 🍚 `បាយពេលព្រឹក` (Breakfast — Blue `#2563EB`)
  - 🍲 `បាយថ្ងៃត្រង់` (Lunch — Green `#16A34A`)
  - 🍛 `បាយល្ងាច` (Dinner — Red `#DC2626`)
  - ⛽ `ចាក់សាំង` (Fuel — Yellow `#EAB308`)
  - ☕ `កាហ្វេ` (Coffee — Purple `#9333EA`)
- **Custom Category Creation**: Add custom categories with name validation (max 40 characters, emoji disallowed, duplicate check) and automated distinct pastel color selection from a 30-color palette.
- **Drag-and-Drop Reordering**: Interactive reordering via `ReorderableListView` updating persistent sort orders.
- **Archiving & Restoration**: Soft-archive categories (`is_archived = 1`) to hide them from entry without breaking historical records; restore anytime.
- **Deletion Safety**: Unused custom categories can be permanently deleted; categories in use prompt for archiving instead.
- **In-Memory Category Cache**: Category reads are cached in memory and automatically invalidated on write/reorder operations.

### 📄 Khmer PDF Export & Statements
- **Supported Export Periods (`ReportPeriodConfig`)**:
  - `ប្រចាំសប្ដាហ៍` (Current or Previous Week)
  - `ប្រចាំខែ` (Any selected calendar month)
  - `ប្រចាំត្រីមាស` (Quarterly: Q1, Q2, Q3, Q4)
  - `ប្រចាំឆមាស` (Semesters: S1, S2)
  - `ប្រចាំឆ្នាំ` (Full calendar year)
- **Detail Levels**:
  - `សង្ខេប` (Summary: period overview and category breakdown table)
  - `លម្អិត` (Detailed: category summary plus full itemized transaction ledger with dates, categories, notes, and amounts)
- **HarfBuzz Complex-Script Shaping**: Uses `pdf_text_shaper` with `NotoSansKhmer` fonts to render Khmer vowels, subscripts, and ligatures without broken glyphs.
- **Khmer Number Words**: Automatically spells out the total period spending in Khmer words (`formatKhmerRielWords`).
- **Export & Storage Actions**: In-app PDF preview, direct native printing, and direct file download (Android uses MediaStore `Downloads/` directory; desktop writes to user's downloads folder).
- **Large Dataset Notice**: Automatically displays an informational banner if the selected period contains over 1,000 transactions.

### ☁️ Google Drive Cloud Backup & Restore
- **Native Android Engine (`DriveBackup.kt`)**: Native Kotlin implementation using Google Play Services identity and Google Drive REST API.
- **Private AppData Folder**: Stores backups in `https://www.googleapis.com/auth/drive.appdata` (`appDataFolder`), isolated from user files and other apps.
- **GZIP Compression**: Backup JSON is compressed using GZIP (`application/gzip`), cutting storage transfer by 80–90% (~20 MB JSON compresses to ~2–4 MB).
- **Backward Compatible Restore**: Automatically detects GZIP magic bytes (`0x1F 0x8B`) to decompress, while supporting legacy uncompressed plain-text backups.
- **Background WorkManager Automation**:
  - `kot_luy_changes`: One-time background task enqueued with 60-second debounce upon data mutation.
  - `kot_luy_periodic`: Periodic background sync scheduled every 6 hours.
  - `kot_luy_manual`: Immediate backup execution on user tap.
- **Network Controls**: Configurable Wi-Fi only (`UNMETERED`) or Wi-Fi + Mobile data (`CONNECTED`).
- **Integrity & Snapshot Retention**:
  - SHA-256 hash comparison avoids redundant uploads when database has not changed.
  - MD5 checksum validated after both upload and download.
  - Keeps the 5 latest verified snapshots per device (older snapshots are automatically moved to trash).
  - Restore validates schema and runs within an atomic SQLite transaction before triggering local UI refresh.

### 🔔 Local Reminders & Notifications (`ReminderService`)
- **Notification Channel**: Dedicated Android channel `expense_reminders` (`ការរំលឹកចំណាយ`).
- **3 Independent Schedules**:
  - **Daily Reminder**: Prompts user to log expenses (`ថ្ងៃនេះបានកត់ត្រាការចំណាយរបស់អ្នកហើយឬនៅ? 😊`), defaults to 8:00 PM. Tapping opens the Add Expense modal.
  - **Weekly Summary**: Sends total weekly spending (`សប្ដាហ៍នេះអ្នកបានចំណាយ ... ៛`), defaults to Monday 9:00 AM. Tapping opens the weekly report.
  - **Monthly Summary**: Sends total monthly spending (`ខែនេះអ្នកបានចំណាយ ... ៛`), defaults to the 1st of the month at 9:00 AM. Tapping opens the monthly report.
- **Time Customization**: Each reminder features an independent toggle and time picker.

### ⚡ Fast Startup Architecture (`StartupScreen`)
- Parallelizes database opening, category cache warming, current month expense loading, and existence checks.
- Pre-caches `assets/logo.png` and pre-compiled `.vec` binary vector graphics.
- Seamlessly transitions to `HomeScreen` with ready data, eliminating cold-start layout jitter or empty loading spinners.

---

## 🗄️ Database Schema & Migrations

Database file: `kot_loy.db` (Managed by `ExpenseRepository`, Current Version: **6**)

### Table: `expenses`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Unique transaction ID |
| `amount` | `INTEGER` | `NOT NULL CHECK(amount > 0 AND amount <= 999999999999)` | Amount in Cambodian Riel |
| `category` | `TEXT` | `NOT NULL` | References category `id` |
| `date` | `INTEGER` | `NOT NULL` | Epoch milliseconds |
| `note` | `TEXT` | `NOT NULL DEFAULT ''` | Optional note (up to 50 chars) |

*Indices: `expenses_date ON expenses(date DESC)`, `expenses_category ON expenses(category)`*

### Table: `categories`
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `TEXT` | `PRIMARY KEY` | Category identifier (e.g. `breakfast`, `custom_...`) |
| `label` | `TEXT` | `NOT NULL` | Display name in Khmer |
| `color_value` | `INTEGER` | `NOT NULL` | ARGB 32-bit color integer |
| `sort_order` | `INTEGER` | `NOT NULL` | User-defined display order |
| `is_custom` | `INTEGER` | `NOT NULL DEFAULT 0` | `1` for user-created, `0` for defaults |
| `is_archived` | `INTEGER` | `NOT NULL DEFAULT 0` | `1` if archived, `0` if active |

### Migration History
- **v1 → v2**: Added dynamic `categories` table with default seeds.
- **v2 → v3**: Deduplicated legacy categories and mapped legacy `other` records.
- **v3 → v4**: Added `is_archived` column for soft-archiving without breaking expense history.
- **v4 → v5**: Refreshed and stabilized category color values.
- **v5 → v6**: Redesigned schema, removed redundant `title` column, transferred data via temporary table, and indexed `category`.

---

## 🏗️ Architecture & Codebase Structure

```text
lib/
├── backup/                  # Native Google Drive backup bridge and snapshot restore
│   ├── backup_snapshot.dart      # JSON snapshot parsing and atomic SQLite restore
│   ├── drive_backup.dart         # MethodChannel client and data structures
│   ├── drive_error_parser.dart   # Khmer error translation for backup exceptions
│   └── drive_formatters.dart     # Timestamp and file size formatters
├── data/
│   └── expense_repository.dart   # SQLite database open, v1-v6 migrations, cache, CRUD
├── formatters/
│   └── khmer_number_words.dart   # Cambodian number-to-words pronunciation engine
├── models/
│   ├── expense.dart              # Expense model, ExpenseCategory enum/class, autoColors
│   └── report_period.dart        # ReportPeriodType, ReportDetailLevel, date calculations
├── pdf/
│   ├── desktop_pdf_file_handler.dart  # Desktop file saving handler
│   ├── expense_pdf_service.dart       # HarfBuzz shaped PDF generation with NotoSansKhmer
│   ├── pdf_download_result.dart       # Result model for saved PDF files
│   ├── pdf_downloader.dart            # Native Android MediaStore and desktop downloader
│   └── pdf_font_asset_loader.dart     # Font asset caching for PDF documents
├── screens/
│   ├── category_management_sheet.dart # Add, reorder, edit, archive/restore categories
│   ├── detail_screen.dart             # Single transaction detail view and actions
│   ├── drive_backup_sheet.dart        # Google Drive status, connect, backup, restore UI
│   ├── expense_form.dart              # Add/edit bottom sheet, quick chips, live clock
│   ├── home_screen.dart               # Dashboard, donut chart, filters, search, bulk delete
│   ├── pdf_export_sheet.dart          # Period picker, preview, print, download trigger
│   ├── reminder_settings_sheet.dart   # Daily, weekly, monthly reminder toggles and time
│   └── startup_screen.dart            # Fast cold-start preloader with vector precaching
├── services/
│   └── reminder_service.dart          # Local notifications scheduling and deep-link routing
├── theme.dart                         # Palette (paper, ink, green, line, muted), typography
└── widgets/
    ├── backup/                        # Cards for account, manual backup, settings, snapshots
    ├── home/                          # HomeAppBar and HomeReportSection
    ├── category_input_row.dart        # Category creation input field with validation
    ├── category_list_item.dart        # Category row with reorder handle and archive actions
    ├── category_picker_sheet.dart     # Modal picker for selecting categories
    ├── expense_chart.dart             # RepaintBoundary-isolated canvas donut chart
    └── riel_input_formatter.dart      # Real-time integer currency formatter with thousand dots
```

---

## 🚀 Getting Started

### Requirements
- **Flutter SDK**: `>= 3.47.0` (Dart `>= 3.13.0`)
- **Android SDK**: API level 24+ (Android 7.0 or higher)
- **Device / Emulator**: Android device with Google Play Services (for Drive backup) or any Flutter-supported platform

### Setup & Run
```sh
# Clone repository
git clone https://github.com/tol-san/kot-luy-flutter-app.git
cd kot-luy-flutter-app

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### Android Production Build
The project includes a release automation script in `scripts/build-release.ps1` that runs static analysis, Flutter tests, and native Android unit tests before generating split APKs:

```powershell
./scripts/build-release.ps1
```

Generated APKs: `build/app/outputs/flutter-apk/app-<abi>-release.apk`

### Web Preview (SQLite WASM)
```sh
# Setup SQLite WASM dependencies
dart run sqflite_common_ffi_web:setup

# Run in Chrome
flutter run -d chrome
```

---

## 🧪 Testing & Verification

The codebase is protected by **75 automated tests** across 15 test suites verifying persistence, schema migrations, widget rendering, PDF generation, HarfBuzz text shaping, and native contract bridges:

```sh
# 1. Run static analysis
flutter analyze

# 2. Run all 75 Flutter tests
flutter test

# 3. Run native Android backup unit regression tests
cd android
./gradlew.bat :app:testDebugUnitTest
```

### Test Suite Summary
- `expense_repository_test.dart`: SQLite persistence, migrations v1–v6, category deduplication, in-memory cache behavior.
- `backup_native_contract_test.dart` & `backup_test.dart`: Schema compatibility contracts between Dart and Kotlin native readers.
- `drive_backup_action_state_test.dart` & `drive_backup_skeleton_test.dart`: Drive backup connection, loading skeletons, and restore states.
- `expense_pdf_service_test.dart`, `harfbuzz_khmer_test.dart`, & `visual_pdf_report_test.dart`: HarfBuzz font shaping, PDF generation, Khmer numerals and layout integrity.
- `reminder_settings_sheet_test.dart`: Independent reminder toggling, permission handling, and time configuration.
- `startup_screen_test.dart`: Cold-start preloading and immediate HomeScreen rendering without jitter.
- `widget_test.dart`: Form validation, quick amount increments, category management, bulk deletion, search debounce, and viewport resilience (320px screen test).

---

## 🔤 Typography & Assets

- **Fonts**:
  - `Google Sans Khmer` & `Noto Sans Khmer` for Khmer text.
  - `Google Sans` (Regular, Medium, Bold) for numerals and Latin text.
- **Graphics**:
  - Custom SVG wallet illustrations (`wallet.svg`, `wallet_arrow_up.svg`, `wallet-writing.svg`) pre-compiled to `.vec` binary vector graphics for instantaneous rendering.

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
