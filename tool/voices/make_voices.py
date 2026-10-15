"""Makes Telugu baby-voice clips with Meta MMS-TTS Telugu (facebook/mms-tts-tel, open model),
then shifts pitch + formants up (ffmpeg) so it sounds like a small child.

  python tool/voices/make_voices.py samples          -> voice_samples/voice_<A|B|C>.m4a
  python tool/voices/make_voices.py all <A|B|C>      -> assets/voice/<key>.m4a
"""
import json, os, subprocess, sys, tempfile

import numpy as np
import soundfile as sf
import torch
from transformers import AutoTokenizer, VitsModel

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LINES = json.load(open(os.path.join(ROOT, "tool", "voices", "lines.json"), encoding="utf-8"))
MODEL = "facebook/mms-tts-tel"
VOICES = {"A": 1.25, "B": 1.4, "C": 1.55}  # child shift amount


def load():
    print("::notice title=voices::loading", MODEL)
    tok = AutoTokenizer.from_pretrained(MODEL)
    model = VitsModel.from_pretrained(MODEL).eval()
    model.speaking_rate = 0.92
    model.noise_scale = 0.6
    return model, tok


def romanize(tok, text):
    if getattr(tok, "is_uroman", False):
        import uroman as ur
        return ur.Uroman().romanize_string(text)
    return text


def speak(model, tok, text, voice, out_path, seed=7):
    torch.manual_seed(seed)
    inp = tok(romanize(tok, text), return_tensors="pt")
    with torch.no_grad():
        a = model(**inp).waveform.squeeze().cpu().numpy().astype(np.float32)
    sr = model.config.sampling_rate
    idx = np.where(np.abs(a) > 0.01)[0]
    if len(idx):
        a = a[max(0, idx[0] - int(0.05 * sr)): idx[-1] + int(0.2 * sr)]
    a = a / (np.max(np.abs(a)) + 1e-9) * 0.92
    k = VOICES[voice]
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        sf.write(wav, a, sr)
        # raise pitch + formants by k, keep the same length; add brightness and warmth
        af = f"asetrate={int(sr * k)},aresample=44100,atempo={1 / k:.5f},highpass=f=120,equalizer=f=3000:t=q:w=1:g=3,loudnorm=I=-16:TP=-1.5"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", af, "-ac", "1", "-c:a", "aac", "-b:a", "96k", out_path], check=True)
    print(f"::notice title=voices::{os.path.basename(out_path)} {len(a) / sr:.1f}s")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "samples"
    model, tok = load()
    if mode == "samples":
        out = os.path.join(ROOT, "voice_samples")
        os.makedirs(out, exist_ok=True)
        for v in VOICES:
            speak(model, tok, LINES["amma"], v, os.path.join(out, f"voice_{v}.m4a"))
    else:
        voice = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else "B"
        only = set(sys.argv[3].split(",")) if len(sys.argv) > 3 and sys.argv[3] else None
        out = os.path.join(ROOT, "assets", "voice")
        os.makedirs(out, exist_ok=True)
        for key, text in LINES.items():
            if not only or key in only:
                speak(model, tok, text, voice, os.path.join(out, f"{key}.m4a"))


if __name__ == "__main__":
    main()
