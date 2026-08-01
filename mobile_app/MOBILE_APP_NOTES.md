# EduBot Mobile (Flutter) — Setup, Architecture & Notes

A Flutter (Android-first) client for the existing **EduBot career-counselling**
system. It talks to the **same Flask backend** as the React web app over the
same REST endpoints — no backend changes were required.

Design language is adapted from the reference mockups in
`../app_frontend_ideas/` — purple/lavender glassmorphism, an EduBot mascot,
match-% badges, stat tiles, chip filters and a floating bottom nav — but the
semantics are *counselling* ("View Career Report"), not job-application ("Apply").

---

## 1. Prerequisites

- Flutter SDK 3.44+ (Dart 3.12+) — verified with `flutter --version`
- Android Studio + Android SDK, and either an emulator or a USB device
- The Python backend from `../backend` running locally

## 2. Run the backend (dev)

```bash
cd ../backend
pip install -r requirements.txt
python app.py            # serves on 0.0.0.0:8080
```

## 3. Point the app at your backend

The base URL defaults to `http://10.0.2.2:8080` (the Android **emulator's**
alias for your PC's `localhost`).

- **Emulator:** no change needed.
- **Physical Android phone:** phone and PC on the same Wi-Fi, then pass your
  PC's LAN IP:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080
```

Cleartext HTTP is already enabled for dev in `AndroidManifest.xml`
(`usesCleartextTraffic="true"`) so the non-HTTPS localhost calls work.

## 4. Run the app

```bash
flutter pub get
flutter run                 # or: flutter build apk --debug
```

---

## 5. The user journey

Landing → Sign up → Onboarding (name/class/board) → Questionnaire (interests,
subjects, strengths, values) → **4 sense-games** (Number/Word/Shape/Logic) →
scores saved → **Top-3 career matches** → tap a career → **full AI report**
(overview, pathway, skills, roadmap, institutes, fees, scholarships, job market,
salary, certifications, experts) → optional **PDF export**.

## 6. Architecture

```
lib/
  main.dart                 – MaterialApp, routes, localization delegates
  src/
    config/app_config.dart  – API base URL + timeouts (--dart-define)
    theme/                  – colors, gradients, ThemeData (design tokens)
    l10n/app_strings.dart   – static UI strings (en/hi/bn), "translate once"
    api/                    – ApiClient (typed wrapper over the Flask REST API)
    models/                 – CareerRecommendation, OnboardingData, QuestionnaireData
    services/               – StorageService (secure storage + prefs)
    state/providers.dart    – Riverpod: auth, locale, questionnaire, recommendations
    games/                  – 4 sense-game definitions + question banks
    widgets/                – GlassCard, PrimaryButton, MatchBadge, StatTile, …
    screens/                – landing, login, signup, onboarding, questionnaire,
                              games, home_shell (+ tabs), role_detail, settings,
                              payment, report/ (renderers + pdf export)
```

- **State:** Riverpod. `authProvider` restores the session from secure storage;
  `recommendationsProvider` is a `FutureProvider` (pull-to-refresh re-invalidates).
- **API contract:** mirrors `backend/app.py` exactly. Endpoints used:
  `/signup`, `/login`, `/logout`, `/api/save-onboarding`, `/api/get-onboarding`,
  `/api/save-questionnaire`, `/api/get-top-3-careers`, `/api/career-details`,
  `/api/translate`, `/api/translate-batch`.
- **Report performance:** each report section is a separate slow AI call, so
  sections are **lazily loaded on first expand** rather than all up front.

## 7. Localization (hybrid)

- Static UI strings live in `l10n/app_strings.dart` (en/hi/bn), translated once.
- AI-generated content is translated at runtime via the backend `/api/translate`.
- Noto Devanagari / Noto Bengali fonts are bundled and set as font fallbacks so
  Hindi/Bengali render on the same type scale.

## 8. What is intentionally deferred / placeholder (v1 scope)

- **Persistence / cipher / blackbox / constraint-grid games** — not ported yet.
  The recommendation engine only reads the four sense scores, so recommendations
  work correctly without them (their DB columns stay null, which the backend
  tolerates).
- **Word Sense game** uses a local question bank for reliability; it can later
  switch to the backend generator (`/api/generate-word-item`).
- **Payment** is a visual-only preview — no gateway is wired.
- **Mascot** is a shape-drawn placeholder (`widgets/mascot.dart`); swap for a
  final illustration/`Image.asset` when art is ready.
- **PDF** is generated client-side (reliable, offline). The backend's
  Playwright `/api/generate-pdf` is an alternative once it's deployed with
  headless Chromium.
- **iOS** not set up (Android-first). Code is kept platform-neutral.

## 9. TECH DEBT (security — carried over from backend, deferred by decision)

- Backend stores **passwords in plaintext** and has **no real token/session**.
  The app therefore stores only the username in secure storage; there is no
  bearer token to protect yet.
- Before this ever leaves a dev machine: hash passwords server-side, add a
  real auth token, and move the backend off cleartext HTTP (TLS).
