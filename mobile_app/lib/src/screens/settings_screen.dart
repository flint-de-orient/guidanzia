import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../state/providers.dart';
import '../config/app_config.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/guidanzia_app_bar.dart';
import '../theme/guidanzia_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = Theme.of(context).guidanzia;
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: const GuidanziaAppBar(title: 'Settings'),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const _GroupLabel('Language'),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final code in AppStrings.supported)
                      ListTile(
                        title: Text(AppStrings.languageNames[code]!),
                        trailing: locale == code
                            ? Icon(Icons.check_circle,
                                color: g.gold)
                            : Icon(Icons.circle_outlined,
                                color: g.onSurfaceVariant),
                        onTap: () =>
                            ref.read(localeProvider.notifier).setLocale(code),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _GroupLabel('About'),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(context, 'App', 'Guidenzia Mobile'),
                    const SizedBox(height: 10),
                    _row(context, 'Version', '1.0.0 (v1 · dev)'),
                    const SizedBox(height: 10),
                    _row(context, 'Backend', AppConfig.apiBaseUrl),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: g.gold),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Static text is translated in-app; AI-generated career '
                        'content is translated on demand by the server.',
                        style: TextStyle(
                            color: g.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    final g = Theme.of(context).guidanzia;
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(k,
                style: TextStyle(
                    color: g.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(v,
                style: TextStyle(
                    color: g.onSurface, fontWeight: FontWeight.w600)),
          ),
        ],
      );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              color: g.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.6)),
    );
  }
}
