import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePasswords = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppIconTile(
                          icon: Icons.schedule_rounded,
                          size: 42,
                          iconSize: 21,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'HRIS',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Ganti kata sandi',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Akun ini wajib mengganti kata sandi sebelum membuka fitur karyawan.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    AppSurfaceCard(
                      padding: const EdgeInsets.all(AppSpacing.section),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            _ErrorMessage(message: _error!),
                            const SizedBox(height: 18),
                          ],
                          _PasswordField(
                            controller: _currentController,
                            label: 'Kata sandi saat ini',
                            autofillHint: AutofillHints.password,
                            obscureText: _obscurePasswords,
                            enabled: !_submitting,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Kata sandi saat ini wajib diisi'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          _PasswordField(
                            controller: _newController,
                            label: 'Kata sandi baru',
                            autofillHint: AutofillHints.newPassword,
                            obscureText: _obscurePasswords,
                            enabled: !_submitting,
                            validator: _validateNewPassword,
                          ),
                          const SizedBox(height: 18),
                          _PasswordField(
                            controller: _confirmationController,
                            label: 'Ulangi kata sandi baru',
                            autofillHint: AutofillHints.newPassword,
                            obscureText: _obscurePasswords,
                            enabled: !_submitting,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            suffixIcon: IconButton(
                              tooltip: _obscurePasswords
                                  ? 'Tampilkan kata sandi'
                                  : 'Sembunyikan kata sandi',
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                      () => _obscurePasswords =
                                          !_obscurePasswords,
                                    ),
                              icon: Icon(
                                _obscurePasswords
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            validator: (value) => value != _newController.text
                                ? 'Konfirmasi kata sandi tidak sama'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Minimal 8 karakter dengan huruf besar, huruf kecil, angka, dan karakter khusus.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 52),
                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: AppLoadingIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Simpan dan masuk kembali'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: _submitting ? null : widget.onSignOut,
                        child: const Text('Keluar dari akun'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.length < 8 || password.length > 128) {
      return 'Kata sandi harus berisi 8 sampai 128 karakter';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(
          r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]''',
        ).hasMatch(password)) {
      return 'Kata sandi belum memenuhi seluruh persyaratan';
    }
    if (password == _currentController.text) {
      return 'Kata sandi baru harus berbeda dari kata sandi saat ini';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
    if (!mounted) return;
    switch (result) {
      case Success<void>():
        break;
      case FailureResult<void>(:final failure):
        setState(() {
          _submitting = false;
          _error = failure.message;
        });
    }
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.autofillHint,
    required this.obscureText,
    required this.enabled,
    required this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String autofillHint;
  final bool obscureText;
  final bool enabled;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      textInputAction: textInputAction,
      autofillHints: [autofillHint],
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: largeText ? null : label,
        suffixIcon: suffixIcon,
      ),
    );
    if (!largeText) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Semantics(label: label, child: field),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
