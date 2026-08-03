import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/guidanzia_colors.dart';

/// Compact light/dark switch for the top nav, mirroring [LanguageMenu]'s pill.
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = Theme.of(context).guidanzia;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Semantics(
      button: true,
      label: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => ref.read(themeModeProvider.notifier).toggle(),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: g.surfaceElevated,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: g.outline),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 18,
            color: g.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
