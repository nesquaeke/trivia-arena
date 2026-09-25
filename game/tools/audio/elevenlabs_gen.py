#!/usr/bin/env python3
"""ElevenLabs ile oyunun seslerini üret → game/assets/audio_pro/<tür>/<id>.ogg

Plan ve tarifler: tools/audio/sound_plan.py (öncelik sırasıyla). Oyun bu dosyaları
AudioPack ile otomatik kullanır; dosya olmayan ses eski hâliyle çalar.

Gerekli:  ELEVENLABS_API_KEY ortam değişkeni, api.elevenlabs.io ağ izni
          pip install numpy scipy soundfile

Kullanım:
  python3 game/tools/audio/elevenlabs_gen.py --dry-run        # plan + tahmini kredi
  python3 game/tools/audio/elevenlabs_gen.py                  # hepsi, öncelik sırasıyla, bütçe bitene dek
  python3 game/tools/audio/elevenlabs_gen.py --max-tier 2     # yalnız öncelik 1-2
  python3 game/tools/audio/elevenlabs_gen.py --only ding buzz --force
  python3 game/tools/audio/elevenlabs_gen.py --reserve 500    # hesapta 500 kredi bırak

Her ses için birden çok seçenek istenebilir; betik en uygununu (süre, kırpılma,
sessizlik) seçer, diğerleri tools/audio/alts/ klasörüne gider (elle değiştirmek için).
Üretilenler tools/audio/elevenlabs_manifest.json'a yazılır; tekrar çalıştırınca atlanır.
"""
import argparse
import io
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "voice"))
import sound_plan as P  # noqa: E402

GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GAME, "assets", "audio_pro")
ALTS = os.path.join(HERE, "alts")
MANIFEST = os.path.join(HERE, "elevenlabs_manifest.json")
API = "https://api.elevenlabs.io"
SR = 44100
UI = {"tick", "click", "ui_hover", "ui_confirm", "ui_back"}


# ── HTTP ────────────────────────────────────────────────────────────
def _ctx():
    for p in (os.environ.get("SSL_CERT_FILE"), os.environ.get("REQUESTS_CA_BUNDLE"), "/root/.ccr/ca-bundle.crt"):
        if p and os.path.exists(p):
            return ssl.create_default_context(cafile=p)
    return ssl.create_default_context()


CTX = _ctx()


def call(method, path, body=None, raw=False, retries=3):
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    data = json.dumps(body).encode() if body is not None else None
    for i in range(retries):
        req = urllib.request.Request(API + path, data=data, method=method,
                                     headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "*/*"})
        try:
            with urllib.request.urlopen(req, context=CTX, timeout=180) as r:
                b = r.read()
                return b if raw else json.loads(b)
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:400]
            if e.code in (429, 500, 502, 503) and i < retries - 1:
                time.sleep(4 * (i + 1))
                continue
            raise RuntimeError("HTTP %d %s: %s" % (e.code, path, msg))
        except urllib.error.URLError as e:
            if i < retries - 1:
                time.sleep(4 * (i + 1))
                continue
            raise RuntimeError("ağ hatası %s: %s" % (path, e))


def credits_left():
    """kalan kredi (anahtarda user_read izni yoksa None)"""
    try:
        s = call("GET", "/v1/user/subscription")
        return int(s["character_limit"]) - int(s["character_count"])
    except Exception:
        return None


# ── ses işleme ──────────────────────────────────────────────────────
def decode(mp3):
    x, sr = sf.read(io.BytesIO(mp3), dtype="float64")
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr, axis=0)
    return x


def trim(x, lead_db=-42.0, tail_db=-55.0):
    e = np.max(np.abs(x), axis=1)
    pk = np.max(e) + 1e-12
    on = np.nonzero(e > pk * 10 ** (lead_db / 20))[0]
    off = np.nonzero(e > pk * 10 ** (tail_db / 20))[0]
    if len(on) == 0:
        return x[:1]
    a = max(0, on[0] - int(0.004 * SR))
    b = min(len(x), off[-1] + int(0.03 * SR))
    y = x[a:b].copy()
    f = min(len(y), int(0.02 * SR))
    y[-f:] *= np.linspace(1, 0, f)[:, None]
    return y


