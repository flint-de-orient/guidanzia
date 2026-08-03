/// A top-3 career recommendation from /api/get-top-3-careers.
class CareerRecommendation {
  const CareerRecommendation({
    required this.title,
    required this.description,
    required this.matchScore,
  });

  final String title;
  final String description;
  final int matchScore;

  factory CareerRecommendation.fromJson(Map<String, dynamic> json) {
    return CareerRecommendation(
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      matchScore: _toInt(json['matchScore']),
    );
  }

  /// Stable id derived from the title (used for /role/:id-style navigation
  /// and save/load-job-role calls).
  String get roleId => title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
