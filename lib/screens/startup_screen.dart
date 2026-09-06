import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/expense_repository.dart';

import 'home_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    this.openRepository = ExpenseRepository.open,
  });

  final Future<ExpenseRepository> Function() openRepository;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late Future<ExpenseRepository> _repository = widget.openRepository();

  @override
  Widget build(BuildContext context) => FutureBuilder<ExpenseRepository>(
    future: _repository,
    builder: (context, snapshot) {
      // No timer or minimum splash duration: enter as soon as storage is ready.
      if (snapshot.hasData) return HomeScreen(repository: snapshot.data!);
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LaunchArtwork(),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 24),
                    const Text('មិនអាចបើកទិន្នន័យបាន'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _repository = widget.openRepository();
                      }),
                      child: const Text('ព្យាយាមម្ដងទៀត'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class LaunchArtwork extends StatelessWidget {
  const LaunchArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final available = screenWidth > 64 ? screenWidth - 48 : 342.0;
    return SvgPicture.asset(
      'assets/illustrations/kot-luy-logo.svg',
      width: math.min(360.0, available),
      semanticsLabel: 'កត់លុយ',
    );
  }
}
