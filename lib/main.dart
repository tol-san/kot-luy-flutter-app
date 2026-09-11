import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/screens/home_screen.dart';
import 'package:kot_luy/screens/startup_screen.dart';
import 'package:kot_luy/services/reminder_service.dart';
import 'package:kot_luy/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final reminderService = LocalReminderService();
  await reminderService.initialize();
  // Draw the first frame while StartupScreen opens storage asynchronously.
  runApp(KotLuyApp(reminderService: reminderService));
}

class KotLuyApp extends StatelessWidget {
  const KotLuyApp({super.key, this.repository, this.reminderService});
  final ExpenseRepository? repository;
  final ReminderService? reminderService;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'កត់លុយ • Kot Luy',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('km'),
    supportedLocales: const [Locale('km'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: repository != null
        ? HomeScreen(
            repository: repository!,
            reminderService: reminderService,
          )
        : StartupScreen(reminderService: reminderService),
  );
}
