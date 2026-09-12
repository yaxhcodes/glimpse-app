"""Generate the approved mascot branding for all app flavors.

Run python tools/generate_mascot_assets.py from the repository root.
Shared vector and notification glyphs follow the approved monochrome alpha.
"""

import json
from io import BytesIO

from PIL import Image, ImageDraw

from generate_android_icons import (
    ADAPTIVE_ICON_XML,
    ADAPTIVE_LAYER_DENSITIES,
    LAUNCHER_DENSITIES,
    PROJECT_ROOT,
    composite,
    make_solid_background,
)


SOURCES = PROJECT_ROOT / "tools" / "icon_sources" / "mascot"
OUT_RES = PROJECT_ROOT / "android" / "app" / "src" / "main" / "res"
BACKGROUND = "#527A68"
PREVIEW_SIZE = (1254, 1254)
TILE_BOUNDS = (64, 64, 1190, 1190)


def write_png(image: Image.Image, path) -> None:
    """Replace a complete export instead of truncating a file readers may hold."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = BytesIO()
    image.save(data, format="PNG", optimize=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(data.getvalue())
    temporary.replace(path)


def load_tile(filename: str, *, require_alpha: bool = False) -> Image.Image:
    with Image.open(SOURCES / filename) as source:
        if source.size != PREVIEW_SIZE:
            raise ValueError(f"{filename}: update tile bounds for {source.size}")
        if require_alpha and (
            source.mode != "RGBA" or source.getchannel("A").getextrema() != (0, 255)
        ):
            raise ValueError(f"{filename}: expected transparent launcher mask")
        return source.convert("RGBA").crop(TILE_BOUNDS)


def centered_layer(tile: Image.Image, size: int, scale: float) -> Image.Image:
    artwork_size = round(size * scale)
    artwork = tile.resize((artwork_size, artwork_size), Image.Resampling.LANCZOS)
    layer = Image.new("RGBA", (size, size))
    offset = (size - artwork_size) // 2
    layer.alpha_composite(artwork, (offset, offset))
    return layer


def adaptive_layer(tile: Image.Image, size: int, scale: float = 1) -> Image.Image:
    # The normal 72dp launcher viewport sits inside the 108dp adaptive layer.
    return centered_layer(tile, size, 72 / 108 * scale)


def generate_screen_artwork() -> None:
    destination = PROJECT_ROOT / "assets" / "mascot"
    destination.mkdir(parents=True, exist_ok=True)
    for name in ("home", "collections", "interests", "search"):
        with Image.open(SOURCES / f"{name}.png") as source:
            if source.mode != "RGBA" or source.getchannel("A").getextrema() != (0, 255):
                raise ValueError(f"{name}: expected genuinely transparent artwork")
            artwork = source.resize((512, 512), Image.Resampling.LANCZOS)
            artwork.save(destination / f"{name}.webp", quality=92, method=6)

    with Image.open(SOURCES / "splash_start.png") as source:
        for density, size in LAUNCHER_DENSITIES.items():
            # A 288dp canvas with 58% artwork stays within the Android 12 mask.
            splash = centered_layer(source, size * 6, 0.58)
            write_png(splash, OUT_RES / f"drawable-{density}" / "splash.png")
            for qualifier in ("drawable", "drawable-night"):
                write_png(
                    splash,
                    OUT_RES / f"{qualifier}-{density}" / "android12splash.png",
                )


def main() -> None:
    color = load_tile("color.png")
    # Remove only the preview tile's outside corners, leaving Android to apply
    # the device's own launcher shape over the full adaptive background.
    tile_mask = Image.new("L", color.size)
    ImageDraw.Draw(tile_mask).rounded_rectangle(
        (0, 0, color.width - 1, color.height - 1),
        radius=round(color.width * 0.25),
        fill=255,
    )
    color.putalpha(tile_mask)
    monochrome = load_tile("monochrome.png", require_alpha=True)

    for density, legacy_size in LAUNCHER_DENSITIES.items():
        mipmap = OUT_RES / f"mipmap-{density}"
        layer_size = ADAPTIVE_LAYER_DENSITIES[density]
        write_png(adaptive_layer(color, layer_size), mipmap / "ic_launcher_foreground.png")
        write_png(
            adaptive_layer(monochrome, layer_size, scale=0.92),
            OUT_RES / f"drawable-{density}" / "ic_launcher_monochrome.png",
        )
        legacy = composite(color, make_solid_background(color.width, BACKGROUND))
        legacy = legacy.resize((legacy_size, legacy_size), Image.Resampling.LANCZOS)
        write_png(legacy, mipmap / "ic_launcher.png")
        round_mask = Image.new("L", color.size)
        ImageDraw.Draw(round_mask).ellipse((0, 0, color.width - 1, color.height - 1), fill=255)
        legacy.putalpha(round_mask.resize(legacy.size, Image.Resampling.LANCZOS))
        write_png(legacy, mipmap / "ic_launcher_round.png")

    anydpi = OUT_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    for filename in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (anydpi / filename).write_text(ADAPTIVE_ICON_XML, encoding="utf-8")
    (OUT_RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <!-- Shared mascot launcher background. -->\n'
        f'    <color name="ic_launcher_background">{BACKGROUND}</color>\n'
        '</resources>\n',
        encoding="utf-8",
    )
    generate_screen_artwork()
    # Source assets keep external icon/splash generators aligned with the app.
    source = Image.open(SOURCES / "home.png").convert("RGBA")
    write_png(source, PROJECT_ROOT / "assets" / "glimpse.png")
    splash_start = Image.open(SOURCES / "splash_start.png").convert("RGBA")
    write_png(centered_layer(splash_start, 1152, 0.58), PROJECT_ROOT / "assets" / "splash_icon.png")
    write_png(monochrome, PROJECT_ROOT / "assets" / "glimpse_monochrome.png")
    square = composite(color, make_solid_background(color.width, BACKGROUND)).convert("RGB")
    write_png(square.resize((512, 512), Image.Resampling.LANCZOS), PROJECT_ROOT / "assets" / "play_store_icon.png")
    ios = PROJECT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if ios.exists():
        for entry in json.loads((ios / "Contents.json").read_text())["images"]:
            size = round(float(entry["size"].split("x")[0]) * float(entry["scale"].rstrip("x")))
            write_png(square.resize((size, size), Image.Resampling.LANCZOS), ios / entry["filename"])
    launch = PROJECT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    if launch.exists():
        for entry in json.loads((launch / "Contents.json").read_text())["images"]:
            size = 288 * int(entry["scale"].rstrip("x"))
            write_png(centered_layer(splash_start, size, 0.58), launch / entry["filename"])
    from generate_mascot_mark import generate as generate_mark

    generate_mark()
    print(f"Generated shared launcher, splash, and screen artwork in {OUT_RES}")


if __name__ == "__main__":
    main()
