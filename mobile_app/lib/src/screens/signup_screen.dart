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
import '../theme/guidanzia_colors.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _agree = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _username.text.trim();
    if (u.isEmpty) {
      setState(() => _error = 'Please enter a username.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Please enter a password.');
      return;
    }
    if (_password.text.length < 4) {
      setState(() => _error =
          'Password is too short — use at least 4 characters (you entered ${_password.text.length}).');
      return;
    }
    if (_confirm.text.isEmpty) {
      setState(() => _error = 'Please re-enter your password to confirm.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error =
          "Passwords don't match — the password and confirm-password fields are different.");
      return;
    }
    if (!_agree) {
      setState(() =>
          _error = 'Please agree to the Privacy Policy and Terms to continue.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signup(u, _password.text);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(Routes.home, (_) => false);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Signup failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 3-segment password-strength bar (Stitch signup), computed from length.
  Widget _strengthBar() {
    final g = Theme.of(context).guidanzia;
    final len = _password.text.length;
    final strength = len == 0 ? 0 : (len < 4 ? 1 : (len < 8 ? 2 : 3));
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: i < strength ? g.lime : g.outline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(ref.watch(localeProvider));
    return Scaffold(
      body: GradientBackground(
        child: AuthScaffold(
          title: "Let's find your thing.",
          subtitle: 'Create your account to get started.',
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
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 10),
            _strengthBar(),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: 'Confirm password'),
            ),
            const SizedBox(height: 16),
            _AgreeRow(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: s.get('createFreeAccount'),
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 20),
            AuthFooterLink(
              prompt: 'Already have an account?  ',
              action: s.get('login'),
              onTap: () =>
                  Navigator.of(context).pushReplacementNamed(Routes.login),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreeRow extends StatelessWidget {
  const _AgreeRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: g.gold,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'I agree to the Privacy Policy and Terms of Service.',
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
