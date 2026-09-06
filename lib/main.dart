import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/expense_repository.dart';
import 'screens/home_screen.dart';
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
        : const _Startup(),
  );
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<ExpenseRepository> _repository = ExpenseRepository.open();
  @override
  Widget build(BuildContext context) => FutureBuilder<ExpenseRepository>(
    future: _repository,
    builder: (context, snapshot) {
      if (snapshot.hasData) return HomeScreen(repository: snapshot.data!);
      return Scaffold(
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: muted, size: 42),
                    const SizedBox(height: 16),
                    const Text('មិនអាចបើកទិន្នន័យបាន'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(
                        () => _repository = ExpenseRepository.open(),
                      ),
                      child: const Text('ព្យាយាមម្ដងទៀត'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
