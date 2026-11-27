#!/usr/bin/env python3
"""Generátor testovacích tónů pro ladění 2.1 (jen standardní knihovna).

Režimy:
  lfe    out.wav [--freq 50] [--seconds 10]          tón jen v LFE kanálu (3 kanály)
  align  out.wav [--seg 10] [--repeat 1] [--lead 3]  10 s sub / 10 s sloupy na 90 Hz (3 kanály);
                                                     sub má úroveň, jakou dostává z hudby
  phase  out.wav [--tone 7] [--pause 5] [--lead 10]  A: 80+100 Hz, pauza (přepnout fázi), B: 80+100 Hz (stereo)
  steps  out.wav [--tone 8] [--lead 10]              tóny 30–120 Hz pro měření (stereo)

Přehrání:
  3kanálové:  pw-play --target room_eq_21 --channel-map FL,FR,LFE out.wav
  stereo:     paplay out.wav
"""
import argparse
import math
import struct
import wave

RATE = 48000
AMP = 3300  # cca -20 dBFS
# Změřená úroveň LFE vůči FL na 90 Hz při channelmix.lfe-cutoff = 200 (viz README).
SUB_90HZ_DB = -4.4
STEPS = [30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 120]


def tone(seconds, amps, freq, fade=1200):
    n = int(RATE * seconds)
    fmt = "<" + "h" * len(amps)
    out = []
    for i in range(n):
        env = min(1.0, i / fade, (n - i) / fade)
        s = env * math.sin(2 * math.pi * freq * i / RATE)
        out.append(struct.pack(fmt, *(int(a * s) for a in amps)))
    return b"".join(out)


def silence(seconds, channels):
    return b"\0" * (int(RATE * seconds) * 2 * channels)


def write(path, channels, frames):
    with wave.open(path, "w") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("mode", choices=["lfe", "align", "phase", "steps"])
    p.add_argument("out")
    p.add_argument("--freq", type=float, default=50)
    p.add_argument("--seconds", type=float, default=10)
    p.add_argument("--seg", type=float, default=10)
    p.add_argument("--repeat", type=int, default=1)
    p.add_argument("--tone", type=float, default=None)
    p.add_argument("--pause", type=float, default=5)
    p.add_argument("--lead", type=float, default=None)
    a = p.parse_args()

    if a.mode == "lfe":
        lead = 2 if a.lead is None else a.lead
        write(a.out, 3, silence(lead, 3) + tone(a.seconds, (0, 0, AMP), a.freq))
    elif a.mode == "align":
        lead = 3 if a.lead is None else a.lead
        sub = AMP * 10 ** (SUB_90HZ_DB / 20)
        cycle = tone(a.seg, (0, 0, sub), 90) + tone(a.seg, (AMP, AMP, 0), 90)
        write(a.out, 3, silence(lead, 3) + cycle * a.repeat)
    elif a.mode == "phase":
        lead = 10 if a.lead is None else a.lead
        t = a.tone or 7
        blk = tone(t, (AMP, AMP), 80) + silence(1, 2) + tone(t, (AMP, AMP), 100)
        write(a.out, 2, silence(lead, 2) + blk + silence(a.pause, 2) + blk)
    elif a.mode == "steps":
        lead = 10 if a.lead is None else a.lead
        t = a.tone or 8
        write(a.out, 2, silence(lead, 2) + b"".join(tone(t, (AMP, AMP), f) + silence(2, 2) for f in STEPS))


if __name__ == "__main__":
    main()
