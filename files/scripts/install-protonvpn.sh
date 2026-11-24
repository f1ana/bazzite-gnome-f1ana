#!/usr/bin/env bash
set -euo pipefail

# proton-vpn-daemon's %posttrans runs `systemctl daemon-reload/enable/start`.
# There is no running systemd in the build container, so `start` fails and dnf5
# aborts the whole transaction. SYSTEMD_OFFLINE=1 makes systemctl skip the
# runtime-only verbs (daemon-reload, start) while still performing `enable`,
# so the split-tunneling service is enabled in the image as intended.
# The protonvpn repo is added by the preceding dnf module in recipe.yml.
SYSTEMD_OFFLINE=1 dnf -y install proton-vpn-gnome-desktop
