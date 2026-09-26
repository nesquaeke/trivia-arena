#!/usr/bin/env python3
"""Polonya haritası (16 voyvodalık) → data/maps/polska.json

Kaynak: game/tools/pl.svg (Simplemaps, ticari kullanım serbest: https://simplemaps.com/resources/svg-license)
Çıktı data/maps/turkiye.json ile aynı biçimde (MapBoard ikisini de okur):
  cols, rows          harita koordinat alanı (SVG viewBox)
  regions[]           id, ad (tüm diller), ab (kısaltma), cx/cy (etiket/kale yeri), adj (komşular), loops (sınır)
  shore[]             Baltık kıyısı (açık mavi sığ su şeridi çizilir)
  ships[]             denizde dolaşan gemiler: [x, y, yön] harita koordinatında
Komşuluk sınırların örtüşmesinden hesaplanır (ortak kenarı olan voyvodalıklar komşu).

Kullanım: python3 game/tools/maps/build_poland.py [--preview onizleme.png]
"""
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SVG = os.path.normpath(os.path.join(HERE, "..", "pl.svg"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "data", "maps", "polska.json"))

# TERYT kodu → (resmî Lehçe ad, haritadaki etiket, İngilizce, Türkçe, Fransızca, İspanyolca, kısaltma)
NAMES = {
    "PL02": ("Dolnośląskie", "Dolno-\nśląskie", "Lower Silesia", "Aşağı Silezya", "Basse-Silésie", "Baja Silesia", "DŚL"),
    "PL04": ("Kujawsko-Pomorskie", "Kujawsko-\nPomorskie", "Kuyavia-Pomerania", "Kuyavya-Pomeranya", "Couïavie-Poméranie", "Cuyavia y Pomerania", "KPM"),
    "PL06": ("Lubelskie", "Lubelskie", "Lublin", "Lublin", "Lublin", "Lublin", "LUB"),
    "PL08": ("Lubuskie", "Lubuskie", "Lubusz", "Lubusz", "Lubusz", "Lubusz", "LBU"),
    "PL10": ("Łódzkie", "Łódzkie", "Łódź", "Łódź", "Łódź", "Łódź", "ŁDZ"),
    "PL12": ("Małopolskie", "Mało-\npolskie", "Lesser Poland", "Küçük Polonya", "Petite-Pologne", "Pequeña Polonia", "MAŁ"),
    "PL14": ("Mazowieckie", "Mazowieckie", "Masovia", "Mazovya", "Mazovie", "Mazovia", "MAZ"),
    "PL16": ("Opolskie", "Opolskie", "Opole", "Opole", "Opole", "Opole", "OPO"),
    "PL18": ("Podkarpackie", "Podkar-\npackie", "Subcarpathia", "Karpat Önü", "Basses-Carpates", "Subcarpacia", "PKR"),
    "PL20": ("Podlaskie", "Podlaskie", "Podlachia", "Podlasya", "Podlachie", "Podlaquia", "PDL"),
    "PL22": ("Pomorskie", "Pomorskie", "Pomerania", "Pomeranya", "Poméranie", "Pomerania", "POM"),
    "PL24": ("Śląskie", "Śląskie", "Silesia", "Silezya", "Silésie", "Silesia", "ŚLĄ"),
    "PL26": ("Świętokrzyskie", "Święto-\nkrzyskie", "Holy Cross", "Kutsal Haç", "Sainte-Croix", "Santa Cruz", "ŚWK"),
    "PL28": ("Warmińsko-Mazurskie", "Warmińsko-\nMazurskie", "Warmia-Masuria", "Varmiya-Mazurya", "Varmie-Mazurie", "Varmia y Masuria", "WMZ"),
    "PL30": ("Wielkopolskie", "Wielko-\npolskie", "Greater Poland", "Büyük Polonya", "Grande-Pologne", "Gran Polonia", "WLK"),
    "PL32": ("Zachodniopomorskie", "Zachodnio-\npomorskie", "West Pomerania", "Batı Pomeranya", "Poméranie-Occidentale", "Pomerania Occidental", "ZPM"),
}
# Küçük bölgeler: kale ([x, y]) ve adın yüksekliği ([x, y], x yalnız ipucu) SVG koordinatında elle.
# Kale kuzeyde, ad güneyde: kamera güneyden baktığı için kale adın üstüne binmez.
PLACE = {
    "PL16": ([398.0, 636.0], [365.0, 704.0]),    # Opolskie: geniş bel y≈700
    "PL24": ([502.0, 640.0], [500.0, 706.0]),    # Śląskie
    "PL26": ([640.0, 614.0], [650.0, 684.0]),    # Świętokrzyskie
}

