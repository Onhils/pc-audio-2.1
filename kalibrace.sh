#!/usr/bin/env bash
# Průvodce laděním subu z postele. Spouštět po ./setup.sh.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
B=$'\e[1m'; N=$'\e[0m'
T="$here/scripts/tones.py"
play3() { pw-play --target room_eq_21 --channel-map FL,FR,LFE "$1"; }
play2() { paplay --device=room_eq_21 "$1"; }
wait_enter() { read -rp "  [Enter] = pokračovat " _; }

pactl list short sinks | awk '{print $2}' | grep -qx room_eq_21 || { echo "Nejdřív spusť ./setup.sh"; exit 1; }

while true; do
  cat <<EOF

${B}=== Kalibrace 2.1 ===${N}   (Penta na běžné hlasitosti filmu, PC 100 %)
  1) Hraje sub?            – 10 s tón jen do subu
  2) Hlasitost sub/sloupy  – 10 s sub, 10 s sloupy (točíš knobem na SUBU)
  3) Fáze 0°/180°          – A, pauza na přepnutí, B (nech, co je hlasitější)
  4) Měření basů telefonem – tóny 30–120 Hz po 8 s (zapiš dB, pošli Claudovi)
  q) Konec
EOF
  read -rp "Vyber: " c
  case "$c" in
    1) python3 "$T" lfe "$tmp/a.wav"
       echo "  Teď 10 s hraje JEN sub (50 Hz). Sloupy mají mlčet."; play3 "$tmp/a.wav"
       echo "  Sub nehrál? Zkontroluj: sub zapnutý, kabel Penta SUB OUT → sub, červený cinch z PC ve vstupu SUB na Pentě." ;;
    2) python3 "$T" align "$tmp/a.wav"
       while true; do
         echo "  Za 3 s: ${B}10 s SUB${N}, pak ${B}10 s SLOUPY${N}. Telefonem (nebo uchem) na posteli – má to být stejně."
         play3 "$tmp/a.wav"
         read -rp "  Znovu? [Enter = znovu, h = hotovo] " r; [[ "$r" == h* ]] && break
       done ;;
    3) python3 "$T" phase "$tmp/a.wav"
       echo "  Za 10 s: ${B}A${N} = 80 Hz (7 s), 100 Hz (7 s) → ${B}5 s pauza: přepni fázi${N} → ${B}B${N} = 80 Hz, 100 Hz"
       echo "  Zapiš si A80, A100, B80, B100. Nech fázi, kde jsou čísla VYŠŠÍ."
       play2 "$tmp/a.wav" ;;
    4) python3 "$T" steps "$tmp/a.wav"
       echo "  Telefon na místo hlavy na posteli, appka Sound Meter. Za 10 s začne:"
       echo "    #   1  2  3  4  5  6  7  8  9  10  11"
       echo "    Hz 30 35 40 45 50 60 70 80 90 100 120   (každý 8 s, mezi nimi 2 s ticho)"
       play2 "$tmp/a.wav"
       echo "  Pošli Claudovi 11 čísel + že je to pro ekvalizér v config/templates/91-room-eq.conf.in" ;;
    q|Q) exit 0 ;;
  esac
done
