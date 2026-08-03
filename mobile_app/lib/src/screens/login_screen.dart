import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../l10n/app_strings.dart';
import '../router/app_routes.dart';
import '../state/providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/common_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Please enter your username and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(_username.text.trim(), _password.text);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(Routes.home, (_) => false);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(localeProvider));
    return Scaffold(
      body: GradientBackground(
        child: AuthScaffold(
          title: 'Welcome back.',
          subtitle: 'Your AI Career Mentor awaits.',
          children: [
            TextField(
              controller: _username,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(hintText: s.get('username')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: s.get('password'),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: s.get('login'),
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 20),
            AuthFooterLink(
              prompt: "Don't have an account?  ",
              action: s.get('signUp'),
              onTap: () =>
                  Navigator.of(context).pushReplacementNamed(Routes.signup),
            ),
          ],
        ),
      ),
    );
  }
}
