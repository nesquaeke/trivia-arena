#!/usr/bin/env python3
"""Soru paketlerini data/questions.json'a ekler.

Paket biçimi (tools/questions/packs/*.txt), her satır bir soru:
    kategori | zorluk | Türkçe soru | English question | doğru | yanlış | yanlış | yanlış
Seçenek iki dilde farklıysa "Türkçe~English" yaz; aynıysa bir kez yaz.
Doğru cevap her zaman ilk seçenektir; betik sırayı karıştırır.
Zorluk: 1 kolay, 2 orta, 3 zor.   # ile başlayan satırlar yorumdur.

Tahmin soruları (tools/questions/packs/estimate*.txt):
    E | cevap | min | max | yıl(0/1) | Türkçe soru | birim | English question | unit

Kullanım: python3 game/tools/questions/build_pack.py
Aynı Türkçe soru zaten varsa atlanır; betik tekrar çalıştırılabilir.
"""
import glob
import json
import os
import random
import sys
from collections import Counter

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(ROOT, "..", "..", "data", "questions.json"))

NEW_CATEGORIES = {
    "space": ["Uzay", "Space", "#2B3F8C"],
    "odd": ["Tuhaf ama Gerçek", "Odd but True", "#8C2B6B"],
    "lang": ["Diller ve Kelimeler", "Words & Languages", "#6B7A1E"],
    "brain": ["Beyin Acıtıcı", "Brain Teasers", "#7A3FB0"],
    "life": ["Bunu Biliyor Olmalısın", "You Should Know This", "#3A8A8A"],
    "toons": ["Çizgi Film & Oyuncak", "Cartoons & Toys", "#D2553A"],
}

## Oyun içi eğlenceli kategori adları (kuru "Bilim" yerine "Beynini Yak")
FUN_NAMES = {
    "geo": ["Dünya Turu", "World Tour"],
    "sci": ["Beynini Yak", "Brain Burner"],
    "hist": ["Geçmişte Neler Olmuş", "Back in the Day"],
    "film": ["Patlamış Mısır", "Popcorn Time"],
    "music": ["Kulağına Güven", "Trust Your Ears"],
    "game": ["Oyun Başlasın", "Game On"],
    "sport": ["Terlemeden Spor", "Couch Athlete"],
    "art": ["Fırça Darbesi", "Brush Strokes"],
    "lit": ["Kitap Kurdu", "Bookworm"],
    "nature": ["Hayvanlar Garip", "Wild Things"],
    "food": ["Ağzın Sulanacak", "Snack Attack"],
    "tech": ["Robotlar Daha Akıllı", "Robots Are Smarter"],
    "space": ["Uzay Boşluğu", "Lost in Space"],
    "odd": ["Tuhaf ama Gerçek", "Odd but True"],
    "lang": ["Dil Sürçmesi", "Tongue Twisters"],
}


def split(opt):
    if "~" in opt:
        a, b = opt.split("~", 1)
        return a.strip(), b.strip()
    return opt.strip(), opt.strip()


def main():
    d = json.load(open(DATA, encoding="utf-8"))
    for k, v in NEW_CATEGORIES.items():
        d["categories"].setdefault(k, v)
    for k, v in FUN_NAMES.items():
        if k in d["categories"]:
            d["categories"][k][0] = v[0]
            d["categories"][k][1] = v[1]
    have = set()
    for t in d["tiers"].values():
        for q in t:
            have.add(q["tr"]["q"].strip().lower())
    have_est = {q["tr"]["q"].strip().lower() for q in d["estimate"]}
    rng = random.Random(2026)
    added = Counter()
    bad = []
    for path in sorted(glob.glob(os.path.join(ROOT, "packs", "*.txt"))):
        for n, raw in enumerate(open(path, encoding="utf-8"), 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if parts[0] == "E":
                if len(parts) != 9:
                    bad.append(f"{os.path.basename(path)}:{n} tahmin alanı {len(parts)}")
                    continue
                _, a, lo, hi, yr, qtr, utr, qen, uen = parts
                if qtr.lower() in have_est:
                    continue
                a, lo, hi = float(a), float(lo), float(hi)
                if not (lo <= a <= hi):
                    bad.append(f"{os.path.basename(path)}:{n} cevap aralık dışında")
                    continue
                d["estimate"].append({"a": int(a) if a == int(a) else a, "min": int(lo), "max": int(hi), "year": yr == "1",
                                      "tr": {"q": qtr, "unit": utr}, "en": {"q": qen, "unit": uen}})
                have_est.add(qtr.lower())
                added["estimate"] += 1
                continue
            if len(parts) != 8:
                bad.append(f"{os.path.basename(path)}:{n} alan sayısı {len(parts)}")
                continue
            cat, tier, qtr, qen = parts[0], parts[1], parts[2], parts[3]
            if cat not in d["categories"]:
                bad.append(f"{os.path.basename(path)}:{n} bilinmeyen kategori {cat}")
                continue
            if qtr.lower() in have:
                continue
            opts = [split(o) for o in parts[4:8]]
            if len({o[0].lower() for o in opts}) < 4:
                bad.append(f"{os.path.basename(path)}:{n} aynı seçenek iki kez")
                continue
            order = [0, 1, 2, 3]
            rng.shuffle(order)
            q = {"c": cat, "a": order.index(0),
                 "tr": {"q": qtr, "o": [opts[i][0] for i in order]},
                 "en": {"q": qen, "o": [opts[i][1] for i in order]}}
            d["tiers"]["d" + tier].append(q)
            have.add(qtr.lower())
            added["d" + tier] += 1
    json.dump(d, open(DATA, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    total = sum(len(t) for t in d["tiers"].values())
    print("eklendi:", dict(added))
    print("toplam çoktan seçmeli:", total, "· tahmin:", len(d["estimate"]))
    per = Counter()
    for t, qs in d["tiers"].items():
        for q in qs:
            per[(q["c"], t)] += 1
    for c in d["categories"]:
        print(f"  {c:7s}", " ".join(f"{t}:{per[(c, t)]:3d}" for t in ("d1", "d2", "d3")))
    if bad:
        print("HATALI SATIRLAR:")
        for b in bad:
            print("  ", b)
        sys.exit(1)


if __name__ == "__main__":
    main()
