import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../state/providers.dart';
import '../theme/guidanzia_colors.dart';

/// Compact EN/HI/BN switcher (used on the landing header and settings).
class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final g = Theme.of(context).guidanzia;
    return PopupMenuButton<String>(
      onSelected: (code) => ref.read(localeProvider.notifier).setLocale(code),
      color: g.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 44),
      itemBuilder: (context) => [
        for (final code in AppStrings.supported)
          PopupMenuItem(
            value: code,
            child: Row(
              children: [
                if (code == locale)
                  Icon(Icons.check, size: 16, color: g.selectedBorder)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  AppStrings.languageNames[code]!,
                  style: TextStyle(color: g.onSurface),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: g.surfaceElevated,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: g.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, size: 16, color: g.gold),
            const SizedBox(width: 6),
            Text(
              AppStrings.languageNames[locale]!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: g.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
