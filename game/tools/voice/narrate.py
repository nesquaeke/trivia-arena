#!/usr/bin/env python3
"""Trivia Arena — sunucu (anlatıcı) replikleri.

Replikler MBROLA sesleriyle (espeak-ng) okunur, sonra "tiyatro anonsu"
işlemesinden geçer: gövde EQ'su, hafif sıkıştırma, salon yankısı.
Çıktı: game/assets/audio/voice/<dil>/<anahtar>.ogg

Gerçek bir seslendirme sanatçısıyla değiştirmek için: aynı adlarla .ogg
dosyalarını bu klasöre koy (bu betiği bir daha çalıştırma). Oyun dosya
adına bakar, sesin nereden geldiğini umursamaz.

Kurulum (Ubuntu/Debian):  sudo apt install espeak-ng mbrola mbrola-tr1 mbrola-us2 mbrola-pl1 mbrola-fr1 mbrola-es2
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
    "pl": ("mb-pl1", 140, 40),
    "fr": ("mb-fr1", 150, 44),
    "es": ("mb-es2", 150, 44),
}
LANG_IDX = {"tr": 0, "en": 1, "pl": 2, "fr": 3, "es": 4}

# anahtar: (Türkçe, İngilizce) — PL/FR/ES aşağıda MORE içinde
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


# anahtar: (Lehçe, Fransızca, İspanyolca)
MORE = {
    "welcome": ("Witajcie na Wielkiej Scenie!", "Bienvenue sur la Grande Scène !", "¡Bienvenidos al Gran Escenario!"),
    "ready": ("Gotowi? Kurtyna w górę!", "Vous êtes prêts ? Lever de rideau !", "¿Estáis listos? ¡Se levanta el telón!"),
    "act1_arena": ("Akt pierwszy! Polowanie na kategorie.", "Premier acte ! La chasse aux catégories.", "¡Primer acto! La caza de categorías."),
    "act2_arena": ("Akt drugi! Runda mocy.", "Deuxième acte ! La manche de pouvoir.", "¡Segundo acto! La ronda de poder."),
    "act3_arena": ("Akt trzeci! Wygrywa ostatni na scenie.", "Troisième acte ! Le dernier debout gagne.", "¡Tercer acto! Gana el último en pie."),
    "act1_cq": ("Akt pierwszy! Wznieście swoje zamki.", "Premier acte ! Bâtissez vos châteaux.", "¡Primer acto! Levantad vuestros castillos."),
    "act2_cq": ("Akt drugi! Wyścig o ziemię.", "Deuxième acte ! La conquête des terres.", "¡Segundo acto! El reparto de tierras."),
    "act3_cq": ("Akt trzeci! Nadchodzi czas wojny.", "Troisième acte ! L'ère de la guerre commence.", "¡Tercer acto! Comienza la era de la guerra."),
    "estimate": ("Czas na wasze typy!", "À vos estimations !", "¡Haced vuestras apuestas!"),
    "reveal": ("A prawidłowa odpowiedź to...", "Et la bonne réponse est...", "Y la respuesta correcta es..."),
    "spot_on": ("W dziesiątkę!", "En plein dans le mille !", "¡Clavado!"),
    "question": ("Nadchodzi pytanie!", "Voici la question !", "¡Ahí va la pregunta!"),
    "correct": ("Prawidłowa odpowiedź!", "Bonne réponse !", "¡Respuesta correcta!"),
    "nobody": ("Nikt nie zgadł!", "Personne n'a trouvé !", "¡Nadie la ha acertado!"),
    "five": ("Zostało pięć sekund!", "Plus que cinq secondes !", "¡Quedan cinco segundos!"),
    "duel": ("Pojedynek!", "Duel !", "¡Duelo!"),
    "attack": ("Atak!", "À l'attaque !", "¡Al ataque!"),
    "tower": ("Wieża upada!", "Une tour s'effondre !", "¡Cae una torre!"),
    "castle_fall": ("Zamek upadł!", "Le château est tombé !", "¡El castillo ha caído!"),
    "repel": ("Atak odparty!", "L'attaque est repoussée !", "¡Ataque rechazado!"),
    "capture": ("Ziemia zmienia właściciela!", "La terre change de mains !", "¡La tierra cambia de manos!"),
    "tie": ("Remis! Rozstrzygnie szacunek.", "Égalité ! Une estimation va trancher.", "¡Empate! Lo decidirá una estimación."),
    "castle_pick": ("Wybierz miejsce na swój zamek!", "Choisis l'emplacement de ton château !", "¡Elige dónde se alza tu castillo!"),
    "last_round": ("Ostatnia runda!", "Dernière manche !", "¡Última ronda!"),
    "eliminated": ("Odpada!", "Éliminé !", "¡Eliminado!"),
    "winner": ("A zwycięzcą tego wieczoru jest...", "Et le gagnant de la soirée est...", "Y el ganador de esta noche es..."),
    "applause": ("Wielkie brawa!", "Une grande salve d'applaudissements !", "¡Un gran aplauso!"),
    "steal": ("Skok na kasę!", "Un braquage !", "¡Un atraco!"),
    "sabotage": ("Sabotaż!", "Sabotage !", "¡Sabotaje!"),
}


def line(key, lang):
    if lang in ("tr", "en"):
        return LINES[key][LANG_IDX[lang]]
    return MORE[key][LANG_IDX[lang] - 2]


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
    want = [a for a in sys.argv[1:] if not a.startswith("--lang=")]
    langs = [a[7:] for a in sys.argv[1:] if a.startswith("--lang=")] or list(VOICES)
    for lang, (voice, speed, pitch) in VOICES.items():
        if lang not in langs:
            continue
        folder = os.path.join(OUT, lang)
        os.makedirs(folder, exist_ok=True)
        for key, pair in LINES.items():
            if want and key not in want:
                continue
            text = line(key, lang)
            y = announcer(speak(text, voice, speed, pitch))
            sf.write(os.path.join(folder, key + ".ogg"), y, SR, format="OGG", subtype="VORBIS")
        print(lang, "tamam:", len(LINES), "replik")


if __name__ == "__main__":
    main()
