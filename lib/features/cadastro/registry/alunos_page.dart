import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/br_input_formatters.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

class AlunosPage extends StatelessWidget {
  const AlunosPage({super.key});

  static String _studentSubtitle(StudentEntity e) {
    final parts = <String>[
      if ((e.email ?? '').trim().isNotEmpty) e.email!.trim(),
      if ((e.phoneMobile ?? '').isNotEmpty) brFormatPhoneDisplay(e.phoneMobile!),
      if ((e.city ?? '').trim().isNotEmpty) e.city!.trim(),
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    return Scaffold(
      appBar: buildGradientAppBar(title: const Text('Alunos')),
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
                    final ok = await confirmDeleteDialog(context, itemName: e.name);
                    if (ok == true && context.mounted) await repo.deleteStudent(e.id);
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
    final cpf = TextEditingController(
      text: brFormatCpfDisplay(x?.cpf ?? ''),
    );
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

    showAppModalSheet<void>(
      context: context,
      title: x == null ? 'Cadastrar novo aluno' : 'Editar aluno',
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, setSt) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            AppTextField(controller: name, label: 'Nome do aluno', required: true),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(controller: email, label: 'E-mail', keyboardType: TextInputType.emailAddress),
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
                Expanded(child: AppTextField(controller: comp, label: 'Complemento')),
              ],
            ),
            const SizedBox(height: kCadastroFieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AppTextField(controller: bairro, label: 'Bairro')),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: cidade, label: 'Cidade')),
              ],
            ),
            const SizedBox(height: kCadastroFieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BrazilStateDropdown(valueUf: uf, onChanged: (v) => setSt(() => uf = v)),
                ),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: cep, label: 'CEP')),
              ],
            ),
            const SizedBox(height: kCadastroFieldGap),
            const Text(
              'Academias',
              style: TextStyle(color: AppColors.splashMint, fontWeight: FontWeight.w600),
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
              'Senha provisória será enviada por e-mail quando o backend estiver ativo.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: x == null ? 'Salvar aluno' : 'Atualizar aluno',
              icon: Icons.check_rounded,
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final cpfDigits = brDigitsOnly(cpf.text);
                if (cpfDigits.isNotEmpty && cpfDigits.length != 11) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('CPF deve ter 11 dígitos ou ficar em branco.')),
                    );
                  }
                  return;
                }
                final telCom = brDigitsOnly(phoneCommercialC.text);
                final telCel = brDigitsOnly(phoneMobileC.text);
                await repo.upsertStudent(
                  id: x?.id,
                  name: name.text.trim(),
                  email: email.text.trim().isEmpty ? null : email.text.trim(),
                  goal: goal.text.trim().isEmpty ? null : goal.text.trim(),
                  cpf: cpfDigits.isEmpty ? null : cpfDigits,
                  birthDate: birth,
                  street: rua.text.trim().isEmpty ? null : rua.text.trim(),
                  number: num.text.trim().isEmpty ? null : num.text.trim(),
                  complement: comp.text.trim().isEmpty ? null : comp.text.trim(),
                  district: bairro.text.trim().isEmpty ? null : bairro.text.trim(),
                  city: cidade.text.trim().isEmpty ? null : cidade.text.trim(),
                  stateUf: uf?.isEmpty ?? true ? null : uf,
                  cep: cep.text.trim().isEmpty ? null : cep.text.trim(),
                  phoneCommercial: telCom.isEmpty ? null : telCom,
                  phoneMobile: telCel.isEmpty ? null : telCel,
                  gymIds: sel.toList(),
                  mustChangePassword: x?.mustChangePassword ?? true,
                  passwordHash: x?.passwordHash,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
