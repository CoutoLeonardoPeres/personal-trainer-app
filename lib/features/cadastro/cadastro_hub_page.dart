import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/futuristic_background.dart';
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
    final items = <({String title, String subtitle, IconData icon, Widget page})>[
      (
        title: 'Grupos musculares',
        subtitle: 'Base para classificar exercícios',
        icon: Icons.accessibility_new_rounded,
        page: const GruposMuscularesPage(),
      ),
      (
        title: 'Exercícios',
        subtitle: 'Nome, grupo, vídeos e alternativas',
        icon: Icons.sports_gymnastics_rounded,
        page: const ExerciciosPage(),
      ),
      (
        title: 'Academias',
        subtitle: 'Endereço completo e CNPJ',
        icon: Icons.apartment_rounded,
        page: const AcademiasPage(),
      ),
      (
        title: 'Alunos',
        subtitle: 'Dados, endereço e multiselect de academias',
        icon: Icons.people_outline_rounded,
        page: const AlunosPage(),
      ),
      (
        title: 'Personais',
        subtitle: 'Registro profissional e contato',
        icon: Icons.badge_outlined,
        page: const PersonaisPage(),
      ),
      (
        title: 'Métodos de treino',
        subtitle: 'Método e descrição',
        icon: Icons.menu_book_outlined,
        page: const MetodosTreinoPage(),
      ),
      (
        title: 'Grupos de treinos',
        subtitle: 'Composição com exercícios cadastrados',
        icon: Icons.layers_rounded,
        page: const GruposTreinosPage(),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = items[i];
        return FuturisticCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => it.page),
            );
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
              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        );
      },
    );
  }
}
