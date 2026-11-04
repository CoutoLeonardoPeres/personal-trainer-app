import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Estilos de fragmento do relatório (UI + texto plano unificado).
enum PerformanceReportSpanStyle {
  title,
  sectionHeading,
  body,
  anamneseMeta,
  anamneseQuestion,
  anamneseAnswer,
  coachingInsight,
}

/// Relatório como sequência de trechos estilizados; [plainText] serve para copiar/compartilhar.
class PerformanceReportDocument {
  PerformanceReportDocument();

  final List<({PerformanceReportSpanStyle style, String text})> _segments = [];

  void write(PerformanceReportSpanStyle style, String text) {
    if (text.isEmpty) return;
    _segments.add((style: style, text: text));
  }

  void writeln(PerformanceReportSpanStyle style, String line) {
    write(style, line);
    write(PerformanceReportSpanStyle.body, '\n');
  }

  String get plainText => _segments.map((s) => s.text).join();

  List<({PerformanceReportSpanStyle style, String text})> get segments =>
      List.unmodifiable(_segments);
}

TextStyle _reportStyleFor(PerformanceReportSpanStyle s) {
  const base = TextStyle(color: Color(0xFFE8EAF0), fontSize: 13, height: 1.38);
  switch (s) {
    case PerformanceReportSpanStyle.title:
      return base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.splashMint,
        height: 1.25,
      );
    case PerformanceReportSpanStyle.sectionHeading:
      return base.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: AppColors.accentGreen.withValues(alpha: 0.95),
        height: 1.45,
      );
    case PerformanceReportSpanStyle.body:
      return base;
    case PerformanceReportSpanStyle.anamneseMeta:
      return base.copyWith(
        color: Colors.white.withValues(alpha: 0.62),
        fontSize: 12.5,
        fontStyle: FontStyle.italic,
      );
    case PerformanceReportSpanStyle.anamneseQuestion:
      return base.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 13.5,
        color: const Color(0xFF81D4FA),
        height: 1.35,
      );
    case PerformanceReportSpanStyle.anamneseAnswer:
      return base.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
        color: const Color(0xFFFFF59D),
        height: 1.4,
      );
    case PerformanceReportSpanStyle.coachingInsight:
      return base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13.2,
        color: const Color(0xFFFFB74D),
        height: 1.42,
      );
  }
}

/// Exibe o relatório com tipografia diferenciada (anamnese, insights, etc.).
class PerformanceReportRichView extends StatelessWidget {
  const PerformanceReportRichView({super.key, required this.document});

  final PerformanceReportDocument document;

  @override
  Widget build(BuildContext context) {
    final children = <TextSpan>[];
    for (final seg in document.segments) {
      children.add(TextSpan(text: seg.text, style: _reportStyleFor(seg.style)));
    }
    return SelectableText.rich(TextSpan(children: children));
  }
}
