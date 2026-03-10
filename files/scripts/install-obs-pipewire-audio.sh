#!/usr/bin/env bash
set -euo pipefail

# Install obs-pipewire-audio-capture plugin
# https://github.com/dimtpap/obs-pipewire-audio-capture

PLUGIN_DIR="/usr/lib64/obs-plugins"
URL="https://github.com/dimtpap/obs-pipewire-audio-capture/releases/download/1.2.1/linux-pipewire-audio-1.2.1.tar.gz"

TMPDIR=$(mktemp -d)
curl -sL "$URL" -o "${TMPDIR}/plugin.tar.gz"
tar -xzf "${TMPDIR}/plugin.tar.gz" -C "${TMPDIR}"
find "${TMPDIR}" -name "*.so" -exec cp -v {} "${PLUGIN_DIR}/" \;
rm -rf "${TMPDIR}"
