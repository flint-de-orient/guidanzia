import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/app_gradients.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/common_widgets.dart';
import '../role_detail_screen.dart';
import '../career_report_screen.dart';
import '../../theme/guidanzia_colors.dart';

/// Assessment recap — aptitude scores + quick access to the full AI reports.
class ReportTab extends ConsumerWidget {
  const ReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = Theme.of(context).guidanzia;
    final q = ref.watch(questionnaireProvider);
    final scores = <(String, int?, Color)>[
      ('Number Sense', q.numberSenseScore, const Color(0xFFE0A92E)),
      ('Word Sense', q.wordSenseScore, const Color(0xFF7FA300)),
      ('Shape Sense', q.shapeSenseScore, const Color(0xFF12A5A5)),
      ('Logic Sense', q.logicSenseScore, const Color(0xFFD6822E)),
    ];
    final async = ref.watch(recommendationsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        const Text('Your report',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('A snapshot of your aptitude profile and career reports.',
            style: TextStyle(color: g.onSurfaceVariant)),
        const SizedBox(height: 20),
        _CareerReportCta(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CareerReportScreen()),
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aptitude profile',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                q.gamesComplete
                    ? 'Based on the four sense-games you played.'
                    : 'Play the assessment games to see your scores here.',
                style: TextStyle(
                    color: g.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 18),
              ...scores.map((s) => _ScoreBar(
                    label: s.$1,
                    score: s.$2,
                    color: s.$3,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Career reports'),
        async.when(
          loading: () => const RotatingLoader(phrases: LoaderPhrases.recommendations),
          error: (e, _) => Text('Complete the assessment to unlock reports.',
              style: TextStyle(color: g.onSurfaceVariant)),
          data: (careers) {
            if (careers.isEmpty) {
              return Text('No reports yet.',
                  style: TextStyle(color: g.onSurfaceVariant));
            }
            return Column(
              children: careers
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SoftCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoleDetailScreen(career: c),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.description_outlined,
                                  color: g.gold),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(c.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 15, color: g.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CareerReportCta extends StatelessWidget {
  const _CareerReportCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppGradients.hero,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Color(0x55283569), blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 34),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Career Report',
                      style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Full mindset profile — motivation, aptitude & more',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.score, required this.color});
  final String label;
  final int? score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final value = (score ?? 0) / 8;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(score == null ? '—' : '$score/8',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: g.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
