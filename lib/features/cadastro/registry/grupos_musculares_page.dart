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

class GruposMuscularesPage extends StatelessWidget {
  const GruposMuscularesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();

    return Scaffold(
      appBar: buildGradientAppBar(title: const Text('Grupos musculares')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, repo, null),
        child: const Icon(Icons.add),
      ),
      body: FuturisticBackground(
        child: StreamBuilder<List<MuscleGroupEntity>>(
          stream: repo.watchMuscleGroupsAlphabetical(),
          builder: (context, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum grupo cadastrado.\nToque em + para adicionar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final e = list[i];
                return SwipeableRegistryCard(
                  slidableKey: e.id,
                  title: e.name,
                  subtitle: 'Grupo muscular',
                  onEdit: () => _openForm(context, repo, e),
                  onDelete: () async {
                    final ok = await confirmDeleteDialog(context, itemName: e.name);
                    if (ok == true && context.mounted) {
                      await repo.deleteMuscleGroup(e.id);
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

  void _openForm(BuildContext context, AppDataRepository repo, MuscleGroupEntity? existing) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    showAppModalSheet<void>(
      context: context,
      title: existing == null
          ? 'Cadastrar novo grupo muscular'
          : 'Editar grupo muscular',
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppTextField(controller: nameC, label: 'Nome do grupo muscular', required: true),
          const SizedBox(height: kCadastroFieldGap),
          AppPrimaryButton(
            label: existing == null ? 'Salvar grupo muscular' : 'Atualizar grupo muscular',
            icon: Icons.check_rounded,
            onPressed: () async {
              final n = nameC.text.trim();
              if (n.isEmpty) return;
              await repo.upsertMuscleGroup(id: existing?.id, name: n);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
