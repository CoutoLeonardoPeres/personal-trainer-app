import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/access/access_tiers.dart';
import '../../core/auth/app_session.dart';
import '../../core/net/supabase_dns_preflight_stub.dart'
  if (dart.library.io) '../../core/net/supabase_dns_preflight_io.dart'
  as supabase_dns_preflight;
import '../../core/preferences/biometric_lock_prefs.dart';
import '../../core/version/app_version_marker.dart';
import '../../core/supabase/supabase_auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_constants.dart';
import '../../core/supabase/supabase_prefs_config.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../../core/preferences/rest_timer_prefs.dart';
import '../../core/preferences/workout_runtime_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/modern_loading.dart';
import '../../core/ui/keyboard_bottom_inset.dart';
import '../../core/workout/ios_lock_screen_live_activity.dart';
import '../../core/widgets/gradient_app_bar.dart';
import '../../core/ui/futuristic_background.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import '../../data/sync/supabase_manual_sync_service.dart';
import '../../data/sync/supabase_pull_sync_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(title: const Text('Configurações')),
      body: FuturisticBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _AppVersionSection(),
            const SizedBox(height: 8),
            const _SessionProfileSection(),
            const SizedBox(height: 8),
            const _AdminRbacSection(),
            const SizedBox(height: 8),
            const _SupabaseAuthSection(),
            const SizedBox(height: 8),
            const _BiometricLockTile(),
            const SizedBox(height: 8),
            const _SupabaseSyncSection(),
            const SizedBox(height: 8),
            const _BatterySaverWorkoutSection(),
            const SizedBox(height: 8),
            const _RestTimerSoundTile(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.password_rounded,
                color: AppColors.accentGreen,
              ),
              title: const Text(
                'Alterar senha',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Atualiza o SQLite local e, se existir sessão Supabase Auth, a senha na nuvem.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              onTap: () => _passwordSheet(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: AppColors.accentPink,
              ),
              title: const Text(
                'Sair da conta',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Encerra a sessão local e a Supabase (se houver). O app fecha; ao '
                'abrir de novo, será pedido e-mail e senha do cadastro.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              onTap: () => _confirmLogoutAndExit(context),
            ),
            Consumer<AppSession>(
              builder: (context, session, _) => ListTile(
                leading: const Icon(
                  Icons.article_outlined,
                  color: AppColors.accentGreen,
                ),
                title: const Text(
                  'Logs do Personal Gym',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  session.hasFullOrgAccess
                      ? 'Auditoria gravada no SQLite (ações e cadastros).'
                      : 'Disponível apenas para o perfil administrador.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                onTap: () => _logsSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmLogoutAndExit(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Sair da conta?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'A sessão será encerrada e o app fechado. Ao reabrir, use o e-mail e a senha '
          'do personal ou do aluno cadastrado neste aparelho.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Sair e fechar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      if (supabaseAppEnabled && SupabaseAuthService.currentSession != null) {
        await SupabaseAuthService.signOut();
      }
    } catch (_) {}
    if (!context.mounted) return;
    await context.read<AppSession>().markLoggedOutRequiresRelogin();
    if (!context.mounted) return;
    SystemNavigator.pop();
  }

  void _passwordSheet(BuildContext context) {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.barBackground,
      builder: (ctx) {
        return KeyboardBottomInsetPadding(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Alterar senha',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Senha atual = provisória ou a que usa hoje no aparelho. '
                  'Com Supabase Auth ativo, a nova senha é enviada também à nuvem.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: current,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Senha atual',
                    labelStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                TextField(
                  controller: next,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Nova senha',
                    labelStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nova senha',
                    labelStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (next.text != confirm.text) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Confirmação não coincide.'),
                        ),
                      );
                      return;
                    }
                    final repo = ctx.read<AppDataRepository>();
                    try {
                      if (supabaseAppEnabled &&
                          SupabaseAuthService.currentSession != null) {
                        await SupabaseAuthService.updatePassword(next.text);
                      }
                      await repo.changePasswordForCurrentSession(
                        currentPassword: current.text,
                        newPassword: next.text,
                      );
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                      return;
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Senha atualizada.')),
                      );
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logsSheet(BuildContext context) async {
    final session = context.read<AppSession>();
    if (!session.hasFullOrgAccess) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Somente administradores podem ver os logs de auditoria.',
          ),
        ),
      );
      return;
    }
    final repo = context.read<AppDataRepository>();
    final logs = await repo.allAuditLogs();
    final text = logs
        .map(
          (e) =>
              '${e.at.toIso8601String()} [${e.action}] ${e.entityType} ${e.entityId ?? ''} ${e.payloadJson ?? ''}',
        )
        .join('\n');

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.barBackground,
      builder: (ctx) => KeyboardBottomInsetPadding(
        child: DraggableScrollableSheet(
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
      ),
    );
  }

  static Future<void> _runTestConnection(BuildContext context) async {
    if (!supabaseAppEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sem Supabase ativo. Use --dart-define no build ou guarde anon key + URL em Nuvem (Supabase) e reinicie o Personal Gym.',
          ),
        ),
      );
      return;
    }
    final sync = context.read<SupabaseSyncController>();
    sync.beginDownload();
    final r = await SupabaseManualSyncService.testConnectionOnly();
    sync.endDownload();
    if (!context.mounted) return;
    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conexão OK (${r.elapsedMs ?? 0} ms)')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: Text(
          'Conexão falhou',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              r.message,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  static Future<void> _runFullSyncAndReport(BuildContext context) async {
    if (!supabaseAppEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sem Supabase ativo. Use --dart-define no build ou guarde anon key + URL em Nuvem (Supabase) e reinicie o Personal Gym.',
          ),
        ),
      );
      return;
    }
    final db = context.read<AppDatabase>();
    final sync = context.read<SupabaseSyncController>();
    final session = context.read<AppSession>();

    if (!context.mounted) return;
    // Não use await em showDialog aqui: o Future só completa quando o diálogo
    // some — o sync ficaria eternamente depois do await e o loading nunca fecharia.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.barBackground,
          content: Row(
            children: [
              ModernLoadingIndicator(size: 40),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Testando conexão e enviando dados (perfil atual)…',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final SupabaseManualSyncReport report;
    try {
      final svc = SupabaseManualSyncService(db, sync);
      report = await svc.testConnectionAndPushAll(session: session);
    } finally {
      if (context.mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }

    if (!context.mounted) return;

    final text = report.toReportText();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Relatório Supabase',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Relatório copiado')),
                );
              }
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () {
              SharePlus.instance.share(ShareParams(text: text));
            },
            child: const Text('Compartilhar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  static Future<void> _runImportFromCloudAndReport(BuildContext context) async {
    if (!supabaseAppEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sem Supabase ativo. Use --dart-define no build ou guarde anon key + URL em Nuvem (Supabase) e reinicie o Personal Gym.',
          ),
        ),
      );
      return;
    }
    final db = context.read<AppDatabase>();
    final sync = context.read<SupabaseSyncController>();
    final session = context.read<AppSession>();

    final netOk = await supabase_dns_preflight.preflightSupabaseDnsLookup();
    if (!netOk) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sem ligação de rede ou DNS não respondeu (supabase.co). '
              'Verifique Wi‑Fi ou dados móveis e tente de novo.',
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.barBackground,
          content: Row(
            children: [
              ModernLoadingIndicator(size: 40),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Baixando da nuvem (escopo do perfil atual)…',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final SupabasePullReport report;
    try {
      final svc = SupabasePullSyncService(db, sync, session: session);
      report = await svc.pullAllFromRemote().timeout(
        const Duration(minutes: 15),
        onTimeout: () => SupabasePullReport(
          connectionOk: false,
          connectionMessage:
              'Tempo limite (15 min). Dados grandes ou rede lenta — tente Wi‑Fi '
              'e volte a usar Importar da nuvem.',
          tables: const [],
          startedAt: DateTime.now(),
          finishedAt: DateTime.now(),
        ),
      );
    } finally {
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
    }

    if (!context.mounted) return;
    await context.read<AppDataRepository>().refreshSessionPersonalAdminFlag();
    if (!context.mounted) return;
    final text = report.toReportText();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Importação da nuvem',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Relatório copiado')),
                );
              }
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _AppVersionSection extends StatelessWidget {
  const _AppVersionSection();

  @override
  Widget build(BuildContext context) {
    final marker = appVersionMarkerLabel();
    return ListTile(
      leading: const Icon(Icons.verified_outlined, color: AppColors.accentGreen),
      title: const Text(
        'Versão do app',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        marker,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: 'Copiar versão',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: marker));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Versão copiada.')),
          );
        },
        icon: const Icon(Icons.copy_rounded, color: AppColors.textMuted),
      ),
    );
  }
}

