#!/usr/bin/env python3
"""Gerçek enstrüman örnekleri: FluidSynth + General MIDI ses bankası (FluidR3_GM, MIT lisansı).

compose.py ve mayhem_sounds.py bu modül varsa sentez enstrümanları yerine buradaki
örneklenmiş notaları kullanır (notalar/besteler aynı kalır, yalnız tını değişir).
Kurulum (Debian/Ubuntu):  sudo apt install fluidsynth fluid-soundfont-gm
Ses bankası yolu değiştirilebilir:  TA_SF2=/yol/banka.sf2

    note(prog, f, dur, vel)      tek nota, mono float dizi (44.1 kHz)
    drum(key, vel, dur)          GM davul kanalı (36 kick, 38 trampet, 42 hi-hat, 49 zil…)
"""
import ctypes
import ctypes.util
import math
import os

import numpy as np

SR = 44100
SF2 = os.environ.get("TA_SF2", "/usr/share/sounds/sf2/FluidR3_GM.sf2")

_lib = None
_synth = None
_sfid = -1
_cache = {}


def available():
    return _init()


def _init():
    global _lib, _synth, _sfid
    if _synth is not None:
        return _synth is not False
    path = ctypes.util.find_library("fluidsynth") or "libfluidsynth.so.3"
    try:
        _lib = ctypes.CDLL(path)
    except OSError:
        _synth = False
        return False
    if not os.path.exists(SF2):
        _synth = False
        return False
    L = _lib
    L.new_fluid_settings.restype = ctypes.c_void_p
    L.new_fluid_synth.restype = ctypes.c_void_p
    L.new_fluid_synth.argtypes = [ctypes.c_void_p]
    L.fluid_settings_setnum.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_double]
    L.fluid_settings_setint.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    L.fluid_synth_sfload.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    L.fluid_synth_program_select.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    L.fluid_synth_noteon.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    L.fluid_synth_noteoff.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
    L.fluid_synth_pitch_bend.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
    L.fluid_synth_all_sounds_off.argtypes = [ctypes.c_void_p, ctypes.c_int]
    L.fluid_synth_write_float.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                                          ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
    st = L.new_fluid_settings()
    L.fluid_settings_setnum(st, b"synth.sample-rate", float(SR))
    L.fluid_settings_setnum(st, b"synth.gain", 0.6)
    # yankı ve koro kapalı: salon yankısını compose.py ekler
    L.fluid_settings_setint(st, b"synth.reverb.active", 0)
    L.fluid_settings_setint(st, b"synth.chorus.active", 0)
    L.fluid_settings_setint(st, b"synth.polyphony", 256)
    _synth = L.new_fluid_synth(st)
    _sfid = L.fluid_synth_sfload(_synth, SF2.encode(), 1)
    if _sfid < 0:
        _synth = False
        return False
    return True


def _render(n):
    lb = (ctypes.c_float * n)()
    rb = (ctypes.c_float * n)()
    _lib.fluid_synth_write_float(_synth, n, lb, 0, 1, rb, 0, 1)
    return (np.frombuffer(lb, dtype=np.float32).astype(np.float64) + np.frombuffer(rb, dtype=np.float32)) * 0.5


def _play(chan, key, vel, dur, tail, bend=0):
    L = _lib
    L.fluid_synth_all_sounds_off(_synth, -1)
    _render(256)
    L.fluid_synth_pitch_bend(_synth, chan, 8192 + bend)
    L.fluid_synth_noteon(_synth, chan, key, vel)
    on = _render(max(1, int(dur * SR)))
    L.fluid_synth_noteoff(_synth, chan, key)
    off = _render(int(tail * SR))
    L.fluid_synth_pitch_bend(_synth, chan, 8192)
    x = np.concatenate([on, off])
    # sondaki sessizliği kırp
    e = np.abs(x)
    nz = np.nonzero(e > 1e-4)[0]
    return x[: nz[-1] + 1] if len(nz) else x[:1]


def midi_of(f):
    """frekans → (en yakın MIDI notası, pitch-bend: ±2 yarım ton aralığında ince ayar)"""
    m = 69 + 12 * math.log2(max(f, 1.0) / 440.0)
    k = int(round(m))
    bend = int(round((m - k) / 2.0 * 8192))
    return max(0, min(127, k)), max(-8191, min(8191, bend))


def note(prog, f, dur, vel=100, tail=1.2, bank=0):
    """Tek nota (mono). prog: GM program (0 piyano, 48 yaylı, 60 korno…)."""
    if not _init():
        return None
    key, bend = midi_of(f)
    k = (prog, bank, key, bend, round(dur, 3), int(vel), round(tail, 2))
    if k in _cache:
        return _cache[k]
    _lib.fluid_synth_program_select(_synth, 0, _sfid, bank, prog)
    x = _play(0, key, int(max(1, min(127, vel))), dur, tail, bend)
    _cache[k] = x
    return x


def drum(key, vel=100, dur=0.4, tail=1.0):
    """GM davul kanalı (kanal 10)"""
    if not _init():
        return None
    k = ("drum", key, int(vel), round(dur, 3), round(tail, 2))
    if k in _cache:
        return _cache[k]
    _lib.fluid_synth_program_select(_synth, 9, _sfid, 128, 0)
    x = _play(9, key, int(max(1, min(127, vel))), dur, tail)
    _cache[k] = x
    return x
