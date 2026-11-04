import 'package:flutter/material.dart';

import '../preferences/biometric_lock_prefs.dart';
import '../theme/app_colors.dart';
import '../ui/futuristic_background.dart';
import '../ui/keyboard_bottom_inset.dart';
import 'modern_loading.dart';
import '../../data/repositories/app_data_repository.dart';

/// Bloqueia o app até o utilizador definir nova senha (troca da provisória).
class MandatoryPasswordChangeScaffold extends StatefulWidget {
  const MandatoryPasswordChangeScaffold({
    super.key,
    required this.repo,
    this.subtitle =
        'Por segurança, defina uma nova senha antes de continuar. '
        'Isto atualiza apenas o cadastro neste aparelho; use também '
        'Supabase Auth em Configurações se a nuvem estiver ligada.',
  });

  final AppDataRepository repo;
  final String subtitle;

  @override
  State<MandatoryPasswordChangeScaffold> createState() =>
      _MandatoryPasswordChangeScaffoldState();
}

class _MandatoryPasswordChangeScaffoldState
    extends State<MandatoryPasswordChangeScaffold> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (_next.text != _confirm.text) {
        setState(() => _error = 'Confirmação não coincide.');
        return;
      }
      await widget.repo.changePasswordForCurrentSession(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Senha atualizada.'),
          action: SnackBarAction(
            label: 'Face ID ao reabrir',
            onPressed: () async {
              await BiometricLockPrefs.setEnabled(true);
            },
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: FuturisticBackground(
          child: SafeArea(
            child: KeyboardBottomInsetPadding(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nova senha obrigatória',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _current,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Senha atual (ou provisória)',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _next,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nova senha',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nova senha',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.accentPink,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: ModernLoadingIndicator(size: 26),
                            )
                          : const Text('Salvar e continuar'),
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
