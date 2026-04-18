import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/app_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/modern_loading.dart';
import '../../core/ui/futuristic_background.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import '../shell/main_shell.dart';

/// Login local (SQLite) com e-mail + senha após «Sair da conta» nas configurações.
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
          'Será gerada uma nova senha provisória para o e-mail:\n$email\n\n'
          'Se o envio automático estiver configurado, receberá um e-mail. '
          'Caso contrário, o app mostrará a nova senha para copiar.',
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
            child: const Text('Continuar'),
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
      if (result.emailSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nova senha enviada. Verifique o e-mail (e a pasta de spam). '
              'No próximo acesso use a senha recebida.',
            ),
          ),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) => AlertDialog(
          backgroundColor: AppColors.barBackground,
          title: const Text(
            'Nova senha provisória',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                const String.fromEnvironment('PASSWORD_RESET_WEBHOOK_URL')
                        .trim()
                        .isEmpty
                    ? 'O envio automático por e-mail ainda não está configurado '
                        '(defina PASSWORD_RESET_WEBHOOK_URL na build). A senha já '
                        'foi atualizada no aparelho — guarde ou copie agora.'
                    : 'Não foi possível confirmar o envio do e-mail. A senha já foi '
                        'atualizada no aparelho — guarde ou copie agora.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(
                result.provisionalPassword,
                style: const TextStyle(
                  color: AppColors.splashMint,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: result.provisionalPassword),
                );
                if (dCtx.mounted) {
                  ScaffoldMessenger.of(dCtx).showSnackBar(
                    const SnackBar(content: Text('Senha copiada.')),
                  );
                }
              },
              child: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () async {
                await SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Personal Gym — nova senha provisória\n\n'
                        'E-mail de acesso: $email\n'
                        'Senha: ${result.provisionalPassword}\n\n'
                        'Altere a senha ao entrar no app.',
                    subject: 'Personal Gym — nova senha',
                  ),
                );
              },
              child: const Text('Partilhar…'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Não foi possível recuperar.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe e-mail e senha.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final db = context.read<AppDatabase>();
      final session = context.read<AppSession>();
      final repo = context.read<AppDataRepository>();

      final personals = await db.select(db.personals).get();
      PersonalEntity? personal;
      for (final p in personals) {
        if (_normEmail(p.email) == email) {
          personal = p;
          break;
        }
      }

      final students = await (db.select(db.students)
            ..where((s) => s.isArchived.equals(false)))
          .get();
      StudentEntity? student;
      for (final s in students) {
        final em = s.email?.trim();
        if (em == null || em.isEmpty) continue;
        if (_normEmail(em) == email) {
          student = s;
          break;
        }
      }

      if (personal != null && student != null) {
        throw ArgumentError(
          'Há personal e aluno com o mesmo e-mail no cadastro. Corrija no SQLite.',
        );
      }

      if (personal != null) {
        final stored = personal.passwordHash;
        if (stored == null || stored.isEmpty) {
          throw ArgumentError(
            'Este personal não tem senha definida no cadastro local.',
          );
        }
        if (stored != password) {
          throw ArgumentError('E-mail ou senha incorretos.');
        }
        await session.completeLocalLoginAfterPasswordCheck(
          role: personal.isAdmin
              ? SessionRole.adminPersonal
              : SessionRole.personalTrainer,
          personalId: personal.id,
          studentId: null,
        );
        await repo.refreshSessionPersonalAdminFlag();
      } else if (student != null) {
        final stored = student.passwordHash;
        if (stored == null || stored.isEmpty) {
          throw ArgumentError(
            'Este aluno não tem senha definida. Peça ao personal para cadastrar.',
          );
        }
        if (stored != password) {
          throw ArgumentError('E-mail ou senha incorretos.');
        }
        await session.completeLocalLoginAfterPasswordCheck(
          role: SessionRole.student,
          personalId: null,
          studentId: student.id,
        );
        await repo.refreshSessionPersonalAdminFlag();
      } else {
        throw ArgumentError(
          'Nenhum personal ou aluno ativo encontrado com este e-mail.',
        );
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushReplacementNamed(MainShell.routeName);
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Não foi possível entrar.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
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
                      'Entre com o e-mail e a senha do cadastro local '
                      '(personal ou aluno).',
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
