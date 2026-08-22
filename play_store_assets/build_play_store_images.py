from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE_DIR = ROOT / "source"
OUTPUT_DIR = ROOT / "final"

CANVAS_SIZE = (1440, 2560)
BACKGROUND_TOP = (10, 20, 14)
BACKGROUND_BOTTOM = (24, 38, 27)
ON_BACKGROUND = (242, 246, 239)
ON_BACKGROUND_MUTED = (192, 204, 192)
SURFACE_FRAME = (35, 50, 38)
ACCENTS = [
    (158, 214, 163),
    (183, 213, 189),
    (222, 198, 151),
    (190, 210, 167),
    (169, 206, 177),
    (153, 204, 171),
    (174, 215, 189),
    (210, 194, 154),
]

REGULAR_FONT = Path(r"C:\Windows\Fonts\segoeui.ttf")
BOLD_FONT = Path(r"C:\Windows\Fonts\segoeuib.ttf")
SERIF_BOLD_FONT = Path(r"C:\Windows\Fonts\georgiab.ttf")

SLIDES = [
    {
        "file": "01_capture.png",
        "source": "add.png",
        "headline": ("Save anything.", "Keep the meaning."),
        "subtitle": "Capture a link, add a note, and let Glimpse find the context.",
        "motif": "links",
    },
    {
        "file": "02_home.png",
        "source": "current.png",
        "headline": ("One calm home", "for every save."),
        "subtitle": "Instagram, YouTube, X, articles and more — together, easy to revisit.",
        "motif": "stacks",
    },
    {
        "file": "03_briefs.png",
        "source": "current-detail.png",
        "headline": ("Turn links into", "useful knowledge."),
        "subtitle": "Automatic summaries, key takeaways and useful recommendations.",
        "motif": "brief",
    },
    {
        "file": "04_ask.png",
        "source": "ask.png",
        "headline": ("Ask what you saved.", "Get grounded answers."),
        "subtitle": "Chat across your library, or focus on one link when you need specifics.",
        "motif": "bubbles",
    },
    {
        "file": "05_library.png",
        "source": "collections.png",
        "headline": ("Your saves become", "a living library."),
        "subtitle": "Books, movies, places and more are found automatically — alongside your own collections.",
        "motif": "grid",
    },
    {
        "file": "06_interests.png",
        "source": "interests-ready.png",
        "headline": ("See what keeps", "your attention."),
        "subtitle": "Your Interest Map groups real patterns without becoming another endless feed.",
        "motif": "network",
    },
    {
        "file": "07_search.png",
        "source": "search-results-ready.png",
        "headline": ("Find anything", "you saved."),
        "subtitle": "Search titles, tags, notes and summaries — then narrow with filters.",
        "motif": "search",
    },
    {
        "file": "08_rediscover.png",
        "source": "rediscover.png",
        "headline": ("Good saves deserve", "a second life."),
        "subtitle": "Rediscover a small daily set, plus weekly and monthly recaps from your library.",
        "motif": "echo",
    },
]


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def vertical_gradient(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size)
    pixels = image.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        eased = t * t * (3 - 2 * t)
        color = tuple(
            round(BACKGROUND_TOP[channel] * (1 - eased) + BACKGROUND_BOTTOM[channel] * eased)
            for channel in range(3)
        )
        for x in range(width):
            pixels[x, y] = color
    return image


