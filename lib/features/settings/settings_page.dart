import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/futuristic_background.dart';
import '../../data/repositories/app_data_repository.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: FuturisticBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              leading: const Icon(Icons.password_rounded, color: AppColors.accentGreen),
              title: const Text('Alterar senha', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text(
                'Primeiro acesso e troca de senha provisória (fluxo completo com auth).',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              onTap: () => _passwordSheet(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.accentPink),
              title: const Text('Sair da conta', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.barBackground,
                    title: const Text('Conta', style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text(
                      'Logout local — integrar com Supabase Auth quando o backend estiver ativo.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined, color: AppColors.accentGreen),
              title: const Text('Logs do app', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text(
                'Auditoria gravada no SQLite (ações e cadastros).',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              onTap: () => _logsSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  void _passwordSheet(BuildContext context) {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.barBackground,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nova senha',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c1,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            TextField(
              controller: c2,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Confirmar'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Salvar (stub)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logsSheet(BuildContext context) async {
    final repo = context.read<AppDataRepository>();
    final logs = await repo.allAuditLogs();
    final text = logs
        .map((e) =>
            '${e.at.toIso8601String()} [${e.action}] ${e.entityType} ${e.entityId ?? ''} ${e.payloadJson ?? ''}')
        .join('\n');

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.barBackground,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.93,
        minChildSize: 0.4,
        maxChildSize: 0.97,
        expand: false,
        builder: (context, scroll) => Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    'Logs',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logs copiados')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        if (text.trim().isEmpty) return;
                        SharePlus.instance.share(ShareParams(text: text));
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Compartilhar'),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  text.isEmpty ? '(sem registros ainda)' : text,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
