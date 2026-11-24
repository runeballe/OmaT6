#!/usr/bin/env bash
# Install the OmaT6 Brightness bar widget: brightness sliders for every
# display, with a click-through dim overlay for screens on the T6.
#
#   ./tools/install-brightness.sh            install / update and enable
#   ./tools/install-brightness.sh --remove   disable and remove
set -euo pipefail

src="$(dirname "$(readlink -f "$0")")/brightness-plugin"
id=$(jq -r .id "$src/manifest.json")
dest="$HOME/.config/omarchy/plugins/$id"

if [[ ${1:-} == --remove ]]; then
  omarchy plugin disable "$id" >/dev/null 2>&1 || true
  rm -rf "$dest"
  echo "Removed $id."
  exit 0
fi

omarchy plugin validate "$src"
mkdir -p "$dest"
cp "$src"/{manifest.json,BarWidget.qml,DimOverlay.qml,display-brightness,brightness-display} "$dest/"
chmod +x "$dest/display-brightness" "$dest/brightness-display"
# The shell caches plugin QML, so restart it to pick up an update, then enable.
# Right after a restart the shell can report "not responding"; retry.
omarchy restart shell >/dev/null 2>&1 || true
for _ in 1 2 3 4 5; do
  sleep 2
  omarchy plugin enable "$id" >/dev/null 2>&1 || true
  omarchy plugin list 2>/dev/null | grep -qE "^$id +enabled" && break
done
omarchy plugin list 2>/dev/null | grep -qE "^$id +enabled" \
  || echo "Could not enable $id yet; run: omarchy plugin enable $id"

cat <<EOF
Installed $id. A brightness icon is now in the bar.

Keyboard shortcuts: Omarchy's brightness keys call omarchy-brightness-display,
which does not know about the overlay. To make keys work on the T6 screen too,
bind them to:
  $dest/brightness-display +5%
  $dest/brightness-display 5%-
EOF
