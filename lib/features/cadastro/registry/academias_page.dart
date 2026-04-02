import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_modal_sheet.dart';
import '../../../core/ui/futuristic_background.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/swipeable_registry_card.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/app_data_repository.dart';

class AcademiasPage extends StatelessWidget {
  const AcademiasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    return Scaffold(
      appBar: buildGradientAppBar(title: const Text('Academias')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(context, repo, null),
        child: const Icon(Icons.add),
      ),
      body: FuturisticBackground(
        child: StreamBuilder<List<GymEntity>>(
          stream: repo.watchGymsAlphabetical(),
          builder: (context, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhuma academia cadastrada.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final e = list[i];
                return SwipeableRegistryCard(
                  slidableKey: e.id,
                  title: e.name,
                  subtitle: '${e.city} — ${e.stateUf}',
                  onEdit: () => _form(context, repo, e),
                  onDelete: () async {
                    final ok = await confirmDeleteDialog(context, itemName: e.name);
                    if (ok == true && context.mounted) await repo.deleteGym(e.id);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _form(BuildContext context, AppDataRepository repo, GymEntity? x) {
    final name = TextEditingController(text: x?.name ?? '');
    final cnpj = TextEditingController(text: x?.cnpj ?? '');
    final rua = TextEditingController(text: x?.street ?? '');
    final num = TextEditingController(text: x?.number ?? '');
    final comp = TextEditingController(text: x?.complement ?? '');
    final bairro = TextEditingController(text: x?.district ?? '');
    final cidade = TextEditingController(text: x?.city ?? '');
    final cep = TextEditingController(text: x?.cep ?? '');
    String? uf = x?.stateUf;

    showAppModalSheet<void>(
      context: context,
      title: x == null ? 'Cadastrar nova academia' : 'Editar academia',
      builder: (ctx, scroll) => StatefulBuilder(
        builder: (ctx, setSt) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            AppTextField(controller: name, label: 'Nome', required: true),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(controller: cnpj, label: 'CNPJ', required: true),
            const SizedBox(height: kCadastroFieldGap),
            AppTextField(controller: rua, label: 'Logradouro', required: true),
            const SizedBox(height: kCadastroFieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(controller: num, label: 'Número', required: true),
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
                  child: AppTextField(controller: bairro, label: 'Bairro', required: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(controller: cidade, label: 'Cidade', required: true),
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
                    requiredField: true,
                    onChanged: (v) => setSt(() => uf = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(controller: cep, label: 'CEP', required: true),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: x == null ? 'Salvar academia' : 'Atualizar academia',
              icon: Icons.check_rounded,
              onPressed: () async {
                if (name.text.trim().isEmpty ||
                    cnpj.text.trim().isEmpty ||
                    uf == null ||
                    uf!.isEmpty) {
                  return;
                }
                await repo.upsertGym(
                  id: x?.id,
                  name: name.text.trim(),
                  cnpj: cnpj.text.trim(),
                  street: rua.text.trim(),
                  number: num.text.trim(),
                  complement: comp.text.trim().isEmpty ? null : comp.text.trim(),
                  district: bairro.text.trim(),
                  city: cidade.text.trim(),
                  stateUf: uf!,
                  cep: cep.text.trim(),
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
