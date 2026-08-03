import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/career_recommendation.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../unlock_career_path_screen.dart';
import '../../theme/guidanzia_colors.dart';
import '../../widgets/tab_header.dart';

/// Browse popular career fields beyond the top-3 (search + category chips,
/// referencing the discovery screens in images 2/4/5). Tapping a field opens
/// the same AI report generator used for recommendations.
class ExploreTab extends ConsumerStatefulWidget {
  const ExploreTab({super.key});

  @override
  ConsumerState<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<ExploreTab> {
  String _category = 'All';
  String _query = '';

  static const _categories = [
    'All', 'Technology', 'Healthcare', 'Business', 'Creative', 'Science', 'Law'
  ];

  static const Map<String, List<String>> _fields = {
    'Technology': [
      'Software Engineer', 'Data Scientist', 'Cybersecurity Analyst',
      'AI/ML Engineer', 'Cloud Architect', 'Mobile App Developer',
    ],
    'Healthcare': [
      'Doctor (MBBS)', 'Dentist', 'Physiotherapist', 'Pharmacist',
      'Clinical Psychologist', 'Nursing',
    ],
    'Business': [
      'Chartered Accountant', 'Management Consultant', 'Digital Marketer',
      'Investment Banker', 'Product Manager', 'Entrepreneur',
    ],
    'Creative': [
      'UX/UI Designer', 'Graphic Designer', 'Content Creator',
      'Architect', 'Film Maker', 'Fashion Designer',
    ],
    'Science': [
      'Research Scientist', 'Biotechnologist', 'Environmental Scientist',
      'Data Analyst', 'Astrophysicist', 'Food Technologist',
    ],
    'Law': [
      'Corporate Lawyer', 'Civil Services (IAS)', 'Judge', 'Legal Advisor',
    ],
  };

  List<(String, String)> get _visible {
    final entries = <(String, String)>[];
    _fields.forEach((cat, roles) {
      if (_category != 'All' && _category != cat) return;
      for (final r in roles) {
        if (_query.isEmpty || r.toLowerCase().contains(_query.toLowerCase())) {
          entries.add((cat, r));
        }
      }
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final items = _visible;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        TabHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Explore careers',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Discover fields and generate an AI report for any of them.',
                  style: TextStyle(color: g.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search a career…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        FilterChips(
          options: _categories,
          selected: _category,
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('No matches found.',
                  style: TextStyle(color: g.onSurfaceVariant)),
            ),
          )
        else
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FieldTile(
                  category: e.$1,
                  title: e.$2,
                  onTap: () => _open(e.$2),
                ),
              )),
      ],
    );
  }

  void _open(String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UnlockCareerPathScreen(
        career: CareerRecommendation(
          title: title,
          description: 'Explore the full AI-generated career report for $title.',
          matchScore: 0,
        ),
      ),
    ));
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.category,
    required this.title,
    required this.onTap,
  });

  final String category;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: g.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.explore_outlined, color: g.gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(category,
                    style: TextStyle(
                        color: g.onSurfaceVariant, fontSize: 12.5)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 15, color: g.onSurfaceVariant),
        ],
      ),
    );
  }
}
