import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/br_input_formatters.dart';
import '../../../core/utils/student_archive_display_utils.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/modern_loading.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

class AlunosPage extends StatelessWidget {
  const AlunosPage({super.key});

  static void _showAccessLinkSentSnackBar(BuildContext context, String email) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Link de acesso enviado para $email. '
          'Peça ao aluno para verificar e-mail e spam.',
        ),
      ),
    );
  }

  static String _studentSubtitle(StudentEntity e) {
    final parts = <String>[
      if ((e.email ?? '').trim().isNotEmpty) e.email!.trim(),
      if ((e.phoneMobile ?? '').isNotEmpty)
        brFormatPhoneDisplay(e.phoneMobile!),
      if ((e.city ?? '').trim().isNotEmpty) e.city!.trim(),
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  static String _archivedListSubtitle(StudentEntity e) {
    final d = e.archivedAt;
    if (d == null) {
      return 'Inativo · toque em Reativar para voltar às listas e ao calendário';
    }
    final ds =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return 'Inativado em $ds · complete e-mail, academias e nova senha no cadastro';
  }

  static Future<void> _showArchivedStudentsSheet(
    BuildContext context,
    AppDataRepository repo,
  ) async {
    await showAppModalSheet<void>(
      context: context,
      title: 'Alunos inativos',
      subtitle:
          'Alunos inativados ficam aqui só para reativação. Reativar devolve o nome '
          'às listas e ao calendário; em seguida complete o cadastro e defina nova senha.',
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => StreamBuilder<List<StudentEntity>>(
        stream: repo.watchArchivedStudentsAlphabetical(),
        builder: (context, snap) {
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(
                  snap.connectionState == ConnectionState.waiting
                      ? 'Carregando…'
                      : 'Nenhum aluno inativo no seu escopo.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final e = list[i];
              final stripped = studentNameWithoutArchivePrefix(e.name);
              final title = stripped.trim().isEmpty ? 'Aluno' : stripped.trim();
              return Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.cadastroCardBorder.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.cadastroCardBorder.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.person_off_rounded,
                          color: AppColors.cadastroCardBorder.withValues(
                            alpha: 0.85,
                          ),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _archivedListSubtitle(e),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.52),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: AppColors.barBackground,
                                title: const Text(
                                  'Reativar aluno?',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                content: Text(
                                  '"$title" volta para a lista de alunos ativos. '
                                  'Abra o cadastro em seguida para definir e-mail, academias '
                                  'e uma nova senha de acesso ao app.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('Reativar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true || !ctx.mounted) return;
                            try {
                              await repo.unarchiveStudent(e.id);
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$title reativado. Abra o cadastro do aluno para '
                                      'completar dados e definir senha.',
                                    ),
                                  ),
                                );
                              }
                            } on ArgumentError catch (err) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      err.message ??
                                          'Não foi possível reativar.',
                                    ),
                                  ),
                                );
                              }
                            } catch (err) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Erro: $err')),
                                );
                              }
                            }
                          },
                          child: const Text('Reativar'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    final showArchived = !repo.session.isStudent;
    return Scaffold(
      appBar: buildGradientAppBar(
        title: const Text('Alunos'),
        actions: showArchived
            ? [
                IconButton(
                  tooltip: 'Alunos inativos — reativar',
                  onPressed: () => _showArchivedStudentsSheet(context, repo),
                  icon: const Icon(Icons.archive_outlined),
                ),
              ]
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final gyms = await repo.watchGymsAlphabetical().first;
          if (!context.mounted) return;
          _form(context, repo, null, gyms, const {});
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: FuturisticBackground(
        child: StreamBuilder<List<StudentEntity>>(
          stream: repo.watchStudentsAlphabetical(),
          builder: (context, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum aluno cadastrado.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final e = list[i];
                Future<void> openForm() async {
                  final gList = await repo.watchGymsAlphabetical().first;
                  final sel = await repo.gymIdsForStudent(e.id);
                  if (!context.mounted) return;
                  _form(context, repo, e, gList, sel.toSet());
                }

                return SwipeableRegistryCard(
                  slidableKey: e.id,
                  title: e.name,
                  subtitle: _studentSubtitle(e),
                  onEdit: () => openForm(),
                  onCardTap: () => openForm(),
                  showEditOnSwipe: false,
                  onDelete: () async {
                    final ok = await confirmDeleteDialog(
                      context,
                      itemName: e.name,
                    );
                    if (ok == true && context.mounted) {
                      await repo.deleteStudent(e.id);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _form(
    BuildContext context,
    AppDataRepository repo,
    StudentEntity? x,
    List<GymEntity> gyms,
    Set<String> selectedGymIds,
  ) {
    final name = TextEditingController(text: x?.name ?? '');
    final email = TextEditingController(text: x?.email ?? '');
    final goal = TextEditingController(text: x?.goal ?? '');
    final cpf = TextEditingController(text: brFormatCpfDisplay(x?.cpf ?? ''));
    final rua = TextEditingController(text: x?.street ?? '');
    final num = TextEditingController(text: x?.number ?? '');
    final comp = TextEditingController(text: x?.complement ?? '');
    final bairro = TextEditingController(text: x?.district ?? '');
    final cidade = TextEditingController(text: x?.city ?? '');
    final cep = TextEditingController(text: x?.cep ?? '');
    final phoneCommercialC = TextEditingController(
      text: brFormatPhoneDisplay(x?.phoneCommercial ?? ''),
    );
    final phoneMobileC = TextEditingController(
      text: brFormatPhoneDisplay(x?.phoneMobile ?? ''),
    );
    DateTime? birth = x?.birthDate;
    String? uf = x?.stateUf;
    var sel = Set<String>.from(selectedGymIds);
    var mustChangeForSave = x?.mustChangePassword ?? true;
    var pwdBusy = false;

    showAppModalSheet<void>(
      context: context,
      title: x == null ? 'Cadastrar novo aluno' : 'Editar aluno',
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, setSt) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            AppTextField(
              controller: name,
              label: 'Nome do aluno',
              required: true,
            ),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(
              controller: email,
              label: x == null
                  ? 'E-mail (obrigatório — é o login no app)'
                  : 'E-mail',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(controller: goal, label: 'Objetivo', maxLines: 2),
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
            AppTextField(
              controller: cpf,
              label: 'CPF',
              keyboardType: TextInputType.number,
              inputFormatters: [BrCpfInputFormatter()],
            ),
            const SizedBox(height: kCadastroFieldGap),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.cadastroCardBorder.withValues(alpha: 0.048),
                  border: Border.all(
                    color: AppColors.cadastroCardBorder.withValues(alpha: 0.44),
                  ),
                ),
                child: ListTile(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  title: const Text(
                    'Data de nascimento',
                    style: TextStyle(
                      color: AppColors.splashMint,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    birth == null
                        ? 'Toque para escolher'
                        : '${birth!.day}/${birth!.month}/${birth!.year}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: birth ?? DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setSt(() => birth = d);
                  },
                ),
              ),
            ),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(controller: rua, label: 'Logradouro'),
            const SizedBox(height: kCadastroFieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: num,
                    label: 'Número',
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(controller: bairro, label: 'Bairro'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(controller: cidade, label: 'Cidade'),
                ),
              ],
            ),
            const SizedBox(height: kCadastroFieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BrazilStateDropdown(
                    valueUf: uf,
                    onChanged: (v) => setSt(() => uf = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(controller: cep, label: 'CEP'),
                ),
              ],
            ),
            const SizedBox(height: kCadastroFieldGap),
            const Text(
              'Academias',
              style: TextStyle(
                color: AppColors.splashMint,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in gyms)
                  FilterChip(
                    label: Text(g.name, style: const TextStyle(fontSize: 12)),
                    selected: sel.contains(g.id),
                    onSelected: (v) => setSt(() {
                      if (v) {
                        sel.add(g.id);
                      } else {
                        sel.remove(g.id);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: kCadastroFieldGap),
            Text(
              'Ao salvar um aluno novo, um link seguro de acesso pode ser enviado por e-mail.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  onPressed: pwdBusy
                      ? null
                      : () async {
                          final go = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              backgroundColor: AppColors.barBackground,
                              title: const Text(
                                'Enviar link de acesso?',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              content: Text(
                                'Será enviado um link seguro por e-mail. '
                                'O aluno define a senha ao abrir o link.',
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
                                  child: const Text('Enviar'),
                                ),
                              ],
                            ),
                          );
                          if (go != true || !ctx.mounted) return;
                          setSt(() => pwdBusy = true);
                          try {
                            final r = await repo.adminSendAccessLinkForStudent(
                              x.id,
                            );
                            mustChangeForSave = true;
                            if (!ctx.mounted) return;
                            if (r.emailSent) {
                              _showAccessLinkSentSnackBar(ctx, r.loginEmail);
                            }
                          } on ArgumentError catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.message ??
                                        'Não foi possível enviar o link.',
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
                        const Icon(Icons.mail_outline, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        pwdBusy ? 'A enviar…' : 'Enviar link de acesso',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: x == null ? 'Salvar aluno' : 'Atualizar aluno',
              icon: Icons.check_rounded,
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final em = email.text.trim();
                if (x == null && em.isEmpty) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Informe o e-mail do aluno: ele será o login no app.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                final cpfDigits = brDigitsOnly(cpf.text);
                if (cpfDigits.isNotEmpty && cpfDigits.length != 11) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'CPF deve ter 11 dígitos ou ficar em branco.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                final telCom = brDigitsOnly(phoneCommercialC.text);
                final telCel = brDigitsOnly(phoneMobileC.text);
                final isNew = x == null;
                await repo.upsertStudent(
                  id: x?.id,
                  name: name.text.trim(),
                  email: em.isEmpty ? null : em,
                  goal: goal.text.trim().isEmpty ? null : goal.text.trim(),
                  cpf: cpfDigits.isEmpty ? null : cpfDigits,
                  birthDate: birth,
                  street: rua.text.trim().isEmpty ? null : rua.text.trim(),
                  number: num.text.trim().isEmpty ? null : num.text.trim(),
                  complement: comp.text.trim().isEmpty
                      ? null
                      : comp.text.trim(),
                  district: bairro.text.trim().isEmpty
                      ? null
                      : bairro.text.trim(),
                  city: cidade.text.trim().isEmpty ? null : cidade.text.trim(),
                  stateUf: uf?.isEmpty ?? true ? null : uf,
                  cep: cep.text.trim().isEmpty ? null : cep.text.trim(),
                  phoneCommercial: telCom.isEmpty ? null : telCom,
                  phoneMobile: telCel.isEmpty ? null : telCel,
                  gymIds: sel.toList(),
                  mustChangePassword: x == null ? true : mustChangeForSave,
                  sendAccessLinkAfterCreate: isNew && em.isNotEmpty,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (isNew && em.isNotEmpty && context.mounted) {
                  _showAccessLinkSentSnackBar(context, em);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
