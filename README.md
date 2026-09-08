# កត់លុយ • Kot Luy

An Android expense tracker built with Flutter and SQLite. Khmer interface, Cambodian riel, a warm sage-and-cream palette, and a custom SVG wallet companion. The supplied logo is included.

## Included

- Dashboard with total spending on the left and a category donut on the right.
- Today, Monday–Sunday week, calendar month, and all-time views.
- Transactions grouped by date, title/note search, and category filtering.
- Add-expense bottom sheet with integer KHR amounts, six categories, quick amounts, date, title, and optional note.
- Transaction details, editing, and confirmed deletion.
- Category reports calculated from stored expenses.
- SQLite persistence, local bundled Khmer font, loading/error/empty states, keyboard-safe scrolling, and responsive layouts.
- Android launcher icon matching the wallet character.

The app starts with no transactions. Sample transactions appear only in the visual tests.

## Run

Requires Flutter 3.47 / Dart 3.13 or compatible, an Android SDK, and an Android device or emulator.

```sh
flutter pub get
flutter run
```

## Installable Android build

```powershell
./scripts/build-release.ps1
```

Runs analysis, all Flutter tests, and the native Android backup regression tests
before building split APKs in `build/app/outputs/flutter-apk/`.
The Flutter contract test generates databases using the actual repository's
creation and upgrade callbacks; Android tests must successfully back them up.
This catches local schema changes that have not been added to the native backup
reader. For native tests alone, first run
`flutter test test/backup_native_contract_test.dart`, then run
`./gradlew.bat :app:testDebugUnitTest` from `android/`.
The current release configuration uses the local development signing key for direct installation/testing. Configure your own release keystore before Play Store distribution.

## Browser preview

The browser build uses SQLite WASM with browser-local persistence. It has separate data from the Android app. Clearing browser site data removes its records.

```sh
dart run sqflite_common_ffi_web:setup
flutter run -d chrome
```

SQLite worker/WASM files are already included. Production browser builds load their CanvasKit engine locally.

```sh
flutter build web --release
python -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

Open http://127.0.0.1:8080. The server must stay running for this local preview.

## Verify

```sh
flutter analyze
flutter test
```

Five tests cover actual file-backed SQLite persistence after reopening, Khmer text and exact integer amounts, updates/deletion, calendar boundaries, form validation and the add/edit/delete flow, visual screenshots, and a 320px screen with enlarged text and keyboard insets.

The three golden images in `test/previews/` use a fixed clock. Regenerate intentionally with `flutter test --update-goldens`. Golden rendering can vary between host platforms.

## Structure

- `lib/data/expense_repository.dart`: SQLite schema and persistence.
- `lib/models/expense.dart`: expense model, category metadata, date filters, KHR formatting.
- `lib/screens/`: dashboard/reports, add/edit sheet, details.
- `lib/widgets/expense_chart.dart`: accessible category donut.
- `lib/theme.dart`: shared colors and typography.
- `assets/illustrations/wallet.svg`: original editable character.
- `assets/fonts/OFL.txt`: Noto Sans Khmer font license.

Amounts are whole riel, from 1 to 999,999,999,999. SQLite stores them as integers. Dates use the device's local timezone. Data stays in the app's SQLite database; uninstalling the app or clearing its storage may remove it. There is no account, cloud sync, budget, or export feature in this version.

SQLite integration follows Flutter's official guide: https://docs.flutter.dev/cookbook/persistence/sqlite
