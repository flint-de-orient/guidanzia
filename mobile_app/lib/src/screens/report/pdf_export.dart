import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart' show rootBundle;
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
///
/// This is a presentation upgrade over the earlier plain-text export: a branded
/// cover page, navy section headers, data tables with shaded rows, and simple
/// charts drawn with `pdf` primitives (no external chart libraries in the PDF).
class CareerPdfExport {
  // Brand palette.
  static const PdfColor _navy = PdfColor.fromInt(0xFF283569); // Guidenzia navy
  static const PdfColor _gold = PdfColor.fromInt(0xFFC9A227); // gold accent
  static const PdfColor _rowAlt = PdfColor.fromInt(0xFFF2F3F7); // subtle shade
  static const PdfColor _hairline = PdfColor.fromInt(0xFFD9DCE6);

  /// Generates the PDF, saves it to the device's Downloads, and returns both the
  /// saved [path] and the raw [bytes] (so the caller can offer an Open/Share
  /// sheet without re-reading the file).
  static Future<({String path, Uint8List bytes})> generateAndSave({
    required CareerRecommendation career,
    required Map<String, dynamic> sections,
  }) async {
    final doc = pw.Document();

    // Brand logo watermark, drawn faint behind every content page. Best-effort:
    // if the asset can't load, the watermark is simply omitted.
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/images/gnz_logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }
    pw.Widget watermark() => logo == null
        ? pw.SizedBox()
        : pw.Center(
            child: pw.Opacity(
              opacity: 0.05,
              child: pw.Image(logo, width: 360),
            ),
          );

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

