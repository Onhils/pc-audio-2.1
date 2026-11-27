#!/usr/bin/env bash
# Potichu (přes dočasný virtuální 2.1 výstup) změří, kolik signálu jde ze sterea do LFE
# pro zadané hodnoty channelmix.lfe-cutoff. Do reproduktorů nejde nic.
#
#   scripts/measure-lfe-response.sh            # změří skutečně nainstalované nastavení
#   scripts/measure-lfe-response.sh 100 200    # porovná zadané hodnoty lfe-cutoff
set -euo pipefail
cutoffs=("${@:-installed}")
freqs=(30 50 70 90 110 150)
work=$(mktemp -d)
trap 'pactl unload-module "$mod" 2>/dev/null || true; rm -rf "$work"' EXIT
mod=$(pactl load-module module-null-sink sink_name=lfe_test21 channels=3 channel_map=front-left,front-right,lfe)

python3 - "$work" "${freqs[@]}" <<'EOF'
import sys, wave, struct, math
d, fs = sys.argv[1], sys.argv[2:]
for f in map(int, fs):
    with wave.open(f"{d}/s{f}.wav", "w") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
        w.writeframes(b"".join(struct.pack("<hh", v, v) for v in
            (int(8000 * math.sin(2 * math.pi * f * i / 48000)) for i in range(96000))))
EOF

for c in "${cutoffs[@]}"; do
  if [[ $c == installed ]]; then
    cfg=${XDG_CONFIG_HOME:-$HOME/.config}
    echo "nainstalované nastavení:"
  else
    cfg="$work/cfg$c"
    mkdir -p "$cfg/pipewire/client.conf.d"
    printf 'stream.properties = {\n  channelmix.upmix = true\n  channelmix.lfe-cutoff = %s\n}\n' "$c" \
      > "$cfg/pipewire/client.conf.d/90-test.conf"
    echo "lfe-cutoff = $c"
  fi
  for f in "${freqs[@]}"; do
    timeout 1.8 pw-record --target lfe_test21 -P stream.capture.sink=true \
      --channels 3 --channel-map FL,FR,LFE --format s16 "$work/r$f.wav" &
    sleep 0.2
    XDG_CONFIG_HOME="$cfg" pw-play --target lfe_test21 "$work/s$f.wav"
    wait
  done
  python3 - "$work" "${freqs[@]}" <<'EOF'
import sys, wave, array, math
d, fs = sys.argv[1], sys.argv[2:]
rms = lambda s: math.sqrt(sum(v * v for v in s) / max(1, len(s)))
for f in fs:
    w = wave.open(f"{d}/r{f}.wav"); a = array.array("h"); a.frombytes(w.readframes(w.getnframes()))
    fl, lfe = rms(a[0::3]), rms(a[2::3])
    print(f"  {f:>4} Hz: LFE vs FL {20 * math.log10(max(lfe, 1e-9) / max(fl, 1e-9)):6.1f} dB")
EOF
done
