import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/career_recommendation.dart';
import '../state/providers.dart';
import '../theme/app_gradients.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dossier_navigator.dart';
import '../widgets/theme_toggle.dart';
import 'report/section_renderers.dart';
import 'report/pdf_export.dart';
import '../theme/guidanzia_colors.dart';

/// Full AI career report ("Role Deep-Dive"), recomposed to the app mockup:
/// a hero with a match ring, a sticky-style section pill nav, glass section
/// cards, and a floating "Export Full Report (PDF)" button. Each section still
/// lazily fetches its content from /api/career-details on first open (avoids
/// ~11 slow AI calls up front).
class RoleDetailScreen extends ConsumerStatefulWidget {
  const RoleDetailScreen({super.key, required this.career});
  final CareerRecommendation career;

  @override
  ConsumerState<RoleDetailScreen> createState() => _RoleDetailScreenState();
}

class _RoleDetailScreenState extends ConsumerState<RoleDetailScreen> {
  Map<String, dynamic> _profile = {};
  final Map<String, Map<String, dynamic>> _loaded = {};

  static const _sections = <({String type, String title, IconData icon})>[
    (type: 'overview', title: 'Overview', icon: Icons.person_search_outlined),
    (type: 'pathway', title: 'Pathway', icon: Icons.route_outlined),
    (type: 'skills', title: 'Skills', icon: Icons.psychology_outlined),
    (type: 'roadmap', title: '90-Day Plan', icon: Icons.map_outlined),
    (type: 'institute', title: 'Institutes', icon: Icons.account_balance_outlined),
    (type: 'fees', title: 'Fees', icon: Icons.payments_outlined),
    (type: 'scholarships', title: 'Scholarships', icon: Icons.volunteer_activism_outlined),
    (type: 'jobmarket', title: 'Market', icon: Icons.insights_outlined),
    (type: 'salary', title: 'Salary', icon: Icons.trending_up_rounded),
    (type: 'certifications', title: 'Certifications', icon: Icons.workspace_premium_outlined),
    (type: 'experts', title: 'Experts', icon: Icons.groups_outlined),
  ];

  final Map<String, GlobalKey> _anchorKeys = {
    for (final s in _sections) s.type: GlobalKey(),
  };
  final Map<String, GlobalKey<_SectionCardState>> _cardKeys = {
    for (final s in _sections) s.type: GlobalKey<_SectionCardState>(),
  };

  /// Mobile section type -> the backend's camelCase key in `job_role_details`.
  static const _serverKey = {
    'overview': 'overview',
    'pathway': 'careerPathway',
    'skills': 'skillsLearning',
    'roadmap': 'roadmap90Days',
    'institute': 'topInstitutes',
    'fees': 'feesInvestment',
    'scholarships': 'scholarships',
    'jobmarket': 'jobMarket',
    'salary': 'salaryGrowth',
    'certifications': 'certifications',
    'experts': 'industryExperts',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1) Reuse anything the server already generated for this role (cheap DB
    //    read) so we never re-run slow AI calls for content we already have.
    await _restoreCachedSections();
    // 2) Build the profile needed to generate any *missing* sections.
    await _buildProfile();
    if (!mounted) return;
    setState(() {});
    // 3) Open Overview by default — instant if it came from the cache.
    _cardKeys['overview']?.currentState?.expand();
  }

  Future<void> _restoreCachedSections() async {
    final username = ref.read(authProvider).user?.username;
    if (username == null) return;
    try {
      final detail = await ref.read(apiClientProvider).loadJobRole(
            username: username,
            roleId: widget.career.roleId,
          );
      if (detail == null) return;
      _serverKey.forEach((local, server) {
        final v = detail[server];
        if (v is Map) _loaded[local] = v.cast<String, dynamic>();
      });
    } catch (_) {
      // No cache / unreachable — fall back to generating on demand.
    }
  }

  /// Push the sections we have back to the server so they survive app restarts.
  Future<void> _persistSections() async {
    final username = ref.read(authProvider).user?.username;
    if (username == null || _loaded.isEmpty) return;
    final detailData = <String, dynamic>{};
    _serverKey.forEach((local, server) {
      final v = _loaded[local];
      if (v != null) detailData[server] = v;
    });
    if (detailData.isEmpty) return;
    try {
      await ref.read(apiClientProvider).saveJobRole(
            username: username,
            roleId: widget.career.roleId,
            roleTitle: widget.career.title,
            detailData: detailData,
          );
    } catch (_) {
      // Caching is best-effort — never block the user on it.
    }
  }

  Future<void> _buildProfile() async {
    final q = ref.read(questionnaireProvider);
    final username = ref.read(authProvider).user?.username;
    final profile = <String, dynamic>{
      ...q.userProfile,
      'careerInterest': widget.career.title,
    };
    if (username != null) {
      try {
        final onboarding = await ref.read(apiClientProvider).getOnboarding(username);
        if (onboarding != null) {
          profile['education'] = onboarding.classLevel;
          profile['name'] = onboarding.name;
        }
      } catch (_) {/* profile stays minimal */}
    }
    if (mounted) setState(() => _profile = profile);
  }

