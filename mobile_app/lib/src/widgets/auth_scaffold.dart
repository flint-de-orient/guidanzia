import 'package:flutter/material.dart';

import '../theme/guidanzia_colors.dart';
import 'language_menu.dart';
import 'theme_toggle.dart';

/// Shared chrome for the Login / Signup screens, styled to the Stitch
/// `sign_up_for_guidanzia` mockup: a top row (back + theme/language), a big
/// left-aligned gold [title] heading, an optional [subtitle], the [children]
/// (bare form fields + button + links), and a small footer.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final canPop = Navigator.of(context).canPop();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (canPop)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  const SizedBox(width: 24),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [ThemeToggle(), SizedBox(width: 8), LanguageMenu()],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 38,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: g.gold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(subtitle!,
                  style: TextStyle(color: g.onSurfaceVariant, fontSize: 15, height: 1.4)),
            ],
            const SizedBox(height: 32),
            ...children,
            const SizedBox(height: 28),
            Center(
              child: Text(
                "© 2026 Guidenzia AI · Empowering Indian students' careers.",
                textAlign: TextAlign.center,
                style: TextStyle(color: g.onSurfaceVariant, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A field label above an auth input (still used by Edit Profile).
class AuthLabel extends StatelessWidget {
  const AuthLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).guidanzia.onSurface)),
      );
}

/// The "Don't have an account? Sign Up" style link row.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: TextStyle(color: g.onSurfaceVariant)),
        GestureDetector(
          onTap: onTap,
          child: Text(action,
              style: TextStyle(color: g.lime, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
