import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/app_session.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/supabase_constants.dart';
import '../../core/supabase/supabase_prefs_config.dart';
import '../../core/supabase/supabase_sync_controller.dart';
import '../../core/preferences/rest_timer_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/keyboard_bottom_inset.dart';
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
            const _SessionProfileSection(),
            const SizedBox(height: 8),
            const _SupabaseSyncSection(),
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
                'Primeiro acesso e troca de senha provisória (fluxo completo com auth).',
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
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.barBackground,
                    title: const Text(
                      'Conta',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    content: const Text(
                      'Logout local — integrar com Supabase Auth quando o backend estiver ativo.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
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
                  session.isAdminPersonal
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

  void _passwordSheet(BuildContext context) {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.barBackground,
      builder: (ctx) => KeyboardBottomInsetPadding(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
      ),
    );
  }

  Future<void> _logsSheet(BuildContext context) async {
    final session = context.read<AppSession>();
    if (!session.isAdminPersonal) {
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
              CircularProgressIndicator(),
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
              CircularProgressIndicator(),
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
      report = await svc.pullAllFromRemote();
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
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
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