# Kıyı voyvodalıkları: dış (paylaşılmayan) sınırlarının kuzeye bakan kısmı Baltık kıyısıdır
COASTAL = {"PL32": 175.0, "PL22": 175.0, "PL28": 120.0}   # id → bu y'nin üstü kıyı (Kaliningrad sınırı hariç)
COAST_X_MAX = {"PL28": 500.0}                              # Varmia'da yalnız Vistül lagünü (batı ucu)


def parse_path(d):
    """M x y l dx dy ... z → [[x, y, x, y, ...], ...] (her M yeni halka)"""
    loops, cur, x, y = [], None, 0.0, 0.0
    for cmd, args in re.findall(r"([MmLlZz])([^MmLlZz]*)", d):
        nums = [float(v) for v in re.findall(r"-?\d*\.?\d+(?:e-?\d+)?", args)]
        if cmd in "Mm":
            if cur:
                loops.append(cur)
            x, y = (nums[0], nums[1]) if cmd == "M" else (x + nums[0], y + nums[1])
            cur = [x, y]
            rest, rel = nums[2:], cmd == "m"
        elif cmd in "Ll":
            rest, rel = nums, cmd == "l"
        else:
            if cur:
                loops.append(cur)
            cur = None
            continue
        for i in range(0, len(rest) - 1, 2):
            x, y = (x + rest[i], y + rest[i + 1]) if rel else (rest[i], rest[i + 1])
            cur += [x, y]
    if cur:
        loops.append(cur)
    return loops


def simplify(flat, tol=0.6):
    """Ramer–Douglas–Peucker: gereksiz ara noktaları at (şekil bozulmaz)"""
    pts = np.array(flat).reshape(-1, 2)
    if len(pts) < 8:
        return flat

    def rdp(p):
        if len(p) < 3:
            return p
        a, b = p[0], p[-1]
        ab = b - a
        n = np.linalg.norm(ab)
        d = np.abs(np.cross(ab, p - a)) / n if n > 1e-9 else np.linalg.norm(p - a, axis=1)
        i = int(np.argmax(d))
        if d[i] > tol:
            return np.vstack([rdp(p[: i + 1])[:-1], rdp(p[i:])])
        return np.vstack([a, b])
    out = rdp(pts)
    return [round(float(v), 1) for v in out.reshape(-1)]


