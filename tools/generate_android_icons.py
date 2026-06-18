"""
Generate all Android icon assets for Glimpse from source artwork.

Inputs (relative to project root):
    assets/glimpse.png   -> RGBA app icon source (will be cropped to bbox)
    assets/mono.svg      -> monochrome notification icon source

Outputs (relative to project root):
    generated_icons/res/...   -> a self-contained res/ folder ready to drop
                                 into android/app/src/main/

The script does not modify the source pixels other than:
    - cropping the launcher PNG to its non-transparent bounding box
    - resizing (high-quality LANCZOS) to target densities
No background removal or recoloring. Launcher artwork is scaled with enough
transparent margin to sit naturally beside other Android adaptive icons.
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

# On Windows, cairosvg/cairocffi need the cairo C library on the DLL search
# path. We bundle a copy under tools/cairo/ next to this script.
_CAIRO_DIR = Path(__file__).resolve().parent / "cairo"
if sys.platform == "win32" and _CAIRO_DIR.is_dir():
    os.add_dll_directory(str(_CAIRO_DIR))
    os.environ["PATH"] = str(_CAIRO_DIR) + os.pathsep + os.environ.get("PATH", "")

import cairosvg
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets"
OUT_RES = PROJECT_ROOT / "generated_icons" / "res"

GLIMPSE_PNG = ASSETS_DIR / "glimpse.png"
MONO_SVG = ASSETS_DIR / "mono.svg"

LAUNCHER_BG_HEX = "#F5F4F0"

# Launcher artwork scale. The source mascot is tall with a top ring and lower
# tail, so a 72% max-dimension scale reads oversized in Android launchers.
LAUNCHER_ARTWORK_SCALE = 0.60

# Android density buckets for launcher icons (mipmap-*).
# Legacy launcher bitmap size is 48dp. Adaptive foreground/background layers
# are 108dp and must not share the smaller legacy dimensions.
LAUNCHER_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

ADAPTIVE_LAYER_DENSITIES = {
    density: int(round(size * 108 / 48))
    for density, size in LAUNCHER_DENSITIES.items()
}

NOTIFICATION_DENSITIES = {
    "mdpi": 24,
    "hdpi": 36,
    "xhdpi": 48,
    "xxhdpi": 72,
    "xxxhdpi": 96,
}

PLAY_STORE_SIZE = 512

# Splash source for flutter_native_splash. Android 12+ shows the splash icon
# inside a circular mask (safe zone is the inner 66% of the canvas), so we
# render the character well inside that zone to guarantee nothing is clipped.
SPLASH_CANVAS = 1152
SPLASH_SCALE = 0.55  # character occupies 55% -> fits inside 66% safe zone
SPLASH_OUT = ASSETS_DIR / "splash_icon.png"


def hex_to_rgba(hex_color: str) -> tuple[int, int, int, int]:
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def load_cropped_glimpse() -> Image.Image:
    """Open glimpse.png as RGBA and crop to its non-transparent bbox."""
    img = Image.open(GLIMPSE_PNG).convert("RGBA")
    bbox = img.getbbox()
    if bbox is None:
        raise RuntimeError("glimpse.png appears to be fully transparent")
    cropped = img.crop(bbox)
    print(
        f"  glimpse.png: original {img.size}, cropped to bbox {bbox} -> "
        f"{cropped.size}"
    )
    return cropped


def fit_centered(
    src: Image.Image, canvas_size: int, scale: float
) -> Image.Image:
    """Return a transparent canvas with src scaled to `scale` of the canvas
    and centered. Aspect ratio of src is preserved."""
    target = int(round(canvas_size * scale))
    w, h = src.size
    if w >= h:
        new_w = target
        new_h = max(1, int(round(h * (target / w))))
    else:
        new_h = target
        new_w = max(1, int(round(w * (target / h))))
    resized = src.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset = ((canvas_size - new_w) // 2, (canvas_size - new_h) // 2)
    canvas.paste(resized, offset, resized)
    return canvas


def make_solid_background(size: int, hex_color: str) -> Image.Image:
    return Image.new("RGBA", (size, size), hex_to_rgba(hex_color))


def composite(fg: Image.Image, bg: Image.Image) -> Image.Image:
    out = bg.copy()
    out.alpha_composite(fg)
    return out


def write_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def generate_launcher_icons(glimpse: Image.Image) -> None:
    print("\n[1/5] Generating mipmap launcher icons...")
    for density, size in LAUNCHER_DENSITIES.items():
        mipmap_dir = OUT_RES / f"mipmap-{density}"
        adaptive_size = ADAPTIVE_LAYER_DENSITIES[density]

        foreground = fit_centered(
            glimpse,
            adaptive_size,
            LAUNCHER_ARTWORK_SCALE,
        )
        background = make_solid_background(size, LAUNCHER_BG_HEX)
        legacy_foreground = fit_centered(
            glimpse,
            size,
            LAUNCHER_ARTWORK_SCALE,
        )
        composed = composite(legacy_foreground, background)

        write_png(foreground, mipmap_dir / "ic_launcher_foreground.png")
        write_png(background, mipmap_dir / "ic_launcher_background.png")
        write_png(composed, mipmap_dir / "ic_launcher.png")
        write_png(composed, mipmap_dir / "ic_launcher_round.png")
        print(
            f"  mipmap-{density:<8} legacy {size:>3}px, "
            f"adaptive {adaptive_size:>3}px -> 4 files"
        )


def generate_play_store_icon(glimpse: Image.Image) -> None:
    print("\n[2/5] Generating Play Store 512x512 icon...")
    foreground = fit_centered(
        glimpse,
        PLAY_STORE_SIZE,
        LAUNCHER_ARTWORK_SCALE,
    )
    background = make_solid_background(PLAY_STORE_SIZE, LAUNCHER_BG_HEX)
    composed = composite(foreground, background)
    out_path = OUT_RES.parent / "play_store_icon_512x512.png"
    write_png(composed, out_path)
    print(f"  -> {out_path.relative_to(PROJECT_ROOT)}")


def generate_splash_source(glimpse: Image.Image) -> None:
    """Render the splash source PNG for flutter_native_splash. Padded so the
    character fits comfortably inside Android 12's circular safe zone."""
    print("\n[3/5] Generating splash source for flutter_native_splash...")
    splash = fit_centered(glimpse, SPLASH_CANVAS, SPLASH_SCALE)
    write_png(splash, SPLASH_OUT)
    print(
        f"  -> {SPLASH_OUT.relative_to(PROJECT_ROOT)} "
        f"({SPLASH_CANVAS}x{SPLASH_CANVAS}, character at "
        f"{int(SPLASH_SCALE * 100)}% of canvas)"
    )


