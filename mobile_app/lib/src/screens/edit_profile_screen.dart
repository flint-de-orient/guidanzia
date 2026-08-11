import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../state/providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/common_widgets.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import '../widgets/guidanzia_app_bar.dart';
import '../widgets/primary_button.dart';
import '../theme/guidanzia_colors.dart';

/// Edit personal information — display name and password.
/// Backed by the existing `/api/update-profile` endpoint (no backend change).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name =
      TextEditingController(text: ref.read(authProvider).user?.name ?? '');
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final newName = _name.text.trim();
    final wantsPasswordChange = _newPassword.text.isNotEmpty;

    if (newName.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    if (wantsPasswordChange) {
      if (_currentPassword.text.isEmpty) {
        setState(() =>
            _error = 'Enter your current password to set a new one.');
        return;
      }
      if (_newPassword.text.length < 8 ||
          !RegExp(r'[a-zA-Z]').hasMatch(_newPassword.text) ||
          !RegExp(r'[0-9]').hasMatch(_newPassword.text)) {
        setState(() => _error =
            'New password must be at least 8 characters and include both letters and numbers.');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).updateProfile(
            username: user.username,
            name: newName,
            currentPassword: wantsPasswordChange ? _currentPassword.text : null,
            newPassword: wantsPasswordChange ? _newPassword.text : null,
          );
      // Reflect the new name locally (and in secure storage).
      await ref.read(authProvider.notifier).updateName(newName);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Profile updated.'),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not update profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: const GuidanziaAppBar(title: 'Edit Profile', centerTitle: false),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthLabel('Full name'),
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Your name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const AuthLabel('Username'),
                      TextFormField(
                        // Disabled display field — use TextFormField's own
                        // managed controller (via initialValue) instead of
                        // allocating a new TextEditingController on every rebuild
                        // that never gets disposed.
                        enabled: false,
                        initialValue: user?.username ?? '',
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                          helperText: 'Username cannot be changed',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Change password',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Leave blank to keep your current password.',
                          style: TextStyle(
                              color: g.onSurfaceVariant, fontSize: 12.5)),
                      const SizedBox(height: 16),
                      const AuthLabel('Current password'),
                      TextField(
                        controller: _currentPassword,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const AuthLabel('New password'),
                      TextField(
                        controller: _newPassword,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          hintText: 'At least 8 characters, letters and numbers',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(_error!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Save changes',
                  loading: _loading,
                  onPressed: _loading ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
