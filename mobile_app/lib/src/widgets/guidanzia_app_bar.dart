import 'package:flutter/material.dart';
import 'theme_toggle.dart';

/// Shared top bar for pushed screens. Carries the light/dark [ThemeToggle] in
/// its actions so the control is reachable on every page, in one consistent
/// place (top-right). Inherits colours from the theme's AppBarTheme
/// (transparent, onSurface icons/title).
class GuidanziaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GuidanziaAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.centerTitle = true,
  });

  final String? title;

  /// A pre-styled title widget. Takes precedence over [title] when set — for
  /// screens that need a custom title (e.g. the questionnaire's module label).
  final Widget? titleWidget;
  final Widget? leading;

  /// Extra actions placed BEFORE the theme toggle.
  final List<Widget> actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titleWidget ?? (title == null ? null : Text(title!)),
      leading: leading,
      centerTitle: centerTitle,
      actions: [
        ...actions,
        const ThemeToggle(),
        const SizedBox(width: 8),
      ],
    );
  }
}
