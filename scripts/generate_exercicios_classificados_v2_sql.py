#!/usr/bin/env python3
"""
Gera scripts/supabase_seed_exercicios_classificados_v2.sql a partir do .xlsx v2.

Planilha: folha "Classificado"
  - Col. A: nome do exercício
  - Col. B: grupo muscular (rótulos curtos: peito, costas, …)

Uso:
  pip install openpyxl
  python3 scripts/generate_exercicios_classificados_v2_sql.py [caminho/exercicios_classificados_v2.xlsx]
"""

from __future__ import annotations

import argparse
import sys
from collections import OrderedDict
from pathlib import Path

try:
    import openpyxl
except ImportError:
    print("Instale: pip install openpyxl", file=sys.stderr)
    sys.exit(1)

# Rótulo col. B (lower) -> nome em public.muscle_groups (app)
MUSCLE_MAP: dict[str, str] = {
    "peito": "Peitoral",
    "costas": "Dorsal",
    "perna": "Coxas",
    "ombro": "Ombros",
    "bíceps": "Bíceps",
    "tríceps": "Tríceps",
    "panturrilha": "Panturrilhas",
    "glúteo": "Glúteo",
    "outros": "Funcional",
}


def sql_str(s: str) -> str:
    return "'" + str(s).replace("'", "''") + "'"


def parse_xlsx(path: Path) -> list[tuple[str, str]]:
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb["Classificado"]
    by_norm: "OrderedDict[str, tuple[str, str]]" = OrderedDict()
    row_num = 0
    try:
        for i in range(2, ws.max_row + 1):
            row_num = i
            a, b = ws.cell(i, 1).value, ws.cell(i, 2).value
            if not a or not str(a).strip():
                continue
            name = str(a).strip()
            if not b or not str(b).strip():
                raise ValueError(f"Linha {row_num}: falta grupo na coluna B para {name!r}")
            key = str(b).strip().lower()
            if key not in MUSCLE_MAP:
                raise ValueError(
                    f"Linha {row_num}: rótulo de grupo desconhecido {str(b).strip()!r} "
                    f"(adicione a MUSCLE_MAP em {Path(__file__).name})"
                )
            by_norm[name.strip().lower()] = (name, MUSCLE_MAP[key])
    finally:
        wb.close()
    return list(by_norm.values())


def build_sql(rows: list[tuple[str, str]]) -> str:
    targets = sorted({r[1] for r in rows})
    lines = [
        "begin;",
        "",
        "insert into public.muscle_groups (id, name)",
        "select gen_random_uuid()::text, v.name",
        "from (values",
        ",\n".join(f"  ({sql_str(n)})" for n in targets),
        ") as v(name)",
        "where not exists (",
        "  select 1 from public.muscle_groups mg",
        "  where lower(trim(mg.name)) = lower(trim(v.name))",
        ");",
        "",
        "insert into public.exercises (id, name, muscle_group_id, video_url)",
        "select",
        "  gen_random_uuid()::text,",
        "  v.exercise_name,",
        "  mg.id,",
        "  null::text",
        "from (values",
    ]
    val_lines = [f"  ({sql_str(name)}, {sql_str(mg)})" for name, mg in rows]
    lines.append(",\n".join(val_lines))
    lines.extend(
        [
            ") as v(exercise_name, muscle_name)",
            "join public.muscle_groups mg on lower(trim(mg.name)) = lower(trim(v.muscle_name))",
            "on conflict ((lower(trim(name))))",
            "do update set",
            "  muscle_group_id = excluded.muscle_group_id,",
            "  video_url = coalesce(nullif(trim(excluded.video_url), ''), exercises.video_url),",
            "  updated_at = now();",
            "",
            "commit;",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "xlsx",
        nargs="?",
        type=Path,
        default=Path.home() / "Downloads" / "exercicios_classificados_v2.xlsx",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "supabase_seed_exercicios_classificados_v2.sql",
    )
    args = parser.parse_args()
    if not args.xlsx.is_file():
        print(f"Ficheiro não encontrado: {args.xlsx}", file=sys.stderr)
        sys.exit(1)
    rows = parse_xlsx(args.xlsx)
    header = "\n".join(
        [
            "-- =============================================================================",
            "-- Carga v2: exercicios_classificados_v2.xlsx (folha Classificado)",
            "-- Col. A = nome do exercício | Col. B = grupo (rótulo curto)",
            "-- Mapeamento B → public.muscle_groups:",
            "--   peito→Peitoral, costas→Dorsal, perna→Coxas, ombro→Ombros,",
            "--   bíceps→Bíceps, tríceps→Tríceps, panturrilha→Panturrilhas, glúteo→Glúteo, outros→Funcional",
            "-- Insere exercícios em falta; em conflito de nome atualiza só muscle_group_id",
            "-- (preserva video_url existente). Sem coluna de vídeo nesta planilha.",
            "-- Regenerar: python3 scripts/generate_exercicios_classificados_v2_sql.py [ficheiro.xlsx]",
            "-- =============================================================================",
            "",
        ]
    )
    args.output.write_text(header + build_sql(rows), encoding="utf-8")
    print(f"{len(rows)} exercícios únicos → {args.output}")


if __name__ == "__main__":
    main()
