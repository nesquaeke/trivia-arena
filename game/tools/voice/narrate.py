#!/usr/bin/env python3
"""Trivia Arena — sunucu (anlatıcı) replikleri.

Replikler MBROLA sesleriyle (espeak-ng) okunur, sonra "tiyatro anonsu"
işlemesinden geçer: gövde EQ'su, hafif sıkıştırma, salon yankısı.
Çıktı: game/assets/audio/voice/<dil>/<anahtar>.ogg

Gerçek bir seslendirme sanatçısıyla değiştirmek için: aynı adlarla .ogg
dosyalarını bu klasöre koy (bu betiği bir daha çalıştırma). Oyun dosya
adına bakar, sesin nereden geldiğini umursamaz.

Kurulum (Ubuntu/Debian):  sudo apt install espeak-ng mbrola mbrola-tr1 mbrola-us2
                          pip install numpy scipy soundfile
Kullanım:                 python3 game/tools/voice/narrate.py
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(ROOT, "..", "..", "assets", "audio", "voice"))
SR = 44100

VOICES = {
    # dil: (espeak sesi, hız, perde)
    "tr": ("mb-tr1", 138, 44),
    "en": ("mb-us2", 150, 42),
}

# anahtar: (Türkçe, İngilizce)
LINES = {
    "welcome": ("Büyük Sahneye hoş geldiniz!", "Welcome to the Grand Stage!"),
    "ready": ("Hazır mısınız? Perde açılıyor!", "Are you ready? Curtain up!"),
    "act1_arena": ("Perde bir! Kategori avı.", "Act one! The category hunt."),
    "act2_arena": ("Perde iki! Güç turu.", "Act two! The power round."),
    "act3_arena": ("Perde üç! Son ayakta kalan kazanır.", "Act three! Last one standing wins."),
    "act1_cq": ("Perde bir! Kalelerinizi kurun.", "Act one! Raise your castles."),
    "act2_cq": ("Perde iki! Toprak paylaşımı.", "Act two! The land grab."),
    "act3_cq": ("Perde üç! Savaş çağı başlıyor.", "Act three! The age of war begins."),
    "estimate": ("Tahminler gelsin!", "Place your guesses!"),
    "reveal": ("Ve doğru cevap...", "And the answer is..."),
    "spot_on": ("Tam isabet!", "Spot on!"),
    "question": ("Soru geliyor!", "Here comes the question!"),
    "correct": ("Doğru cevap!", "That's correct!"),
    "nobody": ("Kimse bilemedi!", "Nobody got it!"),
    "five": ("Son beş saniye!", "Five seconds left!"),
    "duel": ("Düello!", "Duel!"),
    "attack": ("Saldırı!", "Attack!"),
    "tower": ("Bir kule yıkıldı!", "A tower falls!"),
    "castle_fall": ("Kale düştü!", "The castle has fallen!"),
    "repel": ("Saldırı püskürtüldü!", "The attack is repelled!"),
    "capture": ("Toprak el değiştirdi!", "The land changes hands!"),
    "tie": ("Beraberlik! Tahminle bozuyoruz.", "A tie! A guess will settle it."),
    "castle_pick": ("Kalenin yerini seç!", "Choose where your castle stands!"),
    "last_round": ("Son tur!", "Final round!"),
    "eliminated": ("Elendi!", "Eliminated!"),
    "winner": ("Ve gecenin galibi...", "And tonight's winner is..."),
    "applause": ("Büyük bir alkış!", "A big round of applause!"),
    "steal": ("Soygun!", "A heist!"),
    "sabotage": ("Sabotaj!", "Sabotage!"),
}


def speak(text, voice, speed, pitch):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    subprocess.run(["espeak-ng", "-v", voice, "-s", str(speed), "-p", str(pitch), "-w", path, text], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    x, sr = sf.read(path)
    os.unlink(path)
    if x.ndim > 1:
        x = x.mean(axis=1)
    # 44.1 kHz'e çevir
    x = signal.resample_poly(x, SR, sr)
    return x


def announcer(x):
    """Tiyatro anonsu: gövde + netlik EQ, yumuşak sıkıştırma, salon yankısı"""
    x = x / (np.max(np.abs(x)) + 1e-9)
    b, a = signal.butter(2, 110 / (SR / 2), "high")
    x = signal.lfilter(b, a, x)
    # 2.5–4 kHz netlik, 200 Hz gövde
    b, a = signal.butter(2, [2400 / (SR / 2), 4200 / (SR / 2)], "band")
    x = x + 0.35 * signal.lfilter(b, a, x)
    b, a = signal.butter(2, [160 / (SR / 2), 320 / (SR / 2)], "band")
    x = x + 0.4 * signal.lfilter(b, a, x)
    b, a = signal.butter(2, 7000 / (SR / 2), "low")
    x = signal.lfilter(b, a, x)
    # sıkıştırma
    x = np.tanh(x * 2.2) / np.tanh(2.2)
    # salon yankısı
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(3)
    ir = rng.uniform(-1, 1, n) * np.exp(-t * 4.3)
    b, a = signal.butter(1, 4500 / (SR / 2), "low")
    ir = signal.lfilter(b, a, ir)
    ir[: int(0.018 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    pad = np.concatenate([x, np.zeros(n)])
    wet = signal.fftconvolve(pad, ir)[: len(pad)]
    y = pad * 0.85 + wet * 0.22
    # stereo: hafif genişlik
    l = y
    r = np.concatenate([np.zeros(int(0.004 * SR)), y])[: len(y)]
    out = np.stack([l, r * 0.97 + l * 0.03], axis=1)
    e = np.max(np.abs(out), axis=1)
    last = np.nonzero(e > 1e-3)[0]
    out = out[: (last[-1] + 2000) if len(last) else len(out)]
    out = out / (np.max(np.abs(out)) + 1e-9) * 0.9
    return out.astype(np.float32)


def main():
    want = sys.argv[1:]
    for lang, (voice, speed, pitch) in VOICES.items():
        folder = os.path.join(OUT, lang)
        os.makedirs(folder, exist_ok=True)
        for key, pair in LINES.items():
            if want and key not in want:
                continue
            text = pair[0] if lang == "tr" else pair[1]
            y = announcer(speak(text, voice, speed, pitch))
            sf.write(os.path.join(folder, key + ".ogg"), y, SR, format="OGG", subtype="VORBIS")
        print(lang, "tamam:", len(LINES), "replik")


if __name__ == "__main__":
    main()
