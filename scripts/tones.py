#!/usr/bin/env python3
"""Generátor testovacích tónů pro ladění 2.1 (jen standardní knihovna).

Použití:
  tones.py align  out.wav [--minutes 3] [--lead 20]   # střídání 2 s sloupy / 2 s sub (90 Hz), 3 kanály
  tones.py phase  out.wav [--freq 90] [--lead 3]      # 8 s stereo tón (jde normální cestou přes upmix)
  tones.py sweep  out.wav [--start 30] [--end 120] [--seconds 40]  # pomalý stereo sweep
  tones.py lfe    out.wav [--freq 50]                 # 8 s tón jen v LFE kanálu (3 kanály)

Přehrání:
  3kanálové:  pw-play --target <sink> --channel-map FL,FR,LFE out.wav
  stereo:     paplay out.wav
"""
import argparse
import math
import struct
import wave

RATE = 48000
AMP = 3300  # cca -20 dBFS
# Změřená úroveň LFE na 90 Hz při channelmix.lfe-cutoff = 200 (viz README).
SUB_90HZ_DB = -4.4


def tone(seconds, amps, freq, fade=1200):
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        env = min(1.0, i / fade, (n - i) / fade)
        s = env * math.sin(2 * math.pi * freq * i / RATE)
        out.append(struct.pack("<" + "h" * len(amps), *(int(a * s) for a in amps)))
    return b"".join(out)


def silence(seconds, channels):
    return b"\0" * int(RATE * seconds) * 2 * channels


def write(path, channels, frames):
    with wave.open(path, "w") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=["align", "phase", "sweep", "lfe"])
    p.add_argument("out")
    p.add_argument("--minutes", type=float, default=1)
    p.add_argument("--lead", type=float, default=10)
    p.add_argument("--freq", type=float, default=90)
    p.add_argument("--start", type=float, default=30)
    p.add_argument("--end", type=float, default=120)
    p.add_argument("--seconds", type=float, default=40)
    a = p.parse_args()

    if a.mode == "align":
        sub = AMP * 10 ** (SUB_90HZ_DB / 20)
        cycle = tone(2, (AMP, AMP, 0), 90) + tone(2, (0, 0, sub), 90)
        write(a.out, 3, silence(a.lead, 3) + cycle * int(a.minutes * 15))
    elif a.mode == "phase":
        write(a.out, 2, silence(a.lead, 2) + tone(8, (AMP, AMP), a.freq))
    elif a.mode == "lfe":
        write(a.out, 3, tone(8, (0, 0, AMP), a.freq))
    elif a.mode == "sweep":
        n = int(RATE * a.seconds)
        k = math.log(a.end / a.start)
        frames = []
        for i in range(n):
            t = i / RATE
            # logaritmický sweep
            ph = 2 * math.pi * a.start * a.seconds / k * (math.exp(t / a.seconds * k) - 1)
            env = min(1.0, i / 2400, (n - i) / 2400)
            v = int(AMP * env * math.sin(ph))
            frames.append(struct.pack("<hh", v, v))
        write(a.out, 2, silence(a.lead, 2) + b"".join(frames))


if __name__ == "__main__":
    main()
