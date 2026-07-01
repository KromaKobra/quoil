#!/usr/bin/env bash
# Run qs -c quoil using the locally built C++ plugins.
# Build first with: nix develop /path/to/shell# -- cmake -B build && cmake --build build -j$(nproc)
set -euo pipefail

QUOIL="$(cd "$(dirname "$0")" && pwd)"
BUILD="$QUOIL/build"

if [[ ! -d "$BUILD/qml" ]]; then
    echo "error: $BUILD/qml not found — run the build first:" >&2
    echo "  cd $QUOIL && nix develop -- bash -c 'cmake -B build && cmake --build build -j\$(nproc)'" >&2
    exit 1
fi

export NIXPKGS_QT6_QML_IMPORT_PATH="$BUILD/qml${NIXPKGS_QT6_QML_IMPORT_PATH:+:$NIXPKGS_QT6_QML_IMPORT_PATH}"
export CAELESTIA_LIB_DIR="$BUILD/lib"

# xkeyboard-config is a system dep (not caelestia source) — find whichever is in the store
XKB_RULES=$(ls /nix/store/*/share/xkeyboard-config-*/rules/base.lst 2>/dev/null | grep -v lunarclient | head -1)
[[ -n "$XKB_RULES" ]] && export CAELESTIA_XKB_RULES_PATH="$XKB_RULES"

exec qs -c quoil "$@"
