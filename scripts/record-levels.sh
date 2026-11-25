#!/usr/bin/env bash
# Nahraje N sekund z výstupu 2.1 (co právě hraje) a vypíše úrovně FL/FR/LFE,
# nejhlasitější sekundu, špičku a počet ořezaných vzorků.
#
#   scripts/record-levels.sh 30
set -euo pipefail
secs=${1:-20}
sink=${SINK:-alsa_output.pci-0000_0a_00.4.analog-surround-21}
out=$(mktemp --suffix=.wav)
trap 'rm -f "$out"' EXIT
timeout "$secs" pw-record --target "$sink" -P stream.capture.sink=true \
  --channels 3 --channel-map FL,FR,LFE --format s16 "$out" || true
python3 - "$out" <<'EOF'
import sys, wave, array, math
w = wave.open(sys.argv[1]); a = array.array("h"); a.frombytes(w.readframes(w.getnframes())); r = 48000
db = lambda v: 20 * math.log10(max(v, 1e-9))
for i, n in enumerate(["FL", "FR", "LFE"]):
    s = a[i::3]
    if not s:
        print("nic nenahráno"); break
    rms = math.sqrt(sum(v * v for v in s) / len(s)) / 32768
    loud = max((math.sqrt(sum(v * v for v in s[k:k + r]) / r) for k in range(0, max(1, len(s) - r), r // 2)), default=0) / 32768
    clip = sum(1 for v in s if abs(v) >= 32700)
    print(f"{n:>3}: RMS {db(rms):6.1f}  nejhlasitější 1 s {db(loud):6.1f}  špička {db(max(abs(v) for v in s) / 32768):6.1f} dBFS  ořez {clip}")
EOF
