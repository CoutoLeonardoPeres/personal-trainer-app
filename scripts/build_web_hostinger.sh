#!/usr/bin/env bash
# Gera build/web + pasta deploy/hostinger_web pronta para upload no Hostinger.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEFINES="${1:-dart_defines.prod.json}"
BASE_HREF="${2:-/}"

if [[ ! -f "$DEFINES" ]]; then
  echo "Arquivo de defines não encontrado: $DEFINES"
  echo "Copie dart_defines.prod.example.json → dart_defines.prod.json"
  exit 1
fi

echo "==> flutter build web --release"
flutter build web --release \
  --dart-define-from-file="$DEFINES" \
  --base-href="$BASE_HREF"

# Garante assets Drift na pasta web (sqlite3.wasm + drift_worker.js)
if [[ ! -f web/sqlite3.wasm || ! -f web/drift_worker.js ]]; then
  echo "ERRO: faltam web/sqlite3.wasm ou web/drift_worker.js"
  echo "Baixe as versões compatíveis com pubspec.lock (sqlite3 / drift)."
  exit 1
fi

OUT="$ROOT/deploy/hostinger_web"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$ROOT/build/web/." "$OUT/"
cp "$ROOT/web/.htaccess" "$OUT/.htaccess"

ZIP="$ROOT/deploy/personal_gym_web_hostinger.zip"
rm -f "$ZIP"
(
  cd "$OUT"
  zip -qr "$ZIP" .
)

echo ""
echo "OK — pasta: $OUT"
echo "OK — zip:   $ZIP"
echo ""
echo "Hostinger: File Manager → public_html → upload do ZIP → Extract"
echo "Ou envie o conteúdo de deploy/hostinger_web para a raiz do domínio."
