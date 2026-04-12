#!/usr/bin/env python3
"""
Unifica exercicios_classificados.xlsx (vídeo + grupos v1) e exercicios_classificados_v2.xlsx
(classificação por músculo) e gera SQL para public.exercises com alternativas no mesmo grupo.

Regras de fusão (por nome normalizado):
  - Nome: mantém o da v1 se existir, senão o da v2.
  - Grupo muscular: prefere a v2 quando o exercício existe nas duas; senão v1 ou só v2.
  - Vídeo: só a v1 tem URLs; nunca apaga um vídeo já fundido.

Alternativas (mesmo muscle_group canónico após o mapa):
  - Agrupa exercícios pelo grupo; ordena por nome.
  - Cada um sugere o «seguinte» no anel (último → primeiro) como substituto.
  - alternative_note: texto com o nome sugerido; alternative_video_url: URL do substituto, se houver.

Uso:
  pip install openpyxl
  python3 scripts/generate_exercicios_unified_sql.py \\
    [--v1 caminho/exercicios_classificados.xlsx] \\
    [--v2 caminho/exercicios_classificados_v2.xlsx] \\
    [-o scripts/supabase_seed_exercicios_unified.sql]
"""

from __future__ import annotations

import argparse
import sys
from collections import OrderedDict, defaultdict
from pathlib import Path

try:
    import openpyxl
except ImportError:
    print("Instale: pip install openpyxl", file=sys.stderr)
    sys.exit(1)

