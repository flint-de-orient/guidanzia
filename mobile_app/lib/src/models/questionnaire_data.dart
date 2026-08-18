/// Holds the full Module 1-6 assessment answers plus aptitude scores, and
/// serialises them into the exact `questionnaireData` shape expected by
/// /api/save-questionnaire (mirrors the web onboarding-new.tsx fields).
class QuestionnaireData {
  // --- Module 1: Opening Questions ---
  String? whyHere;
  String? fiveYearVision;
  String careerThinking = '';
  String careerRuledOut = '';

  // --- Module 2: How Your Mind Works ---
  String? freeSunday;
  String? groupRole;
  String? jobBothers;

  // --- Module 3: What You're Actually Good At ---
  List<String> favoriteSubjects = [];
  String? difficultSubject;
  Map<String, String> subjectMarks = {};
  String? studyExperience;

  // --- Module 4: Life Outside Marks ---
  List<String> outsideActivities = [];
  String? externalValidation;
  // Optional free-text companion to externalValidation (Q13): the job role
  // others expect / said the student would be great at. Used as soft-de-emphasis
  // context in the report (never a ranking lever). Empty = not provided.
  String expectedRole = '';
  String selfInitiated = '';

  // --- Module 5: The Constraints ---
  List<String> studyLocation = [];
  String? familyBudget;
  List<String> careerValues = [];

  // --- Module 6: The Final Calibration ---
  String? planningStyle;
  String? stressResponse;
  String? surpriseReaction;

  // --- Per-module AI insight ("here's what we noticed"), shown after each
  // module during the assessment and kept for the Career Report (module N →
  // section N; module 6 → the Final Calibration section). ---
  String? module1Insight;
  String? module2Insight;
  String? module3Insight;
  String? module4Insight;
  String? module5Insight;
  String? module6Insight;

  // --- Aptitude game scores (0-8 each) ---
  int? numberSenseScore;
  int? wordSenseScore;
  int? shapeSenseScore;
  int? logicSenseScore;

  // --- Game 5, Task 1: Sliding-Tile persistence profile ---
  String? persistenceEffortRating;
  String? persistenceApproachStyle;
  List<String> persistenceCounselorFlags = [];
  int? persistenceHighestTier;

  // --- Game 5, Task 2: Constraint Grid ---
  String? constraintGridApproach;
  bool constraintGridSolved = false;
  String? constraintGridCounselorFlag;

  // --- Game 5, Task 3: Secret Agent Cipher ---
  String? cipherInformationGathering;
  String? cipherPersistence;
  String? cipherRuleAdaptability;
  bool cipherSolved = false;
  List<String> cipherCounselorFlags = [];

  /// Derived profile the backend reads for career generation (matches the web:
  /// careerInterest = careerThinking, subjects = favoriteSubjects,
  /// interests = outsideActivities).
  Map<String, dynamic> get userProfile => {
        'careerInterest':
            careerThinking.trim().isEmpty ? 'Not specified' : careerThinking.trim(),
        'subjects': favoriteSubjects,
        'strengths': <String>[],
        'interests': outsideActivities,
      };

  Map<String, dynamic> toRequest(String username) => {
        'username': username,
        'questionnaireData': {
          'userProfile': userProfile,
          'whyHere': whyHere,
          'fiveYearVision': fiveYearVision,
          'careerThinking': careerThinking.trim().isEmpty ? 'Not specified' : careerThinking.trim(),
          'careerRuledOut': careerRuledOut.trim().isEmpty ? 'Not specified' : careerRuledOut.trim(),
          'freeSunday': freeSunday,
          'groupRole': groupRole,
          'jobBothers': jobBothers,
          'favoriteSubjects': favoriteSubjects,
          'difficultSubject': difficultSubject,
          'subjectMarks': subjectMarks,
          'studyExperience': studyExperience,
          'outsideActivities': outsideActivities,
          'externalValidation': externalValidation,
          'expectedRole': expectedRole.trim().isEmpty ? null : expectedRole.trim(),
          'selfInitiated': selfInitiated.trim().isEmpty ? 'Not specified' : selfInitiated.trim(),
          'studyLocation': studyLocation,
          'familyBudget': familyBudget,
          'careerValues': careerValues,
          'planningStyle': planningStyle,
          'stressResponse': stressResponse,
          'surpriseReaction': surpriseReaction,
          'module1Insight': module1Insight,
          'module2Insight': module2Insight,
          'module3Insight': module3Insight,
          'module4Insight': module4Insight,
          'module5Insight': module5Insight,
          'module6Insight': module6Insight,
          'numberSenseScore': numberSenseScore,
          'wordSenseScore': wordSenseScore,
          'shapeSenseScore': shapeSenseScore,
          'logicSenseScore': logicSenseScore,
          'persistenceEffortRating': persistenceEffortRating,
          'persistenceApproachStyle': persistenceApproachStyle,
          'persistenceCounselorFlags': persistenceCounselorFlags,
          'persistenceHighestTier': persistenceHighestTier,
          'constraintGridApproach': constraintGridApproach,
          'constraintGridSolved': constraintGridSolved,
          'constraintGridCounselorFlag': constraintGridCounselorFlag,
          'cipherInformationGathering': cipherInformationGathering,
          'cipherPersistence': cipherPersistence,
          'cipherRuleAdaptability': cipherRuleAdaptability,
          'cipherSolved': cipherSolved,
          'cipherCounselorFlags': cipherCounselorFlags,
        },
      };

