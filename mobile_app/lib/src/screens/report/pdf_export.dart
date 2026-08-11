import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/career_recommendation.dart';

/// Builds a clean PDF summary of a career report on-device and downloads it to
/// the device (Downloads), returning the saved path.
///
/// The PDF is generated client-side (reliable, works offline) from the sections
/// already fetched. The backend also exposes /api/generate-pdf (Playwright) as
/// an alternative once it is deployed with headless Chromium.
///
/// Renders every deep-dive section the user has opened. The [sections] map is
/// keyed by the local section-type strings used in section_renderers.dart, and
/// each value's JSON shape mirrors that renderer exactly (same keys/nesting).
class CareerPdfExport {
  /// Generates the PDF and saves it to the device. Returns the saved path.
  static Future<String> generateAndSave({
    required CareerRecommendation career,
    required Map<String, dynamic> sections,
  }) async {
    final doc = pw.Document();
    const brand = PdfColor.fromInt(0xFF283569); // Guidanzia navy

    // --- Defensive readers (mirror SectionRenderer._strList/_mapList) ---
    List<String> strList(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : const [];

    List<Map<String, dynamic>> mapList(dynamic v) => (v is List)
        ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const [];

    // Top-level section content (keyed by local section type).
    Map<String, dynamic>? topMap(String key) {
      final v = sections[key];
      return (v is Map) ? v.cast<String, dynamic>() : null;
    }

    // Mirror `(c['key'] as Map?)?.cast() ?? c` from the on-screen renderer.
    Map<String, dynamic> unwrap(Map<String, dynamic> c, String key) =>
        (c[key] is Map) ? (c[key] as Map).cast<String, dynamic>() : c;

    // --- Shared styles ---
    const body = pw.TextStyle(fontSize: 11, lineSpacing: 3);
    const small = pw.TextStyle(fontSize: 10.5, lineSpacing: 2);
    final bold11 =
        pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11);
    final muted =
        const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700);
    final linkStyle = const pw.TextStyle(
      fontSize: 10.5,
      color: PdfColor.fromInt(0xFF1565C0),
      decoration: pw.TextDecoration.underline,
    );

