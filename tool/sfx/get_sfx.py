"""Real recorded sound effects for the 3D games (CC0 / CC-BY from Freesound) + cheerful voice shouts
("UNO!", "Check!", "Six!") from Microsoft Edge's child voice.

Runs in GitHub Actions:  python tool/sfx/get_sfx.py
Writes assets/games3d/sfx.js (all clips inlined as base64 mp3, so the WebView needs no file access)
and assets/games3d/sfx_credits.json.
"""
import asyncio, base64, json, os, re, subprocess, sys, tempfile, time, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_JS = os.path.join(ROOT, "assets", "games3d", "sfx.js")
OUT_CR = os.path.join(ROOT, "assets", "games3d", "sfx_credits.json")
UA = {"User-Agent": "LittleOneFamilyApp/1.0 (personal, non-commercial; github.com/praveenkumarakumalla/little-one-app)"}

# name: (search queries, how many variants, max seconds per clip, split recording into separate hits?, words that rule a result out)
SPECS = {
    "card_play":   (["card slap table", "playing card throw", "card flick", "card slap"], 4, 0.45, True, r"shuffle|riffle|loop|music"),
    "card_draw":   (["card slide", "playing card slide", "card draw", "card swipe"], 3, 0.5, True, r"shuffle|music|loop"),
    "shuffle":     (["card shuffle riffle", "riffle shuffle", "cards shuffle"], 1, 1.6, False, r"music|loop"),
    "deal":        (["card deal", "dealing cards", "cards dealing"], 1, 1.4, False, r"music|loop"),
    "dice":        (["dice roll wood table", "dice roll", "rolling dice", "dice throw"], 3, 1.1, True, r"cup|shake|music|loop"),
    "dice_shake":  (["dice shake hand", "dice shake cup", "dice shaking"], 1, 0.7, False, r"music|loop"),
    "chess_move":  (["chess piece place", "chess move wood", "chess piece", "wooden piece board"], 4, 0.35, True, r"music|loop|clock"),
    "chess_take":  (["chess capture", "wood knock", "wooden block knock", "wood hit"], 2, 0.45, True, r"door|music|loop"),
    "piece_tap":   (["board game piece", "plastic piece tap", "game token tap", "plastic tap"], 3, 0.25, True, r"music|loop"),
    "hop":         (["cartoon jump boing", "boing", "bounce cartoon", "jump spring"], 2, 0.5, True, r"music|loop"),
    "pop":         (["pop bubble", "cartoon pop", "pop mouth", "cork pop"], 2, 0.35, True, r"music|loop|gun"),
    "whoosh":      (["whoosh swish", "swoosh fast", "whoosh"], 2, 0.7, True, r"music|loop|car|plane"),
    "zip_up":      (["slide whistle up", "rising whistle", "magic rise"], 1, 1.0, False, r"loop|music"),
    "zip_down":    (["slide whistle down", "falling whistle", "cartoon fall"], 1, 1.1, False, r"loop|music|bomb"),
    "hiss":        (["snake hiss", "hiss snake", "hissing"], 2, 1.0, True, r"steam|tire|cat|gas"),
    "sheep":       (["sheep baa", "sheep bleat", "lamb bleat", "sheep"], 6, 1.3, True, r"crowd|farm ambience|herd|loop|music"),
    "bump":        (["body thud", "soft thud", "punch soft", "pillow hit"], 3, 0.4, True, r"music|loop|door|neck|break|dirt"),
    "bell":        (["service bell ding", "desk bell", "reception bell"], 1, 1.4, False, r"church|loop|music|voice|elephant|door"),
    "chime":       (["success chime", "magic chime", "positive notification"], 2, 1.4, False, r"loop|music"),
    "coin":        (["coin collect", "coin pickup", "coin drop"], 1, 0.8, True, r"loop|music|pile"),
    "cheer":       (["kids cheering", "small crowd cheer", "crowd cheer applause"], 1, 3.0, False, r"stadium|loop|firework"),
    "applause":    (["applause short", "clapping small group"], 1, 3.0, False, r"stadium|loop"),
    "fanfare":     (["fanfare win", "victory fanfare", "trumpet fanfare short"], 1, 3.0, False, r"loop"),
    "fail":        (["sad trombone", "fail trombone", "wah wah"], 1, 2.2, False, r"loop"),
    "click":       (["ui click soft", "button click", "click soft"], 2, 0.15, True, r"loop|music|mouse|keyboard"),
    "bubble":      (["bubble pop", "bubble popping", "water bubble pop", "pop bubble wrap single"], 5, 0.35, True, r"music|loop|wrap roll|gum"),
    "bubbles":     (["bubbles water short", "bubbling water", "underwater bubbles short"], 2, 1.2, False, r"music|loop|boil|fish tank|aquarium"),
    "sparkle":     (["magic sparkle", "twinkle sparkle", "fairy sparkle"], 2, 1.2, False, r"music|loop"),
    "meadow":      (["meadow birds ambience", "countryside ambience birds", "spring meadow"], 1, 24.0, False, r"traffic|road|rain|car"),
}

