#!/usr/bin/env python3
"""Arayüz çevirileri: tools/i18n/ui_*.tsv → data/i18n/{pl,fr,es}.json

Her satır:  anahtar <TAB> Lehçe <TAB> Fransızca <TAB> İspanyolca   (\\n satır sonu)
TR ve EN metinleri scripts/core/i18n.gd içindeki S sözlüğündedir.
Kullanım: python3 game/tools/i18n/build_ui.py
"""
import glob
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "data", "i18n"))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "scripts", "core", "i18n.gd"))
LANGS = ["pl", "fr", "es"]


def main():
    keys = re.findall(r'^\t"([^"]+)":\s*\[', open(SRC, encoding="utf-8").read(), re.M)
    out = {l: {} for l in LANGS}
    for path in sorted(glob.glob(os.path.join(HERE, "ui_*.tsv"))):
        for n, line in enumerate(open(path, encoding="utf-8"), 1):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 4:
                raise SystemExit("%s:%d: 4 sütun olmalı (%d)" % (path, n, len(parts)))
            for l, text in zip(LANGS, parts[1:]):
                out[l][parts[0]] = text.replace("\\n", "\n")
    os.makedirs(OUT, exist_ok=True)
    for l in LANGS:
        missing = [k for k in keys if k not in out[l]]
        if missing:
            print(l, "eksik:", " ".join(missing))
        with open(os.path.join(OUT, l + ".json"), "w", encoding="utf-8") as f:
            json.dump(out[l], f, ensure_ascii=False, indent=0, sort_keys=True)
        print(l, len(out[l]), "anahtar")


if __name__ == "__main__":
    main()
