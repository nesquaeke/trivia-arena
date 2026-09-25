#!/usr/bin/env python3
"""Suno (ya da başka bir yerden) gelen müzikleri oyuna hazırla → game/assets/audio_pro/music/<parça>.ogg

Girdi: game/tools/audio/suno_in/<parça>.mp3|.wav|.ogg|.flac   (parça: lobby, trivia, think, conquest, victory)
- Döngü parçaları (lobby, trivia, think, conquest): girişteki sessizlik/intro atlanır, hedef uzunluğa
  yakın, başıyla en iyi örtüşen bitiş noktası aranır (ritme oturan kesim) ve dikiş çapraz geçişle
  kapatılır: Godot parçayı baştan sona döngüde çalar, kesik duyulmaz.
- victory: ilk ~9 sn, yumuşak kapanışla (döngüsüz fanfar).
- Ses düzeyi oyundaki mevcut parçalarla eşitlenir (RMS), tepe -1 dBFS ile sınırlanır.

Kullanım: python3 game/tools/audio/music_import.py [parça ...]
Orijinaller suno_in/ içinde kalır; çıktı assets/audio_pro/music/ (oyun AudioPack ile otomatik kullanır).
"""
import glob
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
IN = os.path.join(HERE, "suno_in")
OUT = os.path.join(GAME, "assets", "audio_pro", "music")
SR = 44100
LOOPS = {"lobby": 75.0, "trivia": 70.0, "think": 45.0, "conquest": 80.0}   # hedef döngü uzunluğu (sn)
STING = {"victory": 9.0}
TARGET_RMS = 0.17   # mevcut parçaların ortalaması


def load(path):
    x, sr = sf.read(path, dtype="float64", always_2d=True)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    x = x[:, :2]
    if sr != SR:
        x = signal.resample_poly(x, SR, sr, axis=0)
    return x


def onset_env(m, hop=512):
    """kaba vuruş zarfı: kısa pencerelerde enerji artışı"""
    n = len(m) // hop
    e = np.sqrt(np.mean(m[: n * hop].reshape(n, hop) ** 2, axis=1))
    d = np.maximum(0, np.diff(e, prepend=e[0]))
    return d / (np.max(d) + 1e-9), hop


def find_loop(x, want):
    m = x.mean(axis=1)
    env = np.abs(m)
    lvl = np.max(env) * 0.05
    # başlangıç: ilk belirgin sesten sonra 2 sn (intro/giriş fade'ini atla), ama 8 sn'yi geçme
    first = int(np.argmax(env > lvl))
    a = min(first + 2 * SR, 8 * SR, max(0, len(m) - int((want + 6) * SR)))
    oe, hop = onset_env(m)
    ai = a // hop
    win = int(8 * SR / hop)                      # başlangıçtaki 8 sn'lik ritim deseni
    ref = oe[ai:ai + win]
    lo = int((want - 6) * SR / hop) + ai
    hi = min(len(oe) - win, int((want + 6) * SR / hop) + ai)
    if hi <= lo or len(ref) < win:
        b = min(len(m), a + int(want * SR))
        return a, b
    best, bi = -1e9, lo
    for i in range(lo, hi):
        seg = oe[i:i + win]
        c = float(np.dot(seg - seg.mean(), ref - ref.mean()) / (np.std(seg) * np.std(ref) * win + 1e-9))
        if c > best:
            best, bi = c, i
    b = bi * hop
    # ince ayar: dalga biçimi örtüşmesi (±20 ms)
    k = int(0.02 * SR)
    seg_a = m[a:a + 2048]
    scores = [np.dot(m[b + d:b + d + 2048], seg_a) for d in range(-k, k)]
    b += int(np.argmax(scores)) - k
    print("  döngü: %.2f → %.2f sn (uzunluk %.1f, ritim uyumu %.2f)" % (a / SR, b / SR, (b - a) / SR, best))
    return a, b


def make_loop(x, want):
    a, b = find_loop(x, want)
    body = x[a:b].copy()
    # dikiş: döngü sonunu, başlangıcın hemen öncesiyle değil başın kendisiyle eşit güçte çapraz geçir
    f = int(0.25 * SR)
    tail = x[b:b + f] if b + f <= len(x) else np.zeros((f, 2))
    ramp = np.linspace(0, 1, f)[:, None]
    body[:f] = body[:f] * np.sqrt(ramp) + tail * np.sqrt(1 - ramp)
    return body


def make_sting(x, dur):
    m = np.max(np.abs(x), axis=1)
    first = int(np.argmax(m > np.max(m) * 0.05))
    y = x[first:first + int(dur * SR)].copy()
    f = int(1.2 * SR)
    y[-f:] *= np.linspace(1, 0, f)[:, None] ** 2
    return y


def level(x):
    x = x - x.mean(axis=0)
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    x = x * (TARGET_RMS / rms)
    pk = np.max(np.abs(x))
    if pk > 0.89:
        x = np.tanh(x / pk * 1.5) / np.tanh(1.5) * 0.89
    return x.astype(np.float32)


def main():
    want = sys.argv[1:] or list(LOOPS) + list(STING)
    os.makedirs(OUT, exist_ok=True)
    for name in want:
        src = [p for p in glob.glob(os.path.join(IN, name + ".*")) if not p.endswith(".txt")]
        if not src:
            print("yok:", name)
            continue
        x = load(src[0])
        print("%s: %s (%.1f sn)" % (name, os.path.basename(src[0]), len(x) / SR))
        y = make_loop(x, LOOPS[name]) if name in LOOPS else make_sting(x, STING[name])
        path = os.path.join(OUT, name + ".ogg")
        sf.write(path, level(y), SR, format="OGG", subtype="VORBIS")
        print("  yazıldı", os.path.relpath(path, GAME), "%.1f sn" % (len(y) / SR))


if __name__ == "__main__":
    main()