# voice shouts (Edge child voice)
SHOUTS = {
    "v_uno": ("UNO!", "+15%"), "v_uno_out": ("UNO out! I win!", "+10%"), "v_skip": ("Skip!", "+10%"),
    "v_reverse": ("Reverse!", "+10%"), "v_draw2": ("Draw two!", "+10%"), "v_draw4": ("Draw four!", "+10%"),
    "v_wild": ("Wild card!", "+10%"), "v_red": ("Red!", "+10%"), "v_green": ("Green!", "+10%"),
    "v_yellow": ("Yellow!", "+10%"), "v_blue": ("Blue!", "+10%"), "v_check": ("Check!", "+5%"),
    "v_checkmate": ("Checkmate!", "+0%"), "v_six": ("Six!", "+15%"), "v_ladder": ("Yay! Ladder!", "+10%"),
    "v_snake": ("Oh no! Snake!", "+5%"), "v_win": ("You win! Hooray!", "+5%"), "v_home": ("Home!", "+10%"),
    "v_capture": ("Gotcha!", "+10%"), "v_point": ("Point!", "+10%"), "v_go": ("Ready, go!", "+10%"),
    "v_combo": ("Combo!", "+15%"), "v_boom": ("Boom!", "+10%"), "v_chain": ("Chain reaction!", "+10%"),
    "v_your_turn": ("Your turn!", "+10%"), "v_draw": ("Draw a card!", "+10%"),
}
VOICE = "en-US-AnaNeural"


def get(url, binary=False, tries=3):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
            time.sleep(0.6)
            return data if binary else data.decode("utf-8", "replace")
        except Exception as e:
            print("retry", url, e)
            time.sleep(3)
    return None


def search(q, maxdur):
    seen, out = set(), []
    filters = [
        f'license:"Creative Commons 0" duration:[0 TO {max(2, int(maxdur * 6))}]',
        'license:"Creative Commons 0"',
        "",
    ]
    for f in filters:
        url = "https://freesound.org/search/?" + urllib.parse.urlencode({"q": q, **({"f": f} if f else {}), "s": "Downloads (most first)"})
        html = get(url)
        if not html:
            continue
        for u, i in re.findall(r'/people/([^/"]+)/sounds/(\d+)/', html):
            if i not in seen:
                seen.add(i)
                out.append((u, i))
        if len(out) >= 6:
            break
    return out[:14]


def info(user, sid):
    html = get(f"https://freesound.org/people/{user}/sounds/{sid}/")
    if not html:
        return None
    title = re.search(r"<title>(.*?)</title>", html, re.S)
    title = re.sub(r"\s+", " ", title.group(1)).replace("Freesound - ", "").strip() if title else str(sid)
    tags = " ".join(re.findall(r'/browse/tags/([^/"]+)/', html))
    lic = None
    if "publicdomain/zero" in html:
        lic = "CC0"
    else:
        m = re.search(r'creativecommons\.org/licenses/(by(?:-[a-z]+)*)/(\d\.\d)', html)
        if m and "nc" not in m.group(1) and "nd" not in m.group(1):
            lic = f"CC {m.group(1).upper()} {m.group(2)}"
    m = re.search(r'(https://cdn\.freesound\.org/previews/\d+/\d+_\d+-hq\.mp3)', html)
    return dict(id=sid, user=user, title=title, tags=tags, lic=lic, preview=m.group(1) if m else None)


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *args], check=True)


def duration(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path], capture_output=True, text=True)
    try:
        return float(r.stdout.strip())
    except ValueError:
        return 0.0


