#!/usr/bin/env python3
"""
Gera scripts/supabase_seed_exercicios_classificados.sql a partir do .xlsx.

Uso:
  pip install openpyxl
  python3 scripts/generate_exercicios_classificados_sql.py [caminho/exercicios_classificados.xlsx]

Regras da planilha (folha "Exercicios Classificados"):
  - Col. A: nome do exercício
  - Col. B: grupo muscular (opcional)
  - Col. C: URL do vídeo
  - Linha só com B preenchida (sem nome em A): início de secção; linhas seguintes sem B herdam esse grupo.
  - Linha com A e B: grupo só para essa linha (não muda a secção).
  - Linha com A sem B: usa o grupo da secção atual.
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

# Nome na planilha (normalizado lower) -> nome em public.muscle_groups (app)
MUSCLE_MAP: dict[str, str] = {
    "peitoral": "Peitoral",
    "abdômen": "Abdômen",
    "alongamento": "Alongamento",
    "antebraço": "Antebraço",
    "bíceps": "Bíceps",
    "coxa": "Coxas",
    "dorsal": "Dorsal",
    "elásticos e faixas": "Elástico e Faixas",
    "glúteo": "Glúteo",
    "hitt": "HITT",
    "interno de coxa": "Coxas Interno",
    "lombar": "Lombar",
    "mobilidade": "Mobilidade",
    "ombros": "Ombros",
    "panturrilhas": "Panturrilhas",
    "para fazer em casa": "Treino em Casa",
    "posterior de coxa": "Coxas Posterior",
    "trapézio": "Trapézio",
    "tríceps": "Tríceps",
    "aeróbicos": "Aeróbico",
    "funcional": "Funcional",
}


def sql_str(s: str) -> str:
    return "'" + str(s).replace("'", "''") + "'"


def parse_xlsx(path: Path) -> list[tuple[str, str, str | None]]:
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb["Exercicios Classificados"]
    section_m: str | None = None
    by_norm: "OrderedDict[str, tuple[str, str, str | None]]" = OrderedDict()
    row_num = 0
    try:
        for i in range(2, ws.max_row + 1):
            row_num = i
            a, b, c = ws.cell(i, 1).value, ws.cell(i, 2).value, ws.cell(i, 3).value
            if b and str(b).strip() and (not a or not str(a).strip()):
                section_m = str(b).strip()
                continue
            if not a or not str(a).strip():
                continue
            name = str(a).strip()
            if b and str(b).strip():
                musc_raw = str(b).strip()
            else:
                musc_raw = section_m
            if not musc_raw:
                raise ValueError(
                    f"Linha {row_num}: exercício sem grupo e sem secção ativa: {name!r}"
                )
            key = musc_raw.strip().lower()
            if key not in MUSCLE_MAP:
                raise ValueError(
                    f"Linha {row_num}: grupo sem mapeamento em MUSCLE_MAP: {musc_raw!r}"
                )
            target_mg = MUSCLE_MAP[key]
            url = str(c).strip() if c else ""
            norm = name.strip().lower()
            by_norm[norm] = (name, target_mg, url or None)
    finally:
        wb.close()
    return list(by_norm.values())


def build_sql(rows: list[tuple[str, str, str | None]]) -> str:
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
        "  nullif(trim(v.video_url), '')::text",
        "from (values",
    ]
    val_lines = []
    for name, mg, vu in rows:
        vsql = sql_str(vu) if vu else "NULL"
        val_lines.append(f"  ({sql_str(name)}, {sql_str(mg)}, {vsql})")
    lines.append(",\n".join(val_lines))
    lines.extend(
        [
            ") as v(exercise_name, muscle_name, video_url)",
            "join public.muscle_groups mg on lower(trim(mg.name)) = lower(trim(v.muscle_name))",
            "on conflict ((lower(trim(name))))",
            "do update set",
            "  muscle_group_id = excluded.muscle_group_id,",
            "  video_url = excluded.video_url,",
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
        default=Path.home() / "Downloads" / "exercicios_classificados.xlsx",
        help="Caminho do Excel",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "supabase_seed_exercicios_classificados.sql",
    )
    args = parser.parse_args()
    if not args.xlsx.is_file():
        print(f"Ficheiro não encontrado: {args.xlsx}", file=sys.stderr)
        sys.exit(1)
    rows = parse_xlsx(args.xlsx)
    header = "\n".join(
        [
            "-- =============================================================================",
            "-- Seed: exercícios a partir de exercicios_classificados.xlsx",
            "-- Col. A = nome | B = grupo (opcional) | C = link vídeo",
            "-- Linha só com B (sem A) = secção; linhas sem B herdam. Linha A+B = grupo só nessa linha.",
            "-- Mapeamento planilha→muscle_groups: ver MUSCLE_MAP em generate_exercicios_classificados_sql.py",
        "-- Regenerar: python3 scripts/generate_exercicios_classificados_sql.py [ficheiro.xlsx]",
            "-- Duplicados (mesmo nome ignorando maiúsculas): última ocorrência.",
            "-- Idempotente: grupos em falta + ON CONFLICT em exercises.",
            "-- =============================================================================",
            "",
        ]
    )
    args.output.write_text(header + build_sql(rows), encoding="utf-8")
    print(f"{len(rows)} exercícios únicos → {args.output}")


if __name__ == "__main__":
    main()
