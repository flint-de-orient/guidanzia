import 'package:flutter/widgets.dart';

/// Lightweight static-string localization (the "translate once" half of the
/// hybrid strategy). AI-generated content is translated at runtime via the
/// backend instead. Can be migrated to gen-l10n/.arb later without touching
/// call sites — they only depend on [AppStrings.of].
class AppStrings {
  AppStrings(this.locale);
  final String locale;

  static AppStrings of(BuildContext context, String locale) =>
      AppStrings(locale);

  static const supported = ['en', 'hi', 'bn'];
  static const languageNames = {
    'en': 'English',
    'hi': 'हिन्दी',
    'bn': 'বাংলা',
  };

  static const Map<String, Map<String, String>> _t = {
    'appName': {'en': 'Guidenzia', 'hi': 'Guidenzia', 'bn': 'Guidenzia'},
    'heroTitle': {
      'en': 'Smart Career\nStarts Here',
      'hi': 'स्मार्ट करियर\nयहाँ से शुरू',
      'bn': 'স্মার্ট ক্যারিয়ার\nএখানে শুরু',
    },
    'heroSubtitle': {
      'en': 'AI-powered career guidance built for Indian students.',
      'hi': 'भारतीय छात्रों के लिए एआई-संचालित करियर मार्गदर्शन।',
      'bn': 'ভারতীয় শিক্ষার্থীদের জন্য এআই-চালিত ক্যারিয়ার গাইড।',
    },
    'getStarted': {'en': 'Get Started', 'hi': 'शुरू करें', 'bn': 'শুরু করুন'},
    'signIn': {'en': 'Sign In', 'hi': 'साइन इन', 'bn': 'সাইন ইন'},
    'signUp': {'en': 'Sign Up', 'hi': 'साइन अप', 'bn': 'সাইন আপ'},
    'login': {'en': 'Log In', 'hi': 'लॉग इन', 'bn': 'লগ ইন'},
    'username': {'en': 'Username', 'hi': 'उपयोगकर्ता नाम', 'bn': 'ইউজারনেম'},
    'password': {'en': 'Password', 'hi': 'पासवर्ड', 'bn': 'পাসওয়ার্ড'},
    'home': {'en': 'Home', 'hi': 'होम', 'bn': 'হোম'},
    'explore': {'en': 'Explore', 'hi': 'एक्सप्लोर', 'bn': 'এক্সপ্লোর'},
    'report': {'en': 'Report', 'hi': 'रिपोर्ट', 'bn': 'রিপোর্ট'},
    'matches': {'en': 'Matches', 'hi': 'मैच', 'bn': 'ম্যাচ'},
    'profile': {'en': 'Profile', 'hi': 'प्रोफ़ाइल', 'bn': 'প্রোফাইল'},
    'continue_': {'en': 'Continue', 'hi': 'जारी रखें', 'bn': 'চালিয়ে যান'},
    'next': {'en': 'Next', 'hi': 'अगला', 'bn': 'পরবর্তী'},
    'yourMatches': {
      'en': 'Your top career matches',
      'hi': 'आपके शीर्ष करियर मैच',
      'bn': 'আপনার সেরা ক্যারিয়ার ম্যাচ',
    },
    'viewReport': {
      'en': 'View Career Report',
      'hi': 'करियर रिपोर्ट देखें',
      'bn': 'ক্যারিয়ার রিপোর্ট দেখুন',
    },

    // ---- Landing: hero badge + description ----
    'heroBadge': {
      'en': 'AI-Powered Career Guidance',
      'hi': 'एआई-संचालित करियर मार्गदर्शन',
      'bn': 'এআই-চালিত ক্যারিয়ার গাইড',
    },
    'heroDescription': {
      'en':
          'Get personalized career recommendations powered by AI analysis of your interests, academic profile, and aptitude. Start your journey to a fulfilling career today.',
      'hi':
          'अपनी रुचियों, शैक्षणिक प्रोफ़ाइल और योग्यता के एआई विश्लेषण से व्यक्तिगत करियर सुझाव पाएं। आज ही एक बेहतर करियर की ओर अपनी यात्रा शुरू करें।',
      'bn':
          'আপনার আগ্রহ, শিক্ষাগত প্রোফাইল ও দক্ষতার এআই বিশ্লেষণে ব্যক্তিগত ক্যারিয়ার পরামর্শ নিন। আজই একটি সফল ক্যারিয়ারের পথে যাত্রা শুরু করুন।',
    },

    // ---- Landing: How It Works ----
    'howItWorks': {
      'en': 'How It Works',
      'hi': 'यह कैसे काम करता है',
      'bn': 'এটি কীভাবে কাজ করে',
    },
    'howItWorksSubtitle': {
      'en': 'Your personalized career journey in 3 simple steps',
      'hi': '3 आसान चरणों में आपकी व्यक्तिगत करियर यात्रा',
      'bn': '৩টি সহজ ধাপে আপনার ব্যক্তিগত ক্যারিয়ার যাত্রা',
    },
    'step1Title': {
      'en': 'Complete Assessment',
      'hi': 'मूल्यांकन पूरा करें',
      'bn': 'মূল্যায়ন সম্পূর্ণ করুন',
    },
    'step1Desc': {
      'en':
          'Answer questions about your education, interests and skills, then play four quick aptitude games.',
      'hi':
          'अपनी शिक्षा, रुचियों और कौशल के बारे में सवालों के जवाब दें, फिर चार त्वरित योग्यता खेल खेलें।',
      'bn':
          'আপনার শিক্ষা, আগ্রহ ও দক্ষতা নিয়ে প্রশ্নের উত্তর দিন, তারপর চারটি দ্রুত দক্ষতা গেম খেলুন।',
    },
    'step2Title': {
      'en': 'AI-Powered Analysis',
      'hi': 'एआई-संचालित विश्लेषण',
      'bn': 'এআই-চালিত বিশ্লেষণ',
    },
    'step2Desc': {
      'en':
          'Our AI engine analyzes your profile and matches you with career paths tailored to your strengths.',
      'hi':
          'हमारा एआई इंजन आपकी प्रोफ़ाइल का विश्लेषण करता है और आपकी ताकत के अनुरूप करियर पथ सुझाता है।',
      'bn':
          'আমাদের এআই ইঞ্জিন আপনার প্রোফাইল বিশ্লেষণ করে আপনার শক্তি অনুযায়ী ক্যারিয়ার পথ মেলায়।',
    },
    'step3Title': {
      'en': 'Get Your Roadmap',
      'hi': 'अपना रोडमैप पाएं',
      'bn': 'আপনার রোডম্যাপ নিন',
    },
    'step3Desc': {
      'en':
          'Receive career recommendations with detailed roadmaps, skills, institutes and salary insights.',
      'hi':
          'विस्तृत रोडमैप, कौशल, संस्थान और वेतन जानकारी के साथ करियर सुझाव प्राप्त करें।',
      'bn':
          'বিস্তারিত রোডম্যাপ, দক্ষতা, প্রতিষ্ঠান ও বেতন তথ্যসহ ক্যারিয়ার পরামর্শ পান।',
    },

    // ---- Landing: Everything You Need (features) ----
    'featuresTitle': {
      'en': 'Everything You Need',
      'hi': 'वह सब जो आपको चाहिए',
      'bn': 'আপনার যা প্রয়োজন সব',
    },
    'featuresSubtitle': {
      'en': 'A comprehensive career guidance platform',
      'hi': 'एक व्यापक करियर मार्गदर्शन मंच',
      'bn': 'একটি পূর্ণাঙ্গ ক্যারিয়ার গাইড প্ল্যাটফর্ম',
    },
    'featRecoTitle': {
      'en': 'Career Recommendations',
      'hi': 'करियर सुझाव',
      'bn': 'ক্যারিয়ার সুপারিশ',
    },
    'featRecoDesc': {
      'en': 'AI suggestions for core, specialized and interdisciplinary roles',
      'hi': 'मुख्य, विशेष और अंतर-विषयक भूमिकाओं के लिए एआई सुझाव',
      'bn': 'মূল, বিশেষায়িত ও আন্তঃবিষয়ক ভূমিকার জন্য এআই পরামর্শ',
    },
    'featRoadmapTitle': {
      'en': 'Learning Roadmaps',
      'hi': 'लर्निंग रोडमैप',
      'bn': 'শেখার রোডম্যাপ',
    },
    'featRoadmapDesc': {
      'en': '90-day plans with actionable tasks and progress tracking',
      'hi': 'कार्ययोग्य कार्यों और प्रगति ट्रैकिंग के साथ 90-दिन की योजनाएं',
      'bn': 'কার্যকর কাজ ও অগ্রগতি ট্র্যাকিংসহ ৯০-দিনের পরিকল্পনা',
    },
    'featSalaryTitle': {
      'en': 'Salary Insights',
      'hi': 'वेतन जानकारी',
      'bn': 'বেতন তথ্য',
    },
    'featSalaryDesc': {
      'en': 'Detailed salary progression and city-wise comparisons',
      'hi': 'विस्तृत वेतन प्रगति और शहर-वार तुलना',
      'bn': 'বিস্তারিত বেতন অগ্রগতি ও শহরভিত্তিক তুলনা',
    },
    'featInstituteTitle': {
      'en': 'Top Institutes',
      'hi': 'शीर्ष संस्थान',
      'bn': 'সেরা প্রতিষ্ঠান',
    },
    'featInstituteDesc': {
      'en': 'Curated government, private and online institutions',
      'hi': 'चुनिंदा सरकारी, निजी और ऑनलाइन संस्थान',
      'bn': 'বাছাই করা সরকারি, বেসরকারি ও অনলাইন প্রতিষ্ঠান',
    },
    'featSkillsTitle': {
      'en': 'Skills Guidance',
      'hi': 'कौशल मार्गदर्शन',
      'bn': 'দক্ষতা নির্দেশনা',
    },
    'featSkillsDesc': {
      'en': 'Must-have, core and bonus skills with learning resources',
      'hi': 'सीखने के संसाधनों के साथ आवश्यक, मुख्य और अतिरिक्त कौशल',
      'bn': 'শেখার রিসোর্সসহ আবশ্যক, মূল ও অতিরিক্ত দক্ষতা',
    },
    'featExpertsTitle': {
      'en': 'Industry Experts',
      'hi': 'उद्योग विशेषज्ञ',
      'bn': 'ইন্ডাস্ট্রি বিশেষজ্ঞ',
    },
    'featExpertsDesc': {
      'en': 'Advice from professionals in your target career',
      'hi': 'आपके लक्षित करियर के पेशेवरों से सलाह',
      'bn': 'আপনার লক্ষ্য ক্যারিয়ারের পেশাদারদের পরামর্শ',
    },

    // ---- Landing: Testimonials ----
    'testimonialsTitle': {
      'en': 'Student Success Stories',
      'hi': 'छात्रों की सफलता की कहानियां',
      'bn': 'শিক্ষার্থীদের সাফল্যের গল্প',
    },
    'testimonialsSubtitle': {
      'en': 'Join thousands of students who found their path',
      'hi': 'हजारों छात्रों से जुड़ें जिन्होंने अपना रास्ता पाया',
      'bn': 'হাজারো শিক্ষার্থীর সাথে যোগ দিন যারা তাদের পথ খুঁজে পেয়েছে',
    },
    'testimonial1': {
      'en':
          'Guidenzia helped me discover my passion for data analytics. The roadmap was so clear and actionable!',
      'hi':
          'Guidenzia ने मुझे डेटा एनालिटिक्स के प्रति अपने जुनून की खोज में मदद की। रोडमैप बहुत स्पष्ट था!',
      'bn':
          'Guidenzia আমাকে ডেটা অ্যানালিটিক্সের প্রতি আমার আগ্রহ খুঁজে পেতে সাহায্য করেছে। রোডম্যাপটি খুব স্পষ্ট ছিল!',
    },
    'testimonial2': {
      'en':
          'The AI recommendations were spot-on. I found a career I never knew existed but absolutely love.',
      'hi':
          'एआई सुझाव बिल्कुल सटीक थे। मैंने एक ऐसा करियर पाया जिसके बारे में मुझे पता नहीं था लेकिन अब पसंद है।',
      'bn':
          'এআই পরামর্শগুলো একদম সঠিক ছিল। আমি এমন একটি ক্যারিয়ার পেয়েছি যা জানতামই না কিন্তু ভীষণ ভালোবাসি।',
    },
    'testimonial3': {
      'en':
          'From a confused student to a confident professional — Guidenzia made all the difference.',
      'hi':
          'एक भ्रमित छात्र से एक आत्मविश्वासी पेशेवर तक — Guidenzia ने पूरा फर्क डाला।',
      'bn':
          'একজন বিভ্রান্ত শিক্ষার্থী থেকে আত্মবিশ্বাসী পেশাদার — Guidenzia পুরো পার্থক্য গড়ে দিয়েছে।',
    },

    // ---- Landing: final CTA ----
    'finalCtaTitle': {
      'en': 'Ready to Discover Your Career Path?',
      'hi': 'अपना करियर पथ खोजने के लिए तैयार हैं?',
      'bn': 'আপনার ক্যারিয়ার পথ খুঁজতে প্রস্তুত?',
    },
    'finalCtaSubtitle': {
      'en': 'Join thousands of students who found their perfect career with Guidenzia',
      'hi': 'हजारों छात्रों से जुड़ें जिन्होंने Guidenzia के साथ अपना सही करियर पाया',
      'bn': 'হাজারো শিক্ষার্থীর সাথে যোগ দিন যারা Guidenzia দিয়ে তাদের সঠিক ক্যারিয়ার পেয়েছে',
    },

    // ---- Primary CTA labels (state-driven) ----
    'startAssessment': {
      'en': 'Start Assessment',
      'hi': 'मूल्यांकन शुरू करें',
      'bn': 'মূল্যায়ন শুরু করুন',
    },
    'startNewAssessment': {
      'en': 'Start New Assessment',
      'hi': 'नया मूल्यांकन शुरू करें',
      'bn': 'নতুন মূল্যায়ন শুরু করুন',
    },
    'resumeAssessment': {
      'en': 'Resume Assessment',
      'hi': 'मूल्यांकन जारी रखें',
      'bn': 'মূল্যায়ন চালিয়ে যান',
    },
    'welcomeBack': {
      'en': 'Welcome back',
      'hi': 'वापसी पर स्वागत है',
      'bn': 'স্বাগতম',
    },
    'unlockMessage': {
      'en': 'Complete your assessment to unlock this.',
      'hi': 'इसे अनलॉक करने के लिए अपना मूल्यांकन पूरा करें।',
      'bn': 'এটি আনলক করতে আপনার মূল্যায়ন সম্পূর্ণ করুন।',
    },

    // ---- Home (app mockup) ----
    'heroTitleV2': {
      'en': 'Discover Your Future with AI Mentor',
      'hi': 'एआई मेंटर के साथ अपना भविष्य खोजें',
      'bn': 'এআই মেন্টরের সাথে আপনার ভবিষ্যৎ আবিষ্কার করুন',
    },
    'heroSubtitleV2': {
      'en':
          'The next-generation career platform for students. Find your perfect path through AI analysis and immersive aptitude games.',
      'hi':
          'छात्रों के लिए अगली पीढ़ी का करियर मंच। एआई विश्लेषण और रोचक योग्यता खेलों के माध्यम से अपना सही रास्ता खोजें।',
      'bn':
          'শিক্ষার্থীদের জন্য পরবর্তী প্রজন্মের ক্যারিয়ার প্ল্যাটফর্ম। এআই বিশ্লেষণ ও আকর্ষণীয় দক্ষতা গেমের মাধ্যমে আপনার সঠিক পথ খুঁজুন।',
    },
    'learnMore': {'en': 'Learn More', 'hi': 'और जानें', 'bn': 'আরও জানুন'},
    'aiMatchingChip': {
      'en': 'AI-Powered Matching',
      'hi': 'एआई-संचालित मिलान',
      'bn': 'এআই-চালিত ম্যাচিং',
    },
    'aiEngineLabel': {'en': 'Guidenzia AI', 'hi': 'Guidenzia एआई', 'bn': 'Guidenzia এআই'},
    'futureReadyFeatures': {
      'en': 'Future-Ready Features',
      'hi': 'भविष्य के लिए तैयार सुविधाएं',
      'bn': 'ভবিষ্যতের জন্য প্রস্তুত বৈশিষ্ট্য',
    },
    'featAiMatchTitle': {
      'en': 'AI Career Match',
      'hi': 'एआई करियर मैच',
      'bn': 'এআই ক্যারিয়ার ম্যাচ',
    },
    'featAiMatchDesc': {
      'en':
          'Our AI analyzes your interests, skills and personality to suggest the career paths that fit you best.',
      'hi':
          'हमारा एआई आपकी रुचियों, कौशल और व्यक्तित्व का विश्लेषण करके आपके लिए सबसे उपयुक्त करियर पथ सुझाता है।',
      'bn':
          'আমাদের এআই আপনার আগ্রহ, দক্ষতা ও ব্যক্তিত্ব বিশ্লেষণ করে আপনার জন্য সবচেয়ে উপযুক্ত ক্যারিয়ার পথ পরামর্শ দেয়।',
    },
    'chipDataDriven': {
      'en': 'Data Driven',
      'hi': 'डेटा आधारित',
      'bn': 'ডেটা চালিত',
    },
    'chipPersonalized': {
      'en': 'Personalized',
      'hi': 'व्यक्तिगत',
      'bn': 'ব্যক্তিগতকৃত',
    },
    'featGamesTitle': {
      'en': 'Aptitude Games',
      'hi': 'योग्यता खेल',
      'bn': 'দক্ষতা গেম',
    },
    'featGamesDesc': {
      'en': 'Engaging cognitive challenges that map your mental strengths.',
      'hi': 'रोचक संज्ञानात्मक चुनौतियां जो आपकी मानसिक ताकत को मापती हैं।',
      'bn': 'আকর্ষণীয় জ্ঞানীয় চ্যালেঞ্জ যা আপনার মানসিক শক্তি নির্ণয় করে।',
    },
    'featPathsTitle': {
      'en': 'Learning Paths',
      'hi': 'लर्निंग पथ',
      'bn': 'শেখার পথ',
    },
    'featPathsDesc': {
      'en': 'Curated resource maps to take you from beginner to industry pro.',
      'hi': 'चुनिंदा संसाधन मानचित्र जो आपको शुरुआत से पेशेवर तक ले जाते हैं।',
      'bn': 'বাছাই করা রিসোর্স যা আপনাকে শুরু থেকে পেশাদার পর্যন্ত নিয়ে যায়।',
    },
    'statGames': {'en': 'Aptitude Games', 'hi': 'योग्यता खेल', 'bn': 'দক্ষতা গেম'},
    'statMatches': {
      'en': 'Career Matches',
      'hi': 'करियर मैच',
      'bn': 'ক্যারিয়ার ম্যাচ',
    },
    'statPowered': {'en': 'AI Powered', 'hi': 'एआई संचालित', 'bn': 'এআই চালিত'},
    'statLanguages': {'en': 'Languages', 'hi': 'भाषाएं', 'bn': 'ভাষা'},
    'readyTitle': {
      'en': 'Ready to find your path?',
      'hi': 'अपना रास्ता खोजने के लिए तैयार हैं?',
      'bn': 'আপনার পথ খুঁজতে প্রস্তুত?',
    },
    'readySubtitle': {
      'en':
          'Join thousands of students building their dream careers with Guidenzia today.',
      'hi':
          'हजारों छात्रों से जुड़ें जो आज Guidenzia के साथ अपने सपनों का करियर बना रहे हैं।',
      'bn':
          'হাজারো শিক্ষার্থীর সাথে যোগ দিন যারা আজ Guidenzia দিয়ে তাদের স্বপ্নের ক্যারিয়ার গড়ছে।',
    },
    'createFreeAccount': {
      'en': 'Create Free Account',
      'hi': 'निःशुल्क खाता बनाएं',
      'bn': 'বিনামূল্যে অ্যাকাউন্ট তৈরি করুন',
    },
  };

  String get(String key) {
    final row = _t[key];
    if (row == null) return key;
    return row[locale] ?? row['en'] ?? key;
  }
}
