import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/supabase/supabase_auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/futuristic_background.dart';
import '../../core/widgets/modern_loading.dart';
import 'local_login_page.dart';

/// Destino seguro do link de recuperação enviado pelo Supabase Auth.
class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});

  static const routeName = '/reset-password';

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _busy = false;
  var _obscurePassword = true;
  var _obscureConfirmation = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    final password = _password.text;
    final confirmation = _confirmation.text;
    if (password.length < 8) {
      _showMessage('A senha deve ter pelo menos 8 caracteres.');
      return;
    }
    if (password != confirmation) {
      _showMessage('As senhas não coincidem.');
      return;
    }
    if (SupabaseAuthService.currentSession == null) {
      _showMessage(
        'O link expirou ou é inválido. Volte ao login e solicite um novo e-mail.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await SupabaseAuthService.updatePassword(password);
      await SupabaseAuthService.signOut();
      if (!mounted) return;
      _showMessage('Senha alterada. Entre novamente com a nova senha.');
      unawaited(
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(LocalLoginPage.routeName, (_) => false),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Não foi possível alterar a senha: $error');
      setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FuturisticBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  color: AppColors.barBackground.withValues(alpha: 0.94),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_reset,
                          color: AppColors.accentGreen,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Definir nova senha',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escolha uma senha segura para acessar o Personal Gym.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          enabled: !_busy,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Nova senha',
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmation,
                          obscureText: _obscureConfirmation,
                          enabled: !_busy,
                          autofillHints: const [AutofillHints.newPassword],
                          onSubmitted: (_) {
                            if (!_busy) unawaited(_savePassword());
                          },
                          decoration: InputDecoration(
                            labelText: 'Confirmar nova senha',
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscureConfirmation =
                                    !_obscureConfirmation,
                              ),
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _savePassword,
                          child: _busy
                              ? const ModernLoadingIndicator(size: 24)
                              : const Text('Salvar nova senha'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                      LocalLoginPage.routeName,
                                      (_) => false,
                                    ),
                          child: const Text('Voltar ao login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
