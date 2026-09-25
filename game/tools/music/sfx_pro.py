#!/usr/bin/env python3
"""Oyun içi efektlerin örneklenmiş sürümleri → game/assets/audio_pro/sfx/<ad>.ogg

scripts/core/sfx.gd bu efektleri çalışma anında sentezler; aynı adlı dosya
assets/audio_pro/sfx içinde varsa (AudioPack) onun yerine bu dosya çalar.
Gerekli: FluidSynth + FluidR3_GM (tools/music/sampler.py).

Kullanım: python3 game/tools/music/sfx_pro.py [ad ...]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import SR, Track, hz, master, write, _sm  # noqa: E402

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio_pro", "sfx"))


def _n(x):
    return x / (np.max(np.abs(x)) + 1e-9)


def ding():
    """Doğru cevap: glokenşpil arpej + çelesta"""
    tr = Track(1.6, 120)
    for i, n in enumerate(("C6", "E6", "G6", "C7")):
        tr.add(_n(_sm.note(9, hz(n), 0.15, 110, 1.0)) * 0.45, i * 0.055, -0.3 + i * 0.2)
    tr.add(_n(_sm.note(8, hz("C6"), 0.3, 100, 1.2)) * 0.3, 0.22, 0.0)
    return master(tr, False, (1.2, 0.2), -2.0)


def buzz():
    """Yanlış cevap: yarışma buzzer'ı (iki kısa, uyumsuz testere)"""
    tr = Track(0.9, 120)
    for s, d in ((0.0, 0.16), (0.2, 0.28)):
        for n in ("E2", "F2", "E3"):
            tr.add(_n(_sm.note(81, hz(n), d, 110, 0.05)) * 0.3, s)
    return master(tr, False, (0.4, 0.08), -3.0)


def applause():
    """Alkış: üç katmanlı gerçek alkış örneği"""
    tr = Track(2.6, 120)
    for j, f in enumerate((196, 247, 294)):
        x = _sm.note(126, f, 2.0, 100 + j * 8, 0.6)
        tr.add(_n(x) * 0.45, 0.04 * j, -0.6 + 0.6 * j)
    return master(tr, False, (1.2, 0.2), -2.0)


def drumroll():
    """Trampet tremolosu, giderek yükselen"""
    tr = Track(1.8, 120)
    hits = int(1.6 / 0.034)
    for i in range(hits):
        v = int(45 + 70 * i / hits)
        tr.add(_sm.drum(38, v, 0.03, 0.12) * 0.9, i * 0.034, 0.1 if i % 2 else -0.1)
    return master(tr, False, (0.8, 0.15), -2.0)


def fanfare():
    """Kazanma fanfarı: trompetler + bakır + timpani"""
    tr = Track(2.2, 120)
    line = (("G4", 0.0, 0.12), ("G4", 0.14, 0.12), ("G4", 0.28, 0.12), ("C5", 0.42, 0.3), ("G4", 0.76, 0.14), ("C5", 0.92, 0.7))
    for n, s, d in line:
        tr.add(_n(_sm.note(56, hz(n), d, 112, 0.4)) * 0.4, s, -0.2)
        tr.add(_n(_sm.note(56, hz(n) * 1.26, d, 100, 0.4)) * 0.25, s, 0.2)
    for n in ("C3", "G3", "E4"):
        tr.add(_n(_sm.note(61, hz(n), 0.8, 105, 0.6)) * 0.3, 0.92, 0.0)
    tr.add(_n(_sm.note(47, hz("C2"), 0.4, 120, 1.0)) * 0.6, 0.92)
    return master(tr, False, (1.6, 0.25), -1.5)


def tick():
    """Süre tıkırtısı: tahta blok"""
    tr = Track(0.3, 120)
    tr.add(_n(_sm.drum(76, 100, 0.03, 0.15)) * 0.6, 0)
    return master(tr, False, (0.2, 0.05), -8.0)


def click():
    """Arayüz tıklaması: kenar vuruşu"""
    tr = Track(0.3, 120)
    tr.add(_n(_sm.drum(37, 90, 0.03, 0.12)) * 0.6, 0)
    return master(tr, False, (0.2, 0.05), -9.0)


def thud():
    """Yere düşme: bas davul + pes tom"""
    tr = Track(0.8, 120)
    tr.add(_n(_sm.drum(36, 120, 0.1, 0.4)) * 0.8, 0)
    tr.add(_n(_sm.drum(41, 90, 0.1, 0.4)) * 0.4, 0.01)
    return master(tr, False, (0.4, 0.1), -3.0)


SOUNDS = {"ding": ding, "buzz": buzz, "applause": applause, "drumroll": drumroll, "fanfare": fanfare,
          "tick": tick, "click": click, "thud": thud}

if __name__ == "__main__":
    if not _sm:
        raise SystemExit("FluidSynth/FluidR3_GM yok: sudo apt install fluidsynth fluid-soundfont-gm")
    for k in sys.argv[1:] or list(SOUNDS):
        write(k, SOUNDS[k](), OUT)
