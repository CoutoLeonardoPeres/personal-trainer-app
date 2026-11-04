import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/access/permission_service.dart';
import '../../core/auth/app_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/futuristic_background.dart';
import '../../data/repositories/app_data_repository.dart';
import 'registry/academias_page.dart';
import 'registry/alunos_page.dart';
import 'registry/exercicios_page.dart';
import 'registry/grupos_musculares_page.dart';
import 'registry/grupos_treinos_page.dart';
import 'registry/metodos_treino_page.dart';
import 'registry/personais_page.dart';

/// Menu de cadastros — cada card abre a lista correspondente (cards + modais 93%).
class CadastroHubPage extends StatelessWidget {
  const CadastroHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final repo = context.watch<AppDataRepository>();

    if (session.isStudent && session.studentId != null) {
      return StreamBuilder(
        stream: repo.watchStudentById(session.studentId!),
        builder: (context, snap) {
          final st = snap.data;
          final perms = PermissionService(session: session, student: st);
          return _CadastroList(permissions: perms);
        },
      );
    }

    if (session.isPersonalTrainer && session.personalId != null) {
      return StreamBuilder(
        stream: repo.watchPersonalById(session.personalId!),
        builder: (context, snap) {
          final perms = PermissionService(
            session: session,
            personal: snap.data,
          );
          return _CadastroList(permissions: perms);
        },
      );
    }

    return _CadastroList(permissions: PermissionService(session: session));
  }
}

class _CadastroList extends StatelessWidget {
  const _CadastroList({required this.permissions});

  final PermissionService permissions;

  @override
  Widget build(BuildContext context) {
    final items =
        <({String title, String subtitle, IconData icon, Widget page})>[];

    void add(
      String title,
      String subtitle,
      IconData icon,
      Widget page,
      bool show,
    ) {
      if (!show) return;
      items.add((title: title, subtitle: subtitle, icon: icon, page: page));
    }

    add(
      'Grupos musculares',
      'Base para classificar exercícios',
      Icons.accessibility_new_rounded,
      const GruposMuscularesPage(),
      !permissions.session.isStudent ||
          permissions.studentCadastroMuscleExerciseGymGroup,
    );
    add(
      'Exercícios',
      'Nome, grupo, vídeos e alternativas',
      Icons.sports_gymnastics_rounded,
      const ExerciciosPage(),
      !permissions.session.isStudent ||
          permissions.studentCadastroMuscleExerciseGymGroup,
    );
    add(
      'Academias',
      'Endereço completo e CNPJ',
      Icons.apartment_rounded,
      const AcademiasPage(),
      !permissions.session.isStudent ||
          permissions.studentCadastroMuscleExerciseGymGroup,
    );
    add(
      'Alunos',
      'Dados, endereço e multiselect de academias',
      Icons.people_outline_rounded,
      const AlunosPage(),
      permissions.canSeeCadastroAlunosPersonais,
    );
    add(
      'Personais',
      'Registro profissional e contato',
      Icons.badge_outlined,
      const PersonaisPage(),
      permissions.canSeeCadastroAlunosPersonais,
    );
    add(
      'Métodos de treino',
      'Método e descrição',
      Icons.menu_book_outlined,
      const MetodosTreinoPage(),
      permissions.canSeeCadastroMetodosTreino,
    );
    add(
      'Grupos de treinos',
      'Composição com exercícios cadastrados',
      Icons.layers_rounded,
      const GruposTreinosPage(),
      !permissions.session.isStudent ||
          permissions.studentCadastroMuscleExerciseGymGroup,
    );

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nenhum cadastro disponível para o seu perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = items[i];
        return FuturisticCard(
          borderColor: AppColors.cadastroCardBorder.withValues(alpha: 0.65),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => it.page));
          },
          child: Row(
            children: [
              Icon(it.icon, color: AppColors.accentGreen, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      it.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        );
      },
    );
  }
}
