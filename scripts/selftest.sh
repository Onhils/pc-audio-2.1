#!/usr/bin/env bash
# Potichu ověří nainstalované nastavení (2.1 nebo 3.1): pustí testovací tóny přes kopii
# filtru do dočasného virtuálního výstupu a změří, kam co jde. Do reproduktorů nejde nic.
#   scripts/selftest.sh [2.1|3.1]      (bez parametru: podle ~/.config/pc-audio-mode)
set -euo pipefail
cfgdir=${XDG_CONFIG_HOME:-$HOME/.config}
mode=${1:-$(cat "$cfgdir/pc-audio-mode" 2>/dev/null || echo 2.1)}
work=$(mktemp -d)
fcpid=""; mod=""
cleanup() { [[ -n $fcpid ]] && kill "$fcpid" 2>/dev/null; [[ -n $mod ]] && pactl unload-module "$mod" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

mod=$(pactl load-module module-null-sink sink_name=selftest_out channels=6 \
      channel_map=front-left,front-right,rear-left,rear-right,front-center,lfe)
mkdir -p "$work/fc/pipewire/filter-chain.conf.d"
sed -e 's|target.object *= *"[^"]*"|target.object = "selftest_out"|' -e 's|room_eq_21|selftest_eq|g' \
    "$cfgdir/pipewire/pipewire.conf.d/91-room-eq.conf" > "$work/fc/pipewire/filter-chain.conf.d/eq.conf"
XDG_CONFIG_HOME="$work/fc" pipewire -c filter-chain.conf >"$work/fc.log" 2>&1 &
fcpid=$!
for _ in $(seq 1 20); do pactl list short sinks | awk '{print $2}' | grep -qx selftest_eq && break; sleep 0.3; done

python3 - "$work" <<'EOF'
import sys, wave, struct, math
d = sys.argv[1]
def mk(name, ch, mask, f):
    with wave.open(f"{d}/{name}.wav", "w") as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(48000)
        w.writeframes(b"".join(struct.pack("<" + "h" * ch, *(int(8000 * m * math.sin(2 * math.pi * f * i / 48000)) for m in mask)) for i in range(72000)))
for f in (50, 1000):
    mk(f"st{f}", 2, (1, 1), f)
    mk(f"fc{f}", 4, (0, 0, 1, 0), f)
EOF

measure() {  # $1 = popis, zbytek = přehrávací příkaz
  local label=$1; shift
  timeout 1.4 pw-record --target selftest_out -P stream.capture.sink=true --channels 6 \
    --channel-map FL,FR,RL,RR,FC,LFE --format s16 "$work/r.wav" &
  local rec=$!
  sleep 0.2; "$@" >/dev/null 2>&1; wait "$rec" || true
  python3 - "$work/r.wav" "$label" <<'EOF'
import sys, wave, array, math
w = wave.open(sys.argv[1]); a = array.array("h"); a.frombytes(w.readframes(w.getnframes()))
ref = 8000 / math.sqrt(2); n = len(a) // 6; s0 = n // 4
lv = {}
for i, nm in [(0, "FL"), (4, "FC"), (5, "LFE")]:
    x = a[6 * s0 + i::6]; v = math.sqrt(sum(t * t for t in x) / max(1, len(x)))
    lv[nm] = 20 * math.log10(max(v, 1e-3) / ref)
print(f"{sys.argv[2]:<22}" + "  ".join(f"{k} {v:6.1f} dB" for k, v in lv.items()))
EOF
}

out=$(
  measure "stereo 50 Hz"   pw-play --target selftest_eq "$work/st50.wav"
  measure "stereo 1 kHz"   pw-play --target selftest_eq "$work/st1000.wav"
  if [[ $mode == 3.1 ]]; then
    measure "centr 50 Hz"  pw-play --target selftest_eq --channel-map FL,FR,FC,LFE "$work/fc50.wav"
    measure "centr 1 kHz"  pw-play --target selftest_eq --channel-map FL,FR,FC,LFE "$work/fc1000.wav"
  fi
)
echo "$out"
python3 - "$mode" "$out" <<'EOF'
import re, sys
mode, out = sys.argv[1], sys.argv[2]
v = {}
for line in out.splitlines():
    label = line[:22].strip()
    for ch, val in re.findall(r"(FL|FC|LFE)\s+(-?[\d.]+) dB", line):
        v[(label, ch)] = float(val)
ok = v[("stereo 50 Hz", "LFE")] > -4 and v[("stereo 1 kHz", "LFE")] < -40 and v[("stereo 1 kHz", "FL")] > -2
if mode == "3.1":
    ok = ok and v[("stereo 1 kHz", "FC")] < -60 and v[("centr 1 kHz", "FC")] > -2 \
            and v[("centr 1 kHz", "LFE")] < -40 and v[("centr 50 Hz", "LFE")] > v[("centr 50 Hz", "FC")] + 3
sys.exit(0 if ok else 1)
EOF
