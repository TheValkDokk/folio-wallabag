#!/usr/bin/env python3
"""Generates Folio's app icon: cream open book on deep green."""
import json
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPICON = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
ANDROID = os.path.join(ROOT, "android/app/src/main/res")
S = 1024
CREAM = (246, 242, 233)
GOLD = (199, 164, 107)


def gradient(size, top, bottom):
    img = Image.new("RGB", (1, size), top)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        px[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img.resize((size, size))


def glow(size, center, radius, color, alpha=90):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    for i in range(24, 0, -1):
        t = i / 24
        r = radius * t
        d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r],
                  fill=int(alpha * (1 - t) ** 2))
    mask = mask.filter(ImageFilter.GaussianBlur(size * 0.03))
    return Image.new("RGB", (size, size), color), mask


def draw():
    img = gradient(S, (36, 86, 76), (20, 52, 46)).convert("RGB")
    tint, mask = glow(S, (S * 0.5, S * 0.45), S * 0.55, (90, 160, 140), 70)
    img = Image.composite(tint, img, mask)

    # open book: two slightly tilted pages with a spine gap
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    left = [(S * 0.20, S * 0.36), (S * 0.485, S * 0.31),
            (S * 0.485, S * 0.72), (S * 0.20, S * 0.68)]
    right = [(S * 0.515, S * 0.31), (S * 0.80, S * 0.36),
             (S * 0.80, S * 0.68), (S * 0.515, S * 0.72)]

    # shadow
    shadow = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(shadow)
    sd.polygon([(x, y + S * 0.02) for x, y in left + right], fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.03))
    dark = Image.new("RGB", (S, S), (8, 22, 19))
    img = Image.composite(dark, img, shadow)

    d.polygon(left, fill=CREAM)
    d.polygon(right, fill=CREAM)
    # page lines
    for i in range(4):
        y = S * (0.43 + i * 0.065)
        d.line([(S * 0.245, y), (S * 0.45, y - S * 0.012)], fill=(206, 199, 186), width=5)
        d.line([(S * 0.55, y - S * 0.012), (S * 0.755, y)], fill=(206, 199, 186), width=5)
    # bookmark
    d.polygon([(S * 0.66, S * 0.33), (S * 0.72, S * 0.33),
               (S * 0.72, S * 0.52), (S * 0.69, S * 0.47),
               (S * 0.66, S * 0.52)], fill=GOLD)

    img = Image.alpha_composite(img.convert("RGBA"), layer)
    return img.convert("RGB")


def main():
    master = draw()
    master.save(os.path.join(APPICON, "icon-1024.png"))
    with open(os.path.join(APPICON, "Contents.json")) as f:
        contents = json.load(f)
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name:
            continue
        px = int(round(float(entry["size"].split("x")[0]) *
                       int(entry["scale"].rstrip("x"))))
        master.resize((px, px), Image.LANCZOS).save(os.path.join(APPICON, name))

    for bucket, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                       "xxhdpi": 144, "xxxhdpi": 192}.items():
        master.resize((px, px), Image.LANCZOS).save(
            os.path.join(ANDROID, f"mipmap-{bucket}", "ic_launcher.png"))
    os.makedirs(os.path.join(ROOT, "assets"), exist_ok=True)
    master.save(os.path.join(ROOT, "assets", "icon-1024.png"))
    print("icon written")


if __name__ == "__main__":
    main()
