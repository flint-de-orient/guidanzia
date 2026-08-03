import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../router/app_routes.dart';
import '../state/providers.dart';
import '../theme/app_gradients.dart';
import '../theme/guidanzia_colors.dart';

/// The single, always-visible primary call-to-action pinned to the bottom of
/// the landing / Home page. Its label and action follow auth + assessment
/// state:
///   * logged-out            -> "Get Started"  -> sign up
///   * in-progress assessment-> "Resume Assessment" -> jump back to the stage
///   * completed (idle)      -> "Start New Assessment" -> onboarding
///   * first-timer (idle)    -> "Start Assessment" -> onboarding
class PrimaryCtaBar extends ConsumerWidget {
  const PrimaryCtaBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(localeProvider));
    final auth = ref.watch(authProvider);
    final status = ref.watch(assessmentStatusProvider);

    late final String label;
    late final VoidCallback onTap;

    if (!auth.isAuthenticated) {
      label = s.get('getStarted');
      onTap = () => Navigator.of(context).pushNamed(Routes.signup);
    } else if (status.inProgress) {
      label = s.get('resumeAssessment');
      onTap = () => _resume(context, status.stage);
    } else {
      label = status.completed
          ? s.get('startNewAssessment')
          : s.get('startAssessment');
      onTap = () {
        ref.read(assessmentStatusProvider.notifier).enter(AssessmentStage.onboarding);
        Navigator.of(context).pushNamed(Routes.onboarding);
      };
    }

    final g = Theme.of(context).guidanzia;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: g.gold.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: g.goldInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: g.goldInk),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _resume(BuildContext context, AssessmentStage stage) {
    final route = switch (stage) {
      AssessmentStage.questionnaire => Routes.questionnaire,
      AssessmentStage.games => Routes.games,
      _ => Routes.onboarding,
    };
    Navigator.of(context).pushNamed(route);
  }
}
