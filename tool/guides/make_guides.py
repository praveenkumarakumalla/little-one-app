"""Builds the parent guide books: assets/trial/guides.json (read in the app) and 4 PDF books
(girl/boy x English/Telugu) in assets/trial/guides/. Run:  python3 tool/guides/make_guides.py
Needs Node + Playwright with Chromium (renders Telugu correctly)."""
import base64, html, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from content import CHAPTERS, BOOK_TITLES, NOTE  # noqa: E402

OUT = os.path.join(ROOT, "assets", "trial")
os.makedirs(os.path.join(OUT, "guides"), exist_ok=True)

# ---- JSON for the app ----
json.dump({"chapters": CHAPTERS, "books": BOOK_TITLES, "note": NOTE}, open(os.path.join(OUT, "guides.json"), "w", encoding="utf-8"), ensure_ascii=False)


def font(name, fam, w):
    b = base64.b64encode(open(os.path.join(HERE, "fonts", name), "rb").read()).decode()
    return f"@font-face{{font-family:'{fam}';font-weight:{w};src:url(data:font/woff2;base64,{b}) format('woff2');}}"


FONTS = "".join([
    font("poppins-latin-400-normal.woff2", "Poppins", 400), font("poppins-latin-600-normal.woff2", "Poppins", 600),
    font("poppins-latin-700-normal.woff2", "Poppins", 700),
    font("noto-sans-telugu-telugu-400-normal.woff2", "NotoTe", 400), font("noto-sans-telugu-telugu-700-normal.woff2", "NotoTe", 700),
])

CSS = FONTS + """
@page { size: A5; margin: 0; }
* { box-sizing: border-box; }
body { margin: 0; font-family: 'Poppins', 'NotoTe', sans-serif; color: #2b2350; font-size: 10.5pt; line-height: 1.55; }
.te body, body.te { line-height: 1.75; }
.cover { height: 210mm; background: #4b3ba8; color: #fff; padding: 22mm 14mm; display: flex; flex-direction: column; justify-content: space-between; page-break-after: always; position: relative; overflow: hidden; }
.cover .blob { position: absolute; border-radius: 50%; background: #f6c9d6; opacity: .9; }
.cover h1 { font-size: 26pt; line-height: 1.25; margin: 0; font-weight: 700; position: relative; }
.cover .sub { font-size: 11pt; opacity: .9; position: relative; }
.cover .badge { background: #f6c9d6; color: #4b3ba8; border-radius: 22px; padding: 10px 16px; display: inline-block; font-weight: 600; box-shadow: 0 6px 0 #d9a2b4; position: relative; }
.page { padding: 12mm 12mm 10mm; }
.ch { page-break-before: always; }
.ch:first-of-type { page-break-before: auto; }
.ch h2 { background: #f6d7e1; color: #3d2c8d; border-radius: 18px; padding: 9px 14px; font-size: 15pt; margin: 0 0 10px; box-shadow: 0 5px 0 #e7b9c8; }
.card { background: #f3f1f7; border-radius: 16px; padding: 9px 13px; margin: 0 0 9px; break-inside: avoid; box-shadow: 0 3px 0 #e2deec; }
.card h3 { margin: 0 0 2px; font-size: 11pt; color: #4b3ba8; font-weight: 700; }
.card p { margin: 0; }
.toc li { margin: 3px 0; }
.note { font-size: 8.5pt; color: #6b6390; margin-top: 12px; }
.danger h2 { background: #ffd9d9; color: #a3202a; box-shadow: 0 5px 0 #f3b5b5; }
"""


def book(gender, lang):
    chs = [c for c in CHAPTERS if c["for"] in ("all", gender)]
    title = BOOK_TITLES[gender][lang]
    sub = {"en": "A month-by-month guide for new parents", "te": "కొత్త తల్లిదండ్రులకు నెల నెలా మార్గదర్శి"}[lang]
    made = {"en": "From the Little One app", "te": "లిటిల్ వన్ యాప్ నుంచి"}[lang]
    contents = {"en": "Contents", "te": "విషయ సూచిక"}[lang]
    h = [f"<html lang='{lang}'><head><meta charset='utf-8'><style>{CSS}</style></head><body class='{lang}'>"]
    h.append("<div class='cover'><div class='blob' style='width:90mm;height:90mm;right:-30mm;top:-25mm'></div>"
             "<div class='blob' style='width:60mm;height:60mm;left:-20mm;bottom:-18mm;background:#7d6fd0'></div>"
             f"<div><div class='badge'>{html.escape(made)}</div></div>"
             f"<div><h1>{html.escape(title)}</h1><p class='sub'>{html.escape(sub)}</p></div>"
             f"<div class='sub' style='font-size:8.5pt'>{html.escape(NOTE[lang])}</div></div>")
    h.append(f"<div class='page'><div class='ch'><h2>{contents}</h2><ol class='toc'>")
    for c in chs:
        h.append(f"<li>{html.escape(c['title'][lang])}</li>")
    h.append("</ol></div>")
    for c in chs:
        cls = "ch danger" if c["key"] == "danger" else "ch"
        h.append(f"<div class='{cls}'><h2>{html.escape(c['title'][lang])}</h2>")
        for head, text in c[lang]:
            h.append("<div class='card'>" + (f"<h3>{html.escape(head)}</h3>" if head else "") + f"<p>{html.escape(text)}</p></div>")
        h.append("</div>")
    h.append(f"<p class='note'>{html.escape(NOTE[lang])}</p></div></body></html>")
    return "".join(h)


tmp = tempfile.mkdtemp()
jobs = []
for g in ("girl", "boy"):
    for lang in ("en", "te"):
        p = os.path.join(tmp, f"{g}_{lang}.html")
        open(p, "w", encoding="utf-8").write(book(g, lang))
        jobs.append((p, os.path.join(OUT, "guides", f"{g}_{lang}.pdf")))

js = os.path.join(tmp, "pdf.js")
open(js, "w").write("""
const { chromium } = require('playwright');
(async () => {
  const jobs = JSON.parse(process.argv[2]);
  const b = await chromium.launch();
  const p = await b.newPage();
  for (const [src, dst] of jobs) {
    await p.goto('file://' + src);
    await p.evaluate(() => document.fonts.ready);
    await p.pdf({ path: dst, format: 'A5', printBackground: true });
    console.log('pdf', dst);
  }
  await b.close();
})();
""")
env = dict(os.environ)
env.setdefault("NODE_PATH", subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip())
subprocess.run(["node", js, json.dumps(jobs)], check=True, env=env)
print("guides: done")
