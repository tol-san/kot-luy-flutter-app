import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/expense_repository.dart';
import 'screens/home_screen.dart';
import 'screens/startup_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  ExpenseRepository? repository;
  try {
    repository = await ExpenseRepository.open();
  } catch (_) {
    // If opening database fails, repository remains null and falls back to StartupScreen with retry.
  }
  runApp(KotLuyApp(repository: repository));
}

class KotLuyApp extends StatelessWidget {
  const KotLuyApp({super.key, this.repository});
  final ExpenseRepository? repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'កត់លុយ • Kot Luy',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('km'),
    supportedLocales: const [Locale('km'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: repository != null
        ? HomeScreen(repository: repository!)
        : const StartupScreen(),
  );
}
