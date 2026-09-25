#!/usr/bin/env python3
"""Mayhem "Kulağına Güven" sesleri: telif dışı melodiler ve tanıdık gündelik sesler.

Hepsi notadan / gürültüden sentezlenir (örnek ses yok). Çıktı:
    game/assets/audio/mayhem/<id>.ogg
Soru verisi (adlar, besteciler) tools/questions/mayhem_pack.py içinde; id'ler aynı.

Kullanım: python3 game/tools/music/mayhem_sounds.py [id ...]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import (SR, Track, hz, t_axis, adsr, lowpass, highpass, bandpass, noise,  # noqa: E402
                     synth_bell, synth_bass_drum, synth_pizz, master, write, _sm, _cal)

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio", "mayhem"))


# ── piyano benzeri ses ──────────────────────────────────────────────
def synth_piano(f, dur, vel=0.5):
    t = t_axis(max(dur, 0.25) + 0.6)
    x = np.zeros_like(t)
    for h, a, d in ((1, 1.0, 2.2), (2, 0.5, 3.0), (3, 0.28, 4.2), (4, 0.14, 5.5), (5, 0.07, 7.0), (6, 0.04, 8.0)):
        fh = f * h * (1 + 0.0004 * h * h)
        x += a * np.sin(2 * np.pi * fh * t) * np.exp(-t * d)
    hammer = bandpass(noise(len(t)), 1500, 6000) * np.exp(-t * 60) * 0.08
    env = adsr(len(t), 0.004, 0.05, 1.0, 0.12)
    rel = np.ones_like(t)
    cut = int(dur * SR)
    if cut < len(t):
        rel[cut:] = np.exp(-(t[cut:] - t[cut]) * 9)
    return (x / 2.0 + hammer) * env * rel * vel


def melody(notes, bpm, voice=synth_piano, bass=None, vel=0.55):
    """notes: [(nota ya da None, vuruş), ...]; bass: [(nota, vuruş), ...] sol el"""
    beat = 60.0 / bpm
    total = sum(d for _, d in notes) * beat + 1.2
    tr = Track(total, bpm)
    t = 0.0
    for n, d in notes:
        if n:
            tr.add(voice(hz(n), d * beat * 0.95, vel), t, 0.1)
        t += d * beat
    if bass:
        t = 0.0
        for n, d in bass:
            if n:
                tr.add(voice(hz(n), d * beat * 0.95, vel * 0.45), t, -0.25)
            t += d * beat
    return master(tr, False, (1.6, 0.22), -2.0)


def seq(s):
    """'E4:1 E4:1 F4:0.5 -:1' → [(nota, vuruş)]; '-' sus"""
    out = []
    for tok in s.split():
        n, d = tok.split(":")
        out.append((None if n == "-" else n, float(d)))
    return out


# ── melodiler (hepsi telif dışı) ────────────────────────────────────
MELODIES = {
    "ode": (seq("E4:1 E4:1 F4:1 G4:1 G4:1 F4:1 E4:1 D4:1 C4:1 C4:1 D4:1 E4:1 E4:1.5 D4:0.5 D4:2"), 120,
            seq("C3:4 G2:4 A2:4 G2:4")),
    "twinkle": (seq("C4:1 C4:1 G4:1 G4:1 A4:1 A4:1 G4:2 F4:1 F4:1 E4:1 E4:1 D4:1 D4:1 C4:2"), 120,
                seq("C3:4 F3:2 C3:2 F3:2 C3:2 G2:2 C3:2")),
    "frere": (seq("C4:1 D4:1 E4:1 C4:1 C4:1 D4:1 E4:1 C4:1 E4:1 F4:1 G4:2 E4:1 F4:1 G4:2"), 132, None),
    "birthday": (seq("G4:0.75 G4:0.25 A4:1 G4:1 C5:1 B4:2 G4:0.75 G4:0.25 A4:1 G4:1 D5:1 C5:2"), 110,
                 seq("-:1 C3:3 G2:3 G2:3 C3:3")),
    "elise": (seq("E5:0.5 D#5:0.5 E5:0.5 D#5:0.5 E5:0.5 B4:0.5 D5:0.5 C5:0.5 A4:1.5 -:0.5 C4:0.5 E4:0.5 A4:0.5 B4:1.5 -:0.5 E4:0.5 G#4:0.5 B4:0.5 C5:1.5"), 100,
              seq("-:4 A2:0.5 E3:0.5 A3:0.5 -:1.5 E2:0.5 E3:0.5 G#3:0.5 -:1.5 A2:0.5 E3:0.5 A3:0.5")),
    "fifth": (seq("-:0.5 G4:0.5 G4:0.5 G4:0.5 Eb4:3 -:1 F4:0.5 F4:0.5 F4:0.5 D4:4"), 108,
              seq("-:0.5 G3:0.5 G3:0.5 G3:0.5 Eb3:3 -:1 F3:0.5 F3:0.5 F3:0.5 D3:4")),
    "jingle": (seq("E4:1 E4:1 E4:2 E4:1 E4:1 E4:2 E4:1 G4:1 C4:1.5 D4:0.5 E4:4"), 150,
               seq("C3:2 G2:2 C3:2 G2:2 C3:2 G2:2 C3:4")),
    "mary": (seq("E4:1 D4:1 C4:1 D4:1 E4:1 E4:1 E4:2 D4:1 D4:1 D4:2 E4:1 G4:1 G4:2"), 128, None),
    "turca": (seq("B4:0.25 A4:0.25 G#4:0.25 A4:0.25 C5:1 D5:0.25 C5:0.25 B4:0.25 C5:0.25 E5:1 F5:0.25 E5:0.25 D#5:0.25 E5:0.25 B5:0.25 A5:0.25 G#5:0.25 A5:0.25 B5:0.25 A5:0.25 G#5:0.25 A5:0.25 C6:2"), 112,
              seq("-:1 A2:0.5 C3:0.5 E3:0.5 C3:0.5 A2:0.5 C3:0.5 E3:0.5 C3:0.5 A2:0.5 C3:0.5 E3:0.5 C3:0.5 A2:2")),
    "mountain": (seq("B3:0.5 C#4:0.5 D4:0.5 E4:0.5 F#4:0.5 D4:0.5 F#4:1 F4:0.5 C#4:0.5 F4:1 E4:0.5 C4:0.5 E4:1 B3:0.5 C#4:0.5 D4:0.5 E4:0.5 F#4:0.5 D4:0.5 F#4:0.5 B4:0.5 A4:0.5 F#4:0.5 D4:0.5 F#4:0.5 A4:2"), 138, None),
    "lullaby": (seq("E4:0.5 E4:0.5 G4:2 E4:0.5 E4:0.5 G4:2 E4:0.5 G4:0.5 C5:1 B4:1.5 A4:0.5 A4:1 G4:2"), 96, None),
    "cucaracha": (seq("C4:0.5 C4:0.5 C4:0.5 F4:1.5 A4:1 C4:0.5 C4:0.5 C4:0.5 F4:1.5 A4:1.5 -:0.5 F4:0.5 F4:0.5 E4:0.5 E4:0.5 D4:0.5 D4:0.5 C4:2"), 140,
                  seq("-:1.5 F2:2.5 -:1.5 F2:2.5 -:0.5 C3:2 G2:1 C3:2")),
    "danube": (seq("D4:1 D4:1 F#4:1 A4:1 A4:2 A5:1 A5:2 F#5:1 F#5:2 D4:1 D4:1 F#4:1 A4:1 A4:2 A5:1 A5:2 G5:1 G5:2"), 170,
               seq("D3:3 D3:3 D3:3 D3:3 A2:3 A2:3 A2:3 A2:3")),
    "nacht": (seq("G4:1 -:0.5 D4:0.5 G4:1 -:0.5 D4:0.5 G4:0.5 D4:0.5 G4:0.5 B4:0.5 D5:2 C5:1 -:0.5 A4:0.5 C5:1 -:0.5 A4:0.5 C5:0.5 A4:0.5 F#4:0.5 A4:0.5 D4:2"), 130,
              seq("G2:1 -:0.5 D2:0.5 G2:1 -:0.5 D2:0.5 G2:2 G2:2 D2:1 -:1 D2:1 -:1 D2:2 D2:2")),
    "wedding": (seq("C4:1 F4:1.5 F4:0.5 F4:2 C4:1 G4:1.5 E4:0.5 F4:2 C4:1 F4:1.5 Bb4:0.5 Bb4:1 A4:1.5 G4:0.5 F4:1.5 E4:0.5 F4:1 G4:2"), 84,
                seq("-:1 F2:4 C3:4 F2:4 C3:2 F2:4")),
    "oldmac": (seq("G4:1 G4:1 G4:1 D4:1 E4:1 E4:1 D4:2 B4:1 B4:1 A4:1 A4:1 G4:3"), 132,
               seq("G2:4 C3:2 G2:2 G2:2 D3:2 G2:3")),
    "london": (seq("G4:1.5 A4:0.5 G4:1 F4:1 E4:1 F4:1 G4:2 D4:1 E4:1 F4:2 E4:1 F4:1 G4:2"), 120, None),
    "habanera": (seq("D5:1.5 C#5:0.5 C5:1 C5:1 B4:0.75 Bb4:0.25 A4:1 A4:0.75 G#4:0.25 G4:1 F4:0.5 E4:0.5 F4:1 E4:1"), 80,
                 seq("D3:0.75 A3:0.25 D3:0.5 A3:0.5 D3:0.75 A3:0.25 D3:0.5 A3:0.5 D3:0.75 A3:0.25 D3:0.5 A3:0.5 D3:0.75 A3:0.25 D3:0.5 A3:0.5 D3:0.75 A3:0.25 D3:0.5 A3:0.5 A2:2")),
    "greensleeves": (seq("A4:1 C5:2 D5:1 E5:1.5 F5:0.5 E5:1 D5:2 B4:1 G4:1.5 A4:0.5 B4:1 C5:2 A4:1 A4:1.5 G#4:0.5 A4:1 B4:2 G#4:1 E4:2"), 132,
                     seq("A2:3 A2:3 G2:3 G2:3 A2:3 A2:3 E2:3")),
}


# ── gündelik sesler ─────────────────────────────────────────────────
def tone(f, dur, shape="sine"):
    t = t_axis(dur)
    if shape == "square":
        return np.sign(np.sin(2 * np.pi * f * t)) * 0.6
    return np.sin(2 * np.pi * f * t)


def s_siren():
    """Ambulans: iki tonlu (hi-lo) siren"""
    parts = []
    for _ in range(4):
        for f in (960, 770):
            x = tone(f, 0.55, "square") * 0.5 + tone(f * 2, 0.55) * 0.15
            parts.append(lowpass(x, 3200) * adsr(len(x), 0.01, 0.01, 1, 0.02))
    return _out(np.concatenate(parts), 1.0)


def s_doorbell():
    tr = Track(2.6, 120)
    tr.add(synth_bell(hz("E5"), 1.4, 0.6), 0.1)
    tr.add(synth_bell(hz("C5"), 1.8, 0.6), 0.75)
    return master(tr, False, (1.2, 0.25), -3.0)


def s_phone():
    """Eski çevirmeli telefon: zil çekicinin hızlı titreşimi, iki kez"""
    out = []
    for _ in range(2):
        t = t_axis(1.1)
        trem = (np.sin(2 * np.pi * 22 * t) > 0).astype(float)
        x = (np.sin(2 * np.pi * 1200 * t) + 0.6 * np.sin(2 * np.pi * 1850 * t) + 0.3 * np.sin(2 * np.pi * 2900 * t)) * trem
        out.append(x * 0.35)
        out.append(np.zeros(int(0.7 * SR)))
    return _out(np.concatenate(out), 0.8)


def s_clock():
    """Duvar saati: tik-tak"""
    out = []
    for i in range(8):
        t = t_axis(0.5)
        f = 2600 if i % 2 == 0 else 1900
        click = bandpass(noise(len(t)), f * 0.7, f * 1.3) * np.exp(-t * 180) + np.sin(2 * np.pi * f * t) * np.exp(-t * 90) * 0.4
        out.append(click * 0.8)
    return _out(np.concatenate(out), 0.5)


def s_train():
    """Buharlı tren: çuf-çuf ve düdük"""
    dur = 4.0
    t = t_axis(dur)
    chuff = np.zeros_like(t)
    rate = np.linspace(2.5, 4.5, len(t))
    ph = np.cumsum(rate) / SR
    puff = (np.sin(2 * np.pi * ph) > 0.6).astype(float)
    chuff = lowpass(bandpass(noise(len(t)), 200, 2500) * puff, 1800) * 0.5
    wt = t_axis(1.4)
    whistle = sum(np.sin(2 * np.pi * f * wt) for f in (hz("E5"), hz("G#5"), hz("B5"))) / 3
    whistle = whistle * adsr(len(wt), 0.08, 0.1, 0.9, 0.3) * 0.5
    x = chuff.copy()
    i = int(2.2 * SR)
    x[i:i + len(whistle)] += whistle[: len(x) - i]
    return _out(x, 0.8)


def s_rain():
    t = t_axis(4.0)
    x = lowpass(highpass(noise(len(t)), 900), 7000) * 0.35
    drops = np.zeros_like(t)
    for _ in range(90):
        i = np.random.randint(0, len(t) - 2000)
        dt = t_axis(0.03)
        drops[i:i + len(dt)] += np.sin(2 * np.pi * np.random.uniform(2000, 4500) * dt) * np.exp(-dt * 200) * 0.3
    return _out((x + drops) * adsr(len(t), 0.6, 0.1, 1, 0.8), 0.9)


def s_thunder():
    t = t_axis(4.5)
    crack = highpass(noise(len(t)), 1500) * np.exp(-t * 8) * 0.8
    rumble = lowpass(noise(len(t)), 120, 3) * 14 * (np.exp(-t * 0.8) * (0.6 + 0.4 * np.sin(2 * np.pi * 1.3 * t) ** 2))
    return _out(crack + rumble, 1.2)


def s_church():
    tr = Track(5.0, 60)
    for i in range(3):
        tr.add(synth_bell(hz("G2"), 3.5, 0.7) + synth_bell(hz("G3"), 3.5, 0.3), i * 1.4)
    return master(tr, False, (3.0, 0.35), -2.0)


def s_cuckoo():
    tr = Track(3.0, 120)
    for i in range(3):
        for n, off in (("E5", 0.0), ("C5", 0.28)):
            t = t_axis(0.3)
            x = np.sin(2 * np.pi * hz(n) * t) * adsr(len(t), 0.02, 0.05, 0.8, 0.1) * 0.6
            x += 0.2 * np.sin(2 * np.pi * hz(n) * 2 * t) * adsr(len(t), 0.02, 0.05, 0.8, 0.1)
            tr.add(x, i * 0.85 + off)
    return master(tr, False, (1.0, 0.2), -3.0)


def s_car_horn():
    out = []
    for dur in (0.35, 0.8):
        t = t_axis(dur)
        x = (np.sign(np.sin(2 * np.pi * 420 * t)) + np.sign(np.sin(2 * np.pi * 500 * t))) * 0.25
        out.append(lowpass(x, 2500) * adsr(len(t), 0.01, 0.05, 1, 0.04))
        out.append(np.zeros(int(0.15 * SR)))
    return _out(np.concatenate(out), 0.5)


def s_ship_horn():
    t = t_axis(3.2)
    x = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in (73, 110)) * 0.3
    x = lowpass(x, 600, 3) * adsr(len(t), 0.15, 0.2, 0.9, 0.6)
    return _out(x, 1.6)


def s_whistle():
    """Hakem düdüğü: titreşen tiz ses"""
    out = []
    for dur in (0.25, 0.25, 0.9):
        t = t_axis(dur)
        f = 3100 * (1 + 0.03 * np.sin(2 * np.pi * 38 * t))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.6 + bandpass(noise(len(t)), 2800, 3600) * 0.1
        out.append(x * adsr(len(t), 0.01, 0.02, 1, 0.03))
        out.append(np.zeros(int(0.12 * SR)))
    return _out(np.concatenate(out), 0.6)


def s_heartbeat():
    tr = Track(3.2, 60)
    for i in range(4):
        tr.add(synth_bass_drum(0.3, 0.9, 70, 40), i * 0.8)
        tr.add(synth_bass_drum(0.3, 0.6, 65, 38), i * 0.8 + 0.2)
    return master(tr, False, (0.5, 0.08), -3.0)


def s_popcorn():
    t = t_axis(3.5)
    x = np.zeros_like(t)
    for _ in range(70):
        c = np.random.beta(2, 2) * 3.2
        i = int(c * SR)
        pt = t_axis(0.04)
        pop = bandpass(noise(len(pt)), 600, 3500) * np.exp(-pt * 120)
        x[i:i + len(pt)] += pop[: len(x) - i] * np.random.uniform(0.4, 1.0)
    return _out(x, 0.6)


def s_typewriter():
    x = []
    for i in range(14):
        t = t_axis(np.random.uniform(0.09, 0.18))
        x.append(bandpass(noise(len(t)), 1500, 5000) * np.exp(-t * 90) * 0.8)
    t = t_axis(0.8)
    x.append(synth_bell(hz("A6"), 0.8, 0.3))
    return _out(np.concatenate(x), 0.5)


def _out(x, rev):
    tr = Track(len(x) / SR + 0.2, 120)
    tr.add(x, 0.05)
    return master(tr, False, (rev, 0.18), -3.0)


# ── örneklenmiş sürümler (FluidR3 GM ses bankası varsa) ────────────
PIANO = synth_piano
if _sm:
    _syn_piano = synth_piano

    def PIANO(f, dur, vel=0.5):  # noqa: F811
        k = _cal("piano", lambda: _syn_piano(440, 0.6, 1.0), lambda: _sm.note(0, 440, 0.6, 100, 1.0))
        return _sm.note(0, f, dur, 100, 1.0) * k * vel

    def _tubular(n, vel):
        x = _sm.note(14, hz(n), 0.6, 110, 3.0)
        return x / (np.max(np.abs(x)) + 1e-9) * vel

    def s_doorbell():  # noqa: F811
        """Kapı zili: ding-dong (borulu çan örneği)"""
        tr = Track(3.2, 120)
        tr.add(_tubular("E5", 0.7), 0.1)
        tr.add(_tubular("C5", 0.7), 0.75)
        return master(tr, False, (1.2, 0.25), -3.0)

    def s_church():  # noqa: F811
        """Kilise çanı: pes borulu çan, üç vuruş"""
        tr = Track(6.0, 60)
        for i in range(3):
            tr.add(_tubular("G3", 0.8) + _tubular("G2", 0.5), i * 1.4)
        return master(tr, False, (3.0, 0.35), -2.0)

    def s_phone():  # noqa: F811
        """Eski telefon zili (GM telefon örneği), iki kez"""
        out = []
        for _ in range(2):
            x = _sm.note(124, hz("C5"), 1.1, 110, 0.2)
            out.append(x / (np.max(np.abs(x)) + 1e-9) * 0.6)
            out.append(np.zeros(int(0.6 * SR)))
        return _out(np.concatenate(out), 0.8)

    def s_cuckoo():  # noqa: F811
        """Guguklu saat: okarina örneğiyle iki nota, üç kez"""
        tr = Track(3.2, 120)
        for i in range(3):
            for n, off in (("E5", 0.0), ("C5", 0.28)):
                x = _sm.note(79, hz(n), 0.24, 105, 0.2)
                tr.add(x / (np.max(np.abs(x)) + 1e-9) * 0.5, i * 0.85 + off)
        return master(tr, False, (1.0, 0.2), -3.0)


SOUNDS = {
    "siren": s_siren, "doorbell": s_doorbell, "phone": s_phone, "clock": s_clock, "train": s_train,
    "rain": s_rain, "thunder": s_thunder, "church": s_church, "cuckoo": s_cuckoo, "car_horn": s_car_horn,
    "ship_horn": s_ship_horn, "whistle": s_whistle, "heartbeat": s_heartbeat, "popcorn": s_popcorn,
    "typewriter": s_typewriter,
}


if __name__ == "__main__":
    np.random.seed(11)
    want = sys.argv[1:] or (list(MELODIES) + list(SOUNDS))
    for k in want:
        if k in MELODIES:
            notes, bpm, bass = MELODIES[k]
            write(k, melody(notes, bpm, voice=PIANO, bass=bass), OUT)
        else:
            write(k, SOUNDS[k](), OUT)
