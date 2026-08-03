import 'package:flutter/material.dart';
import '../theme/app_gradients.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/guidanzia_app_bar.dart';
import '../widgets/primary_button.dart';
import '../theme/guidanzia_colors.dart';

/// Visual-only premium/paywall placeholder (no real gateway wired for v1).
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  static const _perks = [
    ('Unlimited AI career reports', Icons.all_inclusive_rounded),
    ('1:1 mentor guidance sessions', Icons.support_agent_rounded),
    ('Downloadable PDF reports', Icons.picture_as_pdf_rounded),
    ('Priority updated job-market data', Icons.trending_up_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Scaffold(
      appBar: const GuidanziaAppBar(title: 'Guidenzia Premium'),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppGradients.hero,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x55283569),
                        blurRadius: 26,
                        offset: Offset(0, 12)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('30% OFF · FIRST YEAR',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Go Premium',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('₹499',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800)),
                        SizedBox(width: 6),
                        Padding(
                          padding: EdgeInsets.only(bottom: 5),
                          child: Text('/ year',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text("What's included",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  children: [
                    for (var i = 0; i < _perks.length; i++) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: g.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_perks[i].$2,
                                color: g.gold, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(_perks[i].$1,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          Icon(Icons.check_circle,
                              color: g.cyan, size: 20),
                        ],
                      ),
                      if (i != _perks.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Upgrade now',
                icon: Icons.lock_open_rounded,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                          'Payments are a visual preview in this version.'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('Preview only — no payment is taken.',
                    style:
                        TextStyle(color: g.onSurfaceVariant, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
