#!/usr/bin/env bash
# Jedno tlačítko: nainstaluje a nastaví zvuk na Fedoře.
#   2.1 = sloupy Mythos Four + Velodyne (přes Pentu)
#   3.1 = navíc centr Mythos Three (Penta CENTER SPEAKER OUT)
#   5.1 = navíc zadní 2× Mythos Five (Penta SPEAKER OUT REAR)
# Spouštět jako normální uživatel (ne sudo). Dá se spustit opakovaně – nic nerozbije.
#
#   ./setup.sh            # stejný režim jako minule (poprvé 2.1)
#   ./setup.sh 3.1        # přepnout na 3.1 (s centrem)
#   ./setup.sh 2.1        # přepnout zpět na 2.1
#   ./setup.sh 5.1        # navíc zadní 2× Mythos Five (černý jack -> Penta INPUT REAR)
#   REAR_DELAY_MS=8 ./setup.sh 5.1   # zpoždění zadních (zapamatuje se; viz NAVOD.md)
#   CARD=alsa_card.xxx ./setup.sh   # vynutit konkrétní zvukovou kartu
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
modefile="$HOME/.config/pc-audio-mode"
mode=${1:-$(cat "$modefile" 2>/dev/null || echo 2.1)}
case "$mode" in
  2.1) surround=21 ;;
  3.1) surround=51 ;;   # zvuková karta 3.1 neumí -> 5.1 profil, zadní kanály zůstanou nevyužité
  5.1) surround=51 ;;
  *) echo "Neznámý režim '$mode'. Použij: ./setup.sh 2.1 | 3.1 | 5.1"; exit 1 ;;
