import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/screens/home_screen.dart';
import 'package:kot_luy/services/reminder_service.dart';

class StartupData {
  const StartupData({
    required this.repository,
    this.expenses,
    this.categories,
    this.hasAnyExpenses,
  });

  final ExpenseRepository repository;
  final List<Expense>? expenses;
  final List<ExpenseCategory>? categories;
  final bool? hasAnyExpenses;
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    this.openRepository = ExpenseRepository.open,
    this.reminderService,
  });

  final Future<ExpenseRepository> Function() openRepository;
  final ReminderService? reminderService;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late Future<StartupData> _startup = _init();

  Future<StartupData> _init() async {
    final repo = await widget.openRepository();
    try {
      final now = clock.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1);
      final categories = await repo.getCategories(includeArchived: true);
      final results = await Future.wait<Object>([
        repo.all(
          categories: categories,
          categoriesAreComplete: true,
          fromInclusive: start,
          toExclusive: end,
        ),
        repo.hasAnyExpenses(),
      ]);
      return StartupData(
        repository: repo,
        expenses: results[0] as List<Expense>,
        categories: categories,
        hasAnyExpenses: results[1] as bool,
      );
    } catch (_) {
      return StartupData(repository: repo);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<StartupData>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final data = snapshot.data!;
        return HomeScreen(
          repository: data.repository,
          reminderService: widget.reminderService,
          initialExpenses: data.expenses,
          initialCategories: data.categories,
          initialHasAnyExpenses: data.hasAnyExpenses,
        );
      }
      return Scaffold(
        body: Center(
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
                    _startup = _init();
                  }),
                  child: const Text('ព្យាយាមម្ដងទៀត'),
                ),
              ],
            ],
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
    return SvgPicture(
      const AssetBytesLoader('assets/illustrations/kot-luy-logo.svg.vec'),
      width: math.min(360.0, available),
      semanticsLabel: 'កត់លុយ',
    );
  }
}
