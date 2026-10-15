"""Little One app icon: 'Chandamama Amma' — a crescent-moon mother (sleeping smile, profile) cradling
her sleeping baby in a pink blanket, with a heart and a twinkle. Soft clay-3D shading.
Writes assets/icon.png (full), assets/icon_fg.png (adaptive foreground), assets/icon_bg.png (adaptive background).
"""
import io, os
import cairosvg
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
S = 1024

MOON = ("M 560 150 "
        "C 330 140, 150 330, 160 560 "          # outer back of the head / moon
        "C 170 790, 380 930, 610 905 "           # outer bottom curve to the arm tip
        "C 660 900, 700 870, 690 835 "           # arm tip (rounded)
        "C 680 800, 620 805, 570 800 "           # inner arm back towards body
        "C 470 790, 395 720, 400 640 "           # inner lower curve (the cradle)
        "C 402 600, 430 585, 455 572 "           # chin
        "C 478 560, 470 540, 462 532 "           # lower lip
        "C 476 522, 482 510, 470 500 "           # upper lip
        "C 478 488, 495 470, 500 452 "           # under nose
        "C 506 432, 488 420, 470 410 "           # nose tip
        "C 455 400, 448 380, 450 360 "           # bridge / brow
        "C 455 290, 500 230, 560 150 Z")         # forehead to top tip

def svg(body, bg=False):
    defs = """
    <defs>
      <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#FFD6E5"/><stop offset="0.55" stop-color="#FFE3EC"/><stop offset="1" stop-color="#FFEBD9"/>
      </linearGradient>
      <radialGradient id="glow" cx="0.55" cy="0.5" r="0.55">
        <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.75"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
      </radialGradient>
      <linearGradient id="moon" gradientUnits="userSpaceOnUse" x1="200" y1="160" x2="720" y2="900">
        <stop offset="0" stop-color="#FFF6D8"/><stop offset="0.45" stop-color="#FFE29A"/><stop offset="1" stop-color="#F9BE5C"/>
      </linearGradient>
      <linearGradient id="moonshine" x1="0" y1="0" x2="0.6" y2="0.6">
        <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.85"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
      </linearGradient>
      <linearGradient id="blanket" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#FFB3CC"/><stop offset="1" stop-color="#F27DA5"/>
      </linearGradient>
      <radialGradient id="skin" cx="0.4" cy="0.35" r="0.7">
        <stop offset="0" stop-color="#FFEBDD"/><stop offset="1" stop-color="#F7C7A6"/>
      </radialGradient>
      <linearGradient id="heart" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#FF8FB1"/><stop offset="1" stop-color="#E9457C"/>
      </linearGradient>
    </defs>"""
    back = '<rect width="1024" height="1024" fill="url(#bg)"/><circle cx="560" cy="520" r="470" fill="url(#glow)"/>' if bg else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 1024 1024">{defs}{back}{body}</svg>'

def png(svg_text):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg_text.encode()))).convert("RGBA")

def shadow(mask_svg, dx, dy, blur, color=(214, 120, 150), alpha=0.45):
    m = png(mask_svg).split()[3]
    sh = Image.new("RGBA", (S, S), color + (0,))
    a = m.point(lambda v: int(v * alpha))
    sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(sh, (dx, dy))
    return out

MOON_SHAPE = f'<path d="{MOON}" fill="#000"/>'
MOON_BODY = f"""
  <path d="{MOON}" fill="#E9A84A" transform="translate(0,16)"/>
  <path d="{MOON}" fill="url(#moon)" stroke="#FFFFFF" stroke-opacity="0.8" stroke-width="6"/>
  <path d="M 520 185 C 340 200, 210 360, 215 540 C 230 420, 330 280, 470 230 Z" fill="url(#moonshine)"/>
  <!-- Amma's sleeping eye, lashes, cheek, smile -->
  <path d="M 392 392 C 410 410, 438 410, 452 392" fill="none" stroke="#7A4B2A" stroke-width="9" stroke-linecap="round"/>
  <path d="M 398 404 l -8 12 M 414 410 l -3 14 M 432 410 l 2 14" stroke="#7A4B2A" stroke-width="6" stroke-linecap="round"/>
  <ellipse cx="410" cy="465" rx="34" ry="20" fill="#FF8FA8" opacity="0.55"/>
  <!-- tiny flower in her hair -->
  <g transform="translate(330,250)">
    <circle cx="0" cy="-20" r="17" fill="#FF8FB1"/><circle cx="19" cy="-6" r="17" fill="#FF8FB1"/><circle cx="12" cy="16" r="17" fill="#FF8FB1"/>
    <circle cx="-12" cy="16" r="17" fill="#FF8FB1"/><circle cx="-19" cy="-6" r="17" fill="#FF8FB1"/><circle cx="0" cy="0" r="11" fill="#FFE08A"/>
  </g>"""

