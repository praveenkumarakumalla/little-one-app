"""Baby voice clips with Google Gemini TTS (needs a free API key in env GEMINI_API_KEY).

  python tool/voices/gemini_voices.py samples          -> voice_samples/gemini_<voice>.m4a
  python tool/voices/gemini_voices.py all <voice> [shift]  -> assets/voice/<key>.m4a  (skips files that already exist,
                                                          stops politely when the free daily limit is reached)
"""
import base64, json, os, subprocess, sys, tempfile, time, urllib.error, urllib.request, wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LINES = json.load(open(os.path.join(ROOT, "tool", "voices", "lines.json"), encoding="utf-8"))
KEY = os.environ.get("GEMINI_API_KEY", "").strip()
STYLE = "a cute, sweet, happy little 3-year-old girl talking to her family in Telugu; playful, loving, slightly slow and very clear"
SAMPLE_VOICES = ["Leda", "Laomedeia", "Zephyr", "Autonoe"]
PRIORITY = ["amma", "nanna", "ammamma", "tatayya", "biryani", "pizza", "ram", "milk", "okay_amma", "shh", "snooze", "calm", "ok"]


def post(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": KEY})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())


def find_audio(obj):
    """Search any response shape for base64 audio."""
    if isinstance(obj, dict):
        mt = str(obj.get("mimeType") or obj.get("mime_type") or "")
        for k in ("data", "audio", "inlineData", "inline_data"):
            v = obj.get(k)
            if isinstance(v, str) and len(v) > 2000 and ("audio" in mt or k == "audio" or mt == ""):
                return v, mt
        for v in obj.values():
            r = find_audio(v)
            if r:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = find_audio(v)
            if r:
                return r
    return None


EXHAUSTED = set()
NEW_MODELS = ["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts", "gemini-3.1-flash-tts-preview"]
OLD_MODELS = ["gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts"]


def tts(text, voice):
    """Tries each Gemini TTS model; a model whose free daily limit is used up is skipped."""
    errors = []
    for model in NEW_MODELS + OLD_MODELS:
        if model in EXHAUSTED:
            continue
        try:
            if model in NEW_MODELS:
                res = post("https://generativelanguage.googleapis.com/v1beta/interactions", {
                    "model": model,
                    "input": [{"type": "user_input", "content": [{"type": "text", "text": text, "annotations": [{"type": "speech_metadata", "style": STYLE}]}]}],
                    "response_format": {"type": "audio"},
                    "generation_config": {"speech_config": [{"voice": voice}]},
                })
            else:
                res = post(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent", {
                    "contents": [{"parts": [{"text": f"Say this as {STYLE}: {text}"}]}],
                    "generationConfig": {"responseModalities": ["AUDIO"], "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}}},
                })
            a = find_audio(res)
            if a:
                print(f"::notice title=gemini::  via {model}")
                return a
            errors.append(f"{model}: no audio")
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:300]
            if e.code == 429:
                EXHAUSTED.add(model)
                print(f"::warning title=gemini::{model} daily limit used up")
                continue
            errors.append(f"{model}: {e.code} {msg}")
        except Exception as e:
            errors.append(f"{model}: {e}")
    if len(EXHAUSTED) == len(NEW_MODELS + OLD_MODELS):
        raise RuntimeError("LIMIT all models used up for today")
    raise RuntimeError(" | ".join(errors))


def save(b64, mt, out, shift=1.0):
    raw = base64.b64decode(b64)
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "in.wav")
        if raw[:4] == b"RIFF":
            open(src, "wb").write(raw)
        else:  # headerless 24 kHz 16-bit mono PCM
            with wave.open(src, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(24000)
                w.writeframes(raw)
        sr = 24000
        chain = "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse"
        if shift != 1.0:
            chain += f",asetrate={int(sr * shift)},aresample=44100,atempo={1 / shift:.5f}"
        chain += ",loudnorm=I=-16:TP=-1.5"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", chain, "-ac", "1", "-ar", "44100", "-c:a", "aac", "-b:a", "96k", out], check=True)


def main():
    if not KEY:
        print("::error title=gemini::GEMINI_API_KEY secret is missing")
        sys.exit(1)
    mode = sys.argv[1] if len(sys.argv) > 1 else "samples"
    if mode == "samples":
        out = os.path.join(ROOT, "voice_samples")
        os.makedirs(out, exist_ok=True)
        for v in SAMPLE_VOICES:
            try:
                b64, mt = tts(LINES["amma"], v)
                save(b64, mt, os.path.join(out, f"gemini_{v}.m4a"))
                print(f"::notice title=gemini::sample {v} ok")
            except Exception as e:
                print(f"::warning title=gemini::{v}: {str(e)[:600]}")
                if str(e).startswith("LIMIT"):
                    break
            time.sleep(21)
        return
    voice = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else "Leda"
    shift = float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else 1.0
    out = os.path.join(ROOT, "assets", "voice")
    os.makedirs(out, exist_ok=True)
    keys = PRIORITY + [k for k in LINES if k not in PRIORITY]
    done = 0
    for k in keys:
        dst = os.path.join(out, f"{k}.m4a")
        if os.path.exists(dst):
            continue
        try:
            b64, mt = tts(LINES[k], voice)
            save(b64, mt, dst, shift)
            done += 1
            print(f"::notice title=gemini::{k} ok")
        except Exception as e:
            print(f"::warning title=gemini::{k}: {str(e)[:500]}")
            if str(e).startswith("LIMIT"):
                print("::warning title=gemini::free daily limit reached — run again tomorrow for the rest")
                break
        time.sleep(21)
    left = [k for k in keys if not os.path.exists(os.path.join(out, f"{k}.m4a"))]
    print(f"::notice title=gemini::made {done}, still to do {len(left)}")


if __name__ == "__main__":
    main()
