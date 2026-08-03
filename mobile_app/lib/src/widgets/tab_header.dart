import 'package:flutter/material.dart';
import 'theme_toggle.dart';

/// A tab's top row: the tab's own title/content on the left (via [child]) and
/// the light/dark [ThemeToggle] pinned top-right. Mirrors the Home tab's brand
/// row so the toggle sits in one consistent place across every tab, instead of
/// floating over the content.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, this.child});

  /// The left-side header content (title + optional subtitle). When null, the
  /// row is just the toggle — used by tabs that lead with a hero card.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child ?? const SizedBox.shrink()),
        const SizedBox(width: 12),
        const ThemeToggle(),
      ],
    );
  }
}
