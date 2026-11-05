#!/bin/sh
# Install the desktop entry and hicolor icons for a built Linux bundle.
#
#   ./linux/packaging/install-desktop-entry.sh [bundle-dir] [prefix]
#
# bundle-dir defaults to build/linux/x64/release/bundle, prefix to
# $HOME/.local. Nothing is copied into the bundle itself; the entry points at
# the binary where it already lives.
set -eu

BUNDLE=${1:-build/linux/x64/release/bundle}
PREFIX=${2:-$HOME/.local}
BIN=$(cd "$BUNDLE" && pwd)/sibyl_control

if [ ! -x "$BIN" ]; then
  echo "no executable at $BIN — build it first:" >&2
  echo "  flutter build linux --release" >&2
  exit 1
fi

APPS="$PREFIX/share/applications"
mkdir -p "$APPS"
sed "s|^Exec=.*|Exec=$BIN|" "$(dirname "$0")/sibyl-control.desktop" \
  > "$APPS/sibyl-control.desktop"

for size in 16 24 32 48 64 128 256 512; do
  src="$BUNDLE/data/flutter_assets/assets/branding/icon-256.png"
  dir="$PREFIX/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dir"
  if command -v convert >/dev/null 2>&1; then
    convert "$src" -resize "${size}x${size}" "$dir/sibyl-control.png"
  else
    cp "$src" "$dir/sibyl-control.png"
  fi
done

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS" || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" || true
fi

echo "installed $APPS/sibyl-control.desktop -> $BIN"
