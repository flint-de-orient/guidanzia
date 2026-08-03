/// Stage-0 onboarding profile (mirrors /api/save-onboarding fields).
class OnboardingData {
  const OnboardingData({
    this.name = '',
    this.classLevel = '',
    this.board = '',
    this.district = '',
    this.parentMobile = '',
  });

  final String name;
  final String classLevel;
  final String board;
  final String district;
  final String parentMobile;

  OnboardingData copyWith({
    String? name,
    String? classLevel,
    String? board,
    String? district,
    String? parentMobile,
  }) {
    return OnboardingData(
      name: name ?? this.name,
      classLevel: classLevel ?? this.classLevel,
      board: board ?? this.board,
      district: district ?? this.district,
      parentMobile: parentMobile ?? this.parentMobile,
    );
  }

  Map<String, dynamic> toRequest(String username) => {
        'username': username,
        'name': name,
        'classLevel': classLevel,
        'board': board,
        'district': district,
        'parentMobile': parentMobile,
      };

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      name: (json['name'] ?? '').toString(),
      classLevel: (json['classLevel'] ?? json['class_level'] ?? '').toString(),
      board: (json['board'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      parentMobile:
          (json['parentMobile'] ?? json['parent_mobile'] ?? '').toString(),
    );
  }

  bool get isComplete =>
      name.isNotEmpty && classLevel.isNotEmpty && board.isNotEmpty;
}