def generate_notification_icons() -> None:
    print("\n[4/5] Generating drawable notification icons...")
    svg_bytes = MONO_SVG.read_bytes()
    for density, size in NOTIFICATION_DENSITIES.items():
        drawable_dir = OUT_RES / f"drawable-{density}"
        drawable_dir.mkdir(parents=True, exist_ok=True)
        out_png = drawable_dir / "ic_notification.png"
        cairosvg.svg2png(
            bytestring=svg_bytes,
            write_to=str(out_png),
            output_width=size,
            output_height=size,
        )
        print(f"  drawable-{density:<8} {size:>3}px -> ic_notification.png")

    # Keep the source SVG accessible for manual import via Android Studio's
    # Vector Asset Studio. It must NOT live under res/drawable/ because the
    # AGP resource merger only accepts .xml or .png there.
    svg_out_dir = OUT_RES.parent / "vector-source"
    svg_out_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(MONO_SVG, svg_out_dir / "ic_notification_vector.svg")
    print("  vector-source/ic_notification_vector.svg (copy of mono.svg)")


ADAPTIVE_ICON_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

LAUNCHER_BG_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#F5F4F0</color>
</resources>
"""


def generate_xml_resources() -> None:
    print("\n[5/5] Generating XML resources...")
    anydpi = OUT_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ADAPTIVE_ICON_XML, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(
        ADAPTIVE_ICON_XML, encoding="utf-8"
    )
    print("  mipmap-anydpi-v26/ic_launcher.xml")
    print("  mipmap-anydpi-v26/ic_launcher_round.xml")

    values = OUT_RES / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        LAUNCHER_BG_XML, encoding="utf-8"
    )
    print("  values/ic_launcher_background.xml")


def main() -> None:
    print(f"Project root : {PROJECT_ROOT}")
    print(f"Output res/  : {OUT_RES.relative_to(PROJECT_ROOT)}")
    OUT_RES.mkdir(parents=True, exist_ok=True)

    glimpse = load_cropped_glimpse()
    generate_launcher_icons(glimpse)
    generate_play_store_icon(glimpse)
    generate_splash_source(glimpse)
    generate_notification_icons()
    generate_xml_resources()

    print("\nDone. Drop the contents of generated_icons/res/ into")
    print("android/app/src/main/res/ to install the new icons.")
    print("Then run `dart run flutter_native_splash:create` to refresh the")
    print("splash assets from assets/splash_icon.png.")


if __name__ == "__main__":
    main()
