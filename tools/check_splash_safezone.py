"""Verify the splash icon stays inside Android 12's circular safe zone.

The Android 12 splash icon canvas at xxxhdpi is 1152x1152 px (= 288 dp).
The safe zone (no icon-background) is the inner 192 dp = 66.7% of the canvas,
i.e. a circle of radius 384 px from the canvas center. Any pixel beyond that
radius MAY be clipped by the launcher's circular mask.
"""

from __future__ import annotations

import math

from PIL import Image

CANVAS_PATH = "android/app/src/main/res/drawable-xxxhdpi/android12splash.png"


def main() -> None:
    im = Image.open(CANVAS_PATH).convert("RGBA")
    width, height = im.size
    canvas_center = (width / 2, height / 2)
    safe_radius = width * (192 / 288) / 2

    pixels = im.load()
    max_radius = 0.0
    worst_xy = (0, 0)
    for y in range(0, height, 2):
        for x in range(0, width, 2):
            if pixels[x, y][3] > 0:
                r = math.hypot(x - canvas_center[0], y - canvas_center[1])
                if r > max_radius:
                    max_radius = r
                    worst_xy = (x, y)

    margin = safe_radius - max_radius
    status = "INSIDE" if max_radius <= safe_radius else "OUTSIDE"
    print(f"canvas size                : {width} x {height}")
    print(f"safe-zone radius (192 dp)  : {safe_radius:.1f} px")
    print(f"furthest opaque pixel      : {max_radius:.1f} px  at {worst_xy}")
    print(f"margin                     : {margin:+.1f} px ({status})")
    print(f"character / canvas ratio   : {max_radius / (width / 2) * 100:.1f}%")


if __name__ == "__main__":
    main()
