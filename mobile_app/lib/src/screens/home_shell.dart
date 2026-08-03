import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../state/providers.dart';
import '../theme/guidanzia_colors.dart';
import '../widgets/gradient_background.dart';
import 'landing_screen.dart';
import 'tabs/explore_tab.dart';
import 'tabs/recommendations_tab.dart';
import 'tabs/profile_tab.dart';

/// Tab indices in the shell. Used by other screens (e.g. the games flow) to
/// land the user on a specific tab via [shellTabProvider].
class ShellTab {
  const ShellTab._();
  static const home = 0;
  static const explore = 1;
  static const matches = 2;
  static const profile = 3;
}

/// The logged-in shell — a floating bottom tab bar matching the app mockups:
/// **Home · Explore · Matches · Profile**. The tab set is fixed (empty states
/// handle "no data yet") so indices never shift.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(localeProvider));

    // A returning user with recommendations counts as completed.
    ref.listen(recommendationsProvider, (_, next) {
      next.whenData((careers) {
        if (careers.isNotEmpty) {
          ref.read(assessmentStatusProvider.notifier).markCompleted();
        }
      });
    });

    final items = <(IconData, String)>[
      (Icons.home_rounded, s.get('home')),
      (Icons.explore_rounded, s.get('explore')),
      (Icons.auto_awesome_rounded, s.get('matches')),
      (Icons.person_rounded, s.get('profile')),
    ];
    const pages = <Widget>[
      LandingBody(),
      ExploreTab(),
      RecommendationsTab(),
      ProfileTab(),
    ];

    var index = ref.watch(shellTabProvider);
    if (index < 0 || index >= pages.length) index = 0;

    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          // Each tab carries the theme toggle in its own header row (Home in
          // its brand row, the others via TabHeader), so it sits in one
          // consistent top-right spot without floating over content.
          child: IndexedStack(index: index, children: pages),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: index,
        items: items,
        onTap: (i) => ref.read(shellTabProvider.notifier).state = i,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.items,
    required this.onTap,
  });

  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: g.surfaceElevated,
          borderRadius: BorderRadius.circular(26),
          border: isDark ? Border.all(color: g.outline) : null,
          boxShadow: isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x14283569),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final active = i == index;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(items[i].$1,
                        size: 22,
                        color:
                            active ? g.selectedBorder : g.onSurfaceVariant),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? g.selectedBorder : g.onSurfaceVariant,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
