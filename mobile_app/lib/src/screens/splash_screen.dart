import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A short branded splash drawn as an OVERLAY above the already-mounted app
/// (see `_SplashGate` in main.dart) so Home loads behind it.
///
/// The logo is placed to EXACTLY match the mandatory Android-12 system splash —
/// same dead-centre position and same size — so when the OS hands off there's
/// no jump: the logo simply stays put. Only the wordmark animates: it floats up
/// and fades into place beneath the logo. Then the whole thing holds briefly and
/// fades into the app. No pulse.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.onDone});

  /// Fired after the hold + fade, so the overlay can be removed.
  final VoidCallback onDone;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _float; // wordmark rise + fade
  late final AnimationController _fade; // exit fade to the app
  static const _hold = Duration(milliseconds: 2000); // total on-screen time

  // Enlarged brand mark, dead-centre. The emblems are now tight-cropped (no
  // transparent padding), so this fraction is the actual visible mark width.
  static const _logoWidthFrac = 0.6;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360));
    // Start the wordmark float only once the overlay is actually visible (the
    // system splash hands off at the first frame), so it's never consumed by
    // the boot warm-up and the first frame matches the system splash (logo only).
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      await precacheImage(
          AssetImage(isDark
              ? 'assets/images/splash_logo_dark.png'
              : 'assets/images/splash_logo_light.png'),
          context);
    } catch (_) {/* still reveal */}
    if (!mounted) return;
    _float.forward();
    await Future<void>.delayed(_hold);
    if (!mounted) return;
    await _fade.forward();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _float.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light = white bg + navy emblem; dark = navy bg + inverted (white) emblem.
    final bg = isDark ? const Color(0xFF0B1020) : Colors.white;
    final wordColor = isDark ? const Color(0xFFF5C451) : const Color(0xFF0B0A3D);
    final logo = isDark
        ? 'assets/images/splash_logo_dark.png'
        : 'assets/images/splash_logo_light.png';
    final logoW = MediaQuery.of(context).size.width * _logoWidthFrac;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: AnimatedBuilder(
        animation: Listenable.merge([_float, _fade]),
        builder: (context, _) {
          final f = Curves.easeOutCubic.transform(_float.value);
          return Opacity(
            opacity: 1.0 - _fade.value,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: bg),
                // Logo: dead-centre, static — matches the system splash exactly.
                Center(
                    child: Image.asset(logo,
                        width: logoW, height: logoW, fit: BoxFit.contain)),
                // Wordmark: floats up + fades into place just under the logo.
                Align(
                  alignment: const Alignment(0, 0.26),
                  child: Opacity(
                    opacity: f,
                    child: Transform.translate(
                      offset: Offset(0, 22 * (1 - f)),
                      child: Text(
                        'GUIDENZIA',
                        style: TextStyle(
                          color: wordColor,
                          fontFamily: 'Sora',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
