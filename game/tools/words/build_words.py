#!/usr/bin/env python3
"""Günlük Kelime (Kelimle) sözlüğü → data/words.json

  <dil>_answers.txt : elle seçilmiş cevaplar (günlük kelime bunlardan; boşluk ya da satırla ayrılmış)
  diller            : tr, en, pl, fr, es
  normalleştirme    : fr aksanları atar (é→e, ç→c, œ→oe), es aksanları atar ama ñ kalır,
                      pl ve tr kendi harflerini korur
  geçerli tahminler                : wordfreq'in en sık 60.000 kelimesindeki 5 harfliler + cevaplar

Kullanım: pip install wordfreq && python3 game/tools/words/build_words.py
"""
import json
import os
import random

from wordfreq import top_n_list

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "data", "words.json"))
import unicodedata

EN_ALPHA = set("abcdefghijklmnopqrstuvwxyz")
ALPHA = {
    "tr": set("abcçdefgğhıijklmnoöprsştuüvyz"),
    "en": EN_ALPHA,
    "pl": set("aąbcćdeęfghijklłmnńoóprsśtuwyzźż"),
    "fr": EN_ALPHA,
    "es": EN_ALPHA | {"ñ"},
}
SEED = {"tr": 2026, "en": 2027, "pl": 2028, "fr": 2029, "es": 2030}


def norm(w, lang):
    w = w.strip().lower()
    if lang == "fr":
        w = w.replace("œ", "oe").replace("æ", "ae")
        w = "".join(c for c in unicodedata.normalize("NFD", w) if unicodedata.category(c) != "Mn")
    elif lang == "es":
        w = w.replace("ñ", "\0")
        w = "".join(c for c in unicodedata.normalize("NFD", w) if unicodedata.category(c) != "Mn")
        w = w.replace("\0", "ñ")
    return w


def load(lang):
    out = []
    for w in open(os.path.join(HERE, lang + "_answers.txt"), encoding="utf-8").read().split():
        w = norm(w, lang)
        if len(w) == 5 and w not in out:
            out.append(w)
    return out


def main():
    out = {"version": 1}
    for lang, alpha in ALPHA.items():
        freq = [norm(w, lang) for w in top_n_list(lang, 60000)]
        valid = [w for w in freq if len(w) == 5 and set(w) <= alpha]
        common = set(freq[:40000])
        answers = [w for w in load(lang) if set(w) <= alpha]
        if lang not in ("tr", "en"):
            # yazım denetimi: yeni dillerde cevap yaygın kelimelerde olmalı
            dropped = [w for w in answers if w not in common]
            if dropped:
                print(lang, "atlanan", " ".join(dropped))
            answers = [w for w in answers if w in common]
        # cevap sırası sabit tohumla karışık: her gün sıradaki kelime
        rnd = random.Random(SEED[lang])
        rnd.shuffle(answers)
        out[lang] = {"answers": answers, "valid": sorted(set(valid) | set(answers))}
        print(lang, "cevap", len(answers), "geçerli", len(out[lang]["valid"]))
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    main()
