#!/usr/bin/env bash
# Nakopíruje konfiguraci do ~/.config a restartuje PipeWire.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
install -Dm644 "$here/config/pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf" ~/.config/pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf
install -Dm644 "$here/config/pipewire/client.conf.d/90-lfe-sub.conf"        ~/.config/pipewire/client.conf.d/90-lfe-sub.conf
install -Dm644 "$here/config/mpv/mpv.conf"                                  ~/.config/mpv/mpv.conf
systemctl --user restart pipewire pipewire-pulse wireplumber
echo "Hotovo. Aplikace, které hrály, je potřeba spustit znovu (mpv, prohlížeč)."
