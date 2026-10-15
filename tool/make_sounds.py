"""Synthesises the Fun-zone sounds (original, copyright-free) into assets/sounds/*.m4a.

Run: python3 tool/make_sounds.py   (needs numpy + ffmpeg)
"""
import os, subprocess, tempfile, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sounds")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def lowpass(x, cutoff, taps=101):
    fc = cutoff / SR
    n = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(2 * fc * n) * np.hamming(taps)
    h /= h.sum()
    return np.convolve(x, h, mode="same")


def env(n, a=0.02, r=0.15, d=None):
    e = np.ones(n)
    ai, ri = max(1, int(a * SR)), max(1, int(r * SR))
    e[:ai] = np.linspace(0, 1, ai)
    e[-ri:] *= np.linspace(1, 0, ri)
    return e


def fart(dur, f0, f1=None, wobble=8.0, wob_rate=6.0, wet=0.0, flap=0.6, bright=900, jitter=0.15, rough=0.5):
    """Pulse-train 'flap' excitation + noise, low-passed: sounds like… you know."""
    tt = t(dur)
    f1 = f0 if f1 is None else f1
    f = np.linspace(f0, f1, len(tt)) + wobble * np.sin(2 * np.pi * wob_rate * tt)
    f *= 1 + jitter * lowpass(rng.standard_normal(len(tt)), 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    gate = (np.sin(ph) > (1 - 2 * flap)).astype(float)
    gate = lowpass(gate, bright * 1.6, 31)
    noise = rng.standard_normal(len(tt))
    x = gate * (rough * noise + (1 - rough) * np.sign(np.sin(ph))) + 0.35 * np.sin(ph)
    if wet > 0:
        pops = (rng.random(len(tt)) < wet * 0.004).astype(float)
        pops = np.convolve(pops, np.exp(-np.arange(200) / 25.0) * np.sin(np.arange(200) / 3.0), mode="same")
        x += 2.5 * pops
    x = lowpass(x, bright)
    return x * env(len(tt), 0.01, min(0.2, dur / 3))


def tone(freqs, dur, shape="sine", vib=0.0, vib_rate=5.0):
    tt = t(dur)
    f = np.interp(tt, np.linspace(0, dur, len(freqs)), freqs) if len(freqs) > 1 else np.full(len(tt), freqs[0])
    f = f * (1 + vib * np.sin(2 * np.pi * vib_rate * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(ph)
    if shape == "square":
        return np.sign(np.sin(ph)) * 0.6
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    raise ValueError(shape)


def silence(d):
    return np.zeros(int(SR * d))


def cat(*xs):
    return np.concatenate(xs)


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


SOUNDS = {
    # ---- farts ----
    "fart_classic": lambda: fart(1.1, 95, 70),
    "fart_squeaker": lambda: fart(0.9, 260, 420, wobble=30, wob_rate=9, flap=0.3, bright=2400, rough=0.25),
    "fart_machine_gun": lambda: cat(*[cat(fart(0.12 + 0.04 * rng.random(), 110 + 30 * rng.random()), silence(0.06)) for _ in range(9)]),
    "fart_tuba": lambda: fart(2.0, 58, 50, wobble=4, wob_rate=3, bright=500, rough=0.35),
    "fart_long_goodbye": lambda: fart(3.6, 120, 85, wobble=35, wob_rate=2.2, bright=1100),
    "fart_tiny_toot": lambda: fart(0.28, 180, 220, bright=1600, rough=0.3),
    "fart_wet_one": lambda: fart(1.4, 80, 65, wet=1.0, rough=0.75, bright=700),
    "fart_rocket": lambda: fart(1.6, 60, 320, wobble=10, bright=1800),
    "fart_duck": lambda: cat(fart(0.35, 300, 260, flap=0.25, bright=2600, rough=0.2), silence(0.08), fart(0.45, 320, 240, flap=0.25, bright=2600, rough=0.2)),
    "fart_silent_deadly": lambda: cat(0.35 * lowpass(rng.standard_normal(int(SR * 1.8)), 3000) * env(int(SR * 1.8), 0.4, 0.6), fart(0.25, 330, 380, bright=2600, rough=0.2)),
    # ---- funny ----
    "fun_boing": lambda: tone([180, 420, 260, 330, 300], 0.9, vib=0.25, vib_rate=14) * np.exp(-t(0.9) * 3.2),
    "fun_slide_up": lambda: tone([300, 1600], 0.8, vib=0.02, vib_rate=7) * env(int(SR * 0.8), 0.03, 0.1),
    "fun_slide_down": lambda: tone([1600, 260], 0.9, vib=0.02, vib_rate=7) * env(int(SR * 0.9), 0.03, 0.1),
    "fun_ba_dum_tss": lambda: cat(
        tone([180, 90], 0.18) * np.exp(-t(0.18) * 22), silence(0.06),
        tone([200, 100], 0.22) * np.exp(-t(0.22) * 18), silence(0.05),
        lowpass(rng.standard_normal(int(SR * 1.0)), 9000) * np.exp(-t(1.0) * 4.5) * 0.7),
    "fun_pop": lambda: cat(tone([900, 300], 0.07) * np.exp(-t(0.07) * 40), silence(0.05)),
    "fun_cuckoo": lambda: cat(*[cat(tone([659], 0.22, vib=0.004) * env(int(SR * 0.22), 0.01, 0.08), silence(0.04), tone([523], 0.32, vib=0.004) * env(int(SR * 0.32), 0.01, 0.12), silence(0.25)) for _ in range(2)]),
    "fun_clown_horn": lambda: cat(lowpass(tone([420, 400], 0.28, "saw"), 2200) * env(int(SR * 0.28), 0.01, 0.06), silence(0.08), lowpass(tone([420, 390], 0.4, "saw"), 2200) * env(int(SR * 0.4), 0.01, 0.1)),
    "fun_sad_trombone": lambda: cat(*[lowpass(tone([f, f * 0.98], d, "saw", vib=0.012 if i == 3 else 0.004, vib_rate=6), 1800) * env(int(SR * d), 0.03, 0.08) for i, (f, d) in enumerate([(311, 0.42), (294, 0.42), (277, 0.42), (262, 1.3)])]),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, fn in SOUNDS.items():
            x = norm(fn())
            pcm = (x * 32767).astype(np.int16)
            wav = os.path.join(tmp, name + ".wav")
            with wave.open(wav, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes(pcm.tobytes())
            out = os.path.join(OUT, name + ".m4a")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "aac", "-b:a", "64k", out], check=True)
            print(f"{name}: {len(x) / SR:.2f}s {os.path.getsize(out) // 1024} KB")


if __name__ == "__main__":
    main()
