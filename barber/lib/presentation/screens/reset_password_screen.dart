import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../../core/validators/auth_validators.dart';

/// Resend cooldown in seconds (UI-only; backend also enforces 60s)
const int _resendCooldownSeconds = 60;

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  bool _didSubmitReset = false;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    _didSubmitReset = true;
    await ref.read(authStateProvider.notifier).resetPassword(
          email: widget.email,
          code: _codeController.text.trim(),
          newPassword: _passwordController.text,
        );
  }

  Future<void> _handleResendCode() async {
    if (_resendCooldown > 0) return;
    // This should not trigger the "reset success" dialog.
    _didSubmitReset = false;
    await ref.read(authStateProvider.notifier).forgotPassword(widget.email);
    _startResendCooldown();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Si l\'adresse existe, un code a été envoyé.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Succès'),
        content: const Text(
          'Votre mot de passe a été réinitialisé avec succès.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.status == AuthStatus.authenticating;
    final hasError = authState.errorMessage != null;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (!_didSubmitReset) return;
      if (previous?.status == AuthStatus.authenticating &&
          next.status == AuthStatus.unauthenticated &&
          next.errorMessage == null) {
        // Only react to the reset-password request initiated from this screen.
        _didSubmitReset = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSuccessDialog();
        });
      }
    });

    if (hasError && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Reset local "in-flight" flag so the user can retry.
        _didSubmitReset = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(authStateProvider.notifier).clearError();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réinitialiser le mot de passe'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                          Icon(
                        Icons.lock_reset_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Réinitialiser le mot de passe',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Entrez le code reçu par e-mail et choisissez un nouveau mot de passe.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code à 6 chiffres',
                      hintText: '000000',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: AuthValidators.validateResetCode,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _resendCooldown > 0 || isLoading
                        ? null
                        : _handleResendCode,
                    child: Text(
                      _resendCooldown > 0
                          ? 'Renvoyer un code ($_resendCooldown s)'
                          : 'Renvoyer un code',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: AuthValidators.validatePassword,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword);
                        },
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _handleSubmit(),
                    validator: (value) =>
                        AuthValidators.validatePasswordConfirmation(
                      value,
                      _passwordController.text,
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () => _handleSubmit(),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Text('Réinitialiser le mot de passe'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('Retour'),
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}