def add_grain(image: Image.Image, seed: int) -> Image.Image:
    random.seed(seed)
    noise = Image.new("L", image.size)
    noise.putdata([random.randrange(0, 20) for _ in range(image.width * image.height)])
    noise = noise.filter(ImageFilter.GaussianBlur(0.55))
    grain = Image.new("RGBA", image.size, (255, 255, 255, 0))
    grain.putalpha(noise.point(lambda value: min(9, value // 2)))
    return Image.alpha_composite(image.convert("RGBA"), grain)


def fit_font(text: str, path: Path, starting_size: int, max_width: int) -> ImageFont.FreeTypeFont:
    size = starting_size
    test_canvas = Image.new("RGB", (10, 10))
    test_draw = ImageDraw.Draw(test_canvas)
    while size > 46:
        candidate = font(path, size)
        bounds = test_draw.textbbox((0, 0), text, font=candidate)
        if bounds[2] - bounds[0] <= max_width:
            return candidate
        size -= 2
    return font(path, size)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        candidate = " ".join([*current, word])
        width = draw.textbbox((0, 0), candidate, font=text_font)[2]
        if current and width > max_width:
            lines.append(" ".join(current))
            current = [word]
        else:
            current.append(word)
    if current:
        lines.append(" ".join(current))
    return lines


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def draw_motif(layer: Image.Image, kind: str, accent: tuple[int, int, int]) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    soft = (*accent, 45)
    softer = (*accent, 22)
    line = (*accent, 58)
    if kind == "links":
        draw.rounded_rectangle((38, 640, 470, 814), radius=87, outline=line, width=8)
        draw.rounded_rectangle((970, 512, 1410, 686), radius=87, outline=soft, width=8)
        draw.line((432, 727, 1008, 599), fill=line, width=7)
        for x, y in [(392, 734), (777, 648), (1032, 594)]:
            draw.ellipse((x - 16, y - 16, x + 16, y + 16), fill=soft)
    elif kind == "stacks":
        for offset in range(4):
            draw.rounded_rectangle(
                (45 + offset * 28, 715 - offset * 42, 485 + offset * 28, 1000 - offset * 42),
                radius=62,
                fill=softer,
                outline=line,
                width=4,
            )
        draw.ellipse((1050, 560, 1510, 1020), fill=softer, outline=line, width=4)
    elif kind == "brief":
        draw.rounded_rectangle((1010, 510, 1385, 970), radius=72, fill=softer, outline=line, width=4)
        for y, width in [(620, 250), (704, 190), (788, 228)]:
            draw.ellipse((1065, y - 11, 1087, y + 11), fill=soft)
            draw.rounded_rectangle((1118, y - 6, 1118 + width, y + 6), radius=6, fill=soft)
        draw.arc((-120, 660, 430, 1210), start=215, end=35, fill=line, width=8)
    elif kind == "bubbles":
        draw.rounded_rectangle((38, 680, 440, 900), radius=92, fill=softer, outline=line, width=4)
        draw.polygon([(170, 896), (226, 896), (182, 964)], fill=softer)
        draw.rounded_rectangle((1040, 540, 1460, 756), radius=92, fill=softer, outline=line, width=4)
        for x in (1134, 1210, 1286):
            draw.ellipse((x - 13, 638 - 13, x + 13, 638 + 13), fill=soft)
    elif kind == "grid":
        for row in range(2):
            for column in range(3):
                x = 32 + column * 168
                y = 594 + row * 168
                draw.rounded_rectangle((x, y, x + 136, y + 136), radius=38, fill=softer, outline=line, width=3)
        draw.rounded_rectangle((1080, 590, 1508, 884), radius=78, fill=softer, outline=line, width=4)
    elif kind == "network":
        points = [(70, 670), (320, 570), (466, 812), (1100, 590), (1320, 760), (1122, 980)]
        for start, end in [(0, 1), (1, 2), (1, 3), (3, 4), (3, 5), (4, 5)]:
            draw.line((*points[start], *points[end]), fill=line, width=5)
        for x, y in points:
            draw.rounded_rectangle((x - 34, y - 34, x + 34, y + 34), radius=20, fill=soft)
    elif kind == "search":
        for radius, alpha in [(112, 48), (178, 35), (250, 24)]:
            draw.ellipse((1080 - radius, 720 - radius, 1080 + radius, 720 + radius), outline=(*accent, alpha), width=7)
        draw.line((1240, 880, 1430, 1070), fill=line, width=22)
        for y in (610, 730, 850):
            draw.rounded_rectangle((20, y, 420, y + 72), radius=36, fill=softer)
    elif kind == "echo":
        for inset, alpha in [(0, 55), (60, 40), (120, 28), (180, 18)]:
            draw.arc((910 + inset, 510 + inset, 1580 - inset, 1180 - inset), 110, 260, fill=(*accent, alpha), width=9)
        draw.rounded_rectangle((24, 650, 448, 870), radius=90, fill=softer, outline=line, width=4)
        draw.arc((80, 686, 282, 888), 210, 30, fill=line, width=7)


def sanitize_capture(source: Image.Image) -> Image.Image:
    image = source.copy().convert("RGB")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((93, 647, 895, 735), radius=18, fill=(40, 44, 40))
    safe_url = "https://example.com/article"
    safe_font = fit_font(safe_url, REGULAR_FONT, 43, 740)
    draw.text((107, 661), safe_url, font=safe_font, fill=(226, 231, 224))
    return image


def prepare_screen(path: Path, target_width: int, sanitize: bool = False) -> Image.Image:
    source = Image.open(path).convert("RGB")
    if sanitize:
        source = sanitize_capture(source)
    source = source.crop((0, 110, source.width, source.height))
    target_height = round(source.height * target_width / source.width)
    return source.resize((target_width, target_height), Image.Resampling.LANCZOS)


def paste_screen(canvas: Image.Image, screen: Image.Image, top: int, accent: tuple[int, int, int]) -> None:
    screen_width, screen_height = screen.size
    left = (canvas.width - screen_width) // 2
    radius = 58

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow, "RGBA")
    shadow_draw.rounded_rectangle(
        (left - 24, top - 22, left + screen_width + 24, top + screen_height + 30),
        radius=radius + 18,
        fill=(0, 0, 0, 170),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(shadow)

    frame = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame, "RGBA")
    frame_draw.rounded_rectangle(
        (left - 20, top - 20, left + screen_width + 20, top + screen_height + 20),
        radius=radius + 16,
        fill=(*SURFACE_FRAME, 255),
        outline=(*accent, 80),
        width=3,
    )
    canvas.alpha_composite(frame)

    mask = rounded_mask(screen.size, radius)
    canvas.paste(screen, (left, top), mask)


def build_slide(index: int, slide: dict[str, object]) -> Image.Image:
    accent = ACCENTS[index - 1]
    canvas = add_grain(vertical_gradient(CANVAS_SIZE), seed=index * 733)

    motif_layer = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    draw_motif(motif_layer, str(slide["motif"]), accent)
    motif_layer = motif_layer.filter(ImageFilter.GaussianBlur(0.25))
    canvas.alpha_composite(motif_layer)

    draw = ImageDraw.Draw(canvas, "RGBA")
    first_line, second_line = slide["headline"]
    first_font = fit_font(str(first_line), BOLD_FONT, 78, 1296)
    second_font = fit_font(str(second_line), SERIF_BOLD_FONT, 78, 1296)
    draw.text((72, 78), str(first_line), font=first_font, fill=ON_BACKGROUND)
    draw.text((72, 165), str(second_line), font=second_font, fill=accent)

    subtitle_font = font(REGULAR_FONT, 34)
    subtitle_lines = wrap_text(draw, str(slide["subtitle"]), subtitle_font, 1296)
    subtitle_y = 280
    for line_index, line in enumerate(subtitle_lines[:2]):
        draw.text((74, subtitle_y + line_index * 47), line, font=subtitle_font, fill=ON_BACKGROUND_MUTED)

    screen_width = 920 if index in (1, 4) else 980
    screen_top = 505 if index not in (1, 4) else 535
    screen = prepare_screen(
        SOURCE_DIR / str(slide["source"]),
        target_width=screen_width,
        sanitize=index == 1,
    )
    paste_screen(canvas, screen, top=screen_top, accent=accent)

    return canvas.convert("RGB")


def build_contact_sheet(paths: list[Path]) -> None:
    thumb_width = 270
    thumb_height = 480
    margin = 28
    label_height = 48
    sheet = Image.new(
        "RGB",
        (margin * 5 + thumb_width * 4, margin * 3 + (thumb_height + label_height) * 2),
        (18, 25, 20),
    )
    draw = ImageDraw.Draw(sheet)
    label_font = font(BOLD_FONT, 22)
    for index, path in enumerate(paths):
        image = Image.open(path).convert("RGB").resize((thumb_width, thumb_height), Image.Resampling.LANCZOS)
        column = index % 4
        row = index // 4
        x = margin + column * (thumb_width + margin)
        y = margin + row * (thumb_height + label_height + margin)
        sheet.paste(image, (x, y))
        label = " ".join(path.stem.split("_")[1:])
        draw.text((x, y + thumb_height + 10), label, font=label_font, fill=ON_BACKGROUND_MUTED)
    sheet.save(OUTPUT_DIR / "preview-grid.jpg", quality=92, optimize=True)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    rendered: list[Path] = []
    for index, slide in enumerate(SLIDES, start=1):
        destination = OUTPUT_DIR / str(slide["file"])
        build_slide(index, slide).save(destination, format="PNG", optimize=True)
        rendered.append(destination)
    build_contact_sheet(rendered)
    print(f"Rendered {len(rendered)} Play Store screenshots to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
