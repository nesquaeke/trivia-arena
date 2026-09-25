#!/usr/bin/env python3
"""Günlük Kelime (Kelimle) sözlüğü → data/words.json

  tr_answers.txt / en_answers.txt : elle seçilmiş cevaplar (günlük kelime bunlardan)
  geçerli tahminler                : wordfreq'in en sık 60.000 kelimesindeki 5 harfliler + cevaplar

Kullanım: pip install wordfreq && python3 game/tools/words/build_words.py
"""
import json
import os
import random

from wordfreq import top_n_list

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "data", "words.json"))
TR_ALPHA = set("abcçdefgğhıijklmnoöprsştuüvyz")
EN_ALPHA = set("abcdefghijklmnopqrstuvwxyz")


def load(name):
    return [w.strip() for w in open(os.path.join(HERE, name), encoding="utf-8") if len(w.strip()) == 5]


def main():
    out = {"version": 1}
    for lang, alpha in (("tr", TR_ALPHA), ("en", EN_ALPHA)):
        answers = [w for w in load(lang + "_answers.txt") if set(w) <= alpha]
        valid = [w for w in top_n_list(lang, 60000) if len(w) == 5 and set(w) <= alpha]
        # cevap sırası sabit tohumla karışık: her gün sıradaki kelime
        rnd = random.Random(2026 if lang == "tr" else 2027)
        rnd.shuffle(answers)
        out[lang] = {"answers": answers, "valid": sorted(set(valid) | set(answers))}
        print(lang, "cevap", len(answers), "geçerli", len(out[lang]["valid"]))
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    main()
