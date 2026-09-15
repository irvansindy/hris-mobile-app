import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/services/clock.dart';

import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/presentation/controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _mfa = TextEditingController();
  bool _obscure = true;
  bool _indonesian = true;
  bool _requiresMfa = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _mfa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final content = _LoginViewport(
      child: _content(
        loading: auth.isLoading,
        error: auth.hasError ? _errorMessage(auth.error) : null,
        notice: ref.watch(authNoticeProvider),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, constraints) => constraints.maxWidth < 780
              ? content
              : Row(
                  children: [
                    const Expanded(child: _IdentityPanel()),
                    Expanded(child: content),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _content({
    required bool loading,
    required String? error,
    required String? notice,
  }) => AutofillGroup(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            indonesian: _indonesian,
            onLanguage: loading
                ? (_) {}
                : (value) => setState(() => _indonesian = value),
          ),
          const SizedBox(height: 34),
          _DatePill(indonesian: _indonesian),
          const SizedBox(height: 20),
          Text(
            _text('Selamat datang\nkembali', 'Welcome\nback'),
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 12),
          Text(
            _text(
              'Masuk untuk membuka layanan karyawan Anda.',
              'Sign in to open your employee services.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 26),
          if (notice != null) ...[
            _AuthMessage(message: notice, success: true),
            const SizedBox(height: 12),
          ],
          if (error != null) ...[
            _AuthMessage(message: error, success: false),
            const SizedBox(height: 12),
          ],
          _CredentialCard(
            email: _email,
            password: _password,
            enabled: !loading,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onSubmit: _requiresMfa ? null : _submit,
            text: _text,
          ),
          if (_requiresMfa) ...[
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('login-mfa'),
              controller: _mfa,
              enabled: !loading,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: _text('Kode autentikator', 'Authenticator code'),
                hintText: _text('Kode MFA', 'MFA code'),
              ),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                return length < 6 || length > 20
                    ? _text(
                        'Kode harus berisi 6 sampai 20 karakter',
                        'Code must contain 6 to 20 characters',
                      )
                    : null;
              },
            ),
          ],
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              key: const ValueKey('login-submit'),
              onPressed: loading ? null : _submit,
              child: loading
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: 17,
                            child: AppLoadingIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_text('Memverifikasi...', 'Verifying...')),
                        ],
                      ),
                    )
                  : Text(_text('Masuk', 'Sign in')),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(loginSuccessPendingProvider.notifier).state = true;
    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _email.text.trim(),
          password: _password.text,
          totp: _requiresMfa ? _mfa.text.trim() : null,
        );
    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      ref.read(loginSuccessPendingProvider.notifier).state = false;
    }
    if (error is AuthenticationFailure && error.code == 'MFA_REQUIRED') {
      setState(() => _requiresMfa = true);
    }
  }

  String? _errorMessage(Object? error) => error is Failure
      ? error.message
      : _text(
          'Login gagal. Periksa koneksi lalu coba lagi.',
          'Login failed. Check your connection and try again.',
        );

  String _text(String id, String en) => _indonesian ? id : en;
}

class _Header extends StatelessWidget {
  const _Header({required this.indonesian, required this.onLanguage});
  final bool indonesian;
  final ValueChanged<bool> onLanguage;

  @override
  Widget build(BuildContext context) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Text(
            'H',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('HRIS', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
    final language = SizedBox(
      width: 116,
      child: AppSegmentedControl<bool>(
        values: const [true, false],
        selected: indonesian,
        labelBuilder: (value) => value ? 'ID' : 'EN',
        onSelected: onLanguage,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(alignment: Alignment.centerRight, child: language),
              const SizedBox(height: 12),
              brand,
            ],
          );
        }
        return Row(children: [brand, const Spacer(), language]);
      },
    );
  }
}

class _DatePill extends ConsumerWidget {
  const _DatePill({required this.indonesian});
  final bool indonesian;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      '•  ${_dateLabel(ref.watch(clockProvider)(), indonesian)}',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.email,
    required this.password,
    required this.enabled,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.text,
  });
  final TextEditingController email;
  final TextEditingController password;
  final bool enabled;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback? onSubmit;
  final String Function(String, String) text;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 3,
    shadowColor: Colors.black.withValues(alpha: 0.16),
    borderRadius: BorderRadius.circular(AppRadius.largeCard),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          _LoginField(
            fieldKey: const ValueKey('login-email'),
            controller: email,
            icon: Icons.mail_outline_rounded,
            label: text('Email kantor', 'Work email'),
            hint: 'nama@perusahaan.com',
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              final input = value?.trim() ?? '';
              if (input.isEmpty) {
                return text('Email wajib diisi', 'Email is required');
              }
              if (!input.contains('@') || input.endsWith('@')) {
                return text(
                  'Masukkan alamat email yang valid',
                  'Enter a valid email address',
                );
              }
              return null;
            },
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _LoginField(
            fieldKey: const ValueKey('login-password'),
            controller: password,
            icon: Icons.lock_outline_rounded,
            label: text('Kata sandi', 'Password'),
            hint: text('Masukkan kata sandi', 'Enter password'),
            enabled: enabled,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            obscureText: obscure,
            onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
            suffix: IconButton(
              tooltip: obscure
                  ? text('Tampilkan kata sandi', 'Show password')
                  : text('Sembunyikan kata sandi', 'Hide password'),
              onPressed: enabled ? onToggleObscure : null,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
              ),
            ),
            validator: (value) => value == null || value.isEmpty
                ? text('Kata sandi wajib diisi', 'Password is required')
                : null,
          ),
        ],
      ),
    ),
  );
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.fieldKey,
    required this.controller,
    required this.icon,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.keyboardType,
    required this.textInputAction,
    required this.autofillHints,
    required this.validator,
    this.obscureText = false,
    this.onSubmitted,
    this.suffix,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hint;
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final FormFieldValidator<String> validator;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 17),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: obscureText,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            decoration: InputDecoration(
              labelText: label.toUpperCase(),
              hintText: hint,
              suffixIcon: suffix,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 0.7,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoginViewport extends StatelessWidget {
  const _LoginViewport({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      12,
      AppSpacing.screenHorizontal,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight:
            MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).vertical -
            36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child,
        ),
      ),
    ),
  );
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.primary,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'HRIS Mobile',
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.message, required this.success});
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = success
        ? (dark ? AppColors.darkSuccess : AppColors.success)
        : (dark ? AppColors.darkDanger : AppColors.danger);
    final background = success
        ? (dark ? AppColors.darkSuccessBackground : AppColors.successBackground)
        : (dark ? AppColors.darkDangerBackground : AppColors.dangerBackground);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: foreground,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value, bool id) {
  const daysId = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const monthsId = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  const daysEn = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final days = id ? daysId : daysEn;
  final months = id ? monthsId : monthsEn;
  return '${days[value.weekday - 1]}, ${value.day} ${months[value.month - 1]}';
}
