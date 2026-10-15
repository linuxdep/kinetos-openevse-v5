#!/usr/bin/env bash
# Build Kinetos OpenEVSE V5 with DTS4921 meter support on current OpenEVSE master:
#   upstream master (pinned) + Kinetos board / patches + DTS4921 meter patch
#   + Kinetos page in gui-nightshift (English only).
# Output: out/kinetos-v5-<version>.bin (flash via the wallbox's /update page)
set -euo pipefail
UPSTREAM="${UPSTREAM:-a3816295}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/.work-dts4921}"

# Extract base version from build-master.sh (e.g. v5.2.0-dev-kinetos.18)
# and convert to DTS4921 naming (e.g. v5.2.0-dev-dts4921-18)
BASE_VERSION="$(grep '^VERSION=' "$HERE/build-master.sh" | sed -e 's/.*:-//' -e 's/[}"].*//')"
VERSION="${VERSION:-${BASE_VERSION/kinetos./dts4921-}}"

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
mkdir -p "$HERE/out"
cp .pio/build/kinetos-v5/firmware.bin "$HERE/out/kinetos-v5-$VERSION.bin"
cp .pio/build/kinetos-v5/firmware.elf "$HERE/out/kinetos-v5-$VERSION.elf"
(cd "$HERE/out" && sha256sum "kinetos-v5-$VERSION.bin" > "kinetos-v5-$VERSION.bin.sha256")
cat "$HERE/out/kinetos-v5-$VERSION.bin.sha256"
