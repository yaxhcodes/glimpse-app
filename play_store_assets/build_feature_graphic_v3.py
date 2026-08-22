from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "final" / "feature_graphic-v3.png"
MASCOT = ROOT.parent / "assets" / "glimpse.png"
INSTRUMENT_SANS = ROOT / "fonts" / "InstrumentSans.ttf"
NEWSREADER = ROOT / "fonts" / "Newsreader.ttf"

SIZE = (1024, 500)
BACKGROUND_TOP = (18, 20, 18)
BACKGROUND_BOTTOM = (29, 31, 28)
SURFACE = (34, 37, 33)
SURFACE_EDGE = (66, 70, 63)
TEXT = (235, 234, 226)
TEXT_MUTED = (169, 170, 160)
SAGE = (174, 181, 165)
TAUPE = (198, 185, 166)
ICON_INK = (208, 209, 198)
TOKEN_FILLS = [
    (43, 47, 42),
    (48, 47, 43),
    (42, 46, 43),
    (47, 45, 42),
    (42, 45, 42),
]


def variable_font(path: Path, size: int, axes: list[float]) -> ImageFont.FreeTypeFont:
    text_font = ImageFont.truetype(str(path), size=size)
    text_font.set_variation_by_axes(axes)
    return text_font


def sans(size: int, weight: int = 400, width: int = 100) -> ImageFont.FreeTypeFont:
    return variable_font(INSTRUMENT_SANS, size, [width, weight])


def serif(size: int, weight: int = 520, optical_size: int = 54) -> ImageFont.FreeTypeFont:
    return variable_font(NEWSREADER, size, [weight, optical_size])


def background() -> Image.Image:
    canvas = Image.new("RGB", SIZE)
    draw = ImageDraw.Draw(canvas)
    for y in range(SIZE[1]):
        t = y / (SIZE[1] - 1)
        eased = t * t * (3 - 2 * t)
        color = tuple(
            round(BACKGROUND_TOP[channel] * (1 - eased) + BACKGROUND_BOTTOM[channel] * eased)
            for channel in range(3)
        )
        draw.line((0, y, SIZE[0], y), fill=color)
    return canvas.convert("RGBA")


def radial_glow(canvas: Image.Image, center: tuple[int, int], radius: int) -> None:
    left = max(0, center[0] - radius)
    top = max(0, center[1] - radius)
    right = min(SIZE[0], center[0] + radius)
    bottom = min(SIZE[1], center[1] + radius)
    mask = Image.new("L", (right - left, bottom - top), 0)
    pixels = mask.load()
    for y in range(mask.height):
        for x in range(mask.width):
            distance = math.dist((left + x, top + y), center)
            if distance < radius:
                strength = 1 - distance / radius
                pixels[x, y] = round(26 * strength * strength)
    glow = Image.new("RGBA", mask.size, (*TAUPE, 0))
    glow.putalpha(mask.filter(ImageFilter.GaussianBlur(12)))
    canvas.alpha_composite(glow, (left, top))


