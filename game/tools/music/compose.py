#!/usr/bin/env python3
"""Trivia Arena — müzik ve orkestral ses efektleri bestecisi.

Oyundaki bütün müzikler bu dosyadaki notalardan sentezlenir (ses örneği yok).
Çıktı: game/assets/audio/music/*.ogg ve game/assets/audio/sfx/*.ogg

Kullanım:
    pip install numpy scipy soundfile
    python3 game/tools/music/compose.py            # hepsi
    python3 game/tools/music/compose.py conquest   # tek parça

Bir parçayı değiştirmek için aşağıdaki PIECES sözlüğündeki fonksiyonu düzenle:
notalar (isim, vuruş, süre) listeleridir; enstrümanlar synth_* fonksiyonları.
Döngüler kesintisizdir: yankı kuyruğu parçanın başına sarılır.
"""
import math
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_MUSIC = os.path.normpath(os.path.join(ROOT, "..", "..", "assets", "audio", "music"))
OUT_SFX = os.path.normpath(os.path.join(ROOT, "..", "..", "assets", "audio", "sfx"))
RNG = np.random.default_rng(7)

# ── nota adları ─────────────────────────────────────────────────────
_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name):
    """'A4', 'F#3', 'Bb2' → frekans"""
    n = _NAMES[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        n += 1 if name[i] == "#" else -1
        i += 1
    octave = int(name[i:])
    midi = 12 * (octave + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


def chord(root, kind="m"):
    """Kök + akor türü → nota adları (üç ses)"""
    base = hz(root)
    iv = {"M": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "sus": [0, 5, 7], "dim": [0, 3, 6]}[kind]
    return [base * 2 ** (i / 12) for i in iv]


# ── zarflar ve yardımcılar ─────────────────────────────────────────
def adsr(n, a, d, s, r, sr=SR):
    a_n, d_n, r_n = int(a * sr), int(d * sr), int(r * sr)
    s_n = max(0, n - a_n - d_n - r_n)
    env = np.concatenate([
        np.linspace(0, 1, max(1, a_n), endpoint=False),
        np.linspace(1, s, max(1, d_n), endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, max(1, r_n)),
    ])
    return env[:n] if len(env) >= n else np.pad(env, (0, n - len(env)))


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def saw(f, t, detune=0.0):
    ph = (f * (1 + detune)) * t
    return 2.0 * (ph - np.floor(ph + 0.5))


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, SR * 0.45) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def noise(n):
    return RNG.uniform(-1, 1, n)


# ── enstrümanlar (hepsi mono dizi döndürür) ────────────────────────
def synth_strings(f, dur, vel=0.5, bright=2400):
    """Yaylı pad: birkaç hafif akortsuz testere, yavaş giriş, vibrato"""
    t = t_axis(dur + 0.6)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.5, 0, 1)
    x = sum(saw(f * vib, t, d) for d in (-0.006, -0.002, 0.003, 0.007)) / 4
    x = lowpass(x, bright)
    return x * adsr(len(t), 0.18, 0.2, 0.85, 0.55) * vel


def synth_brass(f, dur, vel=0.6, bright=1.0):
    """Bakır: testere, zarfla açılan filtre (ısırma), hafif vibrato"""
    t = t_axis(dur + 0.25)
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.2) / 0.4, 0, 1)
    x = saw(f * vib, t) * 0.7 + saw(f * vib, t, 0.004) * 0.3
    dark = lowpass(x, f * 2.2)
    lit = lowpass(x, min(f * 9 * bright, 7000))
    k = np.clip(t / 0.07, 0, 1) * np.exp(-t * 2.2) * 0.8 + 0.25
    y = dark * (1 - k) + lit * k
    return y * adsr(len(t), 0.03, 0.15, 0.8, 0.2) * vel


def synth_horn(f, dur, vel=0.5):
    """Korno: yumuşak, yuvarlak (düşük harmonikler), yavaş giriş"""
    t = t_axis(dur + 0.35)
    vib = 1 + 0.0035 * np.sin(2 * np.pi * 4.8 * t)
    x = np.zeros_like(t)
    for h, a in ((1, 1.0), (2, 0.55), (3, 0.28), (4, 0.12), (5, 0.05)):
        x += a * np.sin(2 * np.pi * f * h * vib * t)
    x = lowpass(x, 2200)
    return x / 2.0 * adsr(len(t), 0.07, 0.2, 0.9, 0.3) * vel


