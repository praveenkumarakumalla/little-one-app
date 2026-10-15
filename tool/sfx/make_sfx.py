"""Synthesise small game sound effects (no downloads needed)."""
import wave, numpy as np, os
SR = 22050
out = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'sfx')
rng = np.random.default_rng(3)

def env(n, a=0.005, d=0.1):
    t = np.arange(n) / SR
    return np.minimum(1, t / a) * np.exp(-t / d)

def tone(f, dur, d=0.15, kind='sine', f2=None):
    n = int(SR * dur); t = np.arange(n) / SR
    fr = f if f2 is None else f * (f2 / f) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    w = np.sin(ph) if kind == 'sine' else (2 / np.pi) * np.arcsin(np.sin(ph))
    return w * env(n, 0.004, d)

def noise(dur, d=0.05, lo=0.0):
    n = int(SR * dur); x = rng.standard_normal(n)
    if lo:  # crude high-pass
        x = np.diff(np.concatenate([[0], x]))
    return x * env(n, 0.002, d)

def mix(*parts):
    n = max(len(p) for _, p in parts); y = np.zeros(n)
    for off, p in parts:
        o = int(off * SR); y[o:o + len(p)] += p[:max(0, n - o)]
    return y

def save(name, y, vol=0.8):
    y = y / (np.max(np.abs(y)) + 1e-9) * vol
    with wave.open(os.path.join(out, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())

save('flip', mix((0, noise(0.12, 0.03, lo=1) * 0.8), (0.01, tone(900, 0.08, 0.03, 'tri', 500) * 0.4)))
save('draw', mix((0, noise(0.2, 0.06, lo=1) * 0.5), (0, tone(500, 0.15, 0.06, 'tri', 700) * 0.3)), 0.6)
save('skip', mix((0, tone(700, 0.25, 0.12, 'tri', 250)), (0.0, noise(0.25, 0.1, lo=1) * 0.3)))
save('plus', mix(*[(i * 0.07, tone(f, 0.18, 0.1, 'tri')) for i, f in enumerate([392, 523, 659, 784])]))
save('uno', mix((0, tone(988, 0.35, 0.2)), (0.12, tone(1319, 0.5, 0.25)), (0.12, tone(659, 0.5, 0.25) * 0.5)))
save('turn', tone(880, 0.12, 0.05) * 0.6, 0.5)
seq = [(523, 0), (659, 0.12), (784, 0.24), (1047, 0.36), (784, 0.52), (1047, 0.64)]
save('win', mix(*[(w, tone(f, 0.35, 0.18, 'tri') + tone(f / 2, 0.35, 0.18) * 0.5) for f, w in seq], (0.8, tone(1047, 1.0, 0.5) + tone(1319, 1.0, 0.5) + tone(1568, 1.0, 0.5))))
print(sorted(os.listdir(out)))
