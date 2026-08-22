from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "final" / "feature_graphic-v2.png"
MASCOT = ROOT.parent / "assets" / "glimpse.png"

SIZE = (1024, 500)
REGULAR_FONT = Path(r"C:\Windows\Fonts\segoeui.ttf")
BOLD_FONT = Path(r"C:\Windows\Fonts\segoeuib.ttf")
SERIF_BOLD_FONT = Path(r"C:\Windows\Fonts\georgiab.ttf")

INK = (7, 16, 11)
FOREST = (17, 32, 22)
TEXT = (243, 246, 239)
MUTED = (184, 198, 186)
SAGE = (171, 211, 175)
WARM = (222, 200, 160)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def background() -> Image.Image:
    canvas = Image.new("RGB", SIZE)
    draw = ImageDraw.Draw(canvas)
    for y in range(SIZE[1]):
        t = y / (SIZE[1] - 1)
        eased = t * t * (3 - 2 * t)
        color = tuple(round(INK[c] * (1 - eased) + FOREST[c] * eased) for c in range(3))
        draw.line((0, y, SIZE[0], y), fill=color)
    return canvas.convert("RGBA")


def radial_glow(
    canvas: Image.Image,
    center: tuple[int, int],
    radius: int,
    color: tuple[int, int, int],
    opacity: int,
) -> None:
    left = max(0, center[0] - radius)
    top = max(0, center[1] - radius)
    right = min(SIZE[0], center[0] + radius)
    bottom = min(SIZE[1], center[1] + radius)
    width = right - left
    height = bottom - top
    mask = Image.new("L", (width, height), 0)
    pixels = mask.load()
    for y in range(height):
        for x in range(width):
            distance = math.dist((left + x, top + y), center)
            if distance < radius:
                strength = 1 - distance / radius
                pixels[x, y] = round(opacity * strength * strength)
    glow = Image.new("RGBA", (width, height), (*color, 0))
    glow.putalpha(mask.filter(ImageFilter.GaussianBlur(9)))
    canvas.alpha_composite(glow, (left, top))


def abstract_sheet(size: tuple[int, int], variant: int) -> Image.Image:
    sheet = Image.new("RGBA", size, (231, 237, 226, 24))
    draw = ImageDraw.Draw(sheet, "RGBA")
    draw.rounded_rectangle((1, 1, size[0] - 2, size[1] - 2), radius=26, outline=(210, 225, 211, 72), width=2)
    draw.rounded_rectangle((18, 20, size[0] - 18, 78), radius=18, fill=((*WARM, 34) if variant % 2 else (*SAGE, 30)))
    draw.ellipse((30, 34, 58, 62), fill=(*SAGE, 70))
    for row, width_ratio in enumerate((0.72, 0.9, 0.58, 0.82)):
        y = 106 + row * 25
        width = round((size[0] - 40) * width_ratio)
        draw.rounded_rectangle((20, y, 20 + width, y + 6), radius=3, fill=(219, 227, 218, 62 - row * 8))
    draw.rounded_rectangle((20, size[1] - 46, 92, size[1] - 24), radius=11, fill=(*SAGE, 42))
    return sheet


def paste_rotated(canvas: Image.Image, image: Image.Image, angle: float, position: tuple[int, int], blur: float = 0) -> None:
    rotated = image.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    if blur:
        rotated = rotated.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(rotated, position)


def draw_content_sheets(canvas: Image.Image) -> None:
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse((610, 100, 1015, 478), fill=(0, 0, 0, 125))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(42)))

    paste_rotated(canvas, abstract_sheet((154, 224), 0), -11, (585, 105), blur=0.25)
    paste_rotated(canvas, abstract_sheet((145, 210), 1), 10, (858, 86), blur=0.2)
    paste_rotated(canvas, abstract_sheet((166, 235), 2), 4, (785, 236), blur=0.15)

    path_layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(path_layer, "RGBA")
    points: list[tuple[float, float]] = []
    for step in range(71):
        t = step / 70
        x = (1 - t) ** 3 * 560 + 3 * (1 - t) ** 2 * t * 640 + 3 * (1 - t) * t**2 * 670 + t**3 * 738
        y = (1 - t) ** 3 * 365 + 3 * (1 - t) ** 2 * t * 302 + 3 * (1 - t) * t**2 * 334 + t**3 * 265
        points.append((x, y))
    draw.line(points, fill=(*SAGE, 55), width=3)
    for x, y in (points[0], points[24], points[48]):
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(*SAGE, 110))
    canvas.alpha_composite(path_layer)


def paste_mascot(canvas: Image.Image) -> None:
    mascot = Image.open(MASCOT).convert("RGBA")
    bounds = mascot.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Mascot asset is empty")
    mascot = mascot.crop(bounds)
    mascot.thumbnail((276, 355), Image.Resampling.LANCZOS)
    x = 710
    y = 73

    shadow_alpha = mascot.getchannel("A").filter(ImageFilter.GaussianBlur(16))
    shadow = Image.new("RGBA", mascot.size, (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha.point(lambda value: round(value * 0.48)))
    canvas.alpha_composite(shadow, (x + 14, y + 22))
    canvas.alpha_composite(mascot, (x, y))


def draw_halo(canvas: Image.Image) -> None:
    radial_glow(canvas, (822, 240), 260, (89, 133, 94), 86)
    radial_glow(canvas, (824, 225), 145, WARM, 33)
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.ellipse((644, 58, 1002, 416), outline=(*SAGE, 46), width=2)
    draw.arc((674, 88, 972, 386), start=202, end=30, fill=(*WARM, 72), width=3)
    draw.ellipse((959, 186, 969, 196), fill=(*WARM, 150))
    canvas.alpha_composite(layer)


def add_grain(canvas: Image.Image) -> None:
    noise = Image.effect_noise(SIZE, 5).convert("L")
    noise = noise.point(lambda value: min(6, abs(value - 128) // 15))
    grain = Image.new("RGBA", SIZE, (255, 255, 255, 0))
    grain.putalpha(noise)
    canvas.alpha_composite(grain)


def build() -> Image.Image:
    canvas = background()
    draw_halo(canvas)
    draw_content_sheets(canvas)
    paste_mascot(canvas)

    draw = ImageDraw.Draw(canvas)
    draw.text((61, 117), "SAVE ANYTHING WORTH RETURNING TO", font=font(BOLD_FONT, 15), fill=SAGE)
    draw.text((58, 158), "Keep the meaning.", font=font(SERIF_BOLD_FONT, 52), fill=TEXT)
    draw.text(
        (61, 235),
        "Turn scattered links into context you can\nfind, understand and revisit.",
        font=font(REGULAR_FONT, 22),
        fill=MUTED,
        spacing=8,
    )
    draw.line((61, 345, 420, 345), fill=(74, 101, 78), width=1)
    draw.text((61, 366), "CAPTURE  ·  UNDERSTAND  ·  REDISCOVER", font=font(BOLD_FONT, 14), fill=WARM)

    add_grain(canvas)
    return canvas.convert("RGB")


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    build().save(OUTPUT, format="PNG", optimize=True)
    print(f"Rendered refined feature graphic to {OUTPUT}")


if __name__ == "__main__":
    main()