def main():
    svg = open(SVG, encoding="utf-8").read()
    w, h = [float(v) for v in re.search(r'viewbox="0 0 ([\d.]+) ([\d.]+)"', svg, re.I).groups()]
    labels = {i: (float(x), float(y)) for x, y, i in
              re.findall(r'<circle class="[^"]*" cx="([\d.]+)" cy="([\d.]+)" id="(PL\d\d)"', svg)}
    raw = {}
    for attrs in re.findall(r"<path([^>]*)>", svg):
        pid = re.search(r'id="(PL\d\d)"', attrs).group(1)
        raw[pid] = parse_path(re.search(r' d="([^"]*)"', attrs).group(1))
    assert sorted(raw) == sorted(NAMES), sorted(raw)

    # komşuluk: iki sınırın 1.2 birimden yakın en az 6 noktası varsa ortak kenar vardır
    pts = {k: np.vstack([np.array(l).reshape(-1, 2) for l in v]) for k, v in raw.items()}
    adj = {k: [] for k in raw}
    shared = {k: np.zeros(len(pts[k]), bool) for k in raw}
    ids = sorted(raw)
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            d = np.linalg.norm(pts[a][:, None, :] - pts[b][None, :, :], axis=2)
            near_a = d.min(axis=1) < 1.2
            if near_a.sum() >= 6:
                adj[a].append(b)
                adj[b].append(a)
            shared[a] |= near_a
            shared[b] |= d.min(axis=0) < 1.2

    # Baltık kıyısı: kıyı voyvodalıklarının paylaşılmayan, kuzeydeki sınır noktaları (ardışık parçalar)
    shore = []
    for k, ymax in COASTAL.items():
        p = pts[k]
        ok = (~shared[k]) & (p[:, 1] < ymax) & (p[:, 0] < COAST_X_MAX.get(k, 1e9))
        run = []
        for q, flag in zip(p, ok):
            if flag:
                run.append(q)
            elif len(run) > 3:
                shore.append([round(float(v), 1) for v in np.array(run).reshape(-1)])
                run = []
            else:
                run = []
        if len(run) > 3:
            shore.append([round(float(v), 1) for v in np.array(run).reshape(-1)])

    regions = []
    for k in ids:
        pl, lab, en, tr, fr, es, ab = NAMES[k]
        cx, cy = labels[k]
        reg = {"id": k.lower(), "tr": tr, "en": en, "pl": pl, "fr": fr, "es": es, "label": pl, "ab": ab,
                        "cx": round(cx, 1), "cy": round(cy, 1), "adj": sorted(x.lower() for x in adj[k]),
                        "loops": [simplify(l) for l in raw[k]]}
        if "\n" in lab:
            reg["label2"] = lab          # dar bölgede iki satır (MapBoard hangisi büyük sığarsa onu seçer)
        if k in PLACE:                   # küçük bölge: kale ve ad yeri elle
            reg["seat"], reg["label_at"] = PLACE[k]
        regions.append(reg)
    data = {"name": "polska", "cols": w, "rows": h, "links": [], "coast": [], "shore": [simplify(s, 0.8) for s in shore],
            # gemiler Baltık'ta (kıyının kuzeyinde): [x, y, yön]; salınım genişliği (m)
            "ships": [[160.0, 40.0, 1.0], [600.0, 25.0, -1.0]], "ship_roam": 1.4,
            # komşu ülkeler yalnız silik yazı olarak (keçe kara parçası kaldırıldı: tuhaf duruyordu)
            # [yazı, x, y, deniz mi]
            "decor": [["BAŁTYK", -70.0, 200.0, True]],
            # küçük bölgeler: kale kuzey yarıda, ad güney yarıda; ad bölge genişliğine sığdırılır
            "label_scale": 0.9, "split_seat": True,
            # harita dar: seçim ve genel bakış kamerası bu oranda yaklaşır (yanlarda boş masa kalmasın)
            "view_zoom": 1.28,
            "credit": "Map: Simplemaps.com (free for commercial use)", "regions": regions}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(data, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print("yazıldı", os.path.relpath(OUT), "·", len(regions), "voyvodalık,", sum(len(r["adj"]) for r in regions) // 2, "komşuluk,",
          len(shore), "kıyı parçası")
    for r in regions:
        print("  %-20s %s" % (r["pl"], ", ".join(NAMES[a.upper()][0] for a in r["adj"])))
    if "--preview" in sys.argv:
        preview(data, sys.argv[sys.argv.index("--preview") + 1])


def preview(data, path):
    from PIL import Image, ImageDraw
    k = 1.0
    im = Image.new("RGB", (int(data["cols"]), int(data["rows"]) + 120), (40, 80, 110))
    dr = ImageDraw.Draw(im)
    oy = 120
    cols = [(233, 220, 192), (227, 210, 176), (238, 227, 202), (221, 205, 169)]
    for i, r in enumerate(data["regions"]):
        for l in r["loops"]:
            p = [(l[j] * k, l[j + 1] * k + oy) for j in range(0, len(l) - 1, 2)]
            dr.polygon(p, fill=cols[i % 4], outline=(90, 50, 30))
    for s in data["shore"]:
        p = [(s[j], s[j + 1] + oy) for j in range(0, len(s) - 1, 2)]
        dr.line(p, fill=(120, 200, 230), width=6)
    for r in data["regions"]:
        c = (r["cx"], r["cy"] + oy)
        for a in r["adj"]:
            o = next(x for x in data["regions"] if x["id"] == a)
            dr.line([c, (o["cx"], o["cy"] + oy)], fill=(200, 60, 60), width=1)
        dr.text((c[0] - 30, c[1] - 8), r["pl"], fill=(20, 10, 5))
    for x, y, _ in data["ships"]:
        dr.ellipse([x - 8, y + oy - 8, x + 8, y + oy + 8], fill=(255, 255, 255))
    im.save(path)
    print("önizleme:", path)


if __name__ == "__main__":
    main()