def draw_music(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    color = ICON_INK
    draw.line((cx - 3, cy - 12, cx + 11, cy - 16), fill=color, width=3)
    draw.line((cx - 3, cy - 12, cx - 3, cy + 10), fill=color, width=3)
    draw.line((cx + 11, cy - 16, cx + 11, cy + 6), fill=color, width=3)
    draw.ellipse((cx - 11, cy + 5, cx - 1, cy + 14), fill=color)
    draw.ellipse((cx + 3, cy + 1, cx + 13, cy + 10), fill=color)


def draw_movie(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    color = ICON_INK
    draw.rounded_rectangle((cx - 15, cy - 7, cx + 15, cy + 14), radius=4, outline=color, width=3)
    draw.polygon([(cx - 16, cy - 13), (cx + 14, cy - 18), (cx + 16, cy - 11), (cx - 14, cy - 6)], outline=color)
    for offset in (-8, 3):
        draw.line((cx + offset, cy - 14, cx + offset + 5, cy - 8), fill=color, width=2)


def draw_book(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    color = ICON_INK
    draw.line((cx, cy - 12, cx, cy + 14), fill=color, width=2)
    draw.line((cx - 16, cy - 14, cx - 3, cy - 11, cx, cy - 7), fill=color, width=3)
    draw.line((cx + 16, cy - 14, cx + 3, cy - 11, cx, cy - 7), fill=color, width=3)
    draw.line((cx - 16, cy - 14, cx - 16, cy + 10, cx - 3, cy + 12, cx, cy + 15), fill=color, width=3)
    draw.line((cx + 16, cy - 14, cx + 16, cy + 10, cx + 3, cy + 12, cx, cy + 15), fill=color, width=3)


def draw_place(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    color = ICON_INK
    draw.ellipse((cx - 12, cy - 17, cx + 12, cy + 7), outline=color, width=3)
    draw.polygon([(cx - 9, cy + 2), (cx, cy + 17), (cx + 9, cy + 2)], outline=color)
    draw.ellipse((cx - 4, cy - 9, cx + 4, cy - 1), fill=color)


def draw_quote(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    color = ICON_INK
    for offset in (-10, 7):
        draw.ellipse((cx + offset - 5, cy - 9, cx + offset + 5, cy + 1), fill=color)
        draw.polygon([(cx + offset - 4, cy - 1), (cx + offset + 4, cy - 1), (cx + offset - 4, cy + 11)], fill=color)


def draw_icon_row(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    positions = [586, 672, 758, 844, 930]
    labels = ["Music", "Movies", "Books", "Places", "Quotes"]
    icon_drawers = [draw_music, draw_movie, draw_book, draw_place, draw_quote]
    for index, (x, label, icon_drawer) in enumerate(zip(positions, labels, icon_drawers)):
        draw.ellipse((x - 29, 190, x + 29, 248), fill=TOKEN_FILLS[index], outline=SURFACE_EDGE, width=1)
        icon_drawer(draw, x, 219)
        label_font = sans(13, weight=520)
        bounds = draw.textbbox((0, 0), label, font=label_font)
        draw.text((x - (bounds[2] - bounds[0]) / 2, 263), label, font=label_font, fill=TEXT_MUTED)


def draw_library_surface(canvas: Image.Image) -> None:
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((524, 92, 990, 411), radius=45, fill=(0, 0, 0, 115))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(24)))

    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle((518, 82, 984, 401), radius=45, fill=(*SURFACE, 246), outline=(*SURFACE_EDGE, 150), width=2)
    draw.text((558, 116), "YOUR LIBRARY", font=sans(14, weight=650), fill=SAGE)
    draw.text((558, 143), "Music, movies, books, places and ideas", font=sans(16), fill=TEXT_MUTED)
    draw.line((558, 302, 944, 302), fill=(70, 73, 67), width=1)
    draw.text((558, 329), "Everything you save, understood and ready to return to.", font=sans(15), fill=TEXT_MUTED)
    canvas.alpha_composite(layer)
    draw_icon_row(canvas)


def paste_small_mascot(canvas: Image.Image) -> None:
    mascot = Image.open(MASCOT).convert("RGBA")
    bounds = mascot.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Mascot asset is empty")
    mascot = mascot.crop(bounds)
    mascot = ImageEnhance.Color(mascot).enhance(0.42)
    mascot = ImageEnhance.Contrast(mascot).enhance(0.92)
    mascot.thumbnail((63, 84), Image.Resampling.LANCZOS)
    x = 906
    y = 101

    shadow_alpha = mascot.getchannel("A").filter(ImageFilter.GaussianBlur(8))
    shadow = Image.new("RGBA", mascot.size, (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha.point(lambda value: round(value * 0.38)))
    canvas.alpha_composite(shadow, (x + 5, y + 8))
    canvas.alpha_composite(mascot, (x, y))


def add_grain(canvas: Image.Image) -> None:
    noise = Image.effect_noise(SIZE, 4).convert("L")
    noise = noise.point(lambda value: min(4, abs(value - 128) // 18))
    grain = Image.new("RGBA", SIZE, (255, 255, 255, 0))
    grain.putalpha(noise)
    canvas.alpha_composite(grain)


def build() -> Image.Image:
    canvas = background()
    radial_glow(canvas, (802, 247), 315)
    draw_library_surface(canvas)
    paste_small_mascot(canvas)

    draw = ImageDraw.Draw(canvas)
    draw.text((59, 118), "SAVE FROM ANYWHERE", font=sans(14, weight=650), fill=SAGE)
    draw.text((57, 154), "Keep what matters.", font=serif(47, weight=560, optical_size=55), fill=TEXT)
    draw.text((57, 207), "Find it again.", font=serif(47, weight=560, optical_size=55), fill=TAUPE)
    draw.text(
        (60, 287),
        "A calm home for the links, ideas and\nrecommendations you want to remember.",
        font=sans(20),
        fill=TEXT_MUTED,
        spacing=8,
    )
    add_grain(canvas)
    return canvas.convert("RGB")


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    build().save(OUTPUT, format="PNG", optimize=True)
    print(f"Rendered clean feature graphic to {OUTPUT}")


if __name__ == "__main__":
    main()
