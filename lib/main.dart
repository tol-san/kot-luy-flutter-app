import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/expense_repository.dart';
import 'screens/home_screen.dart';
import 'screens/startup_screen.dart';
import 'theme.dart';

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
  runApp(const KotLoyApp());
}

class KotLoyApp extends StatelessWidget {
  const KotLoyApp({super.key, this.repository});
  final ExpenseRepository? repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'កត់លុយ • Kot Loy',
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
