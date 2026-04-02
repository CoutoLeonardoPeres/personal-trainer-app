#!/usr/bin/env bash
# Limpa artefatos que geram "Stale file ... path_provider_foundation_privacy.bundle
# ... outside of the allowed root paths" (Flutter build/ + Xcode DerivedData).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== 1/4 flutter clean =="
flutter clean

echo "== 2/4 Remover build/, Pods e symlinks iOS =="
rm -rf build ios/Pods ios/Podfile.lock ios/.symlinks ios/Flutter/ephemeral

echo "== 3/4 DerivedData do Runner (opcional mas recomendado) =="
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData/Runner-"* 2>/dev/null || true
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData/"*app_personal* 2>/dev/null || true

echo "== 4/4 pub get + pod install =="
flutter pub get
(cd ios && pod install --repo-update)

echo ""
echo "Pronto. Abra ios/Runner.xcworkspace, ⇧⌘K (Clean Build Folder), depois flutter run ou Build."
