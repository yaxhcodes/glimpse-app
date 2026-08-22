from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "final" / "feature_graphic.png"
MASCOT = ROOT.parent / "assets" / "glimpse.png"

SIZE = (1024, 500)
FONT_REGULAR = Path(r"C:\Windows\Fonts\segoeui.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\segoeuib.ttf")
FONT_SERIF_BOLD = Path(r"C:\Windows\Fonts\georgiab.ttf")

BACKGROUND_TOP = (9, 19, 13)
BACKGROUND_BOTTOM = (24, 39, 27)
SURFACE = (25, 39, 29)
SURFACE_HIGH = (34, 51, 38)
OUTLINE = (91, 121, 94)
TEXT = (242, 246, 239)
TEXT_MUTED = (186, 200, 188)
ACCENT = (164, 216, 171)
WARM_ACCENT = (222, 198, 151)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def gradient() -> Image.Image:
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
    return canvas


def rounded_card(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, int, int],
) -> ImageDraw.ImageDraw:
    x1, y1, x2, y2 = box
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((x1 + 5, y1 + 8, x2 + 5, y2 + 8), radius=radius, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    canvas.alpha_composite(shadow)

    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.rounded_rectangle(box, radius=radius, fill=(*fill, 245), outline=(*OUTLINE, 105), width=2)
    canvas.alpha_composite(layer)
    return ImageDraw.Draw(canvas, "RGBA")


def draw_library_card(canvas: Image.Image) -> None:
    draw = rounded_card(canvas, (553, 52, 782, 170), 30, SURFACE)
    draw.text((580, 72), "Library", font=font(FONT_BOLD, 20), fill=TEXT)
    draw.text((580, 103), "Books  •  Movies  •  Places", font=font(FONT_REGULAR, 13), fill=TEXT_MUTED)
    for index, symbol in enumerate(("B", "M", "P")):
        x = 580 + index * 47
        draw.rounded_rectangle((x, 130, x + 35, 158), radius=10, fill=ACCENT)
        symbol_font = font(FONT_BOLD, 13)
        bounds = draw.textbbox((0, 0), symbol, font=symbol_font)
        draw.text((x + (35 - (bounds[2] - bounds[0])) / 2, 135), symbol, font=symbol_font, fill=BACKGROUND_TOP)


def draw_rediscover_card(canvas: Image.Image) -> None:
    draw = rounded_card(canvas, (544, 330, 768, 429), 30, SURFACE)
    draw.text((572, 350), "Rediscover", font=font(FONT_BOLD, 19), fill=TEXT)
    draw.text((572, 379), "Worth returning to", font=font(FONT_REGULAR, 13), fill=TEXT_MUTED)
    draw.arc((687, 350, 741, 404), start=210, end=85, fill=(*WARM_ACCENT, 190), width=4)
    draw.ellipse((715, 374, 725, 384), fill=WARM_ACCENT)


def draw_brief_card(canvas: Image.Image) -> None:
    draw = rounded_card(canvas, (812, 337, 1002, 470), 30, SURFACE_HIGH)
    draw.text((838, 354), "Brief", font=font(FONT_BOLD, 20), fill=TEXT)
    draw.ellipse((839, 392, 847, 400), fill=ACCENT)
    draw.rounded_rectangle((859, 393, 964, 399), radius=3, fill=TEXT_MUTED)
    draw.ellipse((839, 415, 847, 423), fill=ACCENT)
    draw.rounded_rectangle((859, 416, 946, 422), radius=3, fill=(151, 166, 153))
    draw.ellipse((839, 438, 847, 446), fill=ACCENT)
    draw.rounded_rectangle((859, 439, 975, 445), radius=3, fill=(121, 137, 124))


def draw_motifs(canvas: Image.Image) -> None:
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.ellipse((642, -80, 1090, 370), fill=(*ACCENT, 18))
    for inset, alpha in ((0, 62), (40, 42), (80, 24)):
        draw.arc((645 + inset, 28 + inset, 1078 - inset, 461 - inset), 205, 42, fill=(*ACCENT, alpha), width=4)
    draw.rounded_rectangle((482, 201, 631, 258), radius=28, outline=(*ACCENT, 38), width=3)
    draw.rounded_rectangle((921, 74, 1082, 137), radius=31, outline=(*ACCENT, 32), width=3)
    for x, y, radius in ((512, 116, 5), (962, 216, 7), (525, 292, 4), (989, 455, 5)):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*ACCENT, 85))
    layer = layer.filter(ImageFilter.GaussianBlur(0.35))
    canvas.alpha_composite(layer)


def paste_mascot(canvas: Image.Image) -> None:
    mascot = Image.open(MASCOT).convert("RGBA")
    alpha_box = mascot.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("Mascot has no visible pixels")
    mascot = mascot.crop(alpha_box)
    mascot.thumbnail((265, 350), Image.Resampling.LANCZOS)

    x = 702
    y = 93
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow_alpha = mascot.getchannel("A").filter(ImageFilter.GaussianBlur(13))
    shadow_shape = Image.new("RGBA", mascot.size, (0, 0, 0, 145))
    shadow_shape.putalpha(shadow_alpha.point(lambda value: round(value * 0.62)))
    shadow.alpha_composite(shadow_shape, (x + 10, y + 14))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(mascot, (x, y))


def add_grain(canvas: Image.Image) -> None:
    noise = Image.effect_noise(SIZE, 8).convert("L")
    noise = noise.point(lambda value: max(0, min(10, abs(value - 128) // 10)))
    grain = Image.new("RGBA", SIZE, (255, 255, 255, 0))
    grain.putalpha(noise)
    canvas.alpha_composite(grain)


def build() -> Image.Image:
    canvas = gradient().convert("RGBA")
    draw_motifs(canvas)
    draw_library_card(canvas)
    draw_rediscover_card(canvas)
    draw_brief_card(canvas)
    paste_mascot(canvas)

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((60, 55), "YOUR LINKS, UNDERSTOOD", font=font(FONT_BOLD, 17), fill=ACCENT)
    draw.text((58, 103), "Save the link.", font=font(FONT_BOLD, 51), fill=TEXT)
    draw.text((58, 163), "Keep the meaning.", font=font(FONT_SERIF_BOLD, 49), fill=ACCENT)
    draw.text(
        (60, 244),
        "Capture once. Return to the context,\nideas and recommendations that mattered.",
        font=font(FONT_REGULAR, 21),
        fill=TEXT_MUTED,
        spacing=8,
    )

    chip_font = font(FONT_BOLD, 13)
    chip_specs = [("CAPTURE", 60, 362, 145), ("UNDERSTAND", 157, 362, 278), ("REDISCOVER", 290, 362, 416)]
    for label, x1, y1, x2 in chip_specs:
        draw.rounded_rectangle((x1, y1, x2, y1 + 38), radius=19, fill=ACCENT)
        bounds = draw.textbbox((0, 0), label, font=chip_font)
        draw.text((x1 + (x2 - x1 - (bounds[2] - bounds[0])) / 2, y1 + 10), label, font=chip_font, fill=BACKGROUND_TOP)

    add_grain(canvas)
    return canvas.convert("RGB")


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    build().save(OUTPUT, format="PNG", optimize=True)
    print(f"Rendered feature graphic to {OUTPUT}")


if __name__ == "__main__":
    main()
