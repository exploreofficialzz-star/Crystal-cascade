"""Synthesises Cass's voice lines and a few UI/game effects (no recordings needed).
Run:  python3 tools/generate_sounds.py   (needs numpy)
Replace any wav in assets/sounds with a recorded line later; names stay the same."""
import os, wave
import numpy as np
try:
    from scipy.signal import lfilter
except Exception:
    lfilter = None

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(11)

VOWELS = {"a": (800, 1200, 2800), "e": (450, 2000, 2900), "i": (300, 2300, 3000),
          "o": (500, 900, 2600), "u": (330, 800, 2300), "ae": (700, 1700, 2600), "m": (250, 1000, 2200)}

def resonate(x, f, bw):
    r = np.exp(-np.pi * bw / SR); th = 2 * np.pi * f / SR
    b1 = 2 * r * np.cos(th); b2 = -r * r; a = 1 - r
    if lfilter is not None:
        return lfilter([a], [1, -b1, -b2], x)
    y = np.zeros_like(x)
    for i in range(len(x)):
        y[i] = a * x[i] + (b1 * y[i - 1] if i > 0 else 0) + (b2 * y[i - 2] if i > 1 else 0)
    return y

def adsr(n, a=0.02, d=0.04, s=0.75, r=0.07):
    t = np.arange(n) / SR; e = np.ones(n)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, max(na, 1))
    e[na:na + nd] = np.linspace(1, s, max(nd, 1))[:max(0, min(nd, n - na))]
    e[na + nd:] = s
    if nr > 0: e[-nr:] *= np.linspace(1, 0, nr)
    return e

def syl(f0a, f0b, vowel, dur, vib=5.5, vdepth=0.02, breath=0.05, vowel2=None, bump=0.0, burst=0.0, attack=0.02, release=0.06):
    n = int(dur * SR); u = np.linspace(0, 1, n); t = u * dur
    f0 = f0a + (f0b - f0a) * u + bump * np.sin(np.pi * u) * (f0a + f0b) * 0.5
    f0 = f0 * (1 + vdepth * np.sin(2 * np.pi * vib * t))
    ph = 2 * np.pi * np.cumsum(f0) / SR
    src = np.zeros(n)
    for k in range(1, 30):
        mask = (k * f0 < SR / 2 - 500)
        src += np.where(mask, np.sin(k * ph) / (k ** 1.1), 0)
    src += breath * rng.standard_normal(n) * 0.5
    out = np.zeros(n)
    f1 = np.array(VOWELS[vowel], float)
    f2 = np.array(VOWELS[vowel2 or vowel], float)
    # blend formants across the syllable by mixing two filtered versions
    a = sum(resonate(src, f, 90 + 40 * i) * g for i, (f, g) in enumerate(zip(f1, (1.0, 0.7, 0.35))))
    if vowel2:
        b = sum(resonate(src, f, 90 + 40 * i) * g for i, (f, g) in enumerate(zip(f2, (1.0, 0.7, 0.35))))
        out = a * (1 - u) + b * u
    else:
        out = a
    if burst > 0:
        nb = int(0.018 * SR); nz = rng.standard_normal(nb); nz = resonate(nz, 2600, 900) * burst
        out[:nb] += nz * np.linspace(1, 0, nb)
    return out * adsr(n, attack, 0.04, 0.8, release)

def seq(parts, gaps=None):
    gaps = gaps or [0.015] * (len(parts) - 1)
    out = parts[0]
    for g, p in zip(gaps, parts[1:]):
        out = np.concatenate([out, np.zeros(int(g * SR)), p])
    return out

def tone(f, dur, decay=6.0, harm=(1.0, 0.4, 0.2)):
    t = np.arange(int(dur * SR)) / SR
    y = sum(h * np.sin(2 * np.pi * f * (k + 1) * t) for k, h in enumerate(harm))
    return y * np.exp(-decay * t) * np.minimum(1, t / 0.004)

def noise_sweep(dur, f0, f1, bw=700):
    n = int(dur * SR); nz = rng.standard_normal(n); out = np.zeros(n)
    seg = 256
    for i in range(0, n, seg):
        f = f0 + (f1 - f0) * i / n
        out[i:i + seg] = resonate(nz[i:i + seg], f, bw)[:len(out[i:i + seg])]
    return out

