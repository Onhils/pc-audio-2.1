#!/usr/bin/env bash
# Jedno tlačítko: nainstaluje a nastaví zvuk 2.1 (Mythos Four + Velodyne přes Pentu) na Fedoře.
# Spouštět jako normální uživatel (ne sudo). Dá se spustit opakovaně – nic nerozbije.
#
#   ./setup.sh            # vše automaticky
#   CARD=alsa_card.xxx ./setup.sh   # vynutit konkrétní zvukovou kartu
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[1m'; N=$'\e[0m'
step() { echo; echo "${B}▶ $*${N}"; }
ok()   { echo "  ${G}✓${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; }
die()  { echo; echo "${R}✗ $*${N}"; echo "Nic se nerozbilo, jen se nastavení nedokončilo. Pošli tenhle výpis Claudovi."; exit 1; }

[[ $EUID -eq 0 ]] && die "Nespouštěj přes sudo. Spusť jen ./setup.sh – o heslo si skript řekne sám, když bude potřeba."

# ---------------------------------------------------------------- 1. balíčky
step "1/6 Kontroluju programy"
pkgs=(mpv pipewire-utils pulseaudio-utils wireplumber python3)
missing=()
for p in "${pkgs[@]}"; do rpm -q "$p" >/dev/null 2>&1 || missing+=("$p"); done
if ((${#missing[@]})); then
  warn "Chybí: ${missing[*]} – instaluju (zadej heslo k počítači, při psaní se nic nezobrazuje, to je normální)"
  sudo dnf install -y "${missing[@]}" || die "Instalace programů selhala (internet? heslo?)."
fi
ok "mpv, PipeWire nástroje a python jsou nainstalované"
systemctl --user is-active --quiet pipewire || die "PipeWire neběží. Je to Fedora s výchozím zvukem?"
ok "PipeWire běží"

# ---------------------------------------------------------------- 2. zvuková karta
step "2/6 Hledám zvukovou kartu s výstupem 2.1"
read -r card profile < <(pactl -f json list cards | python3 -c '
import json, os, sys
want = os.environ.get("CARD")
best = None
for c in json.load(sys.stdin):
    if want and c["name"] != want:
        continue
    profs = c.get("profiles", {})
    for p in ("output:analog-surround-21+input:analog-stereo", "output:analog-surround-21"):
        if p in profs and profs[p].get("available", True):
            best = best or (c["name"], p)
            break
print(*(best or ("", "")))
')
[[ -n "$card" ]] || die "Nenašel jsem kartu s profilem Analog Surround 2.1. Jsou kabely zapojené vzadu do desky?"
pactl set-card-profile "$card" "$profile"
ok "Karta: $card"
ok "Profil: $profile"

sink=""
for _ in $(seq 1 20); do
  sink=$(pactl list short sinks | awk '$2 ~ /analog-surround-21$/ {print $2; exit}')
  [[ -n "$sink" ]] && break
  sleep 0.5
done
[[ -n "$sink" ]] || die "Výstup 2.1 se neobjevil."
ok "Výstup: $sink"

# ---------------------------------------------------------------- 3. konfigurace
step "3/6 Kopíruju nastavení"
backup="$HOME/.config/pc-audio-backup-$(date +%Y%m%d-%H%M%S)"
for f in pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf pipewire/client.conf.d/90-lfe-sub.conf \
         pipewire/pipewire.conf.d/91-room-eq.conf wireplumber/wireplumber.conf.d/51-analog-no-suspend.conf \
         mpv/mpv.conf; do
  if [[ -f "$HOME/.config/$f" ]]; then mkdir -p "$backup/$(dirname "$f")"; cp "$HOME/.config/$f" "$backup/$f"; fi
done
[[ -d "$backup" ]] && ok "Stará nastavení zazálohována do $backup"

install -Dm644 "$here/config/pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf" "$HOME/.config/pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf"
install -Dm644 "$here/config/pipewire/client.conf.d/90-lfe-sub.conf"        "$HOME/.config/pipewire/client.conf.d/90-lfe-sub.conf"
install -Dm644 "$here/config/wireplumber/wireplumber.conf.d/51-analog-no-suspend.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/51-analog-no-suspend.conf"
install -Dm644 "$here/config/mpv/mpv.conf"                                  "$HOME/.config/mpv/mpv.conf"
mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"
sed "s|@SINK@|$sink|" "$here/templates/91-room-eq.conf.in" > "$HOME/.config/pipewire/pipewire.conf.d/91-room-eq.conf"
ok "Basy do subu (dělení ~100 Hz)"
ok "Ekvalizér místnosti (70 Hz, 120 Hz)"
ok "Výstup se neuspává (žádné rušení v tichu)"
ok "mpv: filmy 5.1/7.1 se správně smíchají do 2.1"

# ---------------------------------------------------------------- 4. restart
step "4/6 Restartuju zvuk (na chvilku ztichne všechno, co hraje)"
systemctl --user restart pipewire pipewire-pulse wireplumber
# po restartu chvíli trvá, než se karta a ekvalizér znovu objeví – zkoušet opakovaně
retry() { for _ in $(seq 1 40); do "$@" >/dev/null 2>&1 && return 0; sleep 0.5; done; return 1; }
has_sink() { pactl list short sinks | awk '{print $2}' | grep -qx "$1"; }
retry has_sink room_eq_21 || die "Ekvalizér (room_eq_21) se nespustil."
retry pactl set-card-profile "$card" "$profile" || warn "Profil karty se nepodařilo znovu nastavit"
retry has_sink "$sink" || die "Výstup 2.1 se po restartu neobjevil."
retry pactl set-default-sink room_eq_21 || die "Nejde nastavit výchozí výstup."
retry pactl set-sink-volume room_eq_21 100% || warn "Hlasitost ekvalizéru nastav ručně na 100 %"
retry pactl set-sink-volume "$sink" 100%    || warn "Hlasitost výstupu nastav ručně na 100 %"
retry pactl set-sink-mute "$sink" 0         || true
ok "Výchozí výstup: 2.1 EQ (místnost), hlasitost PC 100 %"

# ---------------------------------------------------------------- 5. autotest
step "5/6 Kontroluju potichu, že basy jdou do subu (do reproduktorů nic nejde)"
if out=$("$here/scripts/measure-lfe-response.sh" 2>&1); then
  echo "$out" | sed 's/^/    /'
  python3 - "$out" <<'EOF' || die "Basy do subu nejdou podle očekávání."
import re, sys
vals = {int(f): float(v) for f, v in re.findall(r"(\d+) Hz: LFE vs FL\s+(-?[\d.]+)", sys.argv[1])}
assert vals.get(50, -99) > -2 and vals.get(150, 0) < -10, vals
EOF
  ok "Sub dostává basy pod ~100 Hz, výšky ne"
else
  warn "Autotest se nepovedl spustit (nevadí, nastavení je hotové):"
  echo "$out" | tail -3 | sed 's/^/    /'
fi

# ---------------------------------------------------------------- 6. hotovo
step "6/6 HOTOVO 🎉"
cat <<EOF

  ${B}Co teď:${N}
   1. Hlasitost v PC nech na 100 %. Hlasitost ovládej ovladačem od Penty.
   2. Spusť znovu prohlížeč / mpv, pokud běžely.
   3. Pusť si něco s basami – sub musí hrát.
   4. Když něco nesedí (nový pokoj, přesunutý sub): ${B}./kalibrace.sh${N}

  Podrobný návod: NAVOD.md
EOF