    // --- Shared text styles ---
    const body = pw.TextStyle(fontSize: 11, lineSpacing: 3);
    const small = pw.TextStyle(fontSize: 10, lineSpacing: 2);
    const cell = pw.TextStyle(fontSize: 9.5, lineSpacing: 1.5);
    final cellBold =
        pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold);
    final bold11 = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11);
    final muted = const pw.TextStyle(fontSize: 10, color: PdfColors.grey700);
    final linkStyle = const pw.TextStyle(
      fontSize: 9.5,
      color: PdfColor.fromInt(0xFF1565C0),
      decoration: pw.TextDecoration.underline,
    );

    // A clickable hyperlink; emits an empty box for a null/empty URL.
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

    // Branded section header: navy bar, gold accent tick, white title.
    pw.Widget sectionHeader(String title) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 18, bottom: 10),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 4,
                height: 15,
                margin: const pw.EdgeInsets.only(right: 9),
                color: _gold,
              ),
              pw.Text(
                title,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        );

    pw.Widget subheading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 5),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy)),
        );

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

    // Cell padding used across all tables.
    const cellPad = pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5);

    // A branded data table: navy header row, alternating body shading.
    // [rows] are pre-built widgets so cells can hold links as well as text.
    pw.Widget dataTable(
      List<String> headers,
      List<List<pw.Widget>> rows, {
      List<double>? weights,
    }) {
      Map<int, pw.TableColumnWidth>? widths;
      if (weights != null && weights.length == headers.length) {
        widths = {
          for (var i = 0; i < weights.length; i++)
            i: pw.FlexColumnWidth(weights[i]),
        };
      }
      return pw.Table(
        border: pw.TableBorder.all(color: _hairline, width: 0.5),
        columnWidths: widths,
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _navy),
            children: headers
                .map((h) => pw.Padding(
                      padding: cellPad,
                      child: pw.Text(h,
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold)),
                    ))
                .toList(),
          ),
          for (var i = 0; i < rows.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: i.isOdd ? _rowAlt : PdfColors.white),
              children: rows[i]
                  .map((w) => pw.Padding(padding: cellPad, child: w))
                  .toList(),
            ),
        ],
      );
    }

    pw.Widget txt(String s) => pw.Text(s, style: cell);
    pw.Widget txtBold(String s) => pw.Text(s, style: cellBold);

    // A horizontal progress gauge (0-100) for demand percentage.
    pw.Widget gauge(String label, double pct) {
      final v = pct.clamp(0, 100).toDouble();
      final filled = v.round();
      final rest = 100 - filled;
      pw.Widget barFill;
      if (filled <= 0) {
        barFill = pw.SizedBox();
      } else if (rest <= 0) {
        barFill = pw.Container(color: _gold);
      } else {
        barFill = pw.Row(children: [
          pw.Expanded(flex: filled, child: pw.Container(color: _gold)),
          pw.Expanded(flex: rest, child: pw.SizedBox()),
        ]);
      }
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: bold11),
              pw.Text('${v.toStringAsFixed(0)}%',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Container(
            height: 16,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: barFill,
            ),
          ),
        ],
      );
    }

    // A simple bar chart for the 12-month hiring trend, drawn with primitives.
    pw.Widget barChart(List<Map<String, dynamic>> trends) {
      final data = trends.map((m) {
        final v = m['openings'];
        final y = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
        final month = m['month']?.toString() ?? '';
        final short = month.length >= 3 ? month.substring(0, 3) : month;
        return (label: short, value: y < 0 ? 0.0 : y);
      }).toList();
      final maxV =
          data.map((d) => d.value).fold<double>(0, (a, b) => b > a ? b : a);
      const chartH = 120.0;
      return pw.Container(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: data.map((d) {
            final h = maxV > 0 ? (d.value / maxV) * chartH : 0.0;
            return pw.Expanded(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(d.value.toInt().toString(),
                      style: const pw.TextStyle(fontSize: 6.5)),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    height: h < 1 ? 1 : h,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                    decoration: pw.BoxDecoration(
                      color: _gold,
                      borderRadius: const pw.BorderRadius.vertical(
                          top: pw.Radius.circular(2)),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(d.label,
                      style: const pw.TextStyle(
                          fontSize: 6.5, color: PdfColors.grey700)),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    // --- Build the flowing content body ---
    final content = <pw.Widget>[];

    // Each section builds atomically: if one throws, it is skipped whole so a
    // single malformed section can never abort the entire document.
    void section(List<pw.Widget> Function() build) {
      try {
        content.addAll(build());
      } catch (_) {/* skip malformed section */}
    }

    // ---- overview ----
    section(() {
      final top = topMap('overview');
      if (top == null) return const <pw.Widget>[];
      final o = unwrap(top, 'overview');
      final out = <pw.Widget>[sectionHeader('Overview')];
      final desc = o['role_description']?.toString() ?? '';
      if (desc.isNotEmpty) out.add(pw.Text(desc, style: body));
      final resp = strList(o['key_responsibilities']);
      if (resp.isNotEmpty) {
        out.add(pw.SizedBox(height: 8));
        out.add(pw.Text('Key responsibilities', style: bold11));
        out.addAll(bullets(resp));
      }
      final why = o['why_suitable']?.toString() ?? '';
      if (why.isNotEmpty) {
        out.add(pw.SizedBox(height: 6));
        out.add(card('Why it suits you', [pw.Text(why, style: small)]));
      }
      return out.length > 1 ? out : const <pw.Widget>[];
    });

    // ---- pathway (table: # / Phase / Duration / Description) ----
    section(() {
      final top = topMap('pathway');
      if (top == null) return const <pw.Widget>[];
      final p = unwrap(top, 'careerPathway');
      final steps = mapList(p['pathway']);
      if (steps.isEmpty) return const <pw.Widget>[];
      final rows = <List<pw.Widget>>[];
      for (var i = 0; i < steps.length; i++) {
        final m = steps[i];
        rows.add([
          txtBold('${i + 1}'),
          txtBold(m['phase']?.toString() ?? ''),
          txt(m['duration']?.toString() ?? ''),
          txt(m['description']?.toString() ?? ''),
        ]);
      }
      return [
        sectionHeader('Academic Pathway'),
        dataTable(
          const ['#', 'Phase', 'Duration', 'Description'],
          rows,
          weights: const [0.5, 2.2, 1.4, 4.4],
        ),
      ];
    });

    // ---- skills ----
    section(() {
      final top = topMap('skills');
      if (top == null) return const <pw.Widget>[];
      final s = unwrap(top, 'skills');
      final groups = [
        ('high', 'Must-have skills'),
        ('medium', 'Core skills'),
        ('low', 'Bonus skills'),
      ];
      if (!groups.any((g) => mapList(s[g.$1]).isNotEmpty)) {
        return const <pw.Widget>[];
      }
      final out = <pw.Widget>[sectionHeader('Skills to Learn')];
      for (final g in groups) {
        final items = mapList(s[g.$1]);
        if (items.isEmpty) continue;
        out.add(subheading(g.$2));
        final rows = items
            .map<List<pw.Widget>>((m) => [
                  txtBold(m['name']?.toString() ?? ''),
                  txt(m['description']?.toString() ?? ''),
                  pw.Wrap(spacing: 10, runSpacing: 3, children: [
                    link('Course', m['course_url']),
                    link('Video', m['video_url']),
                  ]),
                ])
            .toList();
        out.add(dataTable(
          const ['Skill', 'Description', 'Learn'],
          rows,
          weights: const [2, 4, 1.6],
        ));
      }
      return out;
    });

    // ---- roadmap ----
    section(() {
      final top = topMap('roadmap');
      if (top == null) return const <pw.Widget>[];
      final r = unwrap(top, 'roadmap');
      final out = <pw.Widget>[sectionHeader('Learning Roadmap')];
      final ov = r['overview']?.toString() ?? '';
      if (ov.isNotEmpty) out.add(pw.Text(ov, style: body));
      var added = false;
      for (final key in ['phase1', 'phase2', 'phase3']) {
        final p =
            (r[key] is Map) ? (r[key] as Map).cast<String, dynamic>() : null;
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
        out.add(card(p['title']?.toString() ?? key, children));
        added = true;
      }
      return (added || ov.isNotEmpty) ? out : const <pw.Widget>[];
    });

    // ---- institutes (single combined table with a Type column) ----
    section(() {
      final top = topMap('institute');
      if (top == null) return const <pw.Widget>[];
      final inst = unwrap(top, 'institutes');
      final groups = [
        ('government', 'Government'),
        ('private', 'Private'),
        ('distance', 'Distance'),
        ('online', 'Online'),
      ];
      final rows = <List<pw.Widget>>[];
      for (final g in groups) {
        for (final m in mapList(inst[g.$1])) {
          final rating = m['rating'];
          rows.add([
            txt(g.$2),
            txtBold(m['name']?.toString() ?? ''),
            txt(m['location']?.toString() ?? ''),
            txt(m['department']?.toString() ?? ''),
            txt(rating != null ? '$rating' : ''),
            txt(m['eligibility']?.toString() ?? ''),
          ]);
        }
      }
      if (rows.isEmpty) return const <pw.Widget>[];
      return [
        sectionHeader('Top Institutes'),
        dataTable(
          const [
            'Type',
            'Name',
            'Location',
            'Department',
            'Rating',
            'Eligibility'
          ],
          rows,
          weights: const [1.2, 2.4, 1.7, 2.1, 0.9, 2.4],
        ),
      ];
    });

    // ---- fees (prominent total + breakdown table) ----
    section(() {
      final top = topMap('fees');
      if (top == null) return const <pw.Widget>[];
      final f = unwrap(top, 'fees');
      final out = <pw.Widget>[sectionHeader('Fees & Investment')];
      final total = f['total_investment']?.toString() ?? '';
      if (total.isNotEmpty) {
        out.add(pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFBF6E7),
            border: pw.Border.all(color: _gold, width: 1),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(children: [
            pw.Text('Estimated total investment', style: muted),
            pw.SizedBox(height: 4),
            pw.Text(total,
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy)),
          ]),
        ));
      }
      final rows = mapList(f['breakdown'])
          .map<List<pw.Widget>>((m) => [
                txtBold(m['category']?.toString() ?? ''),
                txt(m['range']?.toString() ?? ''),
                txt(m['duration']?.toString() ?? ''),
              ])
          .toList();
      if (rows.isNotEmpty) {
        out.add(dataTable(
          const ['Category', 'Range', 'Duration'],
          rows,
          weights: const [3, 3, 2],
        ));
      }
      final note = f['note']?.toString() ?? '';
      if (note.isNotEmpty) {
        out.add(pw.SizedBox(height: 6));
        out.add(pw.Text(note, style: muted));
      }
      return out.length > 1 ? out : const <pw.Widget>[];
    });

    // ---- scholarships / loans / government schemes (a table each) ----
    section(() {
      final top = topMap('scholarships');
      if (top == null) return const <pw.Widget>[];
      final fs = unwrap(top, 'financial_support');
      // (key, title, amountHeader, amountKey, subHeader, subKey)
      final groups = [
        ('scholarships', 'Scholarships', 'Amount', 'amount', 'Eligibility',
            'eligibility'),
        ('loans', 'Education Loans', 'Max amount', 'max_amount',
            'Interest rate', 'interest_rate'),
        ('government_schemes', 'Government Schemes', 'Benefit', 'benefit',
            'Eligibility', 'eligibility'),
      ];
      if (!groups.any((g) => mapList(fs[g.$1]).isNotEmpty)) {
        return const <pw.Widget>[];
      }
      final out = <pw.Widget>[sectionHeader('Financial Support')];
      for (final g in groups) {
        final items = mapList(fs[g.$1]);
        if (items.isEmpty) continue;
        out.add(subheading(g.$2));
        final rows = items
            .map<List<pw.Widget>>((m) => [
                  txtBold(m['name']?.toString() ??
                      m['provider']?.toString() ??
                      ''),
                  txt(m[g.$4]?.toString() ?? ''),
                  txt(m[g.$6]?.toString() ?? ''),
                  link('Details', m['link']),
                ])
            .toList();
        out.add(dataTable(
          ['Name', g.$3, g.$5, 'Link'],
          rows,
          weights: const [2.6, 2, 3, 1.1],
        ));
      }
      return out.length > 1 ? out : const <pw.Widget>[];
    });

    // ---- jobmarket (gauge + bar chart + companies table + insights) ----
    section(() {
      final top = topMap('jobmarket');
      if (top == null) return const <pw.Widget>[];
      final j = unwrap(top, 'jobmarket');
      final out = <pw.Widget>[sectionHeader('Job Market')];

      // Demand gauge.
      final demandRaw = j['demand_percentage'];
      final demand = (demandRaw is num)
          ? demandRaw.toDouble()
          : double.tryParse('${demandRaw ?? ''}');
      final success = j['success_rate']?.toString() ?? '';
      if (demand != null) {
        out.add(gauge('Market demand', demand));
      }
      if (success.isNotEmpty) {
        out.add(pw.SizedBox(height: 6));
        out.add(pw.Text('Success rate: $success', style: bold11));
      }

      // Hiring-trend bar chart.
      final trends = mapList(j['hiring_trends']);
      if (trends.isNotEmpty) {
        out.add(subheading('Hiring trend (monthly openings)'));
        out.add(pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(4, 6, 4, 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: barChart(trends),
        ));
      }

      // Top companies table.
      final companies = mapList(j['top_companies']);
      if (companies.isNotEmpty) {
        out.add(subheading('Top hiring companies'));
        final rows = companies
            .map<List<pw.Widget>>((m) => [
                  txtBold(m['name']?.toString() ?? ''),
                  txt(m['type']?.toString() ?? ''),
                  txt(m['hiring_frequency']?.toString() ?? ''),
                  txt(m['package_range']?.toString() ?? ''),
                ])
            .toList();
        out.add(dataTable(
          const ['Company', 'Type', 'Hiring frequency', 'Package range'],
          rows,
          weights: const [2.6, 1.8, 2.2, 2.4],
        ));
      }

      final insights = strList(j['key_insights']);
      if (insights.isNotEmpty) {
        out.add(subheading('Key insights'));
        out.addAll(bullets(insights));
      }
      return out.length > 1 ? out : const <pw.Widget>[];
    });

    // ---- salary ----
    section(() {
      final top = topMap('salary');
      if (top == null) return const <pw.Widget>[];
      final s = unwrap(top, 'salary');
      final levels = [
        'fresher_level',
        '5years_level',
        '10years_level',
        '15years_level'
      ];
      final rows = <List<pw.Widget>>[];
      for (final k in levels) {
        if (s[k] is! Map) continue;
        final lv = (s[k] as Map).cast<String, dynamic>();
        rows.add([
          txtBold(lv['experience']?.toString() ?? k),
          txt(lv['range']?.toString() ?? ''),
        ]);
      }
      if (rows.isEmpty) return const <pw.Widget>[];
      final out = <pw.Widget>[
        sectionHeader('Salary Growth'),
        dataTable(
          const ['Experience level', 'Expected range'],
          rows,
          weights: const [1, 1.2],
        ),
      ];
      final tips = strList(s['growth_tips']);
      if (tips.isNotEmpty) {
        out.add(subheading('Growth tips'));
        out.addAll(bullets(tips));
      }
      return out;
    });

    // ---- certifications ----
    section(() {
      final top = topMap('certifications');
      if (top == null) return const <pw.Widget>[];
      final list = mapList(top['certifications']);
      if (list.isEmpty) return const <pw.Widget>[];
      final rows = list
          .map<List<pw.Widget>>((m) => [
                txtBold(m['name']?.toString() ?? ''),
                txt(m['provider']?.toString() ?? ''),
                txt(m['duration']?.toString() ?? ''),
                txt(m['cost']?.toString() ?? ''),
                txt(m['difficulty']?.toString() ?? ''),
                link('Course', m['link']),
              ])
          .toList();
      return [
        sectionHeader('Certifications'),
        dataTable(
          const [
            'Name',
            'Provider',
            'Duration',
            'Cost',
            'Difficulty',
            'Link'
          ],
          rows,
          weights: const [2.4, 2, 1.3, 1.3, 1.4, 1.1],
        ),
      ];
    });

    // ---- experts (table: Name / Role / Experience / Advice) ----
    section(() {
      final top = topMap('experts');
      if (top == null) return const <pw.Widget>[];
      final list = mapList(top['experts']);
      if (list.isEmpty) return const <pw.Widget>[];
      final rows = list.map<List<pw.Widget>>((m) {
        final desig = m['designation']?.toString() ?? '';
        final company = m['company']?.toString() ?? '';
        final role = company.isNotEmpty
            ? (desig.isNotEmpty ? '$desig, $company' : company)
            : desig;
        final advice = m['key_advice']?.toString() ?? '';
        return [
          txtBold(m['name']?.toString() ?? ''),
          txt(role),
          txt(m['experience']?.toString() ?? ''),
          pw.Text(advice.isNotEmpty ? '"$advice"' : '',
              style: const pw.TextStyle(
                  fontSize: 9.5,
                  fontStyle: pw.FontStyle.italic,
                  lineSpacing: 1.5)),
        ];
      }).toList();
      return [
        sectionHeader('Industry Experts'),
        pw.Text(
          'Representative senior profiles for this field, not specific named individuals.',
          style: muted,
        ),
        pw.SizedBox(height: 6),
        dataTable(
          const ['Name', 'Role', 'Experience', 'Key advice'],
          rows,
          weights: const [1.8, 2.6, 1.4, 4],
        ),
      ];
    });

    // Footer disclaimer (preserved from the original export).
    content.add(pw.SizedBox(height: 20));
    content.add(pw.Divider(color: _hairline));
    content.add(pw.Text(
      'Generated by Guidenzia · AI-powered career guidance. Figures are AI estimates for the Indian market and should be verified before making decisions.',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ));

    // --- Cover page (full-bleed navy) ---
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Container(
          color: _navy,
          padding: const pw.EdgeInsets.all(48),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Wordmark.
              pw.Row(children: [
                pw.Container(width: 10, height: 28, color: _gold),
                pw.SizedBox(width: 10),
                pw.Text('GUIDENZIA',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 3)),
              ]),
              pw.SizedBox(height: 6),
              pw.Text('AI-POWERED CAREER GUIDANCE',
                  style: const pw.TextStyle(
                      color: _gold, fontSize: 10, letterSpacing: 2)),
              pw.Spacer(),
              pw.Text('CAREER REPORT',
                  style: const pw.TextStyle(
                      color: _gold, fontSize: 13, letterSpacing: 3)),
              pw.SizedBox(height: 10),
              pw.Text(career.title,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 34,
                      fontWeight: pw.FontWeight.bold,
                      lineSpacing: 4)),
              pw.SizedBox(height: 16),
              pw.Container(width: 90, height: 3, color: _gold),
              pw.SizedBox(height: 20),
              if (career.matchScore > 0)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: _gold,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text('${career.matchScore}% Profile Match',
                      style: pw.TextStyle(
                          color: _navy,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold)),
                ),
              pw.SizedBox(height: 18),
              pw.Text(
                career.description.isNotEmpty
                    ? career.description
                    : 'A personalised deep-dive into this career path — pathway, institutes, costs, financial support, job market and expert perspectives.',
                style: const pw.TextStyle(
                    color: PdfColors.white, fontSize: 12, lineSpacing: 4),
              ),
              pw.Spacer(),
              pw.Divider(color: _gold, thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Text(
                'Client-generated report · Figures are AI estimates for the Indian market.',
                style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );

    // --- Content pages (flow across pages) ---
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) => watermark(),
        ),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('Guidenzia · ${career.title}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500)),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ),
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
    return (path: path, bytes: bytes);
  }
}
