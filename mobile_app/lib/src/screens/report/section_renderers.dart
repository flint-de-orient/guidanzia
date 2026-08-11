import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/common_widgets.dart';
import '../../theme/guidanzia_colors.dart';

/// Renders the AI JSON for each career-report section into styled widgets.
/// Each section's shape mirrors the backend prompts in app.py.
class SectionRenderer {
  static Widget build(BuildContext context, String type, Map<String, dynamic> content) {
    try {
      switch (type) {
        case 'overview':
          return _overview(context, content);
        case 'pathway':
          return _pathway(context, content);
        case 'skills':
          return _skills(context, content);
        case 'roadmap':
          return _roadmap(context, content);
        case 'institute':
          return _institutes(context, content);
        case 'fees':
          return _fees(context, content);
        case 'scholarships':
          return _scholarships(context, content);
        case 'jobmarket':
          return _jobMarket(context, content);
        case 'salary':
          return _salary(context, content);
        case 'certifications':
          return _certifications(context, content);
        case 'experts':
          return _experts(context, content);
        default:
          return _generic(context, content);
      }
    } catch (_) {
      return _generic(context, content);
    }
  }

  // ---- helpers ----

  static List<String> _strList(dynamic v) =>
      (v is List) ? v.map((e) => e.toString()).toList() : const [];