class _SupabaseSyncSection extends StatelessWidget {
  const _SupabaseSyncSection();

  static String _supabaseIntroText(bool configured) {
    if (configured) {
      final source = supabaseFromDartDefine
          ? 'Chave via build (--dart-define). '
          : 'Chave guardada neste aparelho. ';
      return '${source}Fluxo: listas e formulários usam só o SQLite no celular; a nuvem é atualizada depois, em segundo plano, sem bloquear a tela. '
          'Alterações recentes seguem na fila de sync; o envio de todas as tabelas roda ao minimizar/sair do Personal Gym (no máx. a cada 30 min após sucesso, ou 4 min entre tentativas se falhar). '
          'Para forçar: Enviar tudo para a nuvem. A nuvem não preenche o celular sozinha — use Importar. '
          '401: use a anon key JWT (eyJ…) e a URL corretas do painel.';
    }
    return 'Sem chave ativa ainda. Opções: (1) --dart-define=SUPABASE_ANON_KEY=… e opcionalmente SUPABASE_URL no build; '
        '(2) preencher o formulário abaixo e reiniciar o Personal Gym por completo. O indicador na barra fica desligado até ligar.';
  }

  String _statusLabel(SupabaseCloudStatus s) {
    return switch (s) {
      SupabaseCloudStatus.unconfigured => 'Sem chave',
      SupabaseCloudStatus.unknown => 'Verificando…',
      SupabaseCloudStatus.online => 'Conectado',
      SupabaseCloudStatus.offline => 'Sem conexão / erro',
    };
  }