  Future<Map<String, dynamic>> _loadSection(String type) async {
    // Cache hit (in-memory or restored from the server) — no AI call needed.
    if (_loaded.containsKey(type)) return _loaded[type]!;
    final content = await ref.read(apiClientProvider).getCareerSection(
          careerTitle: widget.career.title,
          sectionType: type,
          profile: _profile,
        );
    _loaded[type] = content;
    // Best-effort: persist so this section is never regenerated again.
    unawaited(_persistSections());
    return content;
  }

  void _goToSection(String type) {
    // Collapse any other open section so the jump lands cleanly on the target,
    // then expand it. (The section list is built non-lazily, so every card's
    // key is live even when the target is currently off-screen.)
    for (final s in _sections) {
      if (s.type != type) _cardKeys[s.type]?.currentState?.collapse();
    }
    _cardKeys[type]?.currentState?.expand();
    // Scroll after the collapse/expand cross-fades settle so we land on target.
    Future.delayed(const Duration(milliseconds: 260), () {
      final ctx = _anchorKeys[type]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.02,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Scaffold(
      backgroundColor: g.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: g.surface,
            surfaceTintColor: Colors.transparent,
            leading: const BackButton(),
            title: const Text('Career Deep-Dive'),
            centerTitle: true,
            actions: const [ThemeToggle(), SizedBox(width: 8)],
          ),
          SliverToBoxAdapter(child: _header()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            // A single Column (inside a box adapter) rather than a SliverList so
            // ALL section cards are truly built at once — a SliverList still
            // lazily instantiates elements near the viewport, leaving off-screen
            // cards' GlobalKeys null, which is why the floating navigator could
            // scroll to a section but not expand it. Collapsed cards are cheap
            // (their body is an empty box until opened), so building all 11 is
            // fine and keeps every card's State live for the jump-to logic.
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  for (var i = 0; i < _sections.length; i++) ...[
                    KeyedSubtree(
                      key: _anchorKeys[_sections[i].type],
                      child: _SectionCard(
                        key: _cardKeys[_sections[i].type],
                        title: _sections[i].title,
                        icon: _sections[i].icon,
                        type: _sections[i].type,
                        loader: _loadSection,
                      ),
                    ),
                    if (i != _sections.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: DossierNavigator(
        sections: [
          for (final s in _sections)
            DossierSection(type: s.type, title: s.title, icon: s.icon),
        ],
        onSelect: _goToSection,
      ),
      bottomNavigationBar: _ExportBar(onTap: _exportPdf),
    );
  }

  // ------------------------------------------------------------------ header
  Widget _header() {
    final c = widget.career;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 28, offset: Offset(0, 16)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars_rounded, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text('PREMIUM PATH ANALYSIS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                    const SizedBox(height: 10),
                    Text(c.description,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.45, fontSize: 13.5)),
                  ],
                ),
              ),
              if (c.matchScore > 0) ...[
                const SizedBox(width: 12),
                _MatchRing(score: c.matchScore),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              _HeaderPill(icon: Icons.auto_awesome, label: 'AI-generated'),
              SizedBox(width: 10),
              _HeaderPill(icon: Icons.place_outlined, label: 'India-focused'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final wanted = ['overview', 'pathway', 'skills', 'salary'];
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      for (final t in wanted) {
        await _loadSection(t);
      }
      final path = await CareerPdfExport.generateAndSave(
        career: widget.career,
        sections: _loaded,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Report downloaded to Downloads\n$path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save PDF: $e')),
        );
      }
    }
  }
}

class _MatchRing extends StatelessWidget {
  const _MatchRing({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: score.clamp(0, 100) / 100,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.0)),
              const Text('MATCH',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: g.gold.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf_rounded, color: g.goldInk, size: 20),
                const SizedBox(width: 10),
                Text('Export Full Report (PDF)',
                    style: TextStyle(
                        color: g.goldInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expandable section card that lazily loads its AI content on first open.
class _SectionCard extends StatefulWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.type,
    required this.loader,
  });

  final String title;
  final IconData icon;
  final String type;
  final Future<Map<String, dynamic>> Function(String type) loader;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;
  bool _loading = false;
  Object? _error;
  Map<String, dynamic>? _content;

  /// Called by the floating navigator to open this section.
  void expand() {
    if (!_expanded) _toggle();
  }

  /// Collapse this section (used when jumping to a different one).
  void collapse() {
    if (_expanded) _toggle();
  }

  Future<void> _toggle() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _content == null && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final c = await widget.loader(widget.type);
        if (mounted) setState(() => _content = c);
      } catch (e) {
        if (mounted) setState(() => _error = e);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await widget.loader(widget.type);
      if (mounted) setState(() => _content = c);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: g.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: g.outline),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: g.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: g.gold, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15.5)),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: g.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: _body(),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingState(message: 'Generating with AI…'),
      );
    }
    if (_error != null) {
      return ErrorStateView(
        message: 'Could not generate this section.\n$_error',
        onRetry: _retry,
      );
    }
    if (_content != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),
          SectionRenderer.build(context, widget.type, _content!),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