esac
M="$here/modes/$mode"
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
echo "${B}Režim: $mode${N}"
step "2/6 Hledám zvukovou kartu s výstupem $mode"
read -r card profile < <(pactl -f json list cards | SURROUND=$surround python3 -c '
import json, os, sys
want = os.environ.get("CARD")
sr = os.environ["SURROUND"]
best = None
for c in json.load(sys.stdin):
    if want and c["name"] != want:
        continue
    profs = c.get("profiles", {})
    for p in (f"output:analog-surround-{sr}+input:analog-stereo", f"output:analog-surround-{sr}"):
        if p in profs and profs[p].get("available", True):
            best = best or (c["name"], p)
            break
print(*(best or ("", "")))
')
[[ -n "$card" ]] || die "Nenašel jsem kartu s profilem Analog Surround (analog-surround-$surround). Jsou kabely zapojené vzadu do desky?"
pactl set-card-profile "$card" "$profile"
ok "Karta: $card"
ok "Profil: $profile"

sink=""
for _ in $(seq 1 20); do
  sink=$(pactl list short sinks | awk -v s="analog-surround-$surround" '$2 ~ s"$" {print $2; exit}')
  [[ -n "$sink" ]] && break
  sleep 0.5
done
[[ -n "$sink" ]] || die "Výstup analog-surround-$surround se neobjevil."
ok "Výstup: $sink"

# ---------------------------------------------------------------- 3. konfigurace
step "3/6 Kopíruju nastavení"
backup="$HOME/.config/pc-audio-backup-$(date +%Y%m%d-%H%M%S)"
for f in pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf pipewire/client.conf.d/90-lfe-sub.conf \
         pipewire/pipewire.conf.d/91-room-eq.conf wireplumber/wireplumber.conf.d/51-analog-no-suspend.conf \
         mpv/mpv.conf mpv/input.conf pc-audio-mode; do
  if [[ -f "$HOME/.config/$f" ]]; then mkdir -p "$backup/$(dirname "$f")"; cp "$HOME/.config/$f" "$backup/$f"; fi
done
if [[ -d "$backup" ]]; then ok "Stará nastavení zazálohována do $backup"; fi

install -Dm644 "$M/90-lfe-sub.conf" "$HOME/.config/pipewire/pipewire-pulse.conf.d/90-lfe-sub.conf"
install -Dm644 "$M/90-lfe-sub.conf" "$HOME/.config/pipewire/client.conf.d/90-lfe-sub.conf"
install -Dm644 "$here/common/51-analog-no-suspend.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/51-analog-no-suspend.conf"
install -Dm644 "$M/mpv.conf" "$HOME/.config/mpv/mpv.conf"
if [[ -f "$M/input.conf" ]]; then
  install -Dm644 "$M/input.conf" "$HOME/.config/mpv/input.conf"
elif grep -qs "^# pc-audio" "$HOME/.config/mpv/input.conf"; then
  rm -f "$HOME/.config/mpv/input.conf"
fi
mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"
delayfile="$HOME/.config/pc-audio-rear-delay-ms"
rear_ms=${REAR_DELAY_MS:-$(cat "$delayfile" 2>/dev/null || echo 0)}
[[ $rear_ms =~ ^[0-9]+([.][0-9]+)?$ ]] && python3 -c "import sys; sys.exit(0 if float('$rear_ms') <= 50 else 1)" \
  || die "REAR_DELAY_MS musí být číslo 0–50 (milisekundy), dostal jsem '$rear_ms'."
rear_s=$(python3 -c "print(round(float('$rear_ms')/1000, 5))")
sed -e "s|@SINK@|$sink|" -e "s|@REAR_DELAY_S@|$rear_s|g" -e "s|@REAR_DELAY_MS@|$rear_ms|g" \
    "$M/91-room-eq.conf.in" > "$HOME/.config/pipewire/pipewire.conf.d/91-room-eq.conf"
if [[ $mode == 5.1 ]]; then echo "$rear_ms" > "$delayfile"; fi
echo "$mode" > "$modefile"
ok "Basy do subu (dělení ~100 Hz)"
ok "Ekvalizér místnosti (70 Hz, 120 Hz)"
ok "Výstup se neuspává (žádné rušení v tichu)"
ok "mpv: filmy 5.1/7.1 se správně smíchají do $mode"
if [[ $mode != 2.1 ]]; then ok "Centr: basy pod 80 Hz jdou do subu, dialogy z Mythos Three"; ok "mpv klávesy: F1 = dialogy z centru, F2 = ze sloupů, F3 = mix"; fi
if [[ $mode == 5.1 ]]; then ok "Zadní: basy pod 100 Hz do subu, zpoždění $rear_ms ms, zap/vyp z telefonu"; fi

# ovládání mpv z telefonu (GSConnect / KDE Connect)
install -Dm755 "$here/common/mpv-ovladac" "$HOME/.local/bin/mpv-ovladac"
phones=0
if command -v dconf >/dev/null && [[ -n "$(dconf read /org/gnome/shell/extensions/gsconnect/devices 2>/dev/null)" ]]; then
  bin="$HOME/.local/bin/mpv-ovladac"
  list="{"
  i=0
  for pair in "centr:Dialogy: CENTR" "sloupy:Dialogy: SLOUPY" "mix:Dialogy: MIX" "zadni-zap:Zadní: ZAP" "zadni-vyp:Zadní: VYP (do sloupů)" "zpet:Zpět 5 s" "pauza:Pauza / přehrát" "smycka:Smyčka (začátek / konec / zrušit)"; do
    i=$((i+1)); cmd=${pair%%:*}; name=${pair#*:}
    list+="'pc-audio-$i': <{'name': <'$name'>, 'command': <'$bin $cmd'>}>, "
  done
  list="${list%, }}"
  for d in $(dconf read /org/gnome/shell/extensions/gsconnect/devices | tr -d "[]',"); do
    [[ "$(dconf read /org/gnome/shell/extensions/gsconnect/device/$d/type)" == "'phone'" ]] || continue
    [[ "$(dconf read /org/gnome/shell/extensions/gsconnect/device/$d/paired)" == "true" ]] || continue
    dconf write "/org/gnome/shell/extensions/gsconnect/device/$d/plugin/runcommand/command-list" "$list"
    phones=$((phones+1))
    ok "Telefon $(dconf read /org/gnome/shell/extensions/gsconnect/device/$d/name): příkazy pro mpv v KDE Connect → Spustit příkaz"
  done
fi
[[ $phones -gt 0 ]] || warn "Ovládání z telefonu: žádný spárovaný telefon v GSConnect (nevadí, jde to doplnit později)"

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
ok "Výchozí výstup: $mode EQ (místnost), hlasitost PC 100 %"
# probudit výstup hned teď i po každém přihlášení (jinak je do prvního zvuku uspaný -> rušení)
mkdir -p "$HOME/.local/share/pc-audio"
python3 -c 'import wave,sys; w=wave.open(sys.argv[1],"w"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000); w.writeframes(b"\0"*48000*4)' "$HOME/.local/share/pc-audio/silence.wav"
install -Dm644 "$here/common/pc-audio-wake.service" "$HOME/.config/systemd/user/pc-audio-wake.service"
systemctl --user daemon-reload
systemctl --user enable pc-audio-wake.service >/dev/null 2>&1 || warn "Nepodařilo se zapnout probouzení po přihlášení"
pw-play --target room_eq_21 "$HOME/.local/share/pc-audio/silence.wav" || true
ok "Výstup probuzený (i po každém přihlášení)"

# ---------------------------------------------------------------- 5. autotest
step "5/6 Kontroluju potichu, že basy jdou do subu (do reproduktorů nic nejde)"
if out=$("$here/scripts/selftest.sh" "$mode" 2>&1); then
  echo "$out" | sed 's/^/    /'
  ok "Sub dostává basy, výšky ne$([[ $mode != 2.1 ]] && echo "; centr$([[ $mode == 5.1 ]] && echo " i zadní") bez basů, ty jdou do subu")"
else
  echo "$out" | sed 's/^/    /'
  die "Autotest nesedí – kanály nejdou tam, kam mají."
fi

# ---------------------------------------------------------------- 6. hotovo
step "6/6 HOTOVO 🎉"
cat <<EOF

  ${B}Co teď:${N}
   1. Hlasitost v PC nech na 100 %. Hlasitost ovládej ovladačem od Penty.
   2. Spusť znovu prohlížeč / mpv, pokud běžely.
   3. Pusť si něco s basami – sub musí hrát.
   4. Když něco nesedí (nový pokoj, přesunutý sub, nový centr): ${B}./kalibrace.sh${N}
   5. Přepnutí režimu: ${B}./setup.sh 2.1${N}  /  ${B}./setup.sh 3.1${N}  /  ${B}./setup.sh 5.1${N}

  Podrobný návod: NAVOD.md
EOF