  @override
  Widget build(BuildContext context) {
    final configured = supabaseAppEnabled;
    return Card(
      color: AppColors.barBackground.withValues(alpha: 0.94),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nuvem (Supabase)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _supabaseIntroText(configured),
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.95),
                fontSize: 12,
              ),
            ),
            const _SupabaseLocalCredentialsCard(),
            if (configured) ...[
              const SizedBox(height: 10),
              Consumer<SupabaseSyncController>(
                builder: (context, sync, _) {
                  final err = sync.lastRemoteError;
                  final okAt = sync.lastRemoteSuccessAt;
                  final fidAt = sync.lastFidelityCheckAt;
                  final fidOk = sync.lastFidelityCountsAligned;
                  final fidDet = sync.lastFidelityDetail;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Estado: ${_statusLabel(sync.cloudStatus)} · Envios OK: ${sync.backgroundPushCount}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      if (okAt != null)
                        Text(
                          'Último envio bem-sucedido: ${okAt.toLocal()}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      if (fidAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          fidOk == true
                              ? 'Fidelidade (contagens): alinhado com a nuvem · ${fidAt.toLocal()}'
                              : fidOk == false
                              ? 'Fidelidade: divergência · ${fidAt.toLocal()}'
                              : 'Fidelidade: verificação falhou · ${fidAt.toLocal()}',
                          style: TextStyle(
                            color: fidOk == true
                                ? AppColors.accentGreen.withValues(alpha: 0.9)
                                : fidOk == false
                                ? Colors.orange.shade200
                                : Colors.red.shade200,
                            fontSize: 11,
                          ),
                        ),
                        if (fidDet != null && fidDet.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SelectableText(
                              fidDet,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                height: 1.25,
                              ),
                            ),
                          ),
                      ],
                      if (err != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Último erro: $err',
                          style: TextStyle(
                            color: Colors.red.shade200,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: configured
                  ? () => SettingsPage._runTestConnection(context)
                  : null,
              icon: const Icon(Icons.wifi_tethering, size: 20),
              label: const Text('Testar conexão'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: configured
                  ? () => SettingsPage._runFullSyncAndReport(context)
                  : null,
              icon: const Icon(Icons.cloud_upload_outlined, size: 20),
              label: const Text('Enviar tudo para a nuvem'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: configured
                  ? () => SettingsPage._runImportFromCloudAndReport(context)
                  : null,
              icon: const Icon(Icons.cloud_download_outlined, size: 20),
              label: const Text('Importar da nuvem (SQLite)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupabaseLocalCredentialsCard extends StatefulWidget {
  const _SupabaseLocalCredentialsCard();

  @override
  State<_SupabaseLocalCredentialsCard> createState() =>
      _SupabaseLocalCredentialsCardState();
}

class _SupabaseLocalCredentialsCardState
    extends State<_SupabaseLocalCredentialsCard> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _anonCtrl;
  bool _loading = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: SupabaseConstants.defaultUrl);
    _anonCtrl = TextEditingController();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final creds = await SupabasePrefsConfig.loadForStartup();
    if (!mounted) return;
    if (creds != null) {
      _urlCtrl.text = creds.url;
      _anonCtrl.text = creds.anonKey;
    } else {
      _urlCtrl.text = SupabaseConstants.defaultUrl;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _anonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var anon = _anonCtrl.text.trim();
    // Aspas/colagens acidentais do terminal
    if ((anon.startsWith('"') && anon.endsWith('"')) ||
        (anon.startsWith("'") && anon.endsWith("'"))) {
      anon = anon.substring(1, anon.length - 1).trim();
    }
    if (anon.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cole a chave anon (JWT).')));
      return;
    }
    if (anon.startsWith('sb_publishable_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Isto é a chave publishable. Use a anon public (JWT que começa com eyJ…) em '
            'Supabase → Settings → API → Legacy API keys.',
          ),
          duration: Duration(seconds: 7),
        ),
      );
      return;
    }
    if (!anon.startsWith('eyJ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aviso: a anon costuma ser um JWT (eyJ…). Se a ligação falhar, confira no painel.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
    final url = _urlCtrl.text.trim();
    await SupabasePrefsConfig.save(
      anonKey: anon,
      url: url.isEmpty ? null : url,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Guardado. Feche o Personal Gym por completo (remova da lista de apps recentes) e abra de novo para o Supabase ligar.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: Text(
          'Apagar chave?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Só após reiniciar o Personal Gym a nuvem ficará desligada.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SupabasePrefsConfig.clear();
    _anonCtrl.clear();
    _urlCtrl.text = SupabaseConstants.defaultUrl;
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chave removida. Reinicie o Personal Gym por completo.'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (supabaseFromDartDefine) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'Chave injetada no build (--dart-define); o formulário abaixo não é usado na inicialização.',
          style: TextStyle(
            color: AppColors.textMuted.withValues(alpha: 0.9),
            fontSize: 11,
          ),
        ),
      );
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: ModernLoadingIndicator(size: 28),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'Chave neste aparelho (sem Xcode)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            labelText: 'URL do projeto',
            labelStyle: const TextStyle(color: AppColors.textMuted),
            hintText: 'https://xxx.supabase.co',
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _anonCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'SUPABASE_ANON_KEY (JWT eyJ…)',
            labelStyle: const TextStyle(color: AppColors.textMuted),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility : Icons.visibility_off,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _save,
                child: const Text('Guardar'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _clear, child: const Text('Apagar')),
          ],
        ),
      ],
    );
  }
}

