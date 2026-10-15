"""Makes natural Telugu baby-voice clips with AI4Bharat Indic Parler-TTS (open source, Apache-2.0).

Runs in GitHub Actions (needs internet + ~4 GB):
  python tool/voices/make_voices.py samples          -> voice_samples/<voice>.m4a  (one test line per voice style)
  python tool/voices/make_voices.py all <voice>      -> assets/voice/<key>.m4a     (every line in lines.json)

A "child" shift raises pitch *and* formants a little (ffmpeg asetrate) so the clear adult-trained
voice sounds like a small girl, while keeping the length the same.
"""
import json, os, subprocess, sys, tempfile

import numpy as np
import soundfile as sf
import torch
from parler_tts import ParlerTTSForConditionalGeneration
from transformers import AutoTokenizer

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LINES = json.load(open(os.path.join(ROOT, "tool", "voices", "lines.json"), encoding="utf-8"))

VOICES = {
    "A": dict(desc="Lalitha speaks with a high-pitched, very cheerful, sweet and playful voice at a moderate pace. The recording is very clear and close-up, with no background noise.", shift=1.0),
    "B": dict(desc="Lalitha speaks with a high-pitched, very cheerful, sweet and playful voice at a moderate pace. The recording is very clear and close-up, with no background noise.", shift=1.2),
    "C": dict(desc="A little girl speaks in a very high-pitched, cute, sweet and happy voice, slowly and clearly, with lots of expression. The recording is very clear and close-up, with no background noise.", shift=1.12),
}

MODEL = "ai4bharat/indic-parler-tts"


def load():
    print("::notice title=voices::loading model")
    model = ParlerTTSForConditionalGeneration.from_pretrained(MODEL).eval()
    tok = AutoTokenizer.from_pretrained(MODEL)
    dtok = AutoTokenizer.from_pretrained(model.config.text_encoder._name_or_path)
    return model, tok, dtok


def speak(model, tok, dtok, text, voice, out_path, seed=11):
    v = VOICES[voice]
    torch.manual_seed(seed)
    d = dtok(v["desc"], return_tensors="pt")
    p = tok(text, return_tensors="pt")
    with torch.no_grad():
        g = model.generate(input_ids=d.input_ids, attention_mask=d.attention_mask, prompt_input_ids=p.input_ids, prompt_attention_mask=p.attention_mask, do_sample=True, temperature=0.8)
    a = g.cpu().numpy().squeeze().astype(np.float32)
    sr = model.config.sampling_rate
    # trim silence at the ends, then normalise
    idx = np.where(np.abs(a) > 0.01)[0]
    if len(idx):
        a = a[max(0, idx[0] - int(0.05 * sr)): idx[-1] + int(0.15 * sr)]
    a = a / (np.max(np.abs(a)) + 1e-9) * 0.92
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        sf.write(wav, a, sr)
        k = v["shift"]
        af = f"asetrate={int(sr * k)},aresample=44100,atempo={1 / k:.5f},highpass=f=90,loudnorm=I=-16:TP=-1.5" if k != 1.0 else "aresample=44100,highpass=f=90,loudnorm=I=-16:TP=-1.5"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", af, "-ac", "1", "-c:a", "aac", "-b:a", "96k", out_path], check=True)
    print(f"::notice title=voices::{os.path.basename(out_path)} {len(a) / sr:.1f}s")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "samples"
    model, tok, dtok = load()
    if mode == "samples":
        os.makedirs(os.path.join(ROOT, "voice_samples"), exist_ok=True)
        text = LINES["amma"]
        for v in VOICES:
            speak(model, tok, dtok, text, v, os.path.join(ROOT, "voice_samples", f"voice_{v}.m4a"))
    else:
        voice = sys.argv[2] if len(sys.argv) > 2 else "B"
        out = os.path.join(ROOT, "assets", "voice")
        os.makedirs(out, exist_ok=True)
        only = set(sys.argv[3].split(",")) if len(sys.argv) > 3 and sys.argv[3] else None
        for key, text in LINES.items():
            if only and key not in only:
                continue
            speak(model, tok, dtok, text, voice, os.path.join(out, f"{key}.m4a"))


if __name__ == "__main__":
    main()
