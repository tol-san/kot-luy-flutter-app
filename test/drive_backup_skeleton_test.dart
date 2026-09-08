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

  testWidgets(
    'DriveBackupSheet shows DriveBackupSkeleton on initial open and on refresh',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1100);
      tester.view.devicePixelRatio = 1;

      Completer<Map<String, dynamic>> initialStatusCompleter =
          Completer<Map<String, dynamic>>();
      Completer<List<Map<String, dynamic>>> initialListCompleter =
          Completer<List<Map<String, dynamic>>>();

      Completer<Map<String, dynamic>>? refreshStatusCompleter;
      Completer<List<Map<String, dynamic>>>? refreshListCompleter;

      var statusCalls = 0;
      var listCalls = 0;

      final connectedStatus = {
        'email': 'tolsan@example.com',
        'automatic': true,
        'wifiOnly': false,
      };

      final backupFiles = [
        {
          'id': 'file-1',
          'name': 'backup_1.json',
          'createdTime': '2026-09-08T10:00:00Z',
          'size': '4096',
        },
      ];

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(DriveBackup.channel, (call) async {
        switch (call.method) {
          case 'status':
            statusCalls++;
            if (statusCalls == 1) {
              return initialStatusCompleter.future;
            } else {
              return refreshStatusCompleter?.future ?? connectedStatus;
            }
          case 'list':
            listCalls++;
            if (listCalls == 1) {
              return initialListCompleter.future;
            } else {
              return refreshListCompleter?.future ?? backupFiles;
            }
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
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => DriveBackupSheet.show(context, _Repository()),
                child: const Text('Open backup'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open the bottom sheet
      await tester.tap(find.text('Open backup'));
      await tester.pump(); // Start opening transition
      await tester.pump(const Duration(milliseconds: 300)); // Finish sheet slide in

      // Verify that while status is loading, DriveBackupSkeleton is visible
      expect(find.byType(DriveBackupSkeleton), findsOneWidget);
      // Verify that old CircularProgressIndicator in the center is NOT present
      expect(
        find.descendant(
          of: find.byType(DriveBackupSheet),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      // Resolve initial loading
      initialStatusCompleter.complete(connectedStatus);
      await tester.pump();
      initialListCompleter.complete(backupFiles);
      await tester.pumpAndSettle();

      // Verify that skeleton is gone and real connected content is shown
      expect(find.byType(DriveBackupSkeleton), findsNothing);
      expect(find.text('tolsan@example.com'), findsOneWidget);
      expect(find.text('ឯកសារបម្រុងទុកលើ Google Drive'), findsOneWidget);
      expect(find.byType(IconButton), findsWidgets);

      // 2. Click the refresh icon
      refreshStatusCompleter = Completer<Map<String, dynamic>>();
      refreshListCompleter = Completer<List<Map<String, dynamic>>>();

      final refreshButton = find.byTooltip('ទាញយកបញ្ជីឡើងវិញ');
      expect(refreshButton, findsOneWidget);

      await tester.tap(refreshButton);
      await tester.pump();

      // Verify DriveBackupSkeleton is shown again during refresh
      expect(find.byType(DriveBackupSkeleton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DriveBackupSheet),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      // Complete the refresh
      refreshStatusCompleter.complete(connectedStatus);
      await tester.pump();
      refreshListCompleter.complete(backupFiles);
      await tester.pumpAndSettle();

      // Verify skeleton is dismissed after refresh completes
      expect(find.byType(DriveBackupSkeleton), findsNothing);
      expect(find.text('tolsan@example.com'), findsOneWidget);
    },
  );
}
