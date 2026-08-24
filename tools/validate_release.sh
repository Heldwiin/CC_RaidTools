#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v luac >/dev/null 2>&1 || fail "luac introuvable. Installe Lua 5.4 (ou fournis luac dans PATH)."

VERSION="$(sed -n 's/^## Version:[[:space:]]*//p' CC_RaidTools.toc | head -n1)"
[[ -n "$VERSION" ]] || fail "Version absente de CC_RaidTools.toc."

echo "== CC RaidTools release validation =="
echo "Version: $VERSION"
echo

echo "[1/4] Vérification des fichiers Lua référencés par le TOC..."
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ "$file" == *.lua ]] || continue
    [[ -f "$file" ]] || fail "Fichier Lua référencé par le TOC introuvable: $file"
    echo "  luac -p $file"
    luac -p "$file"
done < <(awk 'NF && $0 !~ /^#/ {print $1}' CC_RaidTools.toc)

echo "[2/4] Vérification de tous les fichiers Lua du dépôt..."
while IFS= read -r -d '' file; do
    echo "  luac -p ${file#./}"
    luac -p "$file"
done < <(find . -type f -name '*.lua' -not -path './.git/*' -print0)

echo "[3/4] Vérification des références de version..."
grep -Fq "v${VERSION} chargé" CC_RaidTools.lua || fail "Message de chargement absent ou désynchronisé."
grep -Fq "${VERSION}" README.md || fail "Version absente de README.md."
grep -Fq "${VERSION}" CHANGELOG.md || fail "Version absente de CHANGELOG.md."

grep -Fq 'CC RaidTools - Ready Check' ReadyCheck.lua || fail "Titre Ready Check statique introuvable."
if grep -Eq 'Ready Check[^\n]*(v?[0-9]+\.[0-9]+\.[0-9]+)' ReadyCheck.lua; then
    fail "Le titre Ready Check contient encore un numéro de version."
fi

echo "[4/4] Vérification des fichiers référencés par le TOC..."
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ "$file" == *.lua ]] || continue
    [[ -f "$file" ]] || fail "Fichier référencé par le TOC introuvable: $file"
done < <(awk 'NF && $0 !~ /^#/ {print $1}' CC_RaidTools.toc)

echo
echo "OK: validation locale de la release ${VERSION} terminée."