BABY = """
  <!-- blanket -->
  <path d="M 470 690 C 470 610, 560 590, 640 615 C 720 640, 760 700, 730 760 C 700 815, 560 820, 505 785 C 480 768, 470 730, 470 690 Z" fill="#E66A95" transform="translate(0,12)"/>
  <path d="M 470 690 C 470 610, 560 590, 640 615 C 720 640, 760 700, 730 760 C 700 815, 560 820, 505 785 C 480 768, 470 730, 470 690 Z" fill="url(#blanket)" stroke="#FFFFFF" stroke-opacity="0.85" stroke-width="5"/>
  <path d="M 520 650 C 580 625, 660 640, 700 680" fill="none" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="7" stroke-linecap="round"/>
  <circle cx="610" cy="740" r="9" fill="#FFFFFF" opacity="0.8"/><circle cx="660" cy="725" r="7" fill="#FFFFFF" opacity="0.8"/><circle cx="560" cy="755" r="7" fill="#FFFFFF" opacity="0.8"/>
  <!-- head -->
  <circle cx="545" cy="625" r="78" fill="#EDB38D" transform="translate(0,8)"/>
  <circle cx="545" cy="625" r="78" fill="url(#skin)" stroke="#FFFFFF" stroke-opacity="0.85" stroke-width="5"/>
  <path d="M 530 552 C 545 530, 575 540, 565 560 C 558 548, 545 548, 538 560" fill="#6B3E22"/>
  <path d="M 505 625 C 515 637, 530 637, 540 625" fill="none" stroke="#6B3E22" stroke-width="7" stroke-linecap="round"/>
  <path d="M 560 625 C 570 637, 585 637, 595 625" fill="none" stroke="#6B3E22" stroke-width="7" stroke-linecap="round"/>
  <ellipse cx="505" cy="657" rx="17" ry="11" fill="#FF8FA8" opacity="0.6"/><ellipse cx="598" cy="657" rx="17" ry="11" fill="#FF8FA8" opacity="0.6"/>
  <path d="M 540 667 C 547 673, 555 673, 561 667" fill="none" stroke="#C2635F" stroke-width="6" stroke-linecap="round"/>
  <ellipse cx="520" cy="590" rx="22" ry="12" fill="#FFFFFF" opacity="0.6" transform="rotate(-25 520 590)"/>"""

ARM = ('<path d="M 330 600 L 400 640 C 395 720, 470 790, 570 800 C 620 805, 680 800, 690 835 C 700 870, 660 900, 610 905 C 520 915, 420 880, 330 800 Z" fill="url(#moon)"/>'
       '<path d="M 400 640 C 395 720, 470 790, 570 800 C 620 805, 680 800, 690 835 C 700 870, 660 900, 610 905" fill="none" stroke="#FFFFFF" stroke-opacity="0.8" stroke-width="6" stroke-linecap="round"/>')

EXTRAS = """
  <g transform="translate(760,250)">
    <path d="M 0 -62 C 8 -12, 12 -8, 62 0 C 12 8, 8 12, 0 62 C -8 12, -12 8, -62 0 C -12 -8, -8 -12, 0 -62 Z" fill="#FFE08A" stroke="#FFFFFF" stroke-width="5"/>
  </g>
  <g transform="translate(700,395) scale(1.25)">
    <path d="M 0 22 C -40 -5, -32 -40, -10 -38 C 0 -37, 0 -28, 0 -24 C 0 -28, 0 -37, 10 -38 C 32 -40, 40 -5, 0 22 Z" fill="url(#heart)" stroke="#FFFFFF" stroke-width="4"/>
    <ellipse cx="-12" cy="-24" rx="8" ry="5" fill="#FFFFFF" opacity="0.7" transform="rotate(-30 -12 -24)"/>
  </g>
  <circle cx="850" cy="420" r="10" fill="#FFFFFF" opacity="0.9"/><circle cx="660" cy="190" r="8" fill="#FFFFFF" opacity="0.9"/>"""

def art():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.alpha_composite(shadow(svg(MOON_SHAPE), 10, 34, 26))
    img.alpha_composite(png(svg(MOON_BODY)))
    img.alpha_composite(shadow(svg('<circle cx="600" cy="700" r="130" fill="#000"/>'), 0, 18, 18, alpha=0.3))
    img.alpha_composite(png(svg(BABY)))
    img.alpha_composite(png(svg(ARM)))
    img.alpha_composite(png(svg(EXTRAS)))
    return img

def main():
    a = art()
    bg = png(svg("", bg=True))
    full = bg.copy()
    full.alpha_composite(a)
    full.convert("RGB").save(os.path.join(ROOT, "assets", "icon.png"))
    bg.convert("RGB").save(os.path.join(ROOT, "assets", "icon_bg.png"))
    # adaptive foreground: keep the art inside the central safe zone (~66%)
    bbox = a.getbbox()
    crop = a.crop(bbox)
    k = 640 / max(crop.size)
    crop = crop.resize((int(crop.width * k), int(crop.height * k)), Image.LANCZOS)
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fg.alpha_composite(crop, ((S - crop.width) // 2, (S - crop.height) // 2))
    fg.save(os.path.join(ROOT, "assets", "icon_fg.png"))
    print("icon done", bbox)

if __name__ == "__main__":
    main()