  static List<Map<String, dynamic>> _mapList(dynamic v) => (v is List)
      ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];

  static Widget _bullets(BuildContext context, List<String> items, {IconData icon = Icons.check_circle}) {
    final g = Theme.of(context).guidanzia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 17, color: g.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t,
                          style: TextStyle(
                              height: 1.4, color: g.onSurfaceVariant)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  static Future<void> _open(String url) async {
    var raw = url.trim();
    if (raw.isEmpty) return;
    // Ensure a scheme so the OS resolves it to a browser.
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    // Prefer an IN-APP browser (Chrome Custom Tabs) so the link opens inside the
    // app's own task and the Flutter engine stays alive. Leaving to an external
    // browser fully backgrounds the app, which on low-memory devices gets the
    // process killed and cold-starts it on return. Fall back if unavailable.
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!ok) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {/* give up silently */}
    }
  }

  static Widget _linkButton(BuildContext context, String label, String url,
      {IconData icon = Icons.open_in_new}) {
    final g = Theme.of(context).guidanzia;
    if (url.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _open(url),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: g.gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: g.gold),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: g.gold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  static Widget _subCard(BuildContext context, {required String title, required Widget child, Color? tint}) {
    final g = Theme.of(context).guidanzia;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint ?? g.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14.5)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ---- sections ----

  /// A subtle inline caption for honest framing (e.g. "estimated, not live
  /// data") shown at the top of a section that shouldn't read as hard fact.
  static Widget _note(BuildContext context, String text) {
    final g = Theme.of(context).guidanzia;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: g.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: g.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: g.onSurfaceVariant, fontSize: 11.5, height: 1.35)),
          ),
        ],
      ),
    );
  }

  static Widget _overview(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final o = (c['overview'] as Map?)?.cast<String, dynamic>() ?? c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(o['role_description']?.toString() ?? '',
            style: TextStyle(height: 1.5, color: g.onSurfaceVariant)),
        const SizedBox(height: 16),
        const Text('Key responsibilities',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _bullets(context, _strList(o['key_responsibilities'])),
        if (o['why_suitable'] != null) ...[
          const SizedBox(height: 8),
          _subCard(context, 
            title: 'Why it suits you',
            tint: g.gold.withValues(alpha: 0.07),
            child: Text(o['why_suitable'].toString(),
                style: TextStyle(
                    height: 1.5, color: g.onSurfaceVariant)),
          ),
        ],
      ],
    );
  }

  static Widget _pathway(BuildContext context, Map<String, dynamic> c) {
    final p = (c['careerPathway'] as Map?)?.cast<String, dynamic>() ?? c;
    final steps = _mapList(p['pathway']);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineStep(
            index: i + 1,
            isLast: i == steps.length - 1,
            phase: steps[i]['phase']?.toString() ?? '',
            duration: steps[i]['duration']?.toString() ?? '',
            description: steps[i]['description']?.toString() ?? '',
          ),
      ],
    );
  }

  static Widget _skills(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final s = (c['skills'] as Map?)?.cast<String, dynamic>() ?? c;
    Widget group(String key, String label, Color tint) {
      final items = _mapList(s[key]);
      if (items.isEmpty) return const SizedBox.shrink();
      return _subCard(context, 
        title: label,
        tint: tint,
        child: Column(
          children: items.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(m['description']?.toString() ?? '',
                      style: TextStyle(
                          color: g.onSurfaceVariant, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _linkButton(context, 'Course', m['course_url']?.toString() ?? '',
                        icon: Icons.school_outlined),
                    _linkButton(context, 'Video', m['video_url']?.toString() ?? '',
                        icon: Icons.play_circle_outline),
                  ]),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      children: [
        group('high', 'Must-have skills', g.gold.withValues(alpha: 0.12)),
        group('medium', 'Core skills', g.cyan.withValues(alpha: 0.12)),
        group('low', 'Bonus skills', g.lime.withValues(alpha: 0.12)),
      ],
    );
  }

  static Widget _roadmap(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final r = (c['roadmap'] as Map?)?.cast<String, dynamic>() ?? c;
    Widget phase(String key) {
      final p = (r[key] as Map?)?.cast<String, dynamic>();
      if (p == null) return const SizedBox.shrink();
      return _subCard(context, 
        title: p['title']?.toString() ?? key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _miniLabel(context, 'Goals'),
            _bullets(context, _strList(p['goals']), icon: Icons.flag_outlined),
            _miniLabel(context, 'Tasks'),
            _bullets(context, _strList(p['tasks']), icon: Icons.task_alt),
            _miniLabel(context, 'Progress indicators'),
            _bullets(context, _strList(p['progress_indicators']),
                icon: Icons.insights_outlined),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r['overview'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(r['overview'].toString(),
                style: TextStyle(
                    color: g.onSurfaceVariant, height: 1.4)),
          ),
        phase('phase1'),
        phase('phase2'),
        phase('phase3'),
      ],
    );
  }

  static Widget _miniLabel(BuildContext context, String t) {
    final g = Theme.of(context).guidanzia;
    return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(t.toUpperCase(),
            style: TextStyle(
                color: g.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );
  }

  static Widget _institutes(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final inst = (c['institutes'] as Map?)?.cast<String, dynamic>() ?? c;
    Widget group(String key, String label) {
      final items = _mapList(inst[key]);
      if (items.isEmpty) return const SizedBox.shrink();
      return _subCard(context, 
        title: label,
        child: Column(
          children: items.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(m['name']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (m['rating'] != null) ...[
                        Icon(Icons.star, size: 14, color: g.gold),
                        const SizedBox(width: 3),
                        Text('${m['rating']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${m['department'] ?? ''}${m['location'] != null ? ' · ${m['location']}' : ''}',
                    style: TextStyle(
                        color: g.onSurfaceVariant, fontSize: 12.5),
                  ),
                  if (m['eligibility'] != null) ...[
                    const SizedBox(height: 6),
                    Text('Eligibility: ${m['eligibility']}',
                        style: TextStyle(
                            color: g.onSurfaceVariant, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  _linkButton(context, 'Visit website', m['website']?.toString() ?? ''),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      children: [
        group('government', 'Government'),
        group('private', 'Private'),
        group('distance', 'Distance learning'),
        group('online', 'Online'),
      ],
    );
  }

  static Widget _fees(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final f = (c['fees'] as Map?)?.cast<String, dynamic>() ?? c;
    final breakdown = _mapList(f['breakdown']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: g.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text('Estimated total investment',
                  style: TextStyle(color: g.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 6),
              Text(f['total_investment']?.toString() ?? '—',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: g.gold)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...breakdown.map((m) => _subCard(context, 
              title: m['category']?.toString() ?? '',
              child: Row(
                children: [
                  Expanded(
                    child: Text(m['range']?.toString() ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  if (m['duration'] != null)
                    Text(m['duration'].toString(),
                        style: TextStyle(color: g.onSurfaceVariant)),
                ],
              ),
            )),
        if (f['note'] != null)
          Text(f['note'].toString(),
              style: TextStyle(
                  color: g.onSurfaceVariant, fontSize: 12.5, height: 1.4)),
      ],
    );
  }

  static Widget _scholarships(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final fs =
        (c['financial_support'] as Map?)?.cast<String, dynamic>() ?? c;
    Widget group(String key, String label, String amountKey, String subKey) {
      final items = _mapList(fs[key]);
      if (items.isEmpty) return const SizedBox.shrink();
      return _subCard(context, 
        title: label,
        child: Column(
          children: items.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['name']?.toString() ?? m['provider']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${m[amountKey] ?? ''}${m[subKey] != null ? ' · ${m[subKey]}' : ''}',
                    style: TextStyle(
                        color: g.onSurfaceVariant, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  _linkButton(context, 'Details', m['link']?.toString() ?? ''),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      children: [
        group('scholarships', 'Scholarships', 'amount', 'eligibility'),
        group('loans', 'Education loans', 'max_amount', 'interest_rate'),
        group('government_schemes', 'Government schemes', 'benefit', 'eligibility'),
      ],
    );
  }

  static Widget _jobMarket(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final j = (c['jobmarket'] as Map?)?.cast<String, dynamic>() ?? c;
    final trends = _mapList(j['hiring_trends']);
    final companies = _mapList(j['top_companies']);
    final insights = _strList(j['key_insights']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _note(context,
            'Estimated from general market knowledge — not live vacancy data.'),
        // Equal-height stat tiles so the row never goes ragged when one value
        // is longer than the other.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.trending_up,
                  label: 'Demand',
                  value: '${j['demand_percentage'] ?? '—'}%',
                  background: g.cyan.withValues(alpha: 0.14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.verified_outlined,
                  label: 'Success rate',
                  value: j['success_rate']?.toString() ?? '—',
                  background: g.gold.withValues(alpha: 0.14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (trends.isNotEmpty)
          _subCard(context,
            title: 'Hiring trend (monthly openings)',
            child: SizedBox(height: 160, child: _HiringChart(trends: trends)),
          ),
        if (companies.isNotEmpty) ...[
          const Text('Top hiring companies',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...companies.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.business, size: 18, color: g.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(m['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(m['package_range']?.toString() ?? '',
                        style: TextStyle(
                            color: g.onSurfaceVariant, fontSize: 12.5)),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
        if (insights.isNotEmpty) _bullets(context, insights, icon: Icons.lightbulb_outline),
      ],
    );
  }

  static Widget _salary(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final s = (c['salary'] as Map?)?.cast<String, dynamic>() ?? c;
    final levels = ['fresher_level', '5years_level', '10years_level', '15years_level'];
    final tips = _strList(s['growth_tips']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...levels.where((k) => s[k] is Map).map((k) {
          final lv = (s[k] as Map).cast<String, dynamic>();
          return _subCard(context, 
            title: lv['experience']?.toString() ?? k,
            child: Text(lv['range']?.toString() ?? '',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: g.gold)),
          );
        }),
        if (tips.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('Growth tips', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _bullets(context, tips, icon: Icons.tips_and_updates_outlined),
        ],
      ],
    );
  }

  static Widget _certifications(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final list = _mapList(c['certifications']);
    return Column(
      children: list.map((m) {
        return _subCard(context, 
          title: m['name']?.toString() ?? '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m['provider']?.toString() ?? '',
                  style: TextStyle(
                      color: g.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (m['duration'] != null) InfoChip(label: '${m['duration']}'),
                if (m['cost'] != null) InfoChip(label: '${m['cost']}'),
                if (m['difficulty'] != null) InfoChip(label: '${m['difficulty']}'),
              ]),
              const SizedBox(height: 10),
              _linkButton(context, 'View course', m['link']?.toString() ?? ''),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget _experts(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final list = _mapList(c['experts']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _note(context,
            'Representative profiles — typical senior professionals in this field, not specific named individuals.'),
        ...list.map((m) {
        return _subCard(context,
          title: m['name']?.toString() ?? '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m['designation'] ?? ''}${m['company'] != null ? ', ${m['company']}' : ''}',
                style: TextStyle(
                    color: g.onSurfaceVariant, fontSize: 13),
              ),
              if (m['experience'] != null) ...[
                const SizedBox(height: 4),
                Text('${m['experience']} experience',
                    style: TextStyle(
                        color: g.onSurfaceVariant, fontSize: 12.5)),
              ],
              if (m['key_advice'] != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: g.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote,
                          size: 18, color: g.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(m['key_advice'].toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: g.onSurfaceVariant,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }),
      ],
    );
  }

  static Widget _generic(BuildContext context, Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    return Text(
      c.toString(),
      style: TextStyle(color: g.onSurfaceVariant, height: 1.4),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.index,
    required this.isLast,
    required this.phase,
    required this.duration,
    required this.description,
  });

  final int index;
  final bool isLast;
  final String phase;
  final String duration;
  final String description;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: g.gold,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$index',
                      style: TextStyle(
                          color: g.goldInk, fontWeight: FontWeight.w800)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                      width: 2,
                      color: g.gold.withValues(alpha: 0.25)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(phase,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      if (duration.isNotEmpty) InfoChip(label: duration),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(description,
                      style: TextStyle(
                          color: g.onSurfaceVariant, height: 1.45, fontSize: 13.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HiringChart extends StatelessWidget {
  const _HiringChart({required this.trends});
  final List<Map<String, dynamic>> trends;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final spots = <FlSpot>[];
    for (var i = 0; i < trends.length; i++) {
      final v = trends[i]['openings'];
      final y = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
      spots.add(FlSpot(i.toDouble(), y));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (trends.length / 4).ceilToDouble().clamp(1, 12),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= trends.length) return const SizedBox.shrink();
                final month = trends[i]['month']?.toString() ?? '';
                final short = month.length >= 3 ? month.substring(0, 3) : month;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short,
                      style: TextStyle(
                          color: g.onSurfaceVariant, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: g.gold,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: g.gold.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
