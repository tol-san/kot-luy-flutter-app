import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/screens/home_screen.dart';
import 'package:kot_luy/screens/startup_screen.dart';
import 'package:kot_luy/theme.dart';

import 'widget_test.dart' show MemoryRepository;

void main() {
  testWidgets('startup enters home immediately when storage is ready', (
    tester,
  ) async {
    final storage = Completer<ExpenseRepository>();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: StartupScreen(openRepository: () => storage.future),
      ),
    );
    expect(find.byType(LaunchArtwork), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    storage.complete(MemoryRepository());
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LaunchArtwork), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup retries storage errors successfully', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: StartupScreen(
          openRepository: () async {
            if (attempts++ == 0) throw StateError('unavailable');
            return MemoryRepository();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('មិនអាចបើកទិន្នន័យបាន'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('launch artwork renders and honors reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: const MediaQuery(
          data: MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: Scaffold(body: Center(child: LaunchArtwork())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('previews/launch.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
