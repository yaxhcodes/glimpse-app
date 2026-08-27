"""
Generate platform icon assets for Glimpse from source artwork.

Inputs (relative to project root):
    assets/glimpse.png             -> RGBA app icon source
    assets/glimpse_monochrome.png  -> transparent Material You icon source
    assets/mono.svg                -> monochrome notification icon source

Outputs (relative to project root):
    generated_icons/res/...   -> a self-contained Android res/ folder ready to drop
                                 into android/app/src/main/
    ios/Runner/.../AppIcon    -> iOS app icon files updated in place

The script does not modify the source pixels other than:
    - cropping the launcher PNG to its visible alpha bounding box
    - resizing (high-quality LANCZOS) to target densities
No background removal or recoloring. Launcher artwork is scaled with enough
transparent margin to sit naturally beside other Android adaptive icons.
The themed launcher icon uses a dedicated transparent monochrome source whose
alpha channel defines the exact eye, beak, and ribbon cutouts for dynamic tint.
"""

from __future__ import annotations

import json
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

from PIL import Image, ImageDraw, ImageFont

try:
    import cairosvg
except ModuleNotFoundError:
    cairosvg = None

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets"
OUT_RES = PROJECT_ROOT / "generated_icons" / "res"
IOS_APPICONSET = (
    PROJECT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
)

GLIMPSE_PNG = ASSETS_DIR / "glimpse.png"
GLIMPSE_MONOCHROME_PNG = ASSETS_DIR / "glimpse_monochrome.png"
MONO_SVG = ASSETS_DIR / "mono.svg"

LAUNCHER_BG_HEX = "#F5F4F0"

# Launcher artwork scale. Android adaptive icons reserve a central safe zone;
# with visible-alpha cropping, 56% matches the production icon's optical size.
LAUNCHER_ARTWORK_SCALE = 0.56
THEMED_LAUNCHER_ARTWORK_SCALE = 0.58

# Transparent exports can contain 1-alpha edge debris far outside the visible
# artwork. Cropping to only perceptible alpha keeps the optical size correct.
ARTWORK_ALPHA_CROP_THRESHOLD = 1

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
SPLASH_SCALE = 0.64  # character occupies 64% -> fits inside 66% safe zone
SPLASH_OUT = ASSETS_DIR / "splash_icon.png"

BRANDING_SIZE = (800, 320)
BRANDING_TEXT = "SHINRIN YOKU"
BRANDING_OUT = ASSETS_DIR / "splash_branding.png"
BRANDING_DARK_OUT = ASSETS_DIR / "splash_branding_dark.png"


def hex_to_rgba(hex_color: str) -> tuple[int, int, int, int]:
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def load_cropped_glimpse() -> Image.Image:
    """Open glimpse.png as RGBA and crop to its visible alpha bbox."""
    img = Image.open(GLIMPSE_PNG).convert("RGBA")
    visible_alpha = img.getchannel("A").point(
        lambda alpha: 255 if alpha > ARTWORK_ALPHA_CROP_THRESHOLD else 0
    )
    bbox = visible_alpha.getbbox()
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
    print("\n[1/7] Generating mipmap launcher icons...")
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


def build_themed_launcher_mask() -> Image.Image:
    source = Image.open(GLIMPSE_MONOCHROME_PNG).convert("RGBA")
    alpha = source.getchannel("A")
    mask = Image.new("RGBA", source.size, (255, 255, 255, 0))
    mask.putalpha(alpha)
    bbox = mask.getbbox()
    if bbox is None:
        raise RuntimeError("glimpse_monochrome.png appears to be fully transparent")
    cropped = mask.crop(bbox)
    print(
        f"  themed mask: source {mask.size}, cropped to bbox {bbox} -> "
        f"{cropped.size}"
    )
    return cropped


def generate_themed_launcher_icons(themed_mask: Image.Image) -> None:
    print("\n[2/7] Generating Material You themed launcher masks...")
    for density, size in ADAPTIVE_LAYER_DENSITIES.items():
        drawable_dir = OUT_RES / f"drawable-{density}"
        themed = fit_centered(themed_mask, size, THEMED_LAUNCHER_ARTWORK_SCALE)
        themed.putalpha(themed.getchannel("A"))
        write_png(themed, drawable_dir / "ic_launcher_monochrome.png")
        print(f"  drawable-{density:<8} {size:>3}px -> ic_launcher_monochrome.png")


def generate_play_store_icon(glimpse: Image.Image) -> None:
    print("\n[3/7] Generating Play Store 512x512 icon...")
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


