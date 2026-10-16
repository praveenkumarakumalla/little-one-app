"""Fill-in baby voice (Microsoft Edge Telugu voice, pitched up) for lines Gemini hasn't made yet.
Writes assets/voice_fb/<key>.m4a. The app prefers the Gemini (Leda) clip in assets/voice/ when it exists."""
import asyncio, json, os, subprocess, sys
import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LINES = json.load(open(os.path.join(ROOT, "tool", "voices", "lines.json"), encoding="utf-8"))
LEDA = os.path.join(ROOT, "assets", "voice")
OUT = os.path.join(ROOT, "assets", "voice_fb")
VOICE = sys.argv[1] if len(sys.argv) > 1 else "te-IN-ShrutiNeural"
os.makedirs(OUT, exist_ok=True)

async def one(key, text):
    mp3 = f"/tmp/{key}.mp3"
    await edge_tts.Communicate(text, VOICE, rate="-4%", pitch="+38Hz").save(mp3)
    # lift the voice a little more so it sounds like a small child, keep the speed natural
    k = 1.13
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", mp3, "-af",
                    f"asetrate=24000*{k},aresample=24000,atempo={1/k:.4f},loudnorm=I=-16:TP=-1.5",
                    "-c:a", "aac", "-b:a", "96k", os.path.join(OUT, key + ".m4a")], check=True)

async def main():
    done = 0
    for key, text in LINES.items():
        if os.path.exists(os.path.join(LEDA, key + ".m4a")):
            continue  # Leda already has it
        try:
            await one(key, text)
            done += 1
            print(f"::notice title=edge::{key} ok")
        except Exception as e:
            print(f"::warning title=edge::{key} failed: {e}")
    print(f"::notice title=edge::made {done} fill-in lines with {VOICE}")

asyncio.run(main())