  /// Incremental answers used for per-module AI feedback
  /// (/api/generate-module-feedback), matching the web's buildAnswersSoFar.
  Map<String, dynamic> answersSoFar(int upToModule) {
    final a = <String, dynamic>{};
    if (upToModule >= 1) {
      a['module1'] = {
        'whyHere': whyHere,
        'fiveYearVision': fiveYearVision,
        'careerThinking': careerThinking.trim().isEmpty ? 'Not specified' : careerThinking,
        'careerRuledOut': careerRuledOut.trim().isEmpty ? 'Not specified' : careerRuledOut,
      };
    }
    if (upToModule >= 2) {
      a['module2'] = {'freeSunday': freeSunday, 'groupRole': groupRole, 'jobBothers': jobBothers};
    }
    if (upToModule >= 3) {
      a['module3'] = {
        'favoriteSubjects': favoriteSubjects,
        'difficultSubject': difficultSubject,
        'subjectMarks': subjectMarks,
        'studyExperience': studyExperience,
      };
    }
    if (upToModule >= 4) {
      a['module4'] = {
        'outsideActivities': outsideActivities,
        'externalValidation': externalValidation,
        'selfInitiated': selfInitiated.trim().isEmpty ? 'Not specified' : selfInitiated,
      };
    }
    if (upToModule >= 5) {
      a['module5'] = {
        'studyLocation': studyLocation,
        'familyBudget': familyBudget,
        'careerValues': careerValues,
      };
    }
    if (upToModule >= 6) {
      a['module6'] = {
        'planningStyle': planningStyle,
        'stressResponse': stressResponse,
        'surpriseReaction': surpriseReaction,
      };
    }
    return a;
  }

  bool get gamesComplete =>
      numberSenseScore != null &&
      wordSenseScore != null &&
      shapeSenseScore != null &&
      logicSenseScore != null;

  /// Local persistence round-trip (so an app kill mid-assessment does not
  /// destroy the answers). Flat, lossless shape — not the API payload.
  Map<String, dynamic> toJson() => {
        'whyHere': whyHere,
        'fiveYearVision': fiveYearVision,
        'careerThinking': careerThinking,
        'careerRuledOut': careerRuledOut,
        'freeSunday': freeSunday,
        'groupRole': groupRole,
        'jobBothers': jobBothers,
        'favoriteSubjects': favoriteSubjects,
        'difficultSubject': difficultSubject,
        'subjectMarks': subjectMarks,
        'studyExperience': studyExperience,
        'outsideActivities': outsideActivities,
        'externalValidation': externalValidation,
        'expectedRole': expectedRole,
        'selfInitiated': selfInitiated,
        'studyLocation': studyLocation,
        'familyBudget': familyBudget,
        'careerValues': careerValues,
        'planningStyle': planningStyle,
        'stressResponse': stressResponse,
        'surpriseReaction': surpriseReaction,
        'module1Insight': module1Insight,
        'module2Insight': module2Insight,
        'module3Insight': module3Insight,
        'module4Insight': module4Insight,
        'module5Insight': module5Insight,
        'module6Insight': module6Insight,
        'numberSenseScore': numberSenseScore,
        'wordSenseScore': wordSenseScore,
        'shapeSenseScore': shapeSenseScore,
        'logicSenseScore': logicSenseScore,
        'persistenceEffortRating': persistenceEffortRating,
        'persistenceApproachStyle': persistenceApproachStyle,
        'persistenceCounselorFlags': persistenceCounselorFlags,
        'persistenceHighestTier': persistenceHighestTier,
        'constraintGridApproach': constraintGridApproach,
        'constraintGridSolved': constraintGridSolved,
        'constraintGridCounselorFlag': constraintGridCounselorFlag,
        'cipherInformationGathering': cipherInformationGathering,
        'cipherPersistence': cipherPersistence,
        'cipherRuleAdaptability': cipherRuleAdaptability,
        'cipherSolved': cipherSolved,
        'cipherCounselorFlags': cipherCounselorFlags,
      };

