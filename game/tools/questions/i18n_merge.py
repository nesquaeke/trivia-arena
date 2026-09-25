#!/usr/bin/env python3
"""Soru çevirileri (PL/FR/ES) → data/questions.json ve data/mayhem.json

Çeviri dosyaları tools/questions/i18n/*.txt, her soru bir blok:
    @<kimlik>
    <Lehçe soru> TAB <şık1> TAB <şık2> TAB <şık3> TAB <şık4>
    <Fransızca ...>
    <İspanyolca ...>
Kimlik, Türkçe soru metninin sha1'inin ilk 8 hanesi. Şıklar İngilizcedeki sırayla
(doğru cevabın yeri "a" aynı kalır). Tahmin soruları "@E<kimlik>", satırlar: soru TAB birim.

  python3 game/tools/questions/i18n_merge.py export 120   # çevrilecekleri (EN) toplu dosyalara döker
  python3 game/tools/questions/i18n_merge.py              # çevirileri birleştirir, eksikleri sayar
"""
import glob
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "..", "data", "questions.json"))
LANGS = ["pl", "fr", "es"]


def qid(q):
    return hashlib.sha1(q["tr"]["q"].encode("utf-8")).hexdigest()[:8]


def all_mc(d):
    for tier in ("d1", "d2", "d3"):
        for q in d["tiers"][tier]:
            yield q


def load_tr():
    mc, est = {}, {}
    for path in sorted(glob.glob(os.path.join(HERE, "i18n", "*.txt"))):
        lines = [l.rstrip("\n") for l in open(path, encoding="utf-8")]
        i = 0
        while i < len(lines):
            l = lines[i].strip()
            if not l.startswith("@"):
                i += 1
                continue
            key = l[1:].strip()
            rows = lines[i + 1:i + 4]
            if len(rows) < 3:
                raise SystemExit("%s: %s eksik satır" % (path, key))
            parsed = [r.split("\t") for r in rows]
            if key.startswith("E"):
                for p in parsed:
                    if len(p) not in (1, 2):
                        raise SystemExit("%s: %s tahmin satırı bozuk: %r" % (path, key, p))
                est[key[1:]] = {l: {"q": p[0].strip(), "unit": (p[1].strip() if len(p) > 1 else "")} for l, p in zip(LANGS, parsed)}
            else:
                for p in parsed:
                    if len(p) != 5:
                        raise SystemExit("%s: %s 5 sütun olmalı (%d): %r" % (path, key, len(p), p))
                mc[key] = {l: {"q": p[0].strip(), "o": [x.strip() for x in p[1:]]} for l, p in zip(LANGS, parsed)}
            i += 4
    return mc, est


def check():
    """Basit yazım denetimi: İspanyolca ¿, Fransızca boşluklu ?, boş alan, yinelenen şık"""
    mc, est = load_tr()
    warn = 0
    for k, v in mc.items():
        es, fr = v["es"]["q"], v["fr"]["q"]
        if es.endswith("?") and "¿" not in es:
            print(k, "es ¿ eksik"); warn += 1
        if fr.endswith("?") and not fr.endswith(" ?"):
            print(k, "fr ' ?' eksik"); warn += 1
        for l in LANGS:
            o = v[l]["o"]
            if any(not x for x in o) or not v[l]["q"]:
                print(k, l, "boş alan"); warn += 1
            if len(set(o)) != 4:
                print(k, l, "aynı şık iki kez"); warn += 1
    print(len(mc), "soru,", len(est), "tahmin çevirisi;", warn, "uyarı")


def export(n):
    d = json.load(open(DATA, encoding="utf-8"))
    mc, est = load_tr()
    out_dir = sys.argv[3] if len(sys.argv) > 3 else "/tmp/q_export"
    os.makedirs(out_dir, exist_ok=True)
    todo = [q for q in all_mc(d) if qid(q) not in mc]
    for b in range(0, len(todo), n):
        with open(os.path.join(out_dir, "b%03d.txt" % (b // n)), "w", encoding="utf-8") as f:
            for q in todo[b:b + n]:
                f.write("@%s %s\n%s\n%s\n" % (qid(q), q["c"], q["en"]["q"], "\t".join(q["en"]["o"])))
    etodo = [q for q in d["estimate"] if qid(q) not in est]
    with open(os.path.join(out_dir, "est.txt"), "w", encoding="utf-8") as f:
        for q in etodo:
            f.write("@E%s\n%s\t%s\n" % (qid(q), q["en"]["q"], q["en"]["unit"]))
    print("çevrilecek", len(todo), "soru,", len(etodo), "tahmin →", out_dir)


def merge():
    d = json.load(open(DATA, encoding="utf-8"))
    mc, est = load_tr()
    miss = 0
    for q in all_mc(d):
        t = mc.get(qid(q))
        if t is None:
            miss += 1
            continue
        for l in LANGS:
            q[l] = t[l]
    emiss = 0
    for q in d["estimate"]:
        t = est.get(qid(q))
        if t is None:
            emiss += 1
            continue
        for l in LANGS:
            q[l] = t[l]
    with open(DATA, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, separators=(",", ":"))
    print("çeviri eksik:", miss, "soru,", emiss, "tahmin")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "check":
        check()
    elif len(sys.argv) > 1 and sys.argv[1] == "export":
        export(int(sys.argv[2]) if len(sys.argv) > 2 else 120)
    else:
        merge()
