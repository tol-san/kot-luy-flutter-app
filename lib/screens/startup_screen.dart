import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart';

import 'package:kot_luy/data/expense_repository.dart';
import 'package:kot_luy/models/expense.dart';
import 'package:kot_luy/screens/home_screen.dart';
import 'package:kot_luy/services/expense_period_store.dart';
import 'package:kot_luy/services/reminder_service.dart';

import 'package:kot_luy/theme.dart';

class StartupData {
  const StartupData({
    required this.repository,
    this.expenses,
    this.categories,
    this.hasAnyExpenses,
    this.period = ExpensePeriod.month,
  });

  final ExpenseRepository repository;
  final List<Expense>? expenses;
  final List<ExpenseCategory>? categories;
  final bool? hasAnyExpenses;
  final ExpensePeriod period;
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    this.openRepository = ExpenseRepository.open,
    this.reminderService,
    this.transitionDuration = const Duration(milliseconds: 280),
  });

  final Future<ExpenseRepository> Function() openRepository;
  final ReminderService? reminderService;
  final Duration transitionDuration;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late Future<StartupData> _startup = _init();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/logo.png'), context);
  }

  Future<StartupData> _init() async {
    final repositoryFuture = widget.openRepository();
    final selectedPeriod = await loadSelectedExpensePeriod();
    final repo = await repositoryFuture;
    try {
      final now = clock.now();
      final range = selectedPeriod.dateRange(now);
      final hasAnyExpensesFuture = repo.hasAnyExpenses();
      final categories = await repo.getCategories(includeArchived: true);
      final results = await Future.wait<Object>([
        repo.all(
          categories: categories,
          categoriesAreComplete: true,
          fromInclusive: range.start,
          toExclusive: range.end,
        ),
        hasAnyExpensesFuture,
      ]);
      return StartupData(
        repository: repo,
        expenses: results[0] as List<Expense>,
        categories: categories,
        hasAnyExpenses: results[1] as bool,
        period: selectedPeriod,
      );
    } catch (_) {
      return StartupData(repository: repo, period: selectedPeriod);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = disableAnimations
        ? Duration.zero
        : widget.transitionDuration;

    return FutureBuilder<StartupData>(
      future: _startup,
      builder: (context, snapshot) {
        Widget child;
        if (snapshot.hasData) {
          final data = snapshot.data!;
          child = KeyedSubtree(
            key: const ValueKey('home'),
            child: HomeScreen(
              repository: data.repository,
              reminderService: widget.reminderService,
              initialExpenses: data.expenses,
              initialCategories: data.categories,
              initialHasAnyExpenses: data.hasAnyExpenses,
              initialPeriod: data.period,
            ),
          );
        } else {
          child = KeyedSubtree(
            key: const ValueKey('splash'),
            child: Scaffold(
              backgroundColor: paper,
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
            ),
          );
        }

        return ColoredBox(
          color: paper,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [
                ...previousChildren.map(
                  (w) => IgnorePointer(key: w.key, child: w),
                ),
                ?currentChild,
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
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