  /// Reset every answer to its default — starts a clean retake by mutating this
  /// instance in place (deterministic, unlike invalidating the provider).
  void reset() {
    whyHere = null;
    fiveYearVision = null;
    careerThinking = '';
    careerRuledOut = '';
    freeSunday = null;
    groupRole = null;
    jobBothers = null;
    favoriteSubjects = [];
    difficultSubject = null;
    subjectMarks = {};
    studyExperience = null;
    outsideActivities = [];
    externalValidation = null;
    expectedRole = '';
    selfInitiated = '';
    studyLocation = [];
    familyBudget = null;
    careerValues = [];
    planningStyle = null;
    stressResponse = null;
    surpriseReaction = null;
    module1Insight = null;
    module2Insight = null;
    module3Insight = null;
    module4Insight = null;
    module5Insight = null;
    module6Insight = null;
    numberSenseScore = null;
    wordSenseScore = null;
    shapeSenseScore = null;
    logicSenseScore = null;
    persistenceEffortRating = null;
    persistenceApproachStyle = null;
    persistenceCounselorFlags = [];
    persistenceHighestTier = null;
    constraintGridApproach = null;
    constraintGridSolved = false;
    constraintGridCounselorFlag = null;
    cipherInformationGathering = null;
    cipherPersistence = null;
    cipherRuleAdaptability = null;
    cipherSolved = false;
    cipherCounselorFlags = [];
  }

  /// Applies a previously-saved [toJson] map onto this instance in place
  /// (the provider holds a single mutable instance).
  void applyJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];

    whyHere = j['whyHere'] as String?;
    fiveYearVision = j['fiveYearVision'] as String?;
    careerThinking = (j['careerThinking'] ?? '') as String;
    careerRuledOut = (j['careerRuledOut'] ?? '') as String;
    freeSunday = j['freeSunday'] as String?;
    groupRole = j['groupRole'] as String?;
    jobBothers = j['jobBothers'] as String?;
    favoriteSubjects = strList(j['favoriteSubjects']);
    difficultSubject = j['difficultSubject'] as String?;
    subjectMarks = (j['subjectMarks'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        {};
    studyExperience = j['studyExperience'] as String?;
    outsideActivities = strList(j['outsideActivities']);
    externalValidation = j['externalValidation'] as String?;
    expectedRole = (j['expectedRole'] ?? '') as String;
    selfInitiated = (j['selfInitiated'] ?? '') as String;
    studyLocation = strList(j['studyLocation']);
    familyBudget = j['familyBudget'] as String?;
    careerValues = strList(j['careerValues']);
    planningStyle = j['planningStyle'] as String?;
    stressResponse = j['stressResponse'] as String?;
    surpriseReaction = j['surpriseReaction'] as String?;
    module1Insight = j['module1Insight'] as String?;
    module2Insight = j['module2Insight'] as String?;
    module3Insight = j['module3Insight'] as String?;
    module4Insight = j['module4Insight'] as String?;
    module5Insight = j['module5Insight'] as String?;
    module6Insight = j['module6Insight'] as String?;
    numberSenseScore = (j['numberSenseScore'] as num?)?.toInt();
    wordSenseScore = (j['wordSenseScore'] as num?)?.toInt();
    shapeSenseScore = (j['shapeSenseScore'] as num?)?.toInt();
    logicSenseScore = (j['logicSenseScore'] as num?)?.toInt();
    persistenceEffortRating = j['persistenceEffortRating'] as String?;
    persistenceApproachStyle = j['persistenceApproachStyle'] as String?;
    persistenceCounselorFlags = strList(j['persistenceCounselorFlags']);
    persistenceHighestTier = (j['persistenceHighestTier'] as num?)?.toInt();
    constraintGridApproach = j['constraintGridApproach'] as String?;
    constraintGridSolved = j['constraintGridSolved'] == true;
    constraintGridCounselorFlag = j['constraintGridCounselorFlag'] as String?;
    cipherInformationGathering = j['cipherInformationGathering'] as String?;
    cipherPersistence = j['cipherPersistence'] as String?;
    cipherRuleAdaptability = j['cipherRuleAdaptability'] as String?;
    cipherSolved = j['cipherSolved'] == true;
    cipherCounselorFlags = strList(j['cipherCounselorFlags']);
  }
}
