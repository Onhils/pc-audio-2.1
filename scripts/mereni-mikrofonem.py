#!/usr/bin/env python3
"""Měření basů v místě poslechu mikrofonem připojeným k PC (např. Focusrite Solo + CM25).

Pustí krokový sinus 20–200 Hz po 1/24 oktávy (1 s na krok, ~80 s) do výstupu room_eq_21
(sloupy + sub tak, jak hrají hudbu), nahrává mikrofon a pro každý krok změří úroveň přesně
na dané frekvenci (Goertzel – šum okolo, např. ventilátory, se skoro nepočítá).
Na začátku je krátké pípnutí 1 kHz, podle kterého se srovná čas nahrávky.

  scripts/mereni-mikrofonem.py MIKROFON_SOURCE vystup.csv [--sink room_eq_21] [--amp 3300]
        [--fmin 20 --fmax 200 --per-oct 24 --step 1.0]

CSV: freq_hz, db (relativně, průměr 60–100 Hz = 0), db_bez_eq (odečtená křivka ekvalizéru)
"""
import argparse, array, csv, math, os, struct, subprocess, tempfile, time, wave

R = 48000
STEP = 1.0                     # s na frekvenci (--step)
FREQS = [20 * 2 ** (k / 24) for k in range(0, 81)]   # 20–200 Hz (--fmin/--fmax/--per-oct)
LEAD = 0.5                     # ticho před pípnutím
BEEP = 0.05
GAP = 0.45                     # ticho po pípnutí

EQ = [(37.0, 3.0, -4.0), (70.0, 5.0, -9.0), (120.0, 4.0, -10.0)]


def peaking_db(f, f0, q, g):
    import cmath
    A = 10 ** (g / 40); w = 2 * math.pi * f0 / R; al = math.sin(w) / (2 * q)
    b = [1 + al * A, -2 * math.cos(w), 1 - al * A]; a = [1 + al / A, -2 * math.cos(w), 1 - al / A]
    z = cmath.exp(-2j * math.pi * f / R)
    return 20 * math.log10(abs((b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)))


def goertzel(x, f):
    w = 2 * math.pi * f / R; c = 2 * math.cos(w); s1 = s2 = 0.0
    for v in x:
        s1, s2 = v + c * s1 - s2, s1
    p = s1 * s1 + s2 * s2 - c * s1 * s2
    return math.sqrt(max(p, 0)) * 2 / len(x)


def make_stimulus(path, amp):
    out = bytearray(); ph = 0.0
    out += b"\0" * (int(R * LEAD) * 4)
    n = int(R * BEEP)
    for i in range(n):
        v = int(amp * min(1, i / 48, (n - i) / 48) * math.sin(2 * math.pi * 1000 * i / R)); out += struct.pack("<hh", v, v)
    out += b"\0" * (int(R * GAP) * 4)
    total = int(R * STEP) * len(FREQS)
    for k, f in enumerate(FREQS):
        for i in range(int(R * STEP)):
            j = k * int(R * STEP) + i
            env = min(1.0, j / 2400, (total - j) / 2400)
            ph += 2 * math.pi * f / R
            v = int(amp * env * math.sin(ph)); out += struct.pack("<hh", v, v)
    out += b"\0" * (R * 4)
    with wave.open(path, "w") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(R); w.writeframes(bytes(out))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("mic"); p.add_argument("out")
    p.add_argument("--sink", default="room_eq_21"); p.add_argument("--amp", type=int, default=3300)
    p.add_argument("--fmin", type=float, default=20); p.add_argument("--fmax", type=float, default=200)
    p.add_argument("--per-oct", type=int, default=24); p.add_argument("--step", type=float, default=1.0)
    a = p.parse_args()
    global STEP, FREQS
    STEP = a.step
    FREQS = [a.fmin * 2 ** (k / a.per_oct) for k in range(int(round(math.log2(a.fmax / a.fmin) * a.per_oct)) + 1)]
    d = tempfile.mkdtemp()
    stim, rec = os.path.join(d, "s.wav"), os.path.join(d, "r.wav")
    make_stimulus(stim, a.amp)
    r = subprocess.Popen(["pw-record", "--target", a.mic, "--channels", "1", "--format", "s32", "--rate", str(R), rec])
    time.sleep(0.5)
    subprocess.run(["pw-play", "--target", a.sink, stim], check=True)
    time.sleep(0.5); r.terminate(); r.wait()
    w = wave.open(rec); x = array.array("i"); x.frombytes(w.readframes(w.getnframes()))
    x = [v / 2 ** 31 for v in x]
    # najdi pípnutí: 5ms bloky, energie na 1 kHz
    blk = 240; best = (0, 0)
    for s in range(0, min(len(x), R * 3) - blk, blk):
        e = goertzel(x[s:s + blk], 1000)
        if e > best[0]: best = (e, s)
    t0 = best[1] + int(R * (BEEP + GAP))  # začátek prvního kroku
    noise = goertzel(x[:int(R * 0.4)], 60)
    rows = []
    for k, f in enumerate(FREQS):
        s = t0 + int(R * (k * STEP + 0.45 * STEP)); e = t0 + int(R * (k * STEP + 0.95 * STEP))
        lv = 20 * math.log10(goertzel(x[s:e], f) + 1e-12)
        rows.append([f, lv])
    ref = [lv for f, lv in rows if 60 <= f <= 100] or [lv for f, lv in rows]; ref = sum(ref) / len(ref)
    with open(a.out, "w", newline="") as fh:
        cw = csv.writer(fh); cw.writerow(["freq_hz", "db", "db_bez_eq", "abs_dbfs"])
        for f, lv in rows:
            eq = sum(peaking_db(f, *b) for b in EQ)
            cw.writerow([f"{f:.1f}", f"{lv - ref:.1f}", f"{lv - ref - eq:.1f}", f"{lv:.1f}"])
    print(f"pípnutí nalezeno v {best[1] / R:.3f} s (síla {20*math.log10(best[0]+1e-12):.1f} dBFS), šum na 60 Hz {20*math.log10(noise+1e-12):.1f} dBFS")
    print(f"uloženo: {a.out}")


if __name__ == "__main__":
    main()
