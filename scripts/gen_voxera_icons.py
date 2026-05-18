#!/usr/bin/env python3
"""Generate Voxera launcher icons (voxera_brand) and About-tab logo (voxera_about_source)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "luanti" / "textures" / "base" / "pack"
SRC_LEGACY = PACK / "微信图片_20260517231146_146_1.png"
BRAND = PACK / "voxera_brand.png"
# About page only — not used for launcher / startIcon.
ABOUT_SOURCE = PACK / "voxera_about_source.png"
# Deployed to device for About tab (unchanged bytes = true transparency).
ABOUT_OUTPUT = PACK / "voxera_about_source.png"

# Launcher / layered icon only (change when user asks to resize 软件图标)
APP_ICON_SIZE = 1024
APP_LOGO_SCALE = 0.68

# About page in-game only (change when user asks to resize 关于图标)
# Match other menu textures (logo.png is 256²); Irrlicht loads reliably at this size.
ABOUT_SIZE = 256
ABOUT_LOGO_SCALE = 0.88

MEDIA_DIRS = [
    ROOT / "AppScope" / "resources" / "base" / "media",
    ROOT / "entry" / "src" / "main" / "resources" / "base" / "media",
]
RAWFILE_ABOUT = (
    ROOT / "entry" / "src" / "main" / "resources" / "rawfile" / "textures" / "base" / "pack"
)


def load_brand() -> Image.Image:
    if BRAND.is_file():
        return Image.open(BRAND).convert("RGBA")
    if SRC_LEGACY.is_file():
        img = Image.open(SRC_LEGACY).convert("RGBA")
        img.save(BRAND)
        return img
    raise SystemExit(f"Missing brand source: {BRAND} or {SRC_LEGACY}")


def load_about_source() -> Image.Image:
    if ABOUT_SOURCE.is_file():
        return Image.open(ABOUT_SOURCE).convert("RGBA")
    raise SystemExit(f"Missing about source: {ABOUT_SOURCE}")


def fit_center(canvas: Image.Image, logo: Image.Image, scale: float) -> None:
    side = int(min(canvas.size) * scale)
    thumb = logo.copy()
    thumb.thumbnail((side, side), Image.Resampling.LANCZOS)
    x = (canvas.size[0] - thumb.width) // 2
    y = (canvas.size[1] - thumb.height) // 2
    if canvas.mode == "RGBA":
        canvas.paste(thumb, (x, y), thumb)
    else:
        canvas.paste(thumb, (x, y))


def make_app_foreground(logo: Image.Image) -> Image.Image:
    fg = Image.new("RGBA", (APP_ICON_SIZE, APP_ICON_SIZE), (0, 0, 0, 0))
    fit_center(fg, logo, APP_LOGO_SCALE)
    return fg


def make_app_background() -> Image.Image:
    return Image.new("RGB", (APP_ICON_SIZE, APP_ICON_SIZE), (255, 255, 255))


def make_flat_icon(logo: Image.Image) -> Image.Image:
    bg = make_app_background().convert("RGBA")
    fg = make_app_foreground(logo)
    out = bg.copy()
    out.alpha_composite(fg)
    return out


def write_about_png(logo: Image.Image) -> None:
    """Copy transparent source verbatim — resizing was baking in a white matte."""
    logo = logo.convert("RGBA")
    logo.save(ABOUT_OUTPUT, "PNG")
    print(f"wrote {ABOUT_OUTPUT}")
    RAWFILE_ABOUT.mkdir(parents=True, exist_ok=True)
    logo.save(RAWFILE_ABOUT / ABOUT_OUTPUT.name, "PNG")
    print(f"wrote {RAWFILE_ABOUT / ABOUT_OUTPUT.name}")


def main() -> None:
    import sys

    about_only = "--about-only" in sys.argv

    if about_only:
        write_about_png(load_about_source())
        return

    logo = load_brand()
    fg = make_app_foreground(logo)
    bg = make_app_background()
    flat = make_flat_icon(logo)
    write_about_png(load_about_source())

    for media in MEDIA_DIRS:
        media.mkdir(parents=True, exist_ok=True)
        bg.save(media / "background.png", "PNG")
        fg.save(media / "foreground.png", "PNG")
        flat.save(media / "startIcon.png", "PNG")
        print(f"updated {media}")

    if SRC_LEGACY.is_file() and BRAND.is_file():
        SRC_LEGACY.unlink()
        print(f"removed legacy {SRC_LEGACY.name}")


if __name__ == "__main__":
    main()
