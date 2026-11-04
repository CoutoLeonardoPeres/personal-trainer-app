import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/supabase_auth_bridge.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/modern_loading.dart';
import '../../core/ui/futuristic_background.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import '../shell/main_shell.dart';

/// Login com Supabase Auth (JWT) — liga ao perfil local personal/aluno.
class LocalLoginPage extends StatefulWidget {
  const LocalLoginPage({super.key});

  static const routeName = '/local-login';

  @override
  State<LocalLoginPage> createState() => _LocalLoginPageState();
}

class _LocalLoginPageState extends State<LocalLoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _normEmail(String s) => s.trim().toLowerCase();

  Future<void> _forgotPassword() async {
    final email = _normEmail(_email.text);
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o e-mail acima para recuperar a senha.'),
        ),
      );
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Recuperar senha?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Será enviado um e-mail de recuperação para:\n$email\n\n'
          'Siga o link recebido para definir uma nova senha no Supabase Auth.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Enviar e-mail'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = context.read<AppDataRepository>();
      final result = await repo.requestPasswordResetForActiveLocalUser(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.emailSent
                ? 'E-mail de recuperação enviado. Verifique a caixa de entrada e o spam.'
                : 'Pedido de recuperação registado.',
          ),
        ),
      );
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Não foi possível recuperar.')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final rateLimited =
          e.statusCode == '429' || e.code == 'over_email_send_rate_limit';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rateLimited
                ? 'Limite de e-mails do Supabase atingido. Aguarde até 1 hora '
                      'desde os últimos envios e tente novamente.'
                : 'Não foi possível enviar o e-mail de recuperação. '
                      'Tente novamente mais tarde.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível enviar o e-mail de recuperação. '
              'Tente novamente mais tarde.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final email = _normEmail(_email.text);
    final password = _pass.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe e-mail e senha.')));
      return;
    }
    if (!supabaseAppEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Supabase Auth não está configurado neste build. '
            'Defina SUPABASE_ANON_KEY.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final db = context.read<AppDatabase>();
      final session = context.read<AppSession>();
      final repo = context.read<AppDataRepository>();

      await SupabaseAuthBridge.signInAndBindAppSession(
        db: db,
        session: session,
        email: email,
        password: password,
      );
      await repo.refreshSessionPersonalAdminFlag();

      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushReplacementNamed(MainShell.routeName);
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Não foi possível entrar.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'E-mail ou senha incorretos, ou conta sem perfil ligado.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FuturisticBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Personal Gym',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.splashMint.withValues(alpha: 0.98),
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entre com o e-mail e a senha da sua conta '
                      '(autenticação segura via Supabase).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'E-mail (login)',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      autocorrect: false,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: ModernLoadingIndicator(size: 26),
                            )
                          : const Text('Entrar'),
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
}
