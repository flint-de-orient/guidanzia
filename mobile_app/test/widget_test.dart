// Smoke test: the app boots and shows the landing hero CTA.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edubot_mobile/main.dart';

void main() {
  testWidgets('Landing screen renders Get Started CTA', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EduBotApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