def synth_pizz(f, dur=0.5, vel=0.6):
    """Pizzicato / koparma: Karplus-Strong"""
    n = int(max(dur, 0.35) * SR)
    period = max(2, int(SR / f))
    buf = lowpass(noise(period), min(f * 8, 8000), 1)
    out = np.zeros(n)
    ring = buf.copy()
    decay = 0.994 if f < 200 else 0.989
    idx = 0
    prev = 0.0
    for i in range(n):
        v = ring[idx]
        out[i] = v
        nv = decay * 0.5 * (v + prev)
        prev = v
        ring[idx] = nv
        idx = (idx + 1) % period
    out = lowpass(out, 4200)
    return out * vel * 1.6 * adsr(n, 0.002, 0.05, 1.0, 0.06)


def synth_bell(f, dur=1.6, vel=0.4):
    """Glokenşpil/çelesta: uyumsuz kısmi sesler, hızlı sönüm"""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for m, a, d in ((1, 1.0, 1.4), (2.76, 0.4, 3.0), (5.4, 0.2, 5.0), (8.9, 0.08, 7.0)):
        x += a * np.sin(2 * np.pi * f * m * t) * np.exp(-t * d)
    return x * vel * adsr(len(t), 0.002, 0.01, 1.0, 0.05)


def synth_timpani(f, dur=1.4, vel=0.8):
    t = t_axis(dur)
    pitch = f * (1 + 0.12 * np.exp(-t * 18))
    ph = 2 * np.pi * np.cumsum(pitch) / SR
    x = np.sin(ph) + 0.35 * np.sin(ph * 1.5) * np.exp(-t * 6) + 0.2 * np.sin(ph * 1.99) * np.exp(-t * 4)
    x = x * np.exp(-t * 2.6)
    hit = lowpass(noise(len(t)), 900) * np.exp(-t * 40) * 0.8
    return (x + hit) * vel * 0.8


def synth_bass_drum(dur=0.9, vel=0.9, f0=95, f1=42):
    t = t_axis(dur)
    pitch = f1 + (f0 - f1) * np.exp(-t * 16)
    ph = 2 * np.pi * np.cumsum(pitch) / SR
    x = np.sin(ph) * np.exp(-t * 4.5)
    click = lowpass(noise(len(t)), 1800) * np.exp(-t * 70) * 0.5
    return np.tanh((x + click) * 1.4) * vel


def synth_snare(dur=0.35, vel=0.5):
    t = t_axis(dur)
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 28) * 0.6
    rattle = bandpass(noise(len(t)), 1500, 7000) * np.exp(-t * 24) * 0.8
    return (body + rattle) * vel


def synth_hat(dur=0.08, vel=0.25, open_=False):
    t = t_axis(0.35 if open_ else dur)
    x = highpass(noise(len(t)), 7000) * np.exp(-t * (9 if open_ else 55))
    return x * vel


def synth_cymbal(dur=2.5, vel=0.3):
    t = t_axis(dur)
    x = highpass(noise(len(t)), 4500) * np.exp(-t * 1.6)
    shim = sum(np.sin(2 * np.pi * f * t) for f in (3170, 4410, 5230, 6780)) * 0.05 * np.exp(-t * 2)
    return (x + shim) * vel * adsr(len(t), 0.004, 0.01, 1.0, 0.2)


# ── karıştırıcı ─────────────────────────────────────────────────────
class Track:
    """Stereo miks: add(ses, saniye, pan) — pan -1 sol, +1 sağ"""

    def __init__(self, seconds, bpm, beats_per_bar=4):
        self.len = int(seconds * SR)
        self.buf = np.zeros((self.len + SR * 6, 2))
        self.bpm = bpm
        self.bpb = beats_per_bar
        self.beat = 60.0 / bpm

    def at(self, bar, beat=0.0):
        return (bar * self.bpb + beat) * self.beat

    def add(self, x, sec, pan=0.0, gain=1.0):
        i = int(sec * SR)
        if i >= len(self.buf):
            return
        x = x[: len(self.buf) - i] * gain
        l = math.cos((pan + 1) * math.pi / 4)
        r = math.sin((pan + 1) * math.pi / 4)
        self.buf[i:i + len(x), 0] += x * l
        self.buf[i:i + len(x), 1] += x * r