def save(name, y, peak=0.82):
    y = np.asarray(y, float); y = y / (np.max(np.abs(y)) + 1e-9) * peak
    # gentle low-pass for softness
    y = np.convolve(y, np.ones(3) / 3, mode="same")
    pcm = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    print(f"{name:14s} {len(y)/SR:5.2f}s")

# ── Cass voice lines ─────────────────────────────────────────────────────────
save("cass_yay", seq([syl(360, 450, "e", 0.13, burst=0.5), syl(450, 640, "a", 0.34, vowel2="e", vdepth=0.03, bump=0.05)]))
save("cass_wow", seq([syl(300, 430, "o", 0.16, burst=0.3), syl(430, 330, "a", 0.38, vowel2="o", vdepth=0.04, bump=0.08)]))
save("cass_hmm", syl(205, 215, "m", 0.55, vib=3.5, vdepth=0.04, bump=0.12, attack=0.06, release=0.14))
save("cass_think", syl(215, 300, "m", 0.48, vib=3.0, vdepth=0.03, attack=0.05, release=0.12))
save("cass_oh_no", seq([syl(430, 380, "o", 0.20), syl(370, 215, "o", 0.42, vowel2="u", vdepth=0.03)], [0.05]))
save("cass_oops", seq([syl(410, 340, "a", 0.13, burst=0.3), syl(330, 240, "o", 0.24)], [0.04]))
save("cass_nope", seq([syl(250, 205, "a", 0.15, breath=0.12), syl(225, 165, "a", 0.22, breath=0.15)], [0.05]))
save("cass_hello", seq([syl(400, 470, "e", 0.12, burst=0.5), syl(470, 380, "o", 0.30, vowel2="u", vdepth=0.03)]))
save("cass_cheer", seq([syl(380, 480, "e", 0.12, burst=0.4), syl(480, 570, "ae", 0.13, burst=0.4), syl(570, 700, "ae", 0.30, vdepth=0.04)], [0.04, 0.03]))
gig = [syl(520 + 25 * k, 600 + 20 * k, "i", 0.07, burst=0.6, vdepth=0.01) * (1 - 0.1 * k) for k in range(5)]
save("cass_giggle", seq(gig, [0.055] * 4))
sig = noise_sweep(0.7, 1800, 500, 600) * np.linspace(1, 0, int(0.7 * SR)) ** 0.7
save("cass_sigh", sig * adsr(len(sig), 0.1, 0.1, 0.8, 0.2))

# ── UI / game effects ─────────────────────────────────────────────────────────
def layer(parts):
    """parts: list of (offset_seconds, array) summed into one buffer."""
    n = max(int(o * SR) + len(a) for o, a in parts)
    out = np.zeros(n)
    for o, a in parts:
        s0 = int(o * SR); out[s0:s0 + len(a)] += a
    return out

w = noise_sweep(0.36, 350, 2600, 900)
save("ui_whoosh", w * np.sin(np.linspace(0, np.pi, len(w))) ** 1.5, 0.55)
save("ui_chime", layer([(0.0, tone(1046.5, 0.6, 5.0)), (0.09, tone(1318.5, 0.6, 5.0)), (0.18, tone(1568.0, 0.7, 4.0))]))
nz = noise_sweep(0.9, 600, 4200, 1200) * np.exp(-3 * np.linspace(0, 1, int(0.9 * SR)))
save("chest_open", layer([(k * 0.07, tone(f, 0.5, 6.0)) for k, f in enumerate((784, 988, 1175, 1568, 1976))] + [(0.0, nz * 0.25)]))
save("streak_up", layer([(0.0, tone(880, 0.35, 7.0)), (0.12, tone(1318.5, 0.5, 5.0))]))
save("tube_drop", layer([(0.0, tone(95, 0.28, 14.0, (1.0, 0.5, 0.2))), (0.03, 0.5 * tone(2093, 0.4, 9.0, (1.0, 0.2)))]))
save("star_ping", tone(1760, 0.5, 6.0, (1.0, 0.35, 0.15)))
