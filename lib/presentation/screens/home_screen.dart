import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';

import 'placeholder_screen.dart';

/// Màn hình chính — NavigationBar 4 tab: Lớp học / Kỳ thi / Kết quả / Thống kê.
final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  void _pushPlaceholder(BuildContext context, String title) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => PlaceholderScreen(title: title)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _pushPlaceholder(context, l10n.settingsTitle),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          _TabPlaceholder(icon: Icons.school_outlined),
          _TabPlaceholder(icon: Icons.assignment_outlined),
          _TabPlaceholder(icon: Icons.fact_check_outlined),
          _TabPlaceholder(icon: Icons.bar_chart_outlined),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: l10n.navClasses,
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: l10n.navContests,
          ),
          NavigationDestination(
            icon: const Icon(Icons.fact_check_outlined),
            selectedIcon: const Icon(Icons.fact_check),
            label: l10n.navResults,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l10n.navStats,
          ),
        ],
      ),
    );
  }
}

final class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final empty = switch (icon) {
      Icons.school_outlined => l10n.emptyClasses,
      Icons.assignment_outlined => l10n.emptyContests,
      Icons.fact_check_outlined => l10n.emptyResults,
      _ => l10n.navStats,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(empty, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