def reverb(stereo, seconds=2.2, wet=0.28, predelay=0.02, damp=5000):
    """Tiyatro salonu: sönen gürültüden sentetik dürtü yanıtı ile evrişim"""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = stereo * (1 - wet * 0.5)
    for ch in range(2):
        ir = noise(n) * np.exp(-t * 6.9 / seconds)
        ir = lowpass(ir, damp, 1)
        ir[: int(predelay * SR)] = 0
        # erken yansımalar
        for d, a in ((0.013, 0.5), (0.021, 0.35), (0.034, 0.28), (0.047, 0.2)):
            j = int((d + 0.003 * ch) * SR)
            ir[j] += a
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        out[:, ch] += signal.fftconvolve(stereo[:, ch], ir)[: len(stereo)] * wet
    return out


def master(tr, loop=True, rev=(2.2, 0.28), gain_db=-1.0):
    x = reverb(tr.buf, *rev)
    if loop:
        body = x[: tr.len].copy()
        tail = x[tr.len:]
        body[: len(tail)] += tail[: len(body)]
        x = body
    else:
        # sondaki sessizliği kırp
        e = np.max(np.abs(x), axis=1)
        last = np.nonzero(e > 1e-4)[0]
        x = x[: (last[-1] + SR // 10) if len(last) else len(x)]
        fade = min(len(x), int(0.05 * SR))
        x[-fade:] *= np.linspace(1, 0, fade)[:, None]
    # tiz yumuşatma (salonun perdeleri) + hafif sıkıştırma + tepe normalize
    for ch in range(2):
        x[:, ch] = lowpass(x[:, ch], 7500, 1)
    x = np.tanh(x * 1.2) / np.tanh(1.2)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * (10 ** (gain_db / 20))
    return x.astype(np.float32)


def write(name, x, folder):
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name + ".ogg")
    sf.write(path, x, SR, format="OGG", subtype="VORBIS")
    print("yazıldı", os.path.relpath(path), "%.1f sn" % (len(x) / SR))


# ── parçalar ────────────────────────────────────────────────────────
def piece_conquest():
    """Savaş odası marşı: Re minör, 104 bpm, 16 ölçü. Tok ostinato, trampet,
    timpani, kornoda kahramanca tema; ikinci yarıda bakır cevap verir."""
    bpm = 104
    bars = 16
    tr = Track(bars * 4 * 60 / bpm, bpm)
    prog = [("D", "m"), ("D", "m"), ("Bb", "M"), ("C", "M"), ("D", "m"), ("D", "m"), ("G", "m"), ("A", "M")] * 2
    roots = {"D": "D2", "Bb": "Bb1", "C": "C2", "G": "G1", "A": "A1"}
    for bar, (r, k) in enumerate(prog):
        root = roots[r]
        f = hz(root)
        # ostinato: dörtlük ve sekizlik vuruşlu bas (çello+kontrbas)
        for i, (b, d, acc) in enumerate(((0, 0.5, 1.0), (0.5, 0.5, 0.6), (1, 0.5, 0.8), (1.5, 0.5, 0.6), (2, 0.5, 1.0), (2.5, 0.25, 0.6), (2.75, 0.25, 0.6), (3, 0.5, 0.85), (3.5, 0.5, 0.6))):
            tr.add(synth_brass(f, d * tr.beat * 0.9, 0.34 * acc, 0.5), tr.at(bar, b), -0.25)
            tr.add(synth_strings(f * 2, d * tr.beat * 0.8, 0.14 * acc, 1600), tr.at(bar, b), 0.2)
        # yaylı akor yatağı
        for j, cf in enumerate(chord(r + "3", k)):
            tr.add(synth_strings(cf, 4 * tr.beat, 0.11, 2000), tr.at(bar), -0.5 + j * 0.5)
        # timpani 1 ve 3
        tr.add(synth_timpani(f * 2, 1.2, 0.55), tr.at(bar, 0), 0.0)
        tr.add(synth_timpani(f * 2 * (1.5 if bar % 2 else 1), 1.0, 0.35), tr.at(bar, 2), 0.0)
        # trampet marşı
        for b, v in ((0, 0.35), (1, 0.5), (1.5, 0.25), (1.75, 0.3), (2, 0.35), (3, 0.55), (3.25, 0.22), (3.5, 0.3), (3.75, 0.35)):
            tr.add(synth_snare(0.3, v * 0.5), tr.at(bar, b), 0.3)
        if bar % 8 == 7:
            for s in range(8):
                tr.add(synth_snare(0.2, 0.12 + s * 0.035), tr.at(bar, 2 + s * 0.25), 0.3)
        if bar % 4 == 0:
            tr.add(synth_cymbal(2.4, 0.16), tr.at(bar), 0.5)
    # korno teması (ölçü 4'ten itibaren) — (nota, ölçü, vuruş, süre-vuruş)
    theme = [
        ("D4", 4, 0, 1.5), ("A4", 4, 1.5, 0.5), ("A4", 4, 2, 1), ("G4", 4, 3, 0.5), ("F4", 4, 3.5, 0.5),
        ("E4", 5, 0, 1.5), ("F4", 5, 1.5, 0.5), ("D4", 5, 2, 2),
        ("Bb3", 6, 0, 1), ("D4", 6, 1, 1), ("G4", 6, 2, 1.5), ("F4", 6, 3.5, 0.5),
        ("E4", 7, 0, 1), ("C#4", 7, 1, 1), ("A3", 7, 2, 2),
        ("D4", 12, 0, 1.5), ("A4", 12, 1.5, 0.5), ("D5", 12, 2, 1.5), ("C5", 12, 3.5, 0.5),
        ("Bb4", 13, 0, 1), ("A4", 13, 1, 1), ("G4", 13, 2, 1), ("F4", 13, 3, 1),
        ("G4", 14, 0, 1.5), ("A4", 14, 1.5, 0.5), ("Bb4", 14, 2, 1), ("G4", 14, 3, 1),
        ("A4", 15, 0, 2), ("E4", 15, 2, 1), ("C#4", 15, 3, 1),
    ]
    for n, bar, b, d in theme:
        tr.add(synth_horn(hz(n), d * tr.beat * 0.95, 0.5), tr.at(bar, b), -0.15)
        tr.add(synth_horn(hz(n) / 2, d * tr.beat * 0.95, 0.22), tr.at(bar, b), 0.15)
    # bakır cevaplar (trompet)
    for bar in (9, 11):
        for n, b, d in (("A4", 0, 0.5), ("A4", 0.5, 0.25), ("A4", 0.75, 0.25), ("D5", 1, 1), ("F5", 2, 0.5), ("E5", 2.5, 0.5), ("D5", 3, 1)):
            tr.add(synth_brass(hz(n), d * tr.beat * 0.9, 0.3, 1.0), tr.at(bar, b), 0.35)
    return master(tr, True, (2.0, 0.24))


def piece_lobby():
    """Kulis valsi: Fa majör 3/4, 138 bpm, 24 ölçü. Pizzicato bas + akor,
    çelestada neşeli melodi, arkada yumuşak yaylılar."""
    bpm = 138
    bars = 24
    tr = Track(bars * 3 * 60 / bpm, bpm, 3)
    prog = [("F", "M", "F2"), ("F", "M", "F2"), ("C", "7", "C2"), ("C", "7", "C2"), ("C", "7", "G2"), ("C", "7", "C2"), ("F", "M", "F2"), ("F", "M", "C2"),
            ("Bb", "M", "Bb1"), ("Bb", "M", "D2"), ("F", "M", "C2"), ("D", "m", "D2"), ("G", "m", "G2"), ("C", "7", "C2"), ("F", "M", "F2"), ("C", "7", "C2")]
    prog = prog + prog[:8]
    for bar, (r, k, bass) in enumerate(prog):
        tr.add(synth_pizz(hz(bass), 0.8, 0.8), tr.at(bar, 0), -0.2)
        cs = chord(r + "3", k)[:3]
        for b in (1, 2):
            for j, cf in enumerate(cs):
                tr.add(synth_pizz(cf * 2, 0.35, 0.28), tr.at(bar, b), -0.3 + j * 0.3)
        for j, cf in enumerate(chord(r + "3", k)[:3]):
            tr.add(synth_strings(cf, 3 * tr.beat, 0.05, 1500), tr.at(bar), 0.4 - j * 0.4)
        tr.add(synth_hat(0.06, 0.05), tr.at(bar, 1), 0.6)
        tr.add(synth_hat(0.06, 0.04), tr.at(bar, 2), 0.6)
    mel = [
        ("A5", 0, 0, 2), ("C6", 0, 2, 1), ("F5", 1, 0, 3),
        ("G5", 2, 0, 1), ("A5", 2, 1, 1), ("Bb5", 2, 2, 1), ("C6", 3, 0, 2), ("G5", 3, 2, 1),
        ("Bb5", 4, 0, 2), ("E5", 4, 2, 1), ("G5", 5, 0, 2), ("Bb5", 5, 2, 1),
        ("A5", 6, 0, 1), ("G5", 6, 1, 1), ("F5", 6, 2, 1), ("C5", 7, 0, 3),
        ("D6", 8, 0, 2), ("Bb5", 8, 2, 1), ("F5", 9, 0, 2), ("D5", 9, 2, 1),
        ("C5", 10, 0, 1), ("F5", 10, 1, 1), ("A5", 10, 2, 1), ("D6", 11, 0, 2), ("A5", 11, 2, 1),
        ("Bb5", 12, 0, 1), ("A5", 12, 1, 1), ("G5", 12, 2, 1), ("E5", 13, 0, 2), ("C6", 13, 2, 1),
        ("F5", 14, 0, 3), ("E5", 15, 0, 1), ("G5", 15, 1, 1), ("Bb5", 15, 2, 1),
    ]
    for rep in (0, 16):
        for n, bar, b, d in mel:
            if bar + rep >= bars:
                continue
            tr.add(synth_bell(hz(n), 1.4, 0.3), tr.at(bar + rep, b), 0.25)
            if rep == 0 and bar >= 8:
                tr.add(synth_strings(hz(n) / 2, d * tr.beat, 0.07, 3000), tr.at(bar, b), -0.2)
    return master(tr, True, (2.6, 0.3))


def piece_trivia():
    """Yarışma swingi: Si bemol majör, 126 bpm, 16 ölçü. Yürüyen pizz bas,
    bakır vuruşlar, ritim zili, sordinalı trompet melodisi."""
    bpm = 126
    bars = 16
    tr = Track(bars * 4 * 60 / bpm, bpm)
    sw = 0.16   # swing: ikinci sekizlik geç gelir
    prog = [("Bb", "M"), ("G", "m7"), ("C", "m7"), ("F", "7")] * 4
    walks = {"Bb": ["Bb1", "D2", "F2", "A2"], "G": ["G1", "Bb1", "D2", "F2"], "C": ["C2", "Eb2", "G2", "A2"], "F": ["F1", "A1", "C2", "E2"]}
    for bar, (r, k) in enumerate(prog):
        for b, n in enumerate(walks[r]):
            tr.add(synth_pizz(hz(n), 0.5, 0.75), tr.at(bar, b), -0.15)
        for b in (0, 1, 2, 3):
            tr.add(synth_hat(0.07, 0.12 if b % 2 else 0.08), tr.at(bar, b), 0.5)
            tr.add(synth_hat(0.05, 0.06), tr.at(bar, b + 0.5 + sw), 0.5)
        tr.add(synth_bass_drum(0.5, 0.35, 80, 45), tr.at(bar, 0))
        tr.add(synth_snare(0.25, 0.2), tr.at(bar, 1))
        tr.add(synth_snare(0.25, 0.2), tr.at(bar, 3))
        # bakır stablar: 2'nin ve 4'ün arkası
        for b in (1.5 + sw, 3.5 + sw) if bar % 2 == 0 else (0.5 + sw, 2.5 + sw):
            for j, cf in enumerate(chord(r + "3", k)):
                tr.add(synth_brass(cf * 2, 0.16, 0.14, 0.9), tr.at(bar, b), -0.4 + j * 0.27)
    mel = [
        ("F4", 0, 0, 0.5), ("Bb4", 0, 0.5, 0.5), ("D5", 0, 1, 1), ("C5", 0, 2.5, 0.5), ("Bb4", 0, 3, 1),
        ("G4", 1, 0.5, 0.5), ("Bb4", 1, 1, 0.5), ("D5", 1, 1.5, 0.5), ("F5", 1, 2, 1.5),
        ("Eb5", 2, 0, 0.5), ("D5", 2, 0.5, 0.5), ("C5", 2, 1, 1), ("G4", 2, 2, 1), ("A4", 2, 3, 0.5), ("Bb4", 2, 3.5, 0.5),
        ("C5", 3, 0, 2), ("A4", 3, 2.5, 0.5), ("F4", 3, 3, 1),
    ]
    for rep in (4, 8, 12):
        for n, bar, b, d in mel:
            bb = b + (sw if (b * 2) % 2 == 1 else 0)
            up = 2 if rep == 12 else 1
            tr.add(synth_brass(hz(n) * up, d * tr.beat * 0.85, 0.3, 0.55), tr.at(bar + rep, bb), 0.2)
    return master(tr, True, (1.6, 0.2))


def piece_think():
    """Düşünme yatağı: 96 bpm, 8 ölçü. Saat gibi pizz tıkırtıları, alçak
    uğultu, kalp atışı timpani; soru süresince gerilim."""
    bpm = 96
    bars = 8
    tr = Track(bars * 4 * 60 / bpm, bpm)
    for bar in range(bars):
        root = ["D2", "D2", "Eb2", "D2", "D2", "D2", "Bb1", "A1"][bar]
        tr.add(synth_strings(hz(root), 4 * tr.beat, 0.16, 700), tr.at(bar), -0.3)
        tr.add(synth_strings(hz(root) * 1.5, 4 * tr.beat, 0.06, 900), tr.at(bar), 0.3)
        for s in range(8):
            n = ["A4", "D5", "A4", "E5", "A4", "D5", "A4", "F5"][s] if bar % 2 == 0 else ["A4", "C5", "A4", "D5", "A4", "Bb4", "A4", "C#5"][s]
            tr.add(synth_pizz(hz(n), 0.25, 0.22 if s % 2 == 0 else 0.14), tr.at(bar, s * 0.5), 0.35 if s % 2 else -0.35)
        tr.add(synth_timpani(hz("D2"), 0.8, 0.35), tr.at(bar, 0))
        tr.add(synth_timpani(hz("D2"), 0.6, 0.22), tr.at(bar, 0.4))
        tr.add(synth_hat(0.05, 0.05), tr.at(bar, 1), 0.6)
        tr.add(synth_hat(0.05, 0.05), tr.at(bar, 3), 0.6)
    return master(tr, True, (2.4, 0.3), -3.0)


def piece_victory():
    """Zafer fanfarı (döngü yok): Si bemol majör, bakır + timpani + zil"""
    bpm = 120
    tr = Track(9.0, bpm)
    fan = [("F4", 0, 0.33), ("F4", 0.33, 0.33), ("F4", 0.66, 0.34), ("Bb4", 1, 1.5), ("F4", 2.5, 0.5), ("Bb4", 3, 0.5), ("D5", 3.5, 0.5),
           ("F5", 4, 3)]
    for n, b, d in fan:
        for j, mul in enumerate((1, 0.75 if n != "F5" else 0.8, 0.5)):
            tr.add(synth_brass(hz(n) * mul, d * tr.beat * 0.92, 0.32 - j * 0.07, 1.0), b * tr.beat, -0.3 + j * 0.3)
    for b in (0, 1, 2.5, 3, 3.5):
        tr.add(synth_timpani(hz("Bb2") if b != 2.5 else hz("F2"), 0.9, 0.5), b * tr.beat)
    for s in range(8):
        tr.add(synth_snare(0.2, 0.1 + s * 0.04), (3 + s * 0.125) * tr.beat, 0.3)
    tr.add(synth_cymbal(4.0, 0.4), 4 * tr.beat, 0.0)
    tr.add(synth_timpani(hz("Bb2"), 2.5, 0.8), 4 * tr.beat)
    for j, cf in enumerate(chord("Bb3", "M")):
        tr.add(synth_strings(cf * 2, 3.2, 0.14, 3500), 4 * tr.beat, -0.4 + j * 0.4)
        tr.add(synth_horn(cf, 3.2, 0.3), 4 * tr.beat, 0.4 - j * 0.4)
    return master(tr, False, (2.8, 0.32))


# ── orkestral efektler ──────────────────────────────────────────────
def sfx_drum():
    """Savaş davulu: derin gövde + deri tokluğu"""
    tr = Track(1.6, 120)
    tr.add(synth_bass_drum(1.4, 1.0, 110, 48), 0)
    tr.add(synth_timpani(hz("D2"), 1.2, 0.5), 0)
    return master(tr, False, (1.4, 0.25), -2.0)


def sfx_horn():
    """Savaş borusu: iki nota, tok bakır"""
    tr = Track(2.6, 90)
    for n, s, d in (("D3", 0.0, 0.45), ("A3", 0.45, 1.3)):
        tr.add(synth_brass(hz(n), d, 0.6, 0.8), s, -0.2)
        tr.add(synth_horn(hz(n) * 2, d, 0.35), s, 0.2)
    return master(tr, False, (2.2, 0.35), -2.0)


def sfx_collapse():
    """Kale çöküşü: gümbürtü, taş çatırtısı, moloz yağmuru"""
    dur = 3.2
    tr = Track(dur, 120)
    t = t_axis(dur)
    rumble = lowpass(noise(len(t)), 140, 2) * np.exp(-t * 1.2) * 3.0
    tr.add(rumble, 0)
    tr.add(synth_bass_drum(1.6, 1.0, 70, 30), 0.0)
    tr.add(synth_bass_drum(1.2, 0.7, 60, 28), 0.35)
    for i in range(70):
        s = 0.05 + RNG.exponential(0.5)
        if s > dur - 0.3:
            continue
        n = int(0.06 * SR)
        tt = np.arange(n) / SR
        crack = bandpass(noise(n), 600 + RNG.uniform(0, 2400), 5000) * np.exp(-tt * RNG.uniform(40, 90))
        tr.add(crack, s, RNG.uniform(-0.8, 0.8), 0.45 * math.exp(-s * 0.7))
    return master(tr, False, (2.6, 0.35), -1.0)


def sfx_sting():
    """Orkestra vuruşu (perde açılışı, düello)"""
    tr = Track(2.0, 120)
    for j, cf in enumerate(chord("D3", "m") + [hz("D4")]):
        tr.add(synth_brass(cf, 0.35, 0.3, 1.2), 0, -0.4 + j * 0.27)
        tr.add(synth_strings(cf * 2, 0.35, 0.18, 5000), 0, 0.4 - j * 0.27)
    tr.add(synth_timpani(hz("D2"), 1.2, 0.8), 0)
    tr.add(synth_cymbal(1.8, 0.3), 0, 0.3)
    return master(tr, False, (2.0, 0.3), -1.0)


def sfx_stamp():
    """Sancak cetvele çakılır: tahta tok + metal çınlama"""
    tr = Track(0.8, 120)
    t = t_axis(0.5)
    knock = lowpass(noise(len(t)), 1200) * np.exp(-t * 60) + np.sin(2 * np.pi * 220 * t) * np.exp(-t * 30) * 0.6
    tr.add(knock, 0)
    tr.add(synth_bell(hz("A5"), 0.5, 0.12), 0.0, 0.2)
    return master(tr, False, (0.8, 0.15), -3.0)


def sfx_roll():
    """Trampet tremolosu (gerilim, sonuç öncesi)"""
    tr = Track(2.0, 120)
    for s in range(36):
        tr.add(synth_snare(0.12, 0.08 + 0.3 * s / 36), s * 0.05, 0.2)
    tr.add(synth_cymbal(1.2, 0.25), 1.8, 0.2)
    return master(tr, False, (1.2, 0.2), -2.0)


def sfx_claim():
    """Toprak alındı: kısa bakır iki ses + zil"""
    tr = Track(1.4, 120)
    for n, s in (("F4", 0.0), ("C5", 0.12)):
        tr.add(synth_brass(hz(n), 0.22, 0.3, 1.0), s, -0.2)
    tr.add(synth_bell(hz("C6"), 1.0, 0.2), 0.12, 0.3)
    return master(tr, False, (1.4, 0.25), -3.0)


PIECES = {
    "conquest": (piece_conquest, OUT_MUSIC),
    "lobby": (piece_lobby, OUT_MUSIC),
    "trivia": (piece_trivia, OUT_MUSIC),
    "think": (piece_think, OUT_MUSIC),
    "victory": (piece_victory, OUT_MUSIC),
    "war_drum": (sfx_drum, OUT_SFX),
    "war_horn": (sfx_horn, OUT_SFX),
    "collapse": (sfx_collapse, OUT_SFX),
    "sting": (sfx_sting, OUT_SFX),
    "stamp": (sfx_stamp, OUT_SFX),
    "roll": (sfx_roll, OUT_SFX),
    "claim": (sfx_claim, OUT_SFX),
}

if __name__ == "__main__":
    want = sys.argv[1:] or list(PIECES)
    for name in want:
        fn, folder = PIECES[name]
        write(name, fn(), folder)
