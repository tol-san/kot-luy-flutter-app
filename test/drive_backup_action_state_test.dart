import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/backup/drive_backup.dart';
import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/screens/drive_backup_sheet.dart';
import 'package:kot_luy/theme.dart';
import 'package:sqflite/sqflite.dart';

class _Database extends Fake implements Database {}

class _Repository extends Fake implements ExpenseRepository {
  @override
  final Database database = _Database();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Google Sans': 'GoogleSans-Regular.ttf',
      'Google Sans Khmer': 'GoogleSansKhmer-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
  });
  for (final enabled in [true, false]) {
    for (final action in ['backup', 'backup refresh failure', 'restore']) {
      testWidgets(
        '$action preserves settings $enabled and scopes its progress',
        (tester) async {
          tester.view.physicalSize = const Size(400, 1100);
          tester.view.devicePixelRatio = 1;
          final pending = Completer<Object?>();
          var configureCalls = 0;
          var actionCalls = 0;
          var listCalls = 0;
          final status = {
            'email': 'test@example.com',
            'automatic': enabled,
            'wifiOnly': !enabled,
          };
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(DriveBackup.channel, (call) async {
            switch (call.method) {
              case 'status':
                return status;
              case 'list':
                if (++listCalls > 1 && action == 'backup refresh failure') {
                  throw PlatformException(code: 'network');
                }
                return [
                  {
                    'id': 'one',
                    'name': 'one',
                    'createdTime': '2026-09-08T08:00:00Z',
                    'size': '2000',
                  },
                  {
                    'id': 'two',
                    'name': 'two',
                    'createdTime': '2026-09-07T08:00:00Z',
                    'size': '1000',
                  },
                ];
              case 'configure':
                configureCalls++;
                return status;
              case 'backup':
              case 'download':
                actionCalls++;
                return pending.future;
            }
            return null;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(DriveBackup.channel, null);
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: appTheme(),
              home: Scaffold(body: Builder(builder: (context) => TextButton(
                onPressed: () => DriveBackupSheet.show(context, _Repository()),
                child: const Text('Open backup'),
              ))),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open backup'));
          await tester.pumpAndSettle();
          if (action.startsWith('backup')) {
            await tester.ensureVisible(find.text('បម្រុងទុកឥឡូវនេះ'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('បម្រុងទុកឥឡូវនេះ'));
          } else {
            await tester.ensureVisible(find.text('ស្ដារ').first);
            await tester.pumpAndSettle();
            await tester.tap(find.text('ស្ដារ').first);
            await tester.pumpAndSettle();
            await tester.tap(find.text('ស្ដារឡើងវិញ'));
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(
            find.text(action.startsWith('backup') ? 'កំពុងបម្រុងទុក…' : 'កំពុងស្ដារ…'),
            findsOneWidget,
          );
          for (final toggle in tester.widgetList<SwitchListTile>(
            find.byType(SwitchListTile),
          )) {
            expect(toggle.value, enabled);
            expect(toggle.onChanged, isNull);
            final states = {
              WidgetState.disabled,
              if (enabled) WidgetState.selected,
            };
            expect(
              toggle.thumbColor!.resolve(states),
              enabled ? const Color(0xFF52735F) : const Color(0xFF737873),
            );
          }
          for (final button in tester.widgetList<OutlinedButton>(
            find.byType(OutlinedButton),
          )) {
            expect(button.onPressed, isNull);
          }
          expect(configureCalls, 0);
          expect(actionCalls, 1);
          if (action.startsWith('backup') && enabled) {
            pending.complete(status);
          } else {
            pending.completeError(PlatformException(code: 'network'));
          }
          await tester.pumpAndSettle();
          if (action.startsWith('backup')) {
            if (enabled) {
              expect(find.byType(DriveBackupSheet), findsNothing);
              expect(
                find.widgetWithText(SnackBar, 'បានបម្រុងទុកទៅ Google Drive ដោយជោគជ័យ!'),
                findsOneWidget,
              );
            } else {
              final message = find.descendant(
                of: find.byType(DriveBackupSheet),
                matching: find.textContaining('បញ្ហាតភ្ជាប់បណ្ដាញ'),
              );
              expect(message, findsOneWidget);
              expect(message.hitTestable(), findsOneWidget);
              expect(find.byType(SnackBar), findsNothing);
            }
          }
          expect(find.byType(CircularProgressIndicator), findsNothing);
          for (final toggle in tester.widgetList<SwitchListTile>(
            find.byType(SwitchListTile),
          )) {
            expect(toggle.value, enabled);
            expect(toggle.onChanged, isNotNull);
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