    pw.Widget heading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold, color: brand)),
        );

    pw.Widget subheading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
        );

    // A clickable hyperlink; emits nothing for a null/empty URL.
    pw.Widget link(String label, dynamic rawUrl) {
      final url = (rawUrl?.toString() ?? '').trim();
      if (url.isEmpty) return pw.SizedBox();
      var dest = url;
      if (!dest.startsWith('http://') && !dest.startsWith('https://')) {
        dest = 'https://$dest';
      }
      return pw.UrlLink(
        destination: dest,
        child: pw.Text(label, style: linkStyle),
      );
    }

    Iterable<pw.Widget> bullets(List<String> items) => items
        .where((t) => t.trim().isNotEmpty)
        .map((t) => pw.Bullet(text: t, style: small));

    pw.Widget card(String title, List<pw.Widget> children) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                pw.Text(title,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12)),
              if (title.isNotEmpty) pw.SizedBox(height: 4),
              ...children,
            ],
          ),
        );

    // --- Build the document body ---
    final content = <pw.Widget>[];

    // Header — Guidenzia navy banner.
    content.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: const pw.BoxDecoration(
          color: brand,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Guidenzia Career Report',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(career.title,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold)),
            if (career.matchScore > 0) ...[
              pw.SizedBox(height: 4),
              pw.Text('${career.matchScore}% profile match',
                  style: const pw.TextStyle(
                      color: PdfColors.white, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
    content.add(pw.SizedBox(height: 12));
    content.add(pw.Text(career.description, style: body));

    // ---- overview ----
    final ovTop = topMap('overview');
    if (ovTop != null) {
      final o = unwrap(ovTop, 'overview');
      content.add(heading('Overview'));
      final desc = o['role_description']?.toString() ?? '';
      if (desc.isNotEmpty) content.add(pw.Text(desc, style: body));
      final resp = strList(o['key_responsibilities']);
      if (resp.isNotEmpty) {
        content.add(pw.SizedBox(height: 8));
        content.add(pw.Text('Key responsibilities:', style: bold11));
        content.addAll(bullets(resp));
      }
      final why = o['why_suitable']?.toString() ?? '';
      if (why.isNotEmpty) {
        content.add(pw.SizedBox(height: 6));
        content.add(card('Why it suits you', [pw.Text(why, style: small)]));
      }
    }

    // ---- pathway ----
    final pwTop = topMap('pathway');
    if (pwTop != null) {
      final p = unwrap(pwTop, 'careerPathway');
      final steps = mapList(p['pathway']);
      if (steps.isNotEmpty) {
        content.add(heading('Academic Pathway'));
        for (var i = 0; i < steps.length; i++) {
          final m = steps[i];
          content.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${i + 1}. ${m['phase']?.toString() ?? ''}'
                    '${(m['duration']?.toString() ?? '').isNotEmpty ? '  (${m['duration']})' : ''}',
                    style: bold11,
                  ),
                  pw.Text(m['description']?.toString() ?? '', style: small),
                ],
              ),
            ),
          );
        }
      }
    }

    // ---- skills ----
    final skTop = topMap('skills');
    if (skTop != null) {
      final s = unwrap(skTop, 'skills');
      final groups = [
        ('high', 'Must-have skills'),
        ('medium', 'Core skills'),
        ('low', 'Bonus skills'),
      ];
      final anySkills = groups.any((g) => mapList(s[g.$1]).isNotEmpty);
      if (anySkills) content.add(heading('Skills to Learn'));
      for (final g in groups) {
        final items = mapList(s[g.$1]);
        if (items.isEmpty) continue;
        content.add(subheading(g.$2));
        for (final m in items) {
          content.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(m['name']?.toString() ?? '', style: bold11),
                  if ((m['description']?.toString() ?? '').isNotEmpty)
                    pw.Text(m['description'].toString(), style: small),
                  pw.SizedBox(height: 3),
                  pw.Wrap(spacing: 16, runSpacing: 4, children: [
                    link('Course', m['course_url']),
                    link('Video', m['video_url']),
                  ]),
                ],
              ),
            ),
          );
        }
      }
    }

    // ---- roadmap ----
    final rmTop = topMap('roadmap');
    if (rmTop != null) {
      final r = unwrap(rmTop, 'roadmap');
      content.add(heading('Learning Roadmap'));
      final ov = r['overview']?.toString() ?? '';
      if (ov.isNotEmpty) content.add(pw.Text(ov, style: body));
      for (final key in ['phase1', 'phase2', 'phase3']) {
        final p = (r[key] is Map) ? (r[key] as Map).cast<String, dynamic>() : null;
        if (p == null) continue;
        final children = <pw.Widget>[];
        final goals = strList(p['goals']);
        if (goals.isNotEmpty) {
          children.add(pw.Text('Goals', style: bold11));
          children.addAll(bullets(goals));
        }
        final tasks = strList(p['tasks']);
        if (tasks.isNotEmpty) {
          children.add(pw.Text('Tasks', style: bold11));
          children.addAll(bullets(tasks));
        }
        final prog = strList(p['progress_indicators']);
        if (prog.isNotEmpty) {
          children.add(pw.Text('Progress indicators', style: bold11));
          children.addAll(bullets(prog));
        }
        content.add(card(p['title']?.toString() ?? key, children));
      }
    }

    // ---- institute ----
    final inTop = topMap('institute');
    if (inTop != null) {
      final inst = unwrap(inTop, 'institutes');
      final groups = [
        ('government', 'Government'),
        ('private', 'Private'),
        ('distance', 'Distance learning'),
        ('online', 'Online'),
      ];
      final any = groups.any((g) => mapList(inst[g.$1]).isNotEmpty);
      if (any) content.add(heading('Institutes'));
      for (final g in groups) {
        final items = mapList(inst[g.$1]);
        if (items.isEmpty) continue;
        content.add(subheading(g.$2));
        for (final m in items) {
          final loc = m['location']?.toString() ?? '';
          final dept = m['department']?.toString() ?? '';
          final rating = m['rating'];
          final elig = m['eligibility']?.toString() ?? '';
          content.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${m['name']?.toString() ?? ''}'
                    '${rating != null ? '  ($rating*)' : ''}',
                    style: bold11,
                  ),
                  if (dept.isNotEmpty || loc.isNotEmpty)
                    pw.Text(
                      '$dept${loc.isNotEmpty ? '${dept.isNotEmpty ? ' · ' : ''}$loc' : ''}',
                      style: muted,
                    ),
                  if (elig.isNotEmpty)
                    pw.Text('Eligibility: $elig', style: small),
                  pw.SizedBox(height: 3),
                  link('Visit website', m['website']),
                ],
              ),
            ),
          );
        }
      }
    }

    // ---- fees ----
    final feTop = topMap('fees');
    if (feTop != null) {
      final f = unwrap(feTop, 'fees');
      content.add(heading('Fees & Costs'));
      final total = f['total_investment']?.toString() ?? '';
      if (total.isNotEmpty) {
        content.add(card('Estimated total investment', [
          pw.Text(total,
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold, color: brand)),
        ]));
      }
      for (final m in mapList(f['breakdown'])) {
        content.add(card(m['category']?.toString() ?? '', [
          pw.Text(
            '${m['range']?.toString() ?? ''}'
            '${(m['duration']?.toString() ?? '').isNotEmpty ? '  ·  ${m['duration']}' : ''}',
            style: small,
          ),
        ]));
      }
      final note = f['note']?.toString() ?? '';
      if (note.isNotEmpty) content.add(pw.Text(note, style: muted));
    }

    // ---- scholarships ----
    final scTop = topMap('scholarships');
    if (scTop != null) {
      final fs = unwrap(scTop, 'financial_support');
      final groups = [
        ('scholarships', 'Scholarships', 'amount', 'eligibility'),
        ('loans', 'Education loans', 'max_amount', 'interest_rate'),
        ('government_schemes', 'Government schemes', 'benefit', 'eligibility'),
      ];
      final any = groups.any((g) => mapList(fs[g.$1]).isNotEmpty);
      if (any) content.add(heading('Financial Support'));
      for (final g in groups) {
        final items = mapList(fs[g.$1]);
        if (items.isEmpty) continue;
        content.add(subheading(g.$2));
        for (final m in items) {
          final amount = m[g.$3]?.toString() ?? '';
          final sub = m[g.$4]?.toString() ?? '';
          content.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    m['name']?.toString() ?? m['provider']?.toString() ?? '',
                    style: bold11,
                  ),
                  if (amount.isNotEmpty || sub.isNotEmpty)
                    pw.Text(
                      '$amount${sub.isNotEmpty ? '${amount.isNotEmpty ? ' · ' : ''}$sub' : ''}',
                      style: muted,
                    ),
                  pw.SizedBox(height: 3),
                  link('Details', m['link']),
                ],
              ),
            ),
          );
        }
      }
    }

    // ---- jobmarket ----
    final jmTop = topMap('jobmarket');
    if (jmTop != null) {
      final j = unwrap(jmTop, 'jobmarket');
      content.add(heading('Job Market'));
      final demand = j['demand_percentage']?.toString();
      final success = j['success_rate']?.toString();
      final statLines = <String>[];
      if (demand != null && demand.isNotEmpty) statLines.add('Demand: $demand%');
      if (success != null && success.isNotEmpty) {
        statLines.add('Success rate: $success');
      }
      if (statLines.isNotEmpty) {
        content.add(pw.Text(statLines.join('    '), style: bold11));
      }
      final trends = mapList(j['hiring_trends']);
      if (trends.isNotEmpty) {
        content.add(subheading('Hiring trend (monthly openings)'));
        content.addAll(bullets(trends
            .map((m) =>
                '${m['month']?.toString() ?? ''}: ${m['openings']?.toString() ?? ''}')
            .toList()));
      }
      final companies = mapList(j['top_companies']);
      if (companies.isNotEmpty) {
        content.add(subheading('Top hiring companies'));
        content.addAll(bullets(companies
            .map((m) =>
                '${m['name']?.toString() ?? ''}'
                '${(m['package_range']?.toString() ?? '').isNotEmpty ? ' — ${m['package_range']}' : ''}')
            .toList()));
      }
      final insights = strList(j['key_insights']);
      if (insights.isNotEmpty) {
        content.add(subheading('Key insights'));
        content.addAll(bullets(insights));
      }
    }

    // ---- salary ----
    final saTop = topMap('salary');
    if (saTop != null) {
      final s = unwrap(saTop, 'salary');
      content.add(heading('Salary Growth'));
      for (final k in [
        'fresher_level',
        '5years_level',
        '10years_level',
        '15years_level'
      ]) {
        if (s[k] is! Map) continue;
        final lv = (s[k] as Map).cast<String, dynamic>();
        content.add(pw.Text(
          '${lv['experience']?.toString() ?? k}: ${lv['range']?.toString() ?? ''}',
          style: body,
        ));
      }
      final tips = strList(s['growth_tips']);
      if (tips.isNotEmpty) {
        content.add(subheading('Growth tips'));
        content.addAll(bullets(tips));
      }
    }

    // ---- certifications ----
    final ceTop = topMap('certifications');
    if (ceTop != null) {
      final list = mapList(ceTop['certifications']);
      if (list.isNotEmpty) {
        content.add(heading('Certifications'));
        for (final m in list) {
          final chips = <String>[];
          if (m['duration'] != null) chips.add(m['duration'].toString());
          if (m['cost'] != null) chips.add(m['cost'].toString());
          if (m['difficulty'] != null) chips.add(m['difficulty'].toString());
          content.add(card(m['name']?.toString() ?? '', [
            if ((m['provider']?.toString() ?? '').isNotEmpty)
              pw.Text(m['provider'].toString(), style: muted),
            if (chips.isNotEmpty) pw.Text(chips.join('  ·  '), style: small),
            pw.SizedBox(height: 3),
            link('View course', m['link']),
          ]));
        }
      }
    }

    // ---- experts ----
    final exTop = topMap('experts');
    if (exTop != null) {
      final list = mapList(exTop['experts']);
      if (list.isNotEmpty) {
        content.add(heading('Expert Advice'));
        for (final m in list) {
          final desig = m['designation']?.toString() ?? '';
          final company = m['company']?.toString() ?? '';
          final exp = m['experience']?.toString() ?? '';
          final advice = m['key_advice']?.toString() ?? '';
          content.add(card(m['name']?.toString() ?? '', [
            if (desig.isNotEmpty || company.isNotEmpty)
              pw.Text(
                '$desig${company.isNotEmpty ? '${desig.isNotEmpty ? ', ' : ''}$company' : ''}',
                style: muted,
              ),
            if (exp.isNotEmpty)
              pw.Text('$exp experience', style: small),
            if (advice.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('"$advice"',
                  style: const pw.TextStyle(
                      fontSize: 10.5,
                      fontStyle: pw.FontStyle.italic,
                      lineSpacing: 2)),
            ],
          ]));
        }
      }
    }

    // Footer disclaimer.
    content.add(pw.SizedBox(height: 20));
    content.add(pw.Divider());
    content.add(pw.Text(
      'Generated by Guidenzia · AI-powered career guidance. Figures are AI estimates for the Indian market.',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => content,
      ),
    );

    final safe = career.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    final bytes = await doc.save();
    // Saves to the device's Downloads (via MediaStore on Android) and returns
    // the saved file path.
    final path = await FileSaver.instance.saveFile(
      name: 'Guidenzia-Career-Report-$safe',
      bytes: bytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
    return path;
  }
}
