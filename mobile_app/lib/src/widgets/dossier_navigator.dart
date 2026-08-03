import 'package:flutter/material.dart';

import '../theme/guidanzia_colors.dart';

/// One entry in the dossier navigator.
class DossierSection {
  const DossierSection({required this.type, required this.title, required this.icon});
  final String type;
  final String title;
  final IconData icon;
}

/// Stitch `interactive_dossier_navigator` — a persistent floating trigger that
/// opens a bottom sheet listing the dossier's sections; tapping one jumps the
/// page to it. Replaces the old scroll-away pill nav so section-jumping stays
/// reachable the whole way down the report.
///
/// Presentation only: [onSelect] drives the screen's existing
/// expand-card + scroll-to-section logic, so nothing about the data changes.
/// Rendered as the Scaffold's `floatingActionButton`, so it sits above the
/// export bar and never scrolls away.
class DossierNavigator extends StatelessWidget {
  const DossierNavigator({super.key, required this.sections, required this.onSelect});

  final List<DossierSection> sections;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return FloatingActionButton.extended(
      onPressed: () => _open(context),
      backgroundColor: g.gold,
      foregroundColor: g.goldInk,
      elevation: 6,
      icon: const Icon(Icons.list_alt_rounded),
      label: const Text('Sections', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Future<void> _open(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: g.surfaceElevated,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Jump to section',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: g.onSurface)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: sections.length,
                itemBuilder: (context, i) {
                  final s = sections[i];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: g.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.icon, color: g.gold, size: 20),
                    ),
                    title: Text(s.title,
                        style: TextStyle(fontWeight: FontWeight.w700, color: g.onSurface)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: g.onSurfaceVariant),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onSelect(s.type);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
