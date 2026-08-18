import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/guidanzia_colors.dart';

/// The "94% Match" pill seen on every career card (images 2/6) — cyan accent.
class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.percentage, this.compact = false});

  final int percentage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: g.cyan.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: g.cyan),
          const SizedBox(width: 5),
          Text(
            '$percentage% Match',
            style: TextStyle(
              color: g.cyan,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled stat tile (salary / growth / experience) for the 2x2 detail grid.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background ?? g.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: g.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: g.gold),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: g.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: g.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill used for skill/qualification chips.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? g.surfaceMuted,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: g.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: g.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Selectable filter chip row (All / Remote / Full-time … from the mockups).
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final option = options[i];
          final isActive = option == selected;
          return GestureDetector(
            onTap: () => onSelected(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? g.selectedBorder : g.surfaceElevated,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isActive ? g.selectedBorder : g.outline,
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  color: isActive ? g.goldInk : g.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Inline error banner for forms.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: g.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: g.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: g.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: g.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Generic loading state with a spinner + message.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: g.gold),
          if (message != null) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: g.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A loader for indeterminate AI waits, where an honest percentage is
/// impossible. It cycles through a set of status phrases that DESCRIBE the work
/// (mixed calm + light tone) and rotate for liveliness — without ever claiming
/// measured, step-by-step progress.
class RotatingLoader extends StatefulWidget {
  const RotatingLoader({super.key, required this.phrases});
  final List<String> phrases;

  @override
  State<RotatingLoader> createState() => _RotatingLoaderState();
}

class _RotatingLoaderState extends State<RotatingLoader> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % widget.phrases.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: g.gold),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                widget.phrases[_i.clamp(0, widget.phrases.length - 1)],
                key: ValueKey(_i),
                textAlign: TextAlign.center,
                style: TextStyle(color: g.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A determinate loader for genuinely countable work (e.g. "3 of 4 loaded") —
/// an HONEST percentage, used only where we truly know the progress.
class CountLoader extends StatelessWidget {
  const CountLoader({super.key, required this.loaded, required this.total, this.label});
  final int loaded;
  final int total;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final pct = total == 0 ? 0.0 : (loaded / total).clamp(0.0, 1.0);
    // Before the first item resolves (loaded == 0) a determinate ring at 0.0
    // draws nothing and reads as "no loader". Show an INDETERMINATE (animated)
    // spinner until the first item lands, then switch to the honest X/total ring.
    final double? ringValue = loaded == 0 ? null : pct;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: ringValue, color: g.gold, strokeWidth: 5),
                Text('$loaded/$total',
                    style: TextStyle(
                        color: g.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(label!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: g.onSurfaceVariant)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Per-loader phrase sets — each tailored to what that operation is actually
/// doing, in a mixed professional + light tone. They rotate for engagement and
/// never imply a measured step count.
class LoaderPhrases {
  const LoaderPhrases._();

  static const recommendations = [
    'Reading your answers…',
    'Weighing your strengths…',
    'Considering your constraints…',
    'Matching careers across India…',
    'Almost there — good things take a sec ✨',
  ];

  static const report = [
    'Gathering your responses…',
    'Mapping your mindset…',
    'Spotting the patterns…',
    'Putting your profile together…',
  ];

  static const section = [
    'Researching this for you…',
    'Pulling the details together…',
    'Double-checking the specifics…',
    'Almost ready…',
  ];

  static const moduleFeedback = [
    'Noticing how you think…',
    'Connecting the dots…',
    'Jotting down what stands out…',
  ];
}

/// Generic error state with a retry button.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: g.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 15),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
