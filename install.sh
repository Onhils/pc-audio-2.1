#!/usr/bin/env bash
# Nakopíruje konfiguraci do ~/.config a restartuje PipeWire.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
install -Dm644 "$here/config/pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf" ~/.config/pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf
install -Dm644 "$here/config/pipewire/client.conf.d/90-lfe-sub.conf"        ~/.config/pipewire/client.conf.d/90-lfe-sub.conf
install -Dm644 "$here/config/pipewire/pipewire.conf.d/91-room-eq.conf"       ~/.config/pipewire/pipewire.conf.d/91-room-eq.conf
install -Dm644 "$here/config/wireplumber/wireplumber.conf.d/51-analog-no-suspend.conf" ~/.config/wireplumber/wireplumber.conf.d/51-analog-no-suspend.conf
install -Dm644 "$here/config/mpv/mpv.conf"                                  ~/.config/mpv/mpv.conf
systemctl --user restart pipewire pipewire-pulse wireplumber
sleep 2
pactl set-default-sink room_eq_21
echo "Hotovo. Aplikace, které hrály, je potřeba spustit znovu (mpv, prohlížeč)."
