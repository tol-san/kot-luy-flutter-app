import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/screens/home_screen.dart';
import 'package:kot_luy/screens/startup_screen.dart';
import 'package:kot_luy/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  // Draw the first frame while StartupScreen opens storage asynchronously.
  runApp(const KotLuyApp());
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