def finish(x, peak_db):
    x = x - np.mean(x, axis=0)
    return (x / (np.max(np.abs(x)) + 1e-12) * 10 ** (peak_db / 20)).astype(np.float32)


def room(x):
    """sunucu: gövde/netlik EQ, yumuşak sıkıştırma, hafif salon yankısı (oyunun sesleriyle uyumlu)"""
    m = x.mean(axis=1)
    b, a = signal.butter(2, 90 / (SR / 2), "high")
    m = signal.lfilter(b, a, m)
    b, a = signal.butter(2, [2500 / (SR / 2), 4500 / (SR / 2)], "band")
    m = m + 0.2 * signal.lfilter(b, a, m)
    m = m / (np.max(np.abs(m)) + 1e-9)
    m = np.tanh(m * 1.6) / np.tanh(1.6)
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    ir = np.random.default_rng(3).uniform(-1, 1, n) * np.exp(-t * 4.8)
    b, a = signal.butter(1, 4200 / (SR / 2), "low")
    ir = signal.lfilter(b, a, ir)
    ir[: int(0.02 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    pad = np.concatenate([m, np.zeros(n)])
    wet = signal.fftconvolve(pad, ir)[: len(pad)]
    y = pad * 0.9 + wet * 0.14
    r = np.concatenate([np.zeros(int(0.004 * SR)), y])[: len(y)]
    return trim(np.stack([y, r * 0.97 + y * 0.03], axis=1), -45, -50)


def score(x, want):
    """seçenek puanı: süre hedefe yakın, sessiz değil, kırpılmamış"""
    d = len(x) / SR
    if d < 0.03:
        return -99.0
    clip = float(np.mean(np.abs(x) > 0.995))
    return -abs(d - want) / max(want, 0.3) - clip * 50.0


def write(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, x, SR, format="OGG", subtype="VORBIS")


# ── üretim ──────────────────────────────────────────────────────────
def gen_sfx(prompt, dur):
    body = {"text": prompt, "duration_seconds": max(0.5, min(30.0, dur)), "prompt_influence": 0.5,
            "model_id": "eleven_text_to_sound_v2"}
    try:
        b = call("POST", "/v1/sound-generation?output_format=mp3_44100_128", body, raw=True)
    except RuntimeError as e:
        if "model" not in str(e).lower():
            raise
        body.pop("model_id")
        b = call("POST", "/v1/sound-generation?output_format=mp3_44100_128", body, raw=True)
    return decode(b)


_voice = None


def pick_voice():
    global _voice
    if _voice:
        return _voice
    cands = ([(os.environ["TA_VOICE_ID"], "TA_VOICE_ID")] if os.environ.get("TA_VOICE_ID") else []) + P.VOICE_CANDIDATES
    for vid, name in cands:
        try:
            call("GET", "/v1/voices/" + vid)
            _voice = vid
            print("sunucu sesi:", name, vid)
            return vid
        except RuntimeError:
            continue
    raise RuntimeError("uygun ses bulunamadı; TA_VOICE_ID ver")


def gen_tts(text):
    body = {"text": text, "model_id": "eleven_multilingual_v2", "voice_settings": P.VOICE_SETTINGS}
    return decode(call("POST", "/v1/text-to-speech/%s?output_format=mp3_44100_128" % pick_voice(), body, raw=True))


def plan():
    import narrate
    jobs = []
    for i, (sid, tier, dur, var, prompt) in enumerate(P.SFX):
        jobs.append({"key": "sfx/" + sid, "kind": "sfx", "id": sid, "tier": tier, "dur": dur, "var": var,
                     "prompt": prompt + " " + P.THEME, "order": i})
    for i, (sid, tier, dur, var, prompt) in enumerate(P.MAYHEM):
        jobs.append({"key": "mayhem/" + sid, "kind": "mayhem", "id": sid, "tier": tier, "dur": dur, "var": var,
                     "prompt": prompt, "order": 100 + i})
    for li, lang in enumerate(["tr", "en", "pl", "fr", "es"]):
        for i, k in enumerate(narrate.LINES):
            jobs.append({"key": "voice/%s/%s" % (lang, k), "kind": "voice", "id": k, "lang": lang,
                         "tier": P.VOICE_TIERS[lang], "var": 1, "text": narrate.line(k, lang), "order": 200 + li * 50 + i})
    jobs.sort(key=lambda j: (j["tier"], j["order"]))
    return jobs


def estimate(j, sfx_rate):
    if j["kind"] == "voice":
        return len(j["text"])
    return int(sfx_rate * max(0.5, j["dur"]) * j["var"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--max-tier", type=int, default=9)
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--reserve", type=int, default=300)
    ap.add_argument("--sfx-rate", type=float, default=40.0, help="saniye başına tahmini efekt kredisi (ilk üretimde ölçülür)")
    a = ap.parse_args()

    man = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {}
    jobs = [j for j in plan() if j["tier"] <= a.max_tier and (not a.only or j["id"] in a.only or j["key"] in a.only)]
    if not a.force:
        jobs = [j for j in jobs if j["key"] not in man]

    rate = a.sfx_rate
    if a.dry_run:
        tot = 0
        for j in jobs:
            c = estimate(j, rate)
            tot += c
            print("P%d %-26s ~%5d kredi (toplam ~%d)" % (j["tier"], j["key"], c, tot))
        print("%d iş, tahmini %d kredi (efekt: saniye başı %.0f varsayımı)" % (len(jobs), tot, rate))
        return

    if not os.environ.get("ELEVENLABS_API_KEY"):
        raise SystemExit("ELEVENLABS_API_KEY yok: ortam ayarlarına ekleyip yeni oturum aç")
    left = credits_left()
    print("kalan kredi:", left if left is not None else "bilinmiyor (anahtarda user_read izni yok)")
    done = 0
    for j in jobs:
        need = estimate(j, rate)
        if left is not None and left - need < a.reserve:
            print("bütçe sınırı: %s atlandı (gerekli ~%d, kalan %d, ayrılan %d)" % (j["key"], need, left, a.reserve))
            continue
        before = left
        try:
            if j["kind"] == "voice":
                x = room(gen_tts(j["text"]))
                best = finish(x, -1.5)
                alts = []
            else:
                cands = []
                for v in range(j["var"]):
                    raw = gen_sfx(j["prompt"], j["dur"])
                    x = trim(raw)
                    x = finish(x, -8.0 if j["id"] in UI else -1.5)
                    cands.append((score(x, j["dur"]), x))
                cands.sort(key=lambda c: -c[0])
                best = cands[0][1]
                alts = [c[1] for c in cands[1:]]
        except RuntimeError as e:
            print("HATA", j["key"], e)
            if "401" in str(e) or "quota" in str(e).lower():
                break
            continue
        path = os.path.join(OUT, j["key"] + ".ogg")
        write(path, best)
        for k, x in enumerate(alts):
            write(os.path.join(ALTS, j["key"].replace("/", "_") + "_%d.ogg" % (k + 2)), x)
        left = credits_left()
        used = (before - left) if (before is not None and left is not None) else None
        if used and j["kind"] != "voice":
            # efekt kredisini gerçek harcamadan öğren (sonraki tahminler için)
            rate = max(5.0, used / (max(0.5, j["dur"]) * j["var"]))
        man[j["key"]] = {"prompt": j.get("prompt") or j.get("text"), "dur": round(len(best) / SR, 2),
                         "credits": used, "alts": len(alts), "at": time.strftime("%Y-%m-%d %H:%M")}
        json.dump(man, open(MANIFEST, "w"), ensure_ascii=False, indent=1)
        done += 1
        print("✓ P%d %-26s %.2f sn  kredi: %s  kalan: %s" % (j["tier"], j["key"], len(best) / SR, used, left))
    print("bitti: %d yeni ses. Godot'a almak için: godot --headless --path game --import" % done)


if __name__ == "__main__":
    main()
