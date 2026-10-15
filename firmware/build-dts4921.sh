#!/usr/bin/env bash
# Build Kinetos OpenEVSE V5 with DTS4921 meter support on current OpenEVSE master:
#   upstream master (pinned) + Kinetos board / patches + DTS4921 meter patch
#   + Kinetos page in gui-nightshift (English only).
# Output: out/kinetos-v5-<version>.bin (flash via the wallbox's /update page)
set -euo pipefail
UPSTREAM="${UPSTREAM:-a3816295}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/.work-dts4921}"

# Build-Zähler aus Datei lesen / verwalten
COUNTER_FILE="$HERE/.build_number_dts4921"
if [ ! -f "$COUNTER_FILE" ]; then
  echo 19 > "$COUNTER_FILE"
fi

BUILD_NUM="$(cat "$COUNTER_FILE" | tr -d -c '0-9')"
BUILD_NUM="${BUILD_NUM:-19}"

# Basis-Version ermitteln (z.B. v5.2.0-dev aus build-master.sh)
BASE_VERSION="$(grep '^VERSION=' "$HERE/build-master.sh" 2>/dev/null | sed -e 's/.*:-//' -e 's/[}"].*//' || true)"
BASE_PREFIX="$(echo "${BASE_VERSION:-v5.2.0-dev}" | sed -E 's/-(kinetos|dts4921).*//')"
VERSION_BASE="${VERSION_BASE:-${BASE_PREFIX}-dts4921}"

# Manuelle Überschreibung via VERSION erlauben, sonst dynamisch generieren
MANUAL_VERSION=0
if [ -n "${VERSION+x}" ]; then
  MANUAL_VERSION=1
else
  VERSION="${VERSION_BASE}-${BUILD_NUM}"
fi

GIT=(git -c user.name=build -c user.email=build@localhost -c core.autocrlf=false)
if [ ! -d "$WORK/.git" ]; then
  git -c core.autocrlf=false clone -q https://github.com/OpenEVSE/ESP32_WiFi_V4.x.git "$WORK"
fi
cd "$WORK"
git config core.autocrlf false
git fetch -q origin
git checkout -q -f --detach "$UPSTREAM"
git clean -qfdx src
git -c core.autocrlf=false submodule update -q --init --recursive
git submodule foreach -q --recursive 'git config core.autocrlf false && git checkout -q -- . && git clean -qfd'

# GUI: Kinetos settings page, English only
git -C gui-nightshift apply --ignore-whitespace "$HERE"/patches-master/gui-*.patch
(cd gui-nightshift && npm ci --no-audit --no-fund --silent && npm run build --silent)
"${GIT[@]}" -C gui-nightshift add -A && "${GIT[@]}" -C gui-nightshift commit -qm "kinetos gui"
git add gui-nightshift

# Firmware: Original Kinetos patches + DTS4921 meter patch
git apply --ignore-whitespace "$HERE"/patches-master/firmware-*.patch
git apply --ignore-whitespace "$HERE"/patches-dts4921/*.patch
"${GIT[@]}" add -A && "${GIT[@]}" commit -qm "kinetos with dts4921 meter"

export GITHUB_REF_NAME="$VERSION"
if command -v pio >/dev/null; then PIO=(pio); else PIO=(uv tool run --from platformio pio); fi
# First pass regenerates the GUI headers into src/, commit them so the version is not "_modified"
"${PIO[@]}" run -e kinetos-v5
"${GIT[@]}" add -A src && "${GIT[@]}" commit -qm "generated headers" --allow-empty
"${PIO[@]}" run -e kinetos-v5
BIN_FILE="$HERE/out/kinetos-v5-$VERSION.bin"
ELF_FILE="$HERE/out/kinetos-v5-$VERSION.elf"
SHA_FILE="$HERE/out/kinetos-v5-$VERSION.bin.sha256"

mkdir -p "$HERE/out"
cp .pio/build/kinetos-v5/firmware.bin "$BIN_FILE"
cp .pio/build/kinetos-v5/firmware.elf "$ELF_FILE"
(cd "$HERE/out" && sha256sum "kinetos-v5-$VERSION.bin" > "$SHA_FILE")
cat "$SHA_FILE"

# --- Optional: Als GitHub Release veröffentlichen ---
ROOT_DIR="$(cd "$HERE/.." && pwd)"
RELEASE="${RELEASE:-1}"

if [ "$RELEASE" = "1" ]; then
  if command -v gh >/dev/null 2>&1; then
    REPO_URL="$(git -C "$ROOT_DIR" config --get remote.origin.url || true)"
    echo ""
    echo "=== Erstelle GitHub Release für $VERSION ==="
    if [ -n "$REPO_URL" ]; then
      if ! gh release create "$VERSION" \
          "$BIN_FILE" \
          "$SHA_FILE" \
          "$ELF_FILE" \
          --repo "$REPO_URL" \
          --title "Kinetos OpenEVSE V5 DTS4921 ($VERSION)" \
          --notes "Automatischer Build von $VERSION mit DTS4921 Zähler-Unterstützung." \
          --prerelease; then
        echo "Release existiert möglicherweise bereits oder Konfigurationsfehler. Versuche Asset-Upload..."
        gh release upload "$VERSION" "$BIN_FILE" "$SHA_FILE" "$ELF_FILE" --repo "$REPO_URL" --clobber || true
      fi
      echo "GitHub Release Schritt abgeschlossen: $VERSION"
    else
      echo "Warnung: Kein git remote origin gefunden, Release wurde übersprungen."
    fi
  else
    echo ""
    echo "=== Hinweis zu GitHub Release ==="
    echo "GitHub CLI ('gh') ist nicht installiert oder nicht im PATH."
    echo "Die Dateien wurden lokal in 'firmware/out/' bereitgestellt:"
    echo "  - $BIN_FILE"
    echo "  - $SHA_FILE"
    echo "  - $ELF_FILE"
    echo ""
    echo "Tipp: Installiere die GitHub CLI (https://cli.github.com):"
    echo "  Windows: winget install --id GitHub.cli"
    echo "  Linux:   sudo apt install gh"
    echo "und melde dich danach einmalig an: gh auth login"
  fi
fi

# --- Zähler für den nächsten Build um 1 erhöhen ---
if [ "$MANUAL_VERSION" -eq 0 ]; then
  NEXT_BUILD=$((BUILD_NUM + 1))
  echo "$NEXT_BUILD" > "$COUNTER_FILE"
  echo ""
  echo "Build erfolgreich abgeschlossen."
  echo "Build-Zähler erhöht: Nächster Build wird ${VERSION_BASE}-${NEXT_BUILD} sein."
fi
