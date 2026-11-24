#!/usr/bin/env bash
# Remove what install.sh added. Leaves evdi-dkms installed (other tools,
# e.g. DisplayLink, may use it); remove it with: yay -R evdi-dkms
set -euo pipefail
sudo systemctl disable --now triggerdm.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/triggerdm.service /usr/local/bin/triggerdm
sudo systemctl daemon-reload
echo "triggerdm service and binary removed."