def peak(path):
    r = subprocess.run(["ffmpeg", "-i", path, "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True)
    m = re.search(r"max_volume: (-?[\d.]+) dB", r.stderr)
    return float(m.group(1)) if m else 0.0


def events(path, tmp, tag, gap=0.12, thr=-38):
    """Cut a recording into separate hits at the quiet gaps."""
    r = subprocess.run(["ffmpeg", "-i", path, "-af", f"silencedetect=noise={thr}dB:d={gap}", "-f", "null", "-"], capture_output=True, text=True)
    total = duration(path)
    marks = re.findall(r"silence_(start|end): ([\d.]+)", r.stderr)
    spans, cur, inside = [], 0.0, False
    for kind, t in marks:
        t = float(t)
        if kind == "start":
            if t - cur >= 0.04:
                spans.append((cur, t))
        else:
            cur = t
    if total - cur >= 0.04:
        spans.append((cur, total))
    return spans


def finish(src, a, b, maxdur, dst, ambience=False):
    """Trim, fade, normalise and encode one clip."""
    a = max(0.0, a - 0.01)
    length = min(b - a + 0.06, maxdur)
    tmpw = dst + ".wav"
    fade = min(0.06 if not ambience else 2.0, length / 3)
    ffmpeg("-ss", f"{a:.3f}", "-t", f"{length:.3f}", "-i", src, "-ac", "1", "-ar", "44100",
           "-af", f"highpass=f=40,afade=t=in:d=0.004,afade=t=out:st={max(0, length - fade):.3f}:d={fade:.3f}", tmpw)
    g = -1.5 - peak(tmpw) if not ambience else -9 - peak(tmpw)
    ffmpeg("-i", tmpw, "-af", f"volume={g:.2f}dB", "-c:a", "libmp3lame", "-b:a", "48k" if ambience else "64k", "-ar", "44100", "-ac", "1", dst)
    os.remove(tmpw)
    return duration(dst)


def collect(name, spec, tmp, credits):
    queries, n, maxdur, split, bad = spec
    badre = re.compile(bad, re.I) if bad else None
    clips, used = [], set()
    for q in queries:
        if len(clips) >= n:
            break
        for user, sid in search(q, maxdur):
            if len(clips) >= n or sid in used:
                continue
            inf = info(user, sid)
            if not inf or not inf["lic"] or not inf["preview"]:
                continue
            if badre and badre.search(inf["title"]):
                print(f"  skip (title) {inf['title']}")
                continue
            used.add(sid)
            raw = os.path.join(tmp, f"{sid}.mp3")
            data = get(inf["preview"], binary=True)
            if not data:
                continue
            open(raw, "wb").write(data)
            total = duration(raw)
            if total < 0.05:
                continue
            if name != "meadow" and total > 60:
                print(f"  skip (too long {total:.0f}s) {inf['title']}")
                continue
            if split:
                spans = [s for s in events(raw, tmp, sid) if s[1] - s[0] >= (0.03 if maxdur <= 0.25 else 0.12)]
                spans = spans or [(0.0, total)]
                take = spans[: max(1, min(3, n - len(clips)))]  # at most 3 hits from one recording
            else:
                # skip the leading silence
                spans = events(raw, tmp, sid, gap=0.3, thr=-45)
                start = spans[0][0] if spans else 0.0
                take = [(start, total)]
            for a, b in take:
                dst = os.path.join(tmp, f"{name}_{len(clips)}.mp3")
                d = finish(raw, a, b, maxdur, dst, ambience=(name == "meadow"))
                if d < 0.03:
                    continue
                clips.append(dst)
                print(f"  {name}[{len(clips)-1}] {d:.2f}s  ← {inf['title']} ({inf['lic']}, {user})")
            credits.append(dict(sound=name, title=inf["title"], user=user, license=inf["lic"], url=f"https://freesound.org/people/{user}/sounds/{sid}/"))
    return clips


async def shouts(tmp):
    import edge_tts
    out = {}
    for key, (text, rate) in SHOUTS.items():
        try:
            mp3 = os.path.join(tmp, key + "_raw.mp3")
            await edge_tts.Communicate(text, VOICE, rate=rate, pitch="+20Hz").save(mp3)
            dst = os.path.join(tmp, key + ".mp3")
            spans = events(mp3, tmp, key, gap=0.2, thr=-45)
            a = spans[0][0] if spans else 0.0
            b = spans[-1][1] if spans else duration(mp3)
            finish(mp3, a, b, 3.0, dst)
            out[key] = [dst]
            print(f"  voice {key} ok")
        except Exception as e:
            print(f"::warning title=sfx::voice {key} failed: {e}")
    return out


def main():
    only = set(sys.argv[1:])
    tmp = tempfile.mkdtemp()
    credits, result = [], {}
    # keep what earlier runs found (so a re-run for one sound doesn't lose the rest)
    old = {}
    if os.path.exists(OUT_JS):
        m = re.search(r"window\.SFX_DATA = (\{.*\});", open(OUT_JS, encoding="utf-8").read(), re.S)
        if m:
            old = json.loads(m.group(1))
    if os.path.exists(OUT_CR):
        credits = [c for c in json.load(open(OUT_CR, encoding="utf-8")) if not only or c["sound"] not in only]
    for name, spec in SPECS.items():
        if only and name not in only:
            continue
        print(f"== {name}")
        try:
            clips = collect(name, spec, tmp, credits)
        except Exception as e:
            print(f"::warning title=sfx::{name} failed: {e}")
            clips = []
        if clips:
            result[name] = clips
        else:
            print(f"::warning title=sfx::{name}: nothing found (the game keeps its built-in sound)")
    if not only or any(k.startswith("v_") for k in only) or "voices" in only:
        result.update(asyncio.run(shouts(tmp)))
    data = dict(old)
    for name, files in result.items():
        data[name] = ["data:audio/mpeg;base64," + base64.b64encode(open(f, "rb").read()).decode() for f in files]
    with open(OUT_JS, "w", encoding="utf-8") as f:
        f.write("/* Recorded game sounds (Freesound CC0/CC-BY – see sfx_credits.json) and voice shouts. Generated by tool/sfx/get_sfx.py */\n")
        f.write("window.SFX_DATA = " + json.dumps(data, separators=(",", ":")) + ";\n")
    json.dump(credits, open(OUT_CR, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    size = os.path.getsize(OUT_JS) / 1024
    have = sorted(data)
    missing = [k for k in SPECS if k not in data]
    print(f"::notice title=sfx::{len(have)} sounds, {size:.0f} KB. Missing: {', '.join(missing) or 'none'}")


if __name__ == "__main__":
    main()
