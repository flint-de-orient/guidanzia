import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/onboarding_data.dart';
import '../router/app_routes.dart';
import '../state/providers.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/guidanzia_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/common_widgets.dart';
import '../theme/guidanzia_colors.dart';

/// Stage 0 — collects the basic student profile before the assessment.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _district = TextEditingController();
  final _mobile = TextEditingController();
  String? _classLevel;
  String? _board;
  bool _consent = false;
  bool _loading = false;
  String? _error;

  // Values match the web Stage 0 exactly.
  static const _classLevels = {
    '9': 'Class 9',
    '10': 'Class 10',
    '11': 'Class 11',
    '12': 'Class 12',
    'graduated': 'Graduate',
  };
  static const _boards = {
    'cbse': 'CBSE',
    'icse': 'ICSE',
    'state': 'State Board',
    'ib': 'IB',
    'other': 'Other',
  };

  bool get _isValid =>
      _name.text.trim().isNotEmpty &&
      _classLevel != null &&
      _board != null &&
      _district.text.trim().isNotEmpty &&
      _mobile.text.length == 10 &&
      _consent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assessmentStatusProvider.notifier).enter(AssessmentStage.onboarding);
    });
    _prefill();
  }

  /// Returning users see their saved basic info pre-loaded, awaiting
  /// confirmation (mirrors the web onboarding-new behavior). New users get a
  /// blank form.
  Future<void> _prefill() async {
    final username = ref.read(authProvider).user?.username;
    if (username == null) return;
    try {
      final data = await ref.read(apiClientProvider).getOnboarding(username);
      if (data == null || !mounted) return;
      setState(() {
        if (data.name.isNotEmpty) _name.text = data.name;
        if (data.district.isNotEmpty) _district.text = data.district;
        if (data.parentMobile.isNotEmpty) _mobile.text = data.parentMobile;
        if (_classLevels.containsKey(data.classLevel)) {
          _classLevel = data.classLevel;
        }
        if (_boards.containsKey(data.board)) _board = data.board;
      });
    } catch (_) {
      // New user or offline — leave the form blank.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _district.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _classLevel == null || _board == null) {
      setState(() => _error = 'Please fill in your name, class and board.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final username = ref.read(authProvider).user!.username;
    final data = OnboardingData(
      name: _name.text.trim(),
      classLevel: _classLevel!,
      board: _board!,
      district: _district.text.trim(),
      parentMobile: _mobile.text.trim(),
    );
    try {
      await ref.read(apiClientProvider).saveOnboarding(username, data);
      if (mounted) Navigator.of(context).pushNamed(Routes.questionnaire);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Scaffold(
      appBar: const GuidanziaAppBar(title: 'Tell us about you'),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepDots(current: 0, total: 3),
                const SizedBox(height: 20),
                const Text(
                  'Your profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'This helps us tailor career paths to your stage of study.',
                  style: TextStyle(color: g.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Full name'),
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'e.g. Ananya Sharma',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Current education level'),
                      _Dropdown(
                        value: _classLevel,
                        hint: 'Select your class / level',
                        items: _classLevels.entries
                            .map((e) =>
                                DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _classLevel = v),
                      ),
                      const SizedBox(height: 16),
                      _label('Board'),
                      _Dropdown(
                        value: _board,
                        hint: 'Select your board',
                        items: _boards.entries
                            .map((e) =>
                                DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _board = v),
                      ),
                      const SizedBox(height: 16),
                      _label('District'),
                      TextField(
                        controller: _district,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'e.g. Kolkata',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label("Parent's mobile number"),
                      TextField(
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          hintText: '10-digit mobile number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ConsentBox(
                        checked: _consent,
                        onChanged: (v) => setState(() => _consent = v),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        ErrorBanner(_error!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Continue to Questions',
                  icon: Icons.arrow_forward_rounded,
                  loading: _loading,
                  onPressed: (_isValid && !_loading) ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    final g = Theme.of(context).guidanzia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.w600, color: g.onSurface)),
    );
  }
}

/// Required DPDP parental-consent block (matches the web onboarding).
class _ConsentBox extends StatelessWidget {
  const _ConsentBox({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: g.gold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: g.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: g.gold,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 15, color: g.gold),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('Data Consent (Required for minors)',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: g.onSurface)),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'I consent to share my data with my parent/guardian for career '
                    'guidance purposes as per DPDP Act compliance.',
                    style: TextStyle(color: g.onSurfaceVariant, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(hint, style: TextStyle(color: g.onSurfaceVariant)),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: items,
      onChanged: onChanged,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.school_outlined),
      ),
    );
  }
}

/// Small step indicator dots used across the assessment flow.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        return Container(
          margin: const EdgeInsets.only(right: 8),
          height: 6,
          width: active ? 28 : 14,
          decoration: BoxDecoration(
            color: active ? g.gold : g.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
