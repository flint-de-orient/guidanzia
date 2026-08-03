import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/theme/app_theme.dart';
import 'src/services/storage_service.dart';
import 'src/state/providers.dart';
import 'src/router/app_routes.dart';
import 'src/screens/landing_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/signup_screen.dart';
import 'src/screens/onboarding_screen.dart';
import 'src/screens/questionnaire_screen.dart';
import 'src/screens/games_screen.dart';
import 'src/screens/home_shell.dart';
import 'src/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the persisted theme BEFORE first paint and seed it via an override,
  // so a returning dark-mode user never sees a light→dark flash.
  final modeStr = await StorageService().readThemeMode();
  final bootMode = modeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
  runApp(
    ProviderScope(
      overrides: [bootThemeModeProvider.overrideWithValue(bootMode)],
      child: const EduBotApp(),
    ),
  );
}

class EduBotApp extends ConsumerWidget {
  const EduBotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Guidenzia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('bn')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (_) => const _SplashGate(),
        Routes.landing: (_) => const _RootGate(),
        Routes.login: (_) => const LoginScreen(),
        Routes.signup: (_) => const SignupScreen(),
        Routes.onboarding: (_) => const OnboardingScreen(),
        Routes.questionnaire: (_) => const QuestionnaireScreen(),
        Routes.games: (_) => const GamesScreen(),
        Routes.home: (_) => const HomeShell(),
      },
    );
  }
}

/// Cold-start entry: the real app (_RootGate) mounts immediately and loads
/// beneath the brand [SplashOverlay]. The overlay holds ~2s (heartbeat pulse),
/// then fades to reveal Home — already loaded underneath, so no second spinner.
/// Shown only on a fresh launch (logout routes straight to [Routes.landing]).
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _RootGate(),
        if (_showSplash)
          SplashOverlay(
            onDone: () {
              if (mounted) setState(() => _showSplash = false);
            },
          ),
      ],
    );
  }
}

/// Decides the entry surface on launch (and after logout): a returning,
/// authenticated user goes straight to the logged-in shell; everyone else sees
/// the public landing page.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    // Restore any in-progress assessment saved locally before showing the app,
    // so an accidental close never loses the user's answers.
    final restored = ref.watch(assessmentRestoreProvider);

    if (auth.loading || restored.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return auth.isAuthenticated ? const HomeShell() : const LandingScreen();
  }
}
