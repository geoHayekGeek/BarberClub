import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../../core/validators/auth_validators.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _didRequestCode = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _didRequestCode = true;
    await ref.read(authStateProvider.notifier).forgotPassword(
          _emailController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.status == AuthStatus.authenticating;
    final hasError = authState.errorMessage != null;

    // Show success message and navigate to reset password screen
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (!_didRequestCode) return;
      if (previous?.status == AuthStatus.authenticating &&
          next.status == AuthStatus.unauthenticated &&
          next.errorMessage == null) {
        // Only react to the forgot-password request initiated from this screen.
        _didRequestCode = false;
        final email = _emailController.text.trim();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Si l\'adresse existe, un code a été envoyé.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          if (!mounted) return;
          context.push('/reset-password', extra: email);
        });
      }
    });

    // Show error snackbar
    if (hasError && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Reset local "in-flight" flag so the user can retry.
        _didRequestCode = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(authState.errorMessage!)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(authStateProvider.notifier).clearError();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mot de passe oublié'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
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
                    'Mot de passe oublié',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Entrez votre adresse e-mail pour recevoir un code de réinitialisation.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      hintText: 'exemple@email.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) => _handleSubmit(),
                    validator: AuthValidators.validateEmail,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleSubmit,
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
                          : const Text('Envoyer le code'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: isLoading ? null : () => context.pop(),
                    child: const Text('Retour'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getErrorMessage(String errorMessage) {
    // Map specific error codes to French messages for forgot password
    // VALIDATION_ERROR or INVALID_INPUT → "Adresse e-mail invalide."
    if (errorMessage.contains('vérifier les informations') ||
        errorMessage.contains('invalide') ||
        errorMessage.contains('VALIDATION_ERROR') ||
        errorMessage.contains('INVALID_INPUT')) {
      return 'Adresse e-mail invalide.';
    }
    // NETWORK_ERROR / timeout → "Problème de connexion. Réessayez."
    if (errorMessage.contains('connexion') ||
        errorMessage.contains('NETWORK_ERROR') ||
        errorMessage.contains('timeout')) {
      return 'Problème de connexion. Réessayez.';
    }
    // DEFAULT → "Une erreur est survenue. Veuillez réessayer."
    return 'Une erreur est survenue. Veuillez réessayer.';
  }
}
