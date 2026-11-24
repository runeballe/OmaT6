#!/usr/bin/env bash
# OmaT6: drive MCT Trigger 6 USB display adapters (e.g. "T6 USB Station")
# on Omarchy / Arch Linux + Hyprland, using MCT's open-source triggerdm
# driver on top of EVDI.
#
#   ./install.sh            install (asks for sudo where needed)
#   ./install.sh --preview  print what would happen, change nothing
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
PREVIEW=0
[[ "${1:-}" == "--preview" ]] && PREVIEW=1

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
run()  { if ((PREVIEW)); then printf '    would run: %s\n' "$*"; else "$@"; fi; }

step "1. Check for an MCT Trigger 6 device (USB 0711:56xx / 0711:57xx)"
if lsusb | grep -qiE 'ID 0711:5[67]'; then
    lsusb | grep -iE 'ID 0711:5[67]' | sed 's/^/    found: /'
else
    echo "    none plugged in right now (that's fine, the service waits for one)"
fi

step "2. EVDI (virtual display kernel module + libevdi)"
if [[ -e /usr/include/evdi_lib.h ]] && ldconfig -p | grep -q libevdi.so && modinfo evdi >/dev/null 2>&1; then
    echo "    already present (libevdi, header and kernel module found)"
    pacman -Qq evdi-dkms evdi-dkms-git >/dev/null 2>&1 \
        || echo "    note: no evdi-dkms package owns these files; DKMS won't rebuild EVDI on kernel updates. Run: yay -S evdi-dkms"
else
    command -v yay >/dev/null || { echo "    yay not found; install evdi-dkms from the AUR yourself"; exit 1; }
    run yay -S --needed evdi-dkms
fi
run sudo pacman -S --needed --noconfirm libusb libjpeg-turbo base-devel

step "3. Build triggerdm (MCT's driver, git submodule)"
run git submodule update --init triggerdm
run make -C triggerdm

step "4. Install the binary and the systemd service"
run sudo systemctl stop triggerdm.service 2>/dev/null || true
run sudo pkill -x triggerdm || true
run sudo install -Dm755 triggerdm/triggerdm /usr/local/bin/triggerdm
run sudo install -Dm644 systemd/triggerdm.service /etc/systemd/system/triggerdm.service
run sudo systemctl daemon-reload
run sudo systemctl enable --now triggerdm.service

step "5. Status"
if ((PREVIEW)); then
    echo "    (preview: nothing changed)"
else
    sleep 3
    systemctl --no-pager --lines=5 status triggerdm.service || true
    echo
    hyprctl monitors 2>/dev/null | grep -E '^Monitor' || true
    echo "    The T6 screen shows up as DVI-I-1 (or similar) once a monitor is attached."
fi
