#!/usr/bin/env bash
set -euo pipefail

# Compile /etc/dconf/db/gdm.d/* into the binary dconf database GDM reads.
dconf update