String _sessionRoleLabel(SessionRole r) {
  switch (r) {
    case SessionRole.adminPersonal:
      return 'Administrador';
    case SessionRole.personalTrainer:
      return 'Personal';
    case SessionRole.student:
      return 'Aluno';
  }
}

class _SessionProfileSection extends StatelessWidget {
  const _SessionProfileSection();

  Future<void> _applyRole(BuildContext context, SessionRole role) async {
    final session = context.read<AppSession>();
    final repo = context.read<AppDataRepository>();
    switch (role) {
      case SessionRole.adminPersonal:
        final personals = await repo.watchPersonalsAlphabetical().first;
        PersonalEntity? pick;
        for (final p in personals) {
          if (p.isAdmin) {
            pick = p;
            break;
          }
        }
        pick ??= personals.isNotEmpty ? personals.first : null;
        await session.setSession(
          role: SessionRole.adminPersonal,
          personalId: pick?.id,
          studentId: null,
        );
        await repo.refreshSessionPersonalAdminFlag();
        return;
      case SessionRole.personalTrainer:
        final personals = await repo.watchPersonalsAlphabetical().first;
        if (personals.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cadastre ao menos um personal.')),
            );
          }
          return;
        }
        final preferred = session.personalId;
        final id =
            (preferred != null && personals.any((p) => p.id == preferred))
            ? preferred
            : personals.first.id;
        await session.setSession(
          role: SessionRole.personalTrainer,
          personalId: id,
          studentId: null,
        );
        await repo.refreshSessionPersonalAdminFlag();
        return;
      case SessionRole.student:
        final students = await repo.watchStudentsForSessionPicker().first;
        if (students.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cadastre ao menos um aluno.')),
            );
          }
          return;
        }
        final preferred = session.studentId;
        final id = (preferred != null && students.any((s) => s.id == preferred))
            ? preferred
            : students.first.id;
        await session.setSession(
          role: SessionRole.student,
          personalId: null,
          studentId: id,
        );
        await repo.refreshSessionPersonalAdminFlag();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final repo = context.watch<AppDataRepository>();

    return Card(
      color: AppColors.barBackground.withValues(alpha: 0.94),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Perfil da sessão',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Quem está usando o Personal Gym neste aparelho (até haver login). Define quais alunos e treinos aparecem.',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.95),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SessionRole>(
              initialValue: session.role,
              dropdownColor: AppColors.barBackground,
              decoration: const InputDecoration(
                labelText: 'Papel',
                labelStyle: TextStyle(color: AppColors.textMuted),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              items: SessionRole.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(_sessionRoleLabel(r)),
                    ),
                  )
                  .toList(),
              onChanged: (r) async {
                if (r == null) return;
                await _applyRole(context, r);
              },
            ),
            if (session.role == SessionRole.personalTrainer) ...[
              const SizedBox(height: 12),
              StreamBuilder<List<PersonalEntity>>(
                stream: repo.watchPersonalsAlphabetical(),
                builder: (context, snap) {
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Text(
                      'Nenhum personal cadastrado.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    );
                  }
                  final pid = session.personalId;
                  final effective =
                      (pid != null && list.any((p) => p.id == pid))
                      ? pid
                      : list.first.id;
                  return DropdownButtonFormField<String>(
                    initialValue: effective,
                    dropdownColor: AppColors.barBackground,
                    decoration: const InputDecoration(
                      labelText: 'Personal logado',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: list
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (id) async {
                      if (id == null) return;
                      await session.setSession(
                        role: SessionRole.personalTrainer,
                        personalId: id,
                        studentId: null,
                      );
                      if (context.mounted) {
                        await context
                            .read<AppDataRepository>()
                            .refreshSessionPersonalAdminFlag();
                      }
                    },
                  );
                },
              ),
            ],
            if (session.role == SessionRole.student) ...[
              const SizedBox(height: 12),
              StreamBuilder<List<StudentEntity>>(
                stream: repo.watchStudentsForSessionPicker(),
                builder: (context, snap) {
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Text(
                      'Nenhum aluno cadastrado.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    );
                  }
                  final sid = session.studentId;
                  final effective =
                      (sid != null && list.any((s) => s.id == sid))
                      ? sid
                      : list.first.id;
                  return DropdownButtonFormField<String>(
                    initialValue: effective,
                    dropdownColor: AppColors.barBackground,
                    decoration: const InputDecoration(
                      labelText: 'Aluno logado',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: list
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (id) async {
                      if (id == null) return;
                      await session.setSession(
                        role: SessionRole.student,
                        personalId: null,
                        studentId: id,
                      );
                      if (context.mounted) {
                        await context
                            .read<AppDataRepository>()
                            .refreshSessionPersonalAdminFlag();
                      }
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminRbacSection extends StatelessWidget {
  const _AdminRbacSection();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    if (!session.hasFullOrgAccess) return const SizedBox.shrink();
    final repo = context.watch<AppDataRepository>();
    return Card(
      color: AppColors.barBackground.withValues(alpha: 0.94),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Perfis de acesso (admin)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ajusta access_tier no SQLite (e na nuvem no próximo sync). '
              'Premium: opcional data de fim — após ela o app faz downgrade para standard ao abrir.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<StudentEntity>>(
              stream: repo.watchStudentsAlphabetical(),
              builder: (context, stSnap) {
                final students = stSnap.data ?? [];
                return StreamBuilder<List<PersonalEntity>>(
                  stream: repo.watchPersonalsAlphabetical(),
                  builder: (context, pSnap) {
                    final personals = pSnap.data ?? [];
                    return _AdminRbacForm(
                      repo: repo,
                      students: students,
                      personals: personals,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRbacForm extends StatefulWidget {
  const _AdminRbacForm({
    required this.repo,
    required this.students,
    required this.personals,
  });

  final AppDataRepository repo;
  final List<StudentEntity> students;
  final List<PersonalEntity> personals;

  @override
  State<_AdminRbacForm> createState() => _AdminRbacFormState();
}

class _AdminRbacFormState extends State<_AdminRbacForm> {
  String? _studentId;
  String _studentTier = AccessTiers.studentFree;
  DateTime? _studentPremiumUntil;
  String? _personalId;
  String _personalTier = AccessTiers.personalStarter;
  final _capCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.students.isNotEmpty) {
      _studentId = widget.students.first.id;
      _syncStudentFields(widget.students.first);
    }
    if (widget.personals.isNotEmpty) {
      _personalId = widget.personals.first.id;
      _syncPersonalFields(widget.personals.first);
    }
  }

  @override
  void didUpdateWidget(covariant _AdminRbacForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.students.isEmpty) {
      _studentId = null;
    } else if (_studentId == null ||
        !widget.students.any((s) => s.id == _studentId)) {
      _studentId = widget.students.first.id;
      _syncStudentFields(widget.students.first);
    }
    if (widget.personals.isEmpty) {
      _personalId = null;
    } else if (_personalId == null ||
        !widget.personals.any((p) => p.id == _personalId)) {
      _personalId = widget.personals.first.id;
      _syncPersonalFields(widget.personals.first);
    }
  }

  void _syncStudentFields(StudentEntity s) {
    _studentTier = s.accessTier;
    _studentPremiumUntil = s.premiumPlanExpiresAt;
  }

  void _syncPersonalFields(PersonalEntity p) {
    _personalTier = p.accessTier;
    _capCtrl.text = p.maxStudentsCap?.toString() ?? '';
  }

  @override
  void dispose() {
    _capCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPremiumDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _studentPremiumUntil ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d != null) {
      setState(() => _studentPremiumUntil = DateTime(d.year, d.month, d.day, 23, 59, 59));
    }
  }

  Future<void> _applyStudent() async {
    final id = _studentId;
    if (id == null) return;
    try {
      await widget.repo.adminSetStudentAccessTier(
        studentId: id,
        accessTier: _studentTier,
        premiumPlanExpiresAt: _studentTier == AccessTiers.studentPremium
            ? _studentPremiumUntil
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil do aluno atualizado.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _applyPersonal() async {
    final id = _personalId;
    if (id == null) return;
    int? cap;
    final t = _capCtrl.text.trim();
    if (t.isNotEmpty) {
      cap = int.tryParse(t);
    }
    try {
      await widget.repo.adminSetPersonalAccessTier(
        personalId: id,
        accessTier: _personalTier,
        maxStudentsCap: cap,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil do personal atualizado.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Aluno',
          style: TextStyle(
            color: AppColors.accentGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.students.isEmpty)
          const Text(
            'Nenhum aluno.',
            style: TextStyle(color: AppColors.textMuted),
          )
        else ...[
          DropdownButtonFormField<String>(
            initialValue: _studentId,
            dropdownColor: AppColors.barBackground,
            decoration: const InputDecoration(
              labelText: 'Aluno',
              labelStyle: TextStyle(color: AppColors.textMuted),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            items: widget.students
                .map(
                  (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final s = widget.students.firstWhere((e) => e.id == v);
              setState(() {
                _studentId = v;
                _syncStudentFields(s);
              });
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _studentTier,
            dropdownColor: AppColors.barBackground,
            decoration: const InputDecoration(
              labelText: 'access_tier',
              labelStyle: TextStyle(color: AppColors.textMuted),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            items: const [
              DropdownMenuItem(
                value: AccessTiers.studentFree,
                child: Text('aluno_free'),
              ),
              DropdownMenuItem(
                value: AccessTiers.studentBasic,
                child: Text('aluno_basic'),
              ),
              DropdownMenuItem(
                value: AccessTiers.studentPremium,
                child: Text('aluno_premium'),
              ),
              DropdownMenuItem(
                value: AccessTiers.studentStandard,
                child: Text('aluno_standard'),
              ),
              DropdownMenuItem(
                value: AccessTiers.legacy,
                child: Text('legacy'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _studentTier = v);
            },
          ),
          if (_studentTier == AccessTiers.studentPremium) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Premium válido até',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              subtitle: Text(
                _studentPremiumUntil == null
                    ? '(não definido — não expira pelo relógio local)'
                    : MaterialLocalizations.of(context).formatFullDate(
                        _studentPremiumUntil!,
                      ),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              trailing: TextButton(
                onPressed: _pickPremiumDate,
                child: const Text('Data'),
              ),
            ),
          ],
          FilledButton(
            onPressed: _applyStudent,
            child: const Text('Aplicar aluno'),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Personal',
          style: TextStyle(
            color: AppColors.accentGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.personals.isEmpty)
          const Text(
            'Nenhum personal.',
            style: TextStyle(color: AppColors.textMuted),
          )
        else ...[
          DropdownButtonFormField<String>(
            initialValue: _personalId,
            dropdownColor: AppColors.barBackground,
            decoration: const InputDecoration(
              labelText: 'Personal',
              labelStyle: TextStyle(color: AppColors.textMuted),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            items: widget.personals
                .map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final p = widget.personals.firstWhere((e) => e.id == v);
              setState(() {
                _personalId = v;
                _syncPersonalFields(p);
              });
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _personalTier,
            dropdownColor: AppColors.barBackground,
            decoration: const InputDecoration(
              labelText: 'access_tier',
              labelStyle: TextStyle(color: AppColors.textMuted),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            items: const [
              DropdownMenuItem(
                value: AccessTiers.personalStarter,
                child: Text('personal_starter'),
              ),
              DropdownMenuItem(
                value: AccessTiers.personalPro,
                child: Text('personal_pro'),
              ),
              DropdownMenuItem(
                value: AccessTiers.personalProPlus,
                child: Text('personal_pro_plus'),
              ),
              DropdownMenuItem(
                value: AccessTiers.legacy,
                child: Text('legacy'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _personalTier = v);
            },
          ),
          TextField(
            controller: _capCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'max_students_cap (vazio = padrão do tier)',
              labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _applyPersonal,
            child: const Text('Aplicar personal'),
          ),
        ],
      ],
    );
  }
}

class _SupabaseAuthSection extends StatelessWidget {
  const _SupabaseAuthSection();

  @override
  Widget build(BuildContext context) {
    if (!supabaseAppEnabled) return const SizedBox.shrink();
    return Card(
      color: AppColors.barBackground.withValues(alpha: 0.94),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Conta Supabase (JWT)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Necessário para RLS com auth.uid() após aplicar '
              'scripts/supabase_rls_strict_auth_uid.sql. Ligue auth_user_id nas tabelas personals/students.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _SupabaseAuthForm(),
          ],
        ),
      ),
    );
  }
}

class _SupabaseAuthForm extends StatefulWidget {
  @override
  State<_SupabaseAuthForm> createState() => _SupabaseAuthFormState();
}

class _SupabaseAuthFormState extends State<_SupabaseAuthForm> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = SupabaseAuthService.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          u == null
              ? 'Estado: sem sessão Auth'
              : 'Sessão: ${u.email ?? u.id}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        if (u == null) ...[
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await SupabaseAuthService.signInWithGoogle();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Conectar com Google (Gmail)'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await SupabaseAuthService.signInWithGitHub();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.code_rounded),
            label: const Text('Conectar com GitHub'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'E-mail',
              labelStyle: TextStyle(color: AppColors.textMuted),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _pass,
            obscureText: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Senha',
              labelStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await SupabaseAuthService.signInWithEmail(
                        email: _email.text.trim(),
                        password: _pass.text,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sessão Supabase iniciada.')),
                        );
                        setState(() {});
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Entrar'),
          ),
        ] else
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await SupabaseAuthService.signOut();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sessão encerrada.')),
                        );
                        setState(() {});
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Sair da conta Supabase'),
          ),
      ],
    );
  }
}

class _BiometricLockTile extends StatefulWidget {
  const _BiometricLockTile();

  @override
  State<_BiometricLockTile> createState() => _BiometricLockTileState();
}

class _BiometricLockTileState extends State<_BiometricLockTile> {
  bool? _on;

  @override
  void initState() {
    super.initState();
    BiometricLockPrefs.enabled.then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _on;
    return SwitchListTile(
      secondary: const Icon(
        Icons.fingerprint_rounded,
        color: AppColors.accentGreen,
      ),
      title: const Text(
        'Biometria ao voltar do segundo plano',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        v == null
            ? 'Carregando…'
            : 'Face ID / impressão digital ao reabrir o app (não substitui senha).',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      value: v ?? false,
      onChanged: v == null
          ? null
          : (nv) async {
              await BiometricLockPrefs.setEnabled(nv);
              if (mounted) setState(() => _on = nv);
            },
    );
  }
}

class _RestTimerSoundTile extends StatefulWidget {
  const _RestTimerSoundTile();

  @override
  State<_RestTimerSoundTile> createState() => _RestTimerSoundTileState();
}

class _RestTimerSoundTileState extends State<_RestTimerSoundTile> {
  bool? _soundEnabled;

  @override
  void initState() {
    super.initState();
    RestTimerPrefs.isSoundEnabled().then((v) {
      if (mounted) setState(() => _soundEnabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _soundEnabled;
    return SwitchListTile(
      secondary: const Icon(
        Icons.timer_outlined,
        color: AppColors.accentGreen,
      ),
      title: const Text(
        'Som no timer de descanso',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        loaded == null
            ? 'Carregando…'
            : 'Tocar um aviso ao fim do intervalo entre séries durante o treino.',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      value: loaded ?? true,
      onChanged: loaded == null
          ? null
          : (v) async {
              await RestTimerPrefs.setSoundEnabled(v);
              if (mounted) setState(() => _soundEnabled = v);
            },
    );
  }
}

class _BatterySaverWorkoutSection extends StatelessWidget {
  const _BatterySaverWorkoutSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.barBackground.withValues(alpha: 0.94),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bateria (treino)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Desative recursos que gastam mais bateria durante o treino.',
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.95),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            const _RestIntervalEnabledTile(),
            const _LiveActivityEnabledTile(),
          ],
        ),
      ),
    );
  }
}

class _RestIntervalEnabledTile extends StatefulWidget {
  const _RestIntervalEnabledTile();

  @override
  State<_RestIntervalEnabledTile> createState() =>
      _RestIntervalEnabledTileState();
}

class _RestIntervalEnabledTileState extends State<_RestIntervalEnabledTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    WorkoutRuntimePrefs.isRestIntervalEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _enabled;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(
        Icons.timer_outlined,
        color: AppColors.accentGreen,
      ),
      title: const Text(
        'Timer de intervalo entre séries',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        v == null
            ? 'Carregando…'
            : 'Quando desligado, o app não abre o countdown automático após registrar uma série.',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      value: v ?? true,
      onChanged: v == null
          ? null
          : (nv) async {
              await WorkoutRuntimePrefs.setRestIntervalEnabled(nv);
              if (mounted) setState(() => _enabled = nv);
            },
    );
  }
}

class _LiveActivityEnabledTile extends StatefulWidget {
  const _LiveActivityEnabledTile();

  @override
  State<_LiveActivityEnabledTile> createState() =>
      _LiveActivityEnabledTileState();
}

class _LiveActivityEnabledTileState extends State<_LiveActivityEnabledTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    WorkoutRuntimePrefs.isLiveActivityEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _enabled;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(
        Icons.sensors_rounded,
        color: AppColors.accentGreen,
      ),
      title: const Text(
        'Atividade ao vivo (iOS)',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        v == null
            ? 'Carregando…'
            : 'Mostra progresso no ecrã bloqueado/Dynamic Island. Desative para economizar bateria.',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      value: v ?? true,
      onChanged: v == null
          ? null
          : (nv) async {
              await WorkoutRuntimePrefs.setLiveActivityEnabled(nv);
              if (!nv) {
                await IosLockScreenLiveActivity.endIfAny();
              }
              if (mounted) setState(() => _enabled = nv);
            },
    );
  }
}
