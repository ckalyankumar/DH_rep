"""Render the Siequi "S" monogram and rasterize it into all platform icon slots.

Design: Fraunces 500 "S", #F8F6F1, centered on solid #C9704F.
Usage: python scripts/generate_app_icons.py [path/to/Fraunces[SOFT,WONK,opsz,wght].ttf]
The font is only needed to re-render the master; if omitted the committed
assets/branding/app_icon_1024.png is reused.
"""

from __future__ import annotations

from pathlib import Path

import sys
from io import BytesIO

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "branding" / "app_icon_1024.png"
TERRACOTTA = (0xC9, 0x70, 0x4F)
CREAM = (0xF8, 0xF6, 0xF1)
CORNER_RADIUS = 0.224  # fraction of edge; matches the iOS squircle approximation

IOS = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MACOS = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
ANDROID = ROOT / "android" / "app" / "src" / "main" / "res"
WEB = ROOT / "web"
WINDOWS_ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

MACOS_SIZES = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def render_master(font_path: Path) -> Image.Image:
    """Full-bleed 1024px square: Fraunces wght 500 (opsz 144) "S", optically centered."""
    font = TTFont(font_path)
    static = instancer.instantiateVariableFont(
        font, {"wght": 500, "opsz": 144, "SOFT": 0, "WONK": 0}
    )
    buf = BytesIO()
    static.save(buf)
    buf.seek(0)
    pil_font = ImageFont.truetype(buf, 700)
    image = Image.new("RGB", (1024, 1024), TERRACOTTA)
    draw = ImageDraw.Draw(image)
    left, top, right, bottom = draw.textbbox((0, 0), "S", font=pil_font)
    x = (1024 - (right - left)) / 2 - left
    y = (1024 - (bottom - top)) / 2 - top
    draw.text((x, y), "S", font=pil_font, fill=CREAM)
    return image


def rounded(image: Image.Image) -> Image.Image:
    """RGBA copy with squircle-ish rounded corners, for slots that don't get an OS mask."""
    size = image.size[0]
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * CORNER_RADIUS), fill=255
    )
    out = image.convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.Resampling.LANCZOS))
    return out


def as_rgb(image: Image.Image) -> Image.Image:
    if image.mode == "RGB":
        return image
    canvas = Image.new("RGB", image.size, TERRACOTTA)
    if image.mode == "RGBA":
        canvas.paste(image, mask=image.split()[-1])
        return canvas
    return image.convert("RGB")


def resize(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.Resampling.LANCZOS)


def padded(image: Image.Image, size: int, inset: float) -> Image.Image:
    """Shrink the mark toward the center so maskable crops keep the S."""
    inner = max(1, int(round(size * (1.0 - 2 * inset))))
    mark = resize(image, inner)
    canvas = Image.new("RGB", (size, size), TERRACOTTA)
    offset = (size - inner) // 2
    canvas.paste(mark, (offset, offset))
    return canvas


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def main() -> None:
    if len(sys.argv) > 1:
        master = render_master(Path(sys.argv[1]))
        save_png(master, MASTER)
    else:
        master = as_rgb(Image.open(MASTER))
    if master.size != (1024, 1024):
        master = resize(master, 1024)
    soft = rounded(master)  # rounded-square variant

    # iOS: OS applies its own mask and rejects alpha -> full-bleed square.
    for name, size in IOS_SIZES.items():
        save_png(resize(master, size), IOS / name)

    for name, size in MACOS_SIZES.items():
        save_png(resize(soft, size), MACOS / name)

    for folder, size in ANDROID_SIZES.items():
        save_png(resize(soft, size), ANDROID / folder / "ic_launcher.png")

    save_png(resize(soft, 32), WEB / "favicon.png")
    save_png(resize(soft, 192), WEB / "icons" / "Icon-192.png")
    save_png(resize(soft, 512), WEB / "icons" / "Icon-512.png")
    save_png(padded(master, 192, 0.1), WEB / "icons" / "Icon-maskable-192.png")
    save_png(padded(master, 512, 0.1), WEB / "icons" / "Icon-maskable-512.png")

    WINDOWS_ICO.parent.mkdir(parents=True, exist_ok=True)
    ico_sizes = [(16, 16), (32, 32), (48, 48), (256, 256)]
    soft.save(WINDOWS_ICO, format="ICO", sizes=ico_sizes)

    print("Wrote platform icons from", MASTER)


if __name__ == "__main__":
    main()
