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

class MetodosTreinoPage extends StatelessWidget {
  const MetodosTreinoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();
    return Scaffold(
      appBar: buildGradientAppBar(title: const Text('Métodos de treino')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(context, repo, null),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: FuturisticBackground(
        child: StreamBuilder<List<TrainingMethodEntity>>(
          stream: repo.watchTrainingMethodsAlphabetical(),
          builder: (context, snap) {
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum método cadastrado.',
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
                  title: e.method,
                  subtitle: e.description,
                  onEdit: openForm,
                  onCardTap: openForm,
                  showEditOnSwipe: false,
                  onDelete: () async {
                    final ok = await confirmDeleteDialog(
                      context,
                      itemName: e.method,
                    );
                    if (ok == true && context.mounted) {
                      await repo.deleteTrainingMethod(e.id);
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
    TrainingMethodEntity? x,
  ) {
    final method = TextEditingController(text: x?.method ?? '');
    final desc = TextEditingController(text: x?.description ?? '');
    showAppModalSheet<void>(
      context: context,
      title: x == null ? 'Cadastrar novo método' : 'Editar método',
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppTextField(controller: method, label: 'Método', required: true),
          const SizedBox(height: kCadastroFieldGap),
          AppTextField(
            controller: desc,
            label: 'Descrição do método',
            required: true,
            maxLines: 4,
          ),
          const SizedBox(height: kCadastroFieldGap),
          AppPrimaryButton(
            label: x == null ? 'Salvar método' : 'Atualizar método',
            icon: Icons.check_rounded,
            onPressed: () async {
              if (method.text.trim().isEmpty || desc.text.trim().isEmpty) {
                return;
              }
              await repo.upsertTrainingMethod(
                id: x?.id,
                method: method.text.trim(),
                description: desc.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
