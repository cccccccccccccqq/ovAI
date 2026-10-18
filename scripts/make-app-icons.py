#!/usr/bin/env python3
"""Draws the öv AI app icons: the brandbook ger mark centred on ger green.

The geometry is the `gerMark` group from the Geret brandbook
(logo-export/pack/04-mark): a dome with a door and a curved horizon line.
Every size is drawn at 4096 px and downsampled, so small icons stay crisp.

    python3 scripts/make-app-icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "app"
GREEN = (31, 77, 46)  # Ger green #1F4D2E
MARK = (255, 255, 255)
CANVAS = 4096

# Brandbook mark, in its own units.
DOME_CX, DOME_BASE, DOME_R = 512.0, 250.0, 155.0
DOOR_LEFT, DOOR_RIGHT, DOOR_TOP = 489.0, 535.0, 213.0
LINE = ((299.7, 255.2), (513.7, 272.8), (730.9, 255.2))
LINE_WIDTH = 20.0
MARK_LEFT, MARK_RIGHT = LINE[0][0] - LINE_WIDTH / 2, LINE[2][0] + LINE_WIDTH / 2
MARK_TOP, MARK_BOTTOM = DOME_BASE - DOME_R, 264.0 + LINE_WIDTH / 2

# Horizon width as a share of the icon, matching the approved reference.
MARK_SHARE = 0.60


def draw_mark(draw: ImageDraw.ImageDraw, size: int, share: float) -> None:
    scale = size * share / (MARK_RIGHT - MARK_LEFT)
    dx = size / 2 - (MARK_LEFT + MARK_RIGHT) / 2 * scale
    dy = size / 2 - (MARK_TOP + MARK_BOTTOM) / 2 * scale

    def point(x: float, y: float) -> tuple[float, float]:
        return x * scale + dx, y * scale + dy

    # Dome: the upper half of a circle resting on the base line.
    left, top = point(DOME_CX - DOME_R, DOME_BASE - DOME_R)
    right, bottom = point(DOME_CX + DOME_R, DOME_BASE + DOME_R)
    draw.pieslice((left, top, right, bottom), 180, 360, fill=MARK)
    # Door: a rectangle with a round top, cut out of the dome.
    door_r = (DOOR_RIGHT - DOOR_LEFT) / 2
    x0, y0 = point(DOOR_LEFT, DOOR_TOP)
    x1, y1 = point(DOOR_RIGHT, DOME_BASE + 0.5)
    draw.rectangle((x0, y0, x1, y1), fill=GREEN)
    cx, cy = point(DOOR_LEFT + door_r, DOOR_TOP)
    r = door_r * scale
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GREEN)
    # Horizon: a quadratic curve with round caps.
    (ax, ay), (bx, by), (ex, ey) = LINE
    steps = 200
    points = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * ax + 2 * (1 - t) * t * bx + t ** 2 * ex
        y = (1 - t) ** 2 * ay + 2 * (1 - t) * t * by + t ** 2 * ey
        points.append(point(x, y))
    width = LINE_WIDTH * scale
    # A filled outline (both sides of the stroke) avoids jagged polyline joins.
    upper, lower = [], []
    for i, (x, y) in enumerate(points):
        px, py = points[max(i - 1, 0)]
        nx, ny = points[min(i + 1, steps)]
        tx, ty = nx - px, ny - py
        length = (tx * tx + ty * ty) ** 0.5
        ox, oy = -ty / length * width / 2, tx / length * width / 2
        upper.append((x + ox, y + oy))
        lower.append((x - ox, y - oy))
    draw.polygon(upper + lower[::-1], fill=MARK)
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=MARK)


def square(share: float = MARK_SHARE) -> Image.Image:
    """Full-bleed square; iOS and maskable icons are masked by the system."""
    image = Image.new("RGB", (CANVAS, CANVAS), GREEN)
    draw_mark(ImageDraw.Draw(image), CANVAS, share)
    return image


def circle() -> Image.Image:
    """Green disc on transparency, for browsers and Android launchers."""
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((0, 0, CANVAS - 1, CANVAS - 1), fill=GREEN + (255,))
    draw_mark(draw, CANVAS, MARK_SHARE)
    return image


def save(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f"{size:5d}  {path.relative_to(ROOT)}")


def main() -> None:
    full, round_icon = square(), circle()
    # Maskable icons keep the mark inside the 80% safe zone.
    maskable = square(MARK_SHARE * 0.8)

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, px in {
        "20x20@1x": 20, "20x20@2x": 40, "20x20@3x": 60,
        "29x29@1x": 29, "29x29@2x": 58, "29x29@3x": 87,
        "40x40@1x": 40, "40x40@2x": 80, "40x40@3x": 120,
        "60x60@2x": 120, "60x60@3x": 180,
        "76x76@1x": 76, "76x76@2x": 152, "83.5x83.5@2x": 167,
        "1024x1024@1x": 1024,
    }.items():
        # App Store Connect rejects icons with an alpha channel.
        save(full, ios / f"Icon-App-{name}.png", px)

    res = ROOT / "android/app/src/main/res"
    for density, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(round_icon, res / f"mipmap-{density}/ic_launcher.png", px)

    web = ROOT / "web"
    save(round_icon, web / "favicon.png", 32)
    save(round_icon, web / "icons/Icon-192.png", 192)
    save(round_icon, web / "icons/Icon-512.png", 512)
    save(maskable, web / "icons/Icon-maskable-192.png", 192)
    save(maskable, web / "icons/Icon-maskable-512.png", 512)


if __name__ == "__main__":
    main()
