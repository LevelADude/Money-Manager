"""Erzeugt alle App-Symbole aus design/logo/portemonnaie-gemini.jpg.

Aufruf (Projektwurzel):  py tool/make_icons.py
Danach fuer Android/Windows:  flutter pub run flutter_launcher_icons
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "design/logo/portemonnaie-gemini.jpg"
BG_TOP, BG_BOTTOM = (0xF8, 0xFB, 0xF9), (0xD5, 0xE2, 0xDA)  # Salbei-Palette


def cut_out(src):
    """Weissen Hintergrund entfernen (Flutung von den Ecken), eng zuschneiden."""
    rgb = Image.open(src).convert("RGB")
    near_white = (np.asarray(rgb).min(axis=2) > 236).astype(np.uint8) * 255
    m = Image.fromarray(near_white).copy()
    w, h = m.size
    for xy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(m, xy, 128)
    alpha = Image.fromarray(((np.asarray(m) != 128) * 255).astype(np.uint8), "L")
    # 2 px abtragen gegen weissen Saum, Kante leicht weichzeichnen.
    alpha = alpha.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out.crop(alpha.getbbox())


def fit(logo, size, scale):
    """Logo zentriert auf transparente Flaeche, laengste Seite = size*scale."""
    k = size * scale / max(logo.size)
    small = logo.resize((round(logo.width * k), round(logo.height * k)), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((size - small.width) // 2, (size - small.height) // 2))
    return canvas


def background(size):
    t = np.linspace(0, 1, size)[:, None, None]
    col = np.array(BG_TOP) * (1 - t) + np.array(BG_BOTTOM) * t
    arr = np.broadcast_to(col, (size, size, 3)).astype(np.uint8)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def on_background(logo, size, scale):
    bg = background(size)
    bg.alpha_composite(fit(logo, size, scale))
    return bg


logo = cut_out(SRC)
# Quellen fuer flutter_launcher_icons / MSIX
on_background(logo, 1024, 0.68).save("assets/icon/app_icon.png")
fit(logo, 1024, 0.52).save("assets/icon/app_icon_foreground.png")  # Android-Schutzzone
fit(logo, 1024, 0.94).save("assets/icon/app_icon_transparent.png")  # Windows, In-App
fit(logo, 256, 1.0).save("assets/icon/logo.png")  # Logo in der App (Login)
# Web / PWA
for s in (192, 512):
    fit(logo, s, 0.94).save(f"web/icons/Icon-{s}.png")
    on_background(logo, s, 0.60).save(f"web/icons/Icon-maskable-{s}.png")
on_background(logo, 180, 0.72).convert("RGB").save("web/icons/apple-touch-icon.png")
fit(logo, 48, 1.0).save("web/favicon.png")
print("ok", logo.size)
