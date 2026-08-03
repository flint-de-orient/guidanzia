import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../router/app_routes.dart';
import '../state/providers.dart';
import '../theme/guidanzia_colors.dart';
import 'language_menu.dart';
import 'theme_toggle.dart';

/// One destination in the persistent top navigation.
class AppNavTab {
  const AppNavTab(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// The canonical logged-in tab set. Explore only appears once the user has
/// completed an assessment. Shared by the shell and the assessment screens so
/// they never drift.
List<AppNavTab> shellTabs(AppStrings s, bool completed) => [
      AppNavTab(Icons.home_rounded, s.get('home')),
      if (completed) AppNavTab(Icons.explore_rounded, s.get('explore')),
      AppNavTab(Icons.description_rounded, s.get('report')),
      AppNavTab(Icons.person_rounded, s.get('profile')),
    ];

/// The persistent tab strip shown inside the AppBar of the assessment screens
/// (onboarding / questionnaire / games), so the nav is present there too.
/// Tapping a tab records it and returns to the shell; Resume brings the user
/// back to where they left off.
class AssessmentNavTabs extends ConsumerWidget implements PreferredSizeWidget {
  const AssessmentNavTabs({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(localeProvider));
    final completed =
        ref.watch(assessmentStatusProvider.select((st) => st.completed));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _TabStrip(
        tabs: shellTabs(s, completed),
        currentIndex: -1, // none active — user is inside the assessment
        onTabSelected: (i) {
          ref.read(shellTabProvider.notifier).state = i;
          Navigator.of(context)
              .pushNamedAndRemoveUntil(Routes.home, (_) => false);
        },
      ),
    );
  }
}

/// The persistent top navigation chrome shown throughout the app.
///
/// Two modes:
///   * Logged-out — brand + language + a [trailing] action (Sign In).
///   * Logged-in — brand + language, plus a horizontal [tabs] strip whose
///     contents are decided by the caller (3 tabs before the first completed
///     assessment, 4 tabs after). Selection is driven by [currentIndex] /
///     [onTabSelected] so it can back an IndexedStack.
class AppTopNav extends ConsumerWidget {
  const AppTopNav({
    super.key,
    this.trailing,
    this.tabs,
    this.currentIndex = 0,
    this.onTabSelected,
  });

  final Widget? trailing;
  final List<AppNavTab>? tabs;
  final int currentIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(localeProvider));
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, color: g.gold),
              const SizedBox(width: 8),
              Text(
                s.get('appName'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  // Navy on light, yellow-gold on dark (matches the Home wordmark).
                  color: Theme.of(context).brightness == Brightness.dark
                      ? g.gold
                      : g.onSurface,
                ),
              ),
              const Spacer(),
              const ThemeToggle(),
              const SizedBox(width: 8),
              const LanguageMenu(),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
          if (tabs != null && tabs!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TabStrip(
              tabs: tabs!,
              currentIndex: currentIndex,
              onTabSelected: onTabSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final List<AppNavTab> tabs;
  final int currentIndex;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: g.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: isDark ? Border.all(color: g.outline) : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1A4B3BC7),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) {
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTabSelected?.call(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: active ? g.selectedFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[i].icon,
                      size: 20,
                      color: active ? g.selectedBorder : g.onSurfaceVariant,
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tabs[i].label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: g.selectedBorder,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