def generate_ios_icons(glimpse: Image.Image) -> None:
    print("\n[4/7] Generating iOS AppIcon.appiconset icons...")
    contents_path = IOS_APPICONSET / "Contents.json"
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    generated = 0

    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        point_size = float(entry["size"].split("x", maxsplit=1)[0])
        scale = int(entry["scale"].removesuffix("x"))
        pixel_size = round(point_size * scale)

        foreground = fit_centered(
            glimpse,
            pixel_size,
            LAUNCHER_ARTWORK_SCALE,
        )
        background = make_solid_background(pixel_size, LAUNCHER_BG_HEX)
        composed = composite(foreground, background).convert("RGB")
        write_png(composed, IOS_APPICONSET / filename)
        generated += 1

    print(f"  -> {generated} iOS icon files")


def generate_splash_source(glimpse: Image.Image) -> None:
    """Render the splash source PNG for flutter_native_splash. Padded so the
    character fits comfortably inside Android 12's circular safe zone."""
    print("\n[5/8] Generating splash source for flutter_native_splash...")
    splash = fit_centered(glimpse, SPLASH_CANVAS, SPLASH_SCALE)
    write_png(splash, SPLASH_OUT)
    print(
        f"  -> {SPLASH_OUT.relative_to(PROJECT_ROOT)} "
        f"({SPLASH_CANVAS}x{SPLASH_CANVAS}, character at "
        f"{int(SPLASH_SCALE * 100)}% of canvas)"
    )


def load_branding_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    font_paths = [
        Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts" / "segoeui.ttf",
        Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts" / "arial.ttf",
    ]
    for path in font_paths:
        if path.is_file():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def tracked_text_size(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
    tracking: int,
) -> tuple[int, int]:
    width = 0
    height = 0
    for index, char in enumerate(text):
        bbox = draw.textbbox((0, 0), char, font=font)
        width += bbox[2] - bbox[0]
        if index < len(text) - 1:
            width += tracking
        height = max(height, bbox[3] - bbox[1])
    return width, height


def draw_tracked_text(
    draw: ImageDraw.ImageDraw,
    position: tuple[float, float],
    text: str,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
    fill: tuple[int, int, int, int],
    tracking: int,
) -> None:
    x, y = position
    for index, char in enumerate(text):
        draw.text((x, y), char, font=font, fill=fill)
        bbox = draw.textbbox((0, 0), char, font=font)
        x += bbox[2] - bbox[0]
        if index < len(text) - 1:
            x += tracking


def make_branding(fill: tuple[int, int, int, int]) -> Image.Image:
    image = Image.new("RGBA", BRANDING_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    font = load_branding_font(size=31)
    tracking = 6
    text_width, text_height = tracked_text_size(draw, BRANDING_TEXT, font, tracking)
    position = (
        (BRANDING_SIZE[0] - text_width) / 2,
        (BRANDING_SIZE[1] - text_height) / 2,
    )
    draw_tracked_text(draw, position, BRANDING_TEXT, font, fill, tracking)
    return image


def generate_splash_branding() -> None:
    print("\n[6/8] Generating subtle splash branding...")
    write_png(make_branding((96, 103, 78, 130)), BRANDING_OUT)
    write_png(make_branding((214, 218, 193, 130)), BRANDING_DARK_OUT)
    print(f"  -> {BRANDING_OUT.relative_to(PROJECT_ROOT)}")
    print(f"  -> {BRANDING_DARK_OUT.relative_to(PROJECT_ROOT)}")


def generate_notification_icons() -> None:
    print("\n[7/8] Generating drawable notification icons...")
    if cairosvg is None:
        print("  skipped: cairosvg is not installed and mono.svg is unchanged")
        return

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
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
"""

LAUNCHER_BG_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#F5F4F0</color>
</resources>
"""


def generate_xml_resources() -> None:
    print("\n[8/8] Generating XML resources...")
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
    themed_mask = build_themed_launcher_mask()
    generate_launcher_icons(glimpse)
    generate_themed_launcher_icons(themed_mask)
    generate_play_store_icon(glimpse)
    generate_ios_icons(glimpse)
    generate_splash_source(glimpse)
    generate_splash_branding()
    generate_notification_icons()
    generate_xml_resources()

    print("\nDone. Drop the contents of generated_icons/res/ into")
    print("android/app/src/main/res/ to install the new icons.")
    print("Then run `dart run flutter_native_splash:create` to refresh the")
    print("splash assets from assets/splash_icon.png and splash_branding*.png.")


if __name__ == "__main__":
    main()