# --- v1: rótulos da col. B (planilha) → muscle_groups ---
MUSCLE_MAP_V1: dict[str, str] = {
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

# --- v2: rótulos curtos col. B → muscle_groups ---
MUSCLE_MAP_V2: dict[str, str] = {
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


def sql_str(s: str | None) -> str:
    if s is None or s == "":
        return "NULL"
    return "'" + str(s).replace("'", "''") + "'"


def parse_v1(path: Path) -> dict[str, tuple[str, str, str | None]]:
    """norm_name -> (display_name, muscle_group_name, video_url|None)"""
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb["Exercicios Classificados"]
    section_m: str | None = None
    out: dict[str, tuple[str, str, str | None]] = {}
    try:
        for i in range(2, ws.max_row + 1):
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
                raise ValueError(f"v1 linha {i}: exercício sem grupo: {name!r}")
            key = musc_raw.strip().lower()
            if key not in MUSCLE_MAP_V1:
                raise ValueError(f"v1 linha {i}: grupo desconhecido {musc_raw!r}")
            target = MUSCLE_MAP_V1[key]
            url = str(c).strip() if c else ""
            out[name.strip().lower()] = (name, target, url or None)
    finally:
        wb.close()
    return out


def parse_v2(path: Path) -> dict[str, tuple[str, str]]:
    """norm_name -> (display_name, muscle_group_name)"""
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb["Classificado"]
    out: dict[str, tuple[str, str]] = {}
    try:
        for i in range(2, ws.max_row + 1):
            a, b = ws.cell(i, 1).value, ws.cell(i, 2).value
            if not a or not str(a).strip():
                continue
            name = str(a).strip()
            if not b or not str(b).strip():
                raise ValueError(f"v2 linha {i}: falta grupo na col. B: {name!r}")
            key = str(b).strip().lower()
            if key not in MUSCLE_MAP_V2:
                raise ValueError(f"v2 linha {i}: grupo desconhecido {str(b).strip()!r}")
            out[name.strip().lower()] = (name, MUSCLE_MAP_V2[key])
    finally:
        wb.close()
    return out


def merge(
    v1: dict[str, tuple[str, str, str | None]],
    v2: dict[str, tuple[str, str]],
) -> list[dict[str, str | None]]:
    """
    Lista de dicts: name, muscle, video, alt_note, alt_video
    """
    all_norms = sorted(set(v1.keys()) | set(v2.keys()))
    merged: dict[str, dict[str, str | None]] = {}
    for norm in all_norms:
        r1 = v1.get(norm)
        r2 = v2.get(norm)
        if r1 and r2:
            name_v1, musc_v1, vid = r1
            name_v2, musc_v2 = r2
            merged[norm] = {
                "name": name_v1,
                "muscle": musc_v2,
                "video": vid,
            }
        elif r1:
            n, m, v = r1
            merged[norm] = {"name": n, "muscle": m, "video": v}
        else:
            assert r2
            n, m = r2
            merged[norm] = {"name": n, "muscle": m, "video": None}

    by_muscle: dict[str, list[tuple[str, dict[str, str | None]]]] = defaultdict(list)
    for norm, d in merged.items():
        by_muscle[str(d["muscle"])].append((norm, d))
    for muscle, items in by_muscle.items():
        items.sort(key=lambda x: x[0])
        n = len(items)
        for i, (norm, d) in enumerate(items):
            if n < 2:
                d["alt_note"] = None
                d["alt_video"] = None
            else:
                _alt_norm, alt_d = items[(i + 1) % n]
                alt_name = alt_d["name"]
                d["alt_note"] = (
                    f"Substituição sugerida (mesmo grupo muscular — {muscle}): {alt_name}"
                )
                d["alt_video"] = alt_d.get("video")

    return list(merged.values())


def build_sql(rows: list[dict[str, str | None]]) -> str:
    targets = sorted({r["muscle"] for r in rows if r["muscle"]})
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
        "insert into public.exercises (id, name, muscle_group_id, video_url, alternative_note, alternative_video_url)",
        "select",
        "  gen_random_uuid()::text,",
        "  v.exercise_name,",
        "  mg.id,",
        "  nullif(trim(v.video_url), '')::text,",
        "  nullif(trim(v.alternative_note), '')::text,",
        "  nullif(trim(v.alternative_video_url), '')::text",
        "from (values",
    ]
    val_lines = []
    for r in sorted(rows, key=lambda x: x["name"] or ""):
        vn = sql_str(r["video"] if r["video"] else None)
        an = sql_str(r["alt_note"] if r["alt_note"] else None)
        av = sql_str(r["alt_video"] if r["alt_video"] else None)
        val_lines.append(
            f"  ({sql_str(r['name'])}, {sql_str(r['muscle'])}, {vn}, {an}, {av})"
        )
    lines.append(",\n".join(val_lines))
    lines.extend(
        [
            ") as v(exercise_name, muscle_name, video_url, alternative_note, alternative_video_url)",
            "join public.muscle_groups mg on lower(trim(mg.name)) = lower(trim(v.muscle_name))",
            "on conflict ((lower(trim(name))))",
            "do update set",
            "  muscle_group_id = excluded.muscle_group_id,",
            "  video_url = coalesce(nullif(trim(excluded.video_url), ''), exercises.video_url),",
            "  alternative_note = excluded.alternative_note,",
            "  alternative_video_url = excluded.alternative_video_url,",
            "  updated_at = now();",
            "",
            "commit;",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--v1",
        type=Path,
        default=Path.home() / "Downloads" / "exercicios_classificados.xlsx",
    )
    p.add_argument(
        "--v2",
        type=Path,
        default=Path.home() / "Downloads" / "exercicios_classificados_v2.xlsx",
    )
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "supabase_seed_exercicios_unified.sql",
    )
    args = p.parse_args()
    for label, path in ("v1", args.v1), ("v2", args.v2):
        if not path.is_file():
            print(f"Ficheiro {label} não encontrado: {path}", file=sys.stderr)
            sys.exit(1)

    d1 = parse_v1(args.v1)
    d2 = parse_v2(args.v2)
    only_v1 = set(d1.keys()) - set(d2.keys())
    only_v2 = set(d2.keys()) - set(d1.keys())
    both = set(d1.keys()) & set(d2.keys())
    rows = merge(d1, d2)

    header = "\n".join(
        [
            "-- =============================================================================",
            "-- Carga unificada: exercicios_classificados.xlsx + exercicios_classificados_v2.xlsx",
            "--",
            "-- Fusão por nome (ignorando maiúsculas):",
            "--   • Grupo muscular: v2 quando existe nas duas planilhas; senão v1 ou só v2.",
            "--   • Vídeo: apenas v1 (URLs na col. C); preservado no ON CONFLICT se vier vazio.",
            "--",
            "-- Alternativas (substituição no mesmo grupo muscular após o mapa):",
            "--   Exercícios ordenados alfabeticamente por nome; cada um aponta para o «seguinte»",
            "--   no grupo (anel). alternative_note = texto sugestivo; alternative_video_url =",
            "--   link do substituto quando o substituto tem vídeo na v1.",
            "--",
            f"-- Comparativo: só v1={len(only_v1)} | só v2={len(only_v2)} | ambas={len(both)} | total único={len(rows)}",
            "--",
            "-- Regenerar:",
            "--   python3 scripts/generate_exercicios_unified_sql.py [--v1 ...] [--v2 ...] [-o ...]",
            "-- =============================================================================",
            "",
        ]
    )
    args.output.write_text(header + build_sql(rows), encoding="utf-8")
    print(f"Escrito {args.output} ({len(rows)} exercícios)")


if __name__ == "__main__":
    main()
