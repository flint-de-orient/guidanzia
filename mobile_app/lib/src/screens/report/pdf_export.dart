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
class CareerPdfExport {
  /// Generates the PDF and saves it to the device. Returns the saved path.
  static Future<String> generateAndSave({
    required CareerRecommendation career,
    required Map<String, dynamic> sections,
  }) async {
    final doc = pw.Document();
    const brand = PdfColor.fromInt(0xFF283569); // Guidanzia navy

    List<String> strList(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : const [];

    // --- Extract the sections we summarise ---
    final overview =
        (sections['overview']?['overview'] as Map?)?.cast<String, dynamic>();
    final pathway = (sections['pathway']?['careerPathway']?['pathway'] as List?)
            ?.whereType<Map>()
            .toList() ??
        const [];
    final skills =
        (sections['skills']?['skills'] as Map?)?.cast<String, dynamic>();
    final salary =
        (sections['salary']?['salary'] as Map?)?.cast<String, dynamic>();

    pw.Widget heading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold, color: brand)),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
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
          pw.SizedBox(height: 12),
          pw.Text(career.description,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),

          if (overview != null) ...[
            heading('Overview'),
            pw.Text(overview['role_description']?.toString() ?? '',
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
            if (strList(overview['key_responsibilities']).isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Key responsibilities:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ...strList(overview['key_responsibilities'])
                  .map((t) => pw.Bullet(text: t, style: const pw.TextStyle(fontSize: 11))),
            ],
          ],

          if (pathway.isNotEmpty) ...[
            heading('Academic Pathway'),
            ...pathway.asMap().entries.map((e) {
              final m = e.value.cast<String, dynamic>();
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${e.key + 1}. ${m['phase'] ?? ''}  (${m['duration'] ?? ''})',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text(m['description']?.toString() ?? '',
                        style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 3)),
                  ],
                ),
              );
            }),
          ],

          if (skills != null) ...[
            heading('Skills to Learn'),
            for (final entry in [
              ('high', 'Must-have'),
              ('medium', 'Core'),
              ('low', 'Bonus'),
            ])
              if ((skills[entry.$1] as List?)?.isNotEmpty ?? false) ...[
                pw.Text('${entry.$2}:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text(
                  (skills[entry.$1] as List)
                      .whereType<Map>()
                      .map((m) => m['name']?.toString() ?? '')
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                  style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 3),
                ),
                pw.SizedBox(height: 6),
              ],
          ],

          if (salary != null) ...[
            heading('Salary Growth'),
            for (final k in ['fresher_level', '5years_level', '10years_level', '15years_level'])
              if (salary[k] is Map)
                pw.Text(
                  '${(salary[k] as Map)['experience'] ?? k}: ${(salary[k] as Map)['range'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
                ),
          ],

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Text(
            'Generated by Guidenzia · AI-powered career guidance. Figures are AI estimates for the Indian market.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
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
