import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/br_input_formatters.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/modern_loading.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

class PersonaisPage extends StatelessWidget {
  const PersonaisPage({super.key});

  static Future<void> _showPersonalPasswordResetDialog(
    BuildContext context, {
    required String loginEmail,
    required String password,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.barBackground,
        title: const Text(
          'Nova senha provisória',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No app, o login do personal é o e-mail cadastrado. '
              'No próximo acesso será pedida troca de senha.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              'E-mail (login):',
              style: TextStyle(
                color: AppColors.splashMint.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              loginEmail.isEmpty ? '(e-mail em branco no cadastro)' : loginEmail,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontStyle: loginEmail.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Senha provisória:',
              style: TextStyle(
                color: AppColors.splashMint,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              password,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Guarde ou copie agora. Se o envio por e-mail estiver ativo, '
              'a senha também foi enviada para a caixa de entrada.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final clip = loginEmail.isEmpty
                  ? 'Senha provisória: $password'
                  : 'Login (e-mail): $loginEmail\nSenha: $password';
              await Clipboard.setData(ClipboardData(text: clip));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Copiado para a área de transferência')),
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

  static String _personalSubtitle(PersonalEntity e) {
    final parts = <String>[
      if (e.email.isNotEmpty) e.email,
      if ((e.phoneMobile ?? '').isNotEmpty) brFormatPhoneDisplay(e.phoneMobile!),
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    return Scaffold(
      appBar: buildGradientAppBar(title: const Text('Personais')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(context, repo, null),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: FuturisticBackground(
        child: StreamBuilder<List<PersonalEntity>>(
          stream: repo.watchPersonalsAlphabetical(),
          builder: (context, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum personal cadastrado.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final e = list[i];
                void openForm() => _form(context, repo, e);
                return SwipeableRegistryCard(
                  slidableKey: e.id,
                  title: e.name,
                  subtitle: _personalSubtitle(e),
                  onEdit: openForm,
                  onCardTap: openForm,
                  showEditOnSwipe: false,
                  onDelete: () async {
                    final ok = await confirmDeleteDialog(context, itemName: e.name);
                    if (ok == true && context.mounted) await repo.deletePersonal(e.id);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _form(BuildContext context, AppDataRepository repo, PersonalEntity? x) {
    final name = TextEditingController(text: x?.name ?? '');
    final cpf = TextEditingController(
      text: brFormatCpfDisplay(x?.cpf ?? ''),
    );
    final reg = TextEditingController(text: x?.professionalRegistry ?? '');
    final rua = TextEditingController(text: x?.street ?? '');
    final num = TextEditingController(text: x?.number ?? '');
    final comp = TextEditingController(text: x?.complement ?? '');
    final cidade = TextEditingController(text: x?.city ?? '');
    final cep = TextEditingController(
      text: brFormatCepDisplay(x?.cep ?? ''),
    );
    final email = TextEditingController(text: x?.email ?? '');
    final phoneCommercialC = TextEditingController(
      text: brFormatPhoneDisplay(x?.phoneCommercial ?? ''),
    );
    final phoneMobileC = TextEditingController(
      text: brFormatPhoneDisplay(x?.phoneMobile ?? ''),
    );
    String? uf = x?.stateUf;
    var isAdmin = x?.isAdmin ?? false;
    var passwordHashForSave = x?.passwordHash;
    var mustChangeForSave = x?.mustChangePassword ?? true;
    var pwdBusy = false;

    showAppModalSheet<void>(
      context: context,
      title: x == null ? 'Cadastrar novo personal' : 'Editar personal',
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, setSt) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            AppTextField(controller: name, label: 'Nome', required: true),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(
              controller: cpf,
              label: 'CPF',
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [BrCpfInputFormatter()],
            ),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(controller: reg, label: 'Registro profissional', required: true),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(controller: rua, label: 'Logradouro', required: true),
            const SizedBox(height: kCadastroFieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: num,
                    label: 'Número',
                    required: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(controller: comp, label: 'Complemento'),
                ),
              ],
            ),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(controller: cidade, label: 'Cidade', required: true),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(
              controller: cep,
              label: 'CEP',
              required: true,
              hint: '00000-000',
              keyboardType: TextInputType.number,
              inputFormatters: [BrCepInputFormatter()],
            ),
            const SizedBox(height: kCadastroFieldGap),
            BrazilStateDropdown(
              valueUf: uf,
              requiredField: true,
              onChanged: (v) => setSt(() => uf = v),
            ),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(
              controller: email,
              label: 'E-mail',
              required: true,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(
              controller: phoneCommercialC,
              label: 'Telefone comercial',
              hint: '(11) 3456-7890',
              keyboardType: TextInputType.phone,
              inputFormatters: [BrPhoneLandlineInputFormatter()],
            ),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(
              controller: phoneMobileC,
              label: 'Celular',
              hint: '(11) 98765-4321',
              keyboardType: TextInputType.phone,
              inputFormatters: [BrPhoneMobileInputFormatter()],
            ),
            const SizedBox(height: kCadastroFieldGap),
            Text(
              'Senha provisória: enviar por e-mail quando o serviço de e-mail estiver configurado.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
            ),
            if (x != null) ...[
              const SizedBox(height: kCadastroFieldGap),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.splashMint,
                    side: BorderSide(
                      color: AppColors.splashMint.withValues(alpha: 0.65),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  onPressed: pwdBusy
                      ? null
                      : () async {
                          final go = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              backgroundColor: AppColors.barBackground,
                              title: const Text(
                                'Gerar nova senha?',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              content: Text(
                                'A senha atual deixará de funcionar. Será criada uma '
                                'senha provisória; no próximo login será pedida troca de senha.',
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
                                  child: const Text('Gerar'),
                                ),
                              ],
                            ),
                          );
                          if (go != true || !ctx.mounted) return;
                          setSt(() => pwdBusy = true);
                          try {
                            final r = await repo.adminGenerateNewPersonalPassword(x.id);
                            passwordHashForSave = r.provisionalPassword;
                            mustChangeForSave = true;
                            if (!ctx.mounted) return;
                            if (r.emailSent) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Nova senha enviada por e-mail (verifique spam). '
                                    'Use essa senha no próximo acesso.',
                                  ),
                                ),
                              );
                            } else if (context.mounted) {
                              await _showPersonalPasswordResetDialog(
                                context,
                                loginEmail: r.loginEmail,
                                password: r.provisionalPassword,
                              );
                            }
                          } on ArgumentError catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.message ?? 'Não foi possível gerar.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Erro: $e')),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setSt(() => pwdBusy = false);
                          }
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (pwdBusy)
                        const ModernLoadingIndicator(size: 20)
                      else
                        const Icon(Icons.vpn_key_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        pwdBusy ? 'A gerar…' : 'Gerar nova senha',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: kCadastroFieldGap),
            SwitchListTile.adaptive(
              value: isAdmin,
              onChanged: (v) => setSt(() => isAdmin = v),
              title: const Text(
                'Administrador do Personal Gym',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Vê todos os alunos e registros; demais personais só veem os próprios alunos.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              activeThumbColor: AppColors.accentGreen,
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: x == null ? 'Salvar personal' : 'Atualizar personal',
              icon: Icons.check_rounded,
              onPressed: () async {
                if (name.text.trim().isEmpty || cpf.text.trim().isEmpty || uf == null) {
                  return;
                }
                final cpfDigits = brDigitsOnly(cpf.text);
                if (cpfDigits.length != 11) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('CPF deve ter 11 dígitos.')),
                    );
                  }
                  return;
                }
                final cepDigits = brDigitsOnly(cep.text);
                if (cepDigits.length != 8) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('CEP deve ter 8 dígitos.')),
                    );
                  }
                  return;
                }
                final telCom = brDigitsOnly(phoneCommercialC.text);
                final telCel = brDigitsOnly(phoneMobileC.text);
                await repo.upsertPersonal(
                  id: x?.id,
                  name: name.text.trim(),
                  cpf: cpfDigits,
                  professionalRegistry: reg.text.trim(),
                  street: rua.text.trim(),
                  number: num.text.trim(),
                  complement: comp.text.trim().isEmpty ? null : comp.text.trim(),
                  city: cidade.text.trim(),
                  stateUf: uf!,
                  cep: cepDigits,
                  phoneCommercial: telCom.isEmpty ? null : telCom,
                  phoneMobile: telCel.isEmpty ? null : telCel,
                  email: email.text.trim(),
                  mustChangePassword: mustChangeForSave,
                  passwordHash: passwordHashForSave,
                  isAdmin: isAdmin,
                );
                await repo.refreshSessionPersonalAdminFlag();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
