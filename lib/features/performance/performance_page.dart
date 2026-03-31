import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/app_data_repository.dart';

/// Gráficos em carrossel horizontal por aluno (dados reais virão das tabelas de treino).
class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  final PageController _chartPage = PageController();
  String? _studentId;

  @override
  void dispose() {
    _chartPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppDataRepository>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder(
            stream: repo.watchStudentsAlphabetical(),
            builder: (context, snap) {
              final students = snap.data ?? [];
              return DropdownButtonFormField<String?>(
                key: ValueKey(_studentId ?? '__none__'),
                initialValue: _studentId,
                dropdownColor: AppColors.barBackground,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Aluno',
                  prefixIcon: Icon(Icons.person_search, color: AppColors.accentGreen),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Selecione o aluno'),
                  ),
                  ...students.map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _studentId = v),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PageView(
            controller: _chartPage,
            children: [
              _chartCard('Rendimento (exemplo)', _lineSample()),
              _chartCard('Tempo / sessão (exemplo)', _barSample()),
              _chartCard('Cargas máximas (exemplo)', _lineSample(color: AppColors.accentPink)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Deslize para os lados para mais gráficos',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentPink.withValues(alpha: 0.45)),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  Widget _lineSample({Color color = AppColors.accentGreen}) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 2),
              FlSpot(1, 3),
              FlSpot(2, 2.5),
              FlSpot(3, 4),
              FlSpot(4, 3.2),
            ],
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _barSample() {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < 6; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (i + 3) * 8.0,
                  color: AppColors.accentGreen.withValues(alpha: 0.75),
                  width: 14,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
