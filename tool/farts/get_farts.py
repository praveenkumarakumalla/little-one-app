"""Collects 20 real (human) fart recordings from Freesound, CC0 licence only, and makes 5–10 s clips.

Runs in GitHub Actions:  python tool/farts/get_farts.py
Writes assets/farts/fart_01.m4a … fart_20.m4a and assets/farts/credits.json
"""
import json, os, random, re, subprocess, sys, tempfile, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "farts")
UA = {"User-Agent": "LittleOneFamilyApp/1.0 (personal, non-commercial; github.com/praveenkumarakumalla/little-one-app)"}

PACKS = [
    ("Jagadamba", 15564),
    ("frenkfurth", 36232),
    ("frenkfurth", 42449),
    ("designerschoice", 43542),
    ("timtube", 3907),
    ("Zott820", 11588),
]
SOUNDS = [
    ("Opposit", 58836), ("chimerical", 104425), ("Huminaatio", 221907), ("sandyrb", 110045), ("sandyrb", 110048),
    ("sandyrb", 110049), ("sandyrb", 110050), ("timtube", 61047), ("IFartInUrGeneralDirection", 37733),
    ("DiArchangeli", 195146), ("taliasauce", 158739), ("Jagadamba", 253862), ("Jagadamba", 253803),
    ("frenkfurth", 650693), ("Hajisounds", 640073), ("edfuentesg", 469695), ("shaundoogan", 465486),
    ("TeddyFerguson", 402569), ("Sadiquecat", 787755), ("Crimsonblaze", 833105),
]
BAD = re.compile(r"synth|computer|cartoon|8.?bit|arcade|whoopee|balloon|mouth|armpit|hand|vocal|voice|fake|laugh|burp|belch|pee|poop|toilet|splat|game", re.I)

NAMES = [
    ("🌩️", "Thunder Rumble"), ("🫧", "Bubble Bath"), ("🎺", "Morning Trumpet"), ("🚪", "Squeaky Door"),
    ("🏍️", "Bullet Bike"), ("👋", "Long Goodbye"), ("🔫", "Machine Gun"), ("💦", "Wet Surprise"),
    ("🐘", "Elephant Walk"), ("🍿", "Popcorn"), ("🐍", "Silent Hiss"), ("🦆", "Duck Parade"),
    ("🚀", "Rocket Launch"), ("🌋", "Volcano"), ("🍗", "Biryani Aftermath"), ("👴", "Thatayya Special"),
    ("🧨", "Diwali Cracker"), ("🚂", "Train Horn"), ("🎻", "Violin Solo"), ("🏆", "Grand Finale"),
]


def get(url, binary=False, tries=3):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
            time.sleep(0.8)  # be polite
            return data if binary else data.decode("utf-8", "replace")
        except Exception as e:
            print("retry", url, e)
            time.sleep(3)
    return None


def pack_sounds(user, pid):
    ids = set()
    for page in range(1, 6):
        html = get(f"https://freesound.org/people/{user}/packs/{pid}/sounds/?page={page}")
        if not html:
            break
        found = set((u, int(i)) for u, i in re.findall(r'/people/([^/"]+)/sounds/(\d+)/', html))
        if not found - ids:
            break
        ids |= found
    return ids


def info(user, sid):
    html = get(f"https://freesound.org/people/{user}/sounds/{sid}/")
    if not html:
        return None
    title = re.search(r"<title>(.*?)</title>", html, re.S)
    title = re.sub(r"\s+", " ", title.group(1)).replace("Freesound - ", "").strip() if title else str(sid)
    cc0 = "publicdomain/zero" in html or "Creative Commons 0" in html
    m = re.search(r'(https://cdn\.freesound\.org/previews/\d+/\d+_\d+-hq\.mp3)', html)
    return dict(id=sid, user=user, title=title, cc0=cc0, preview=m.group(1) if m else None)


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *args], check=True)


def duration(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path], capture_output=True, text=True)
    try:
        return float(r.stdout.strip())
    except ValueError:
        return 0.0


def main():
    random.seed(20261006)
    os.makedirs(OUT, exist_ok=True)
    cands = set(SOUNDS)
    for u, p in PACKS:
        s = pack_sounds(u, p)
        print(f"pack {u}/{p}: {len(s)} sounds")
        cands |= s
    print("candidates:", len(cands))
    good = []
    with tempfile.TemporaryDirectory() as tmp:
        for u, sid in sorted(cands, key=lambda x: x[1]):
            it = info(u, sid)
            if not it or not it["cc0"] or not it["preview"] or BAD.search(it["title"]):
                continue
            raw = os.path.join(tmp, f"{sid}.mp3")
            data = get(it["preview"], binary=True)
            if not data:
                continue
            open(raw, "wb").write(data)
            # trim silence from both ends
            clean = os.path.join(tmp, f"{sid}.wav")
            ffmpeg("-i", raw, "-af", "silenceremove=start_periods=1:start_threshold=-45dB:stop_periods=-1:stop_threshold=-45dB:stop_duration=0.6,aresample=44100", "-ac", "1", clean)
            d = duration(clean)
            if d < 0.6:
                continue
            it["dur"] = d
            it["wav"] = clean
            good.append(it)
            print(f"ok {sid} {d:.1f}s {it['title']}")
            if len(good) >= 80:
                break

        if len(good) < 8:
            print("::error title=farts::only", len(good), "usable CC0 recordings found")
            sys.exit(1)

        long = [g for g in good if g["dur"] >= 5]
        short = [g for g in good if g["dur"] < 5]
        random.shuffle(long)
        random.shuffle(short)
        clips = []
        for g in long:
            clips.append([g])
        # build medleys of short ones until 5–10 s
        while short and len(clips) < 20:
            group, total = [], 0.0
            while short and total < 5.5:
                g = short.pop()
                group.append(g)
                total += g["dur"] + 0.35
            if total >= 4.0:
                clips.append(group)
        random.shuffle(clips)
        clips = clips[:20]
        credits = []
        for n, group in enumerate(clips, 1):
            out = os.path.join(OUT, f"fart_{n:02d}.m4a")
            lst = os.path.join(tmp, f"list{n}.txt")
            gap = os.path.join(tmp, "gap.wav")
            ffmpeg("-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "0.35", gap)
            with open(lst, "w") as f:
                for i, g in enumerate(group):
                    if i:
                        f.write(f"file '{gap}'\n")
                    f.write(f"file '{g['wav']}'\n")
            joined = os.path.join(tmp, f"j{n}.wav")
            ffmpeg("-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined)
            # 5–10 s: cut long ones to 10 s with a fade out; normalise loudness
            ffmpeg("-i", joined, "-t", "10", "-af", "afade=t=out:st=9.4:d=0.6,loudnorm=I=-15:TP=-1.0", "-ac", "1", "-c:a", "aac", "-b:a", "96k", out)
            e, name = NAMES[n - 1]
            credits.append({"file": f"fart_{n:02d}", "emoji": e, "name": name, "secs": round(min(10.0, duration(out)), 1),
                            "sources": [{"title": g["title"], "by": g["user"], "url": f"https://freesound.org/people/{g['user']}/sounds/{g['id']}/", "license": "CC0"} for g in group]})
            print(f"::notice title=farts::fart_{n:02d} {name} {credits[-1]['secs']}s from {len(group)} recording(s)")
        json.dump(credits, open(os.path.join(OUT, "credits.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
