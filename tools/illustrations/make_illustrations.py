"""Draw original, code-generated illustrations for destinations that have no
licensed photograph yet.

These are NOT photos of the real places. Every image is drawn from scratch with
simple shapes in the app's brand colours, and the app labels each one
"Illustration" wherever it is shown. Replace them with real photos as they
arrive (see assets/photos/credits.json, where they are marked "kind":
"illustration").

Usage:  python3 tools/illustrations/make_illustrations.py [--out assets/photos]
Needs:  Pillow
"""
from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 960, 640
S = 2  # supersampling factor for smooth edges

FONT_PATHS = [
    "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]

# Brand palette (matches the redesign).
LAGOON = "#00A3B4"
DEEP = "#0B2F44"
SUNSET = "#FF8A1F"
SUN = "#FFC93C"
PALM = "#13855A"
LEAF = "#2BB673"
SAND = "#F6E3B4"
SAND_LIGHT = "#FFF4D6"
WHITE = "#FFFFFF"
TRUNK = "#9A6A3C"
ROAD = "#C9C2B4"
PAVE = "#E9E2D3"
WALLS = ["#FFD6A5", "#BDE7F2", "#FFF1A8", "#F8BBD0", "#C8F0D8", "#E3D4FA", "#FFFFFF", "#FFE0CC"]
ROOFS = ["#E8344F", "#00727E", "#1E6FE0", "#EF6C00", "#7B3FD0", "#13855A"]


def font(size: int) -> ImageFont.FreeTypeFont:
    for p in FONT_PATHS:
        if Path(p).exists():
            return ImageFont.truetype(p, size * S)
    return ImageFont.load_default()


def hexrgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def mix(a: str, b: str, t: float) -> tuple[int, int, int]:
    ca, cb = hexrgb(a), hexrgb(b)
    return tuple(round(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))  # type: ignore[return-value]


class Canvas:
    def __init__(self, seed: int):
        self.img = Image.new("RGB", (W * S, H * S), WHITE)
        self.d = ImageDraw.Draw(self.img)
        self.rnd = random.Random(seed)

    # --- primitives in 960x640 space -------------------------------------
    def rect(self, x0, y0, x1, y1, fill, r=0, outline=None, width=0):
        box = [x0 * S, y0 * S, x1 * S, y1 * S]
        if r:
            self.d.rounded_rectangle(box, radius=r * S, fill=fill, outline=outline, width=width * S)
        else:
            self.d.rectangle(box, fill=fill, outline=outline, width=width * S)

    def ellipse(self, cx, cy, rx, ry, fill, outline=None, width=0):
        self.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill,
                       outline=outline, width=width * S)

    def poly(self, pts, fill):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=fill)

    def line(self, pts, fill, width):
        self.d.line([(x * S, y * S) for x, y in pts], fill=fill, width=int(width * S), joint="curve")

    def text(self, cx, cy, s, size, fill):
        f = font(size)
        self.d.text((cx * S, cy * S), s, font=f, fill=fill, anchor="mm")

    def vgrad(self, y0, y1, top, bottom):
        for y in range(int(y0 * S), int(y1 * S)):
            t = (y - y0 * S) / max(1, (y1 - y0) * S)
            self.d.line([(0, y), (W * S, y)], fill=mix(top, bottom, t))

    def save(self, path: Path):
        self.img.resize((W, H), Image.LANCZOS).save(path, quality=86, optimize=True)

    # --- scenery ----------------------------------------------------------
    def sky(self, horizon, warm=False):
        self.vgrad(0, horizon, "#2FA8EE", "#FFE3B0" if warm else "#C5F1FF")
        sx = self.rnd.uniform(620, 860)
        self.ellipse(sx, 110, 92, 92, "#FFE9A8")
        self.ellipse(sx, 110, 58, 58, SUN)
        for _ in range(3):
            cx, cy, r = self.rnd.uniform(60, 900), self.rnd.uniform(60, horizon * 0.55), self.rnd.uniform(22, 34)
            for dx, dy, k in [(0, 0, 1), (r * 1.1, 6, 0.8), (-r * 1.0, 8, 0.75), (r * 0.4, -r * 0.5, 0.8)]:
                self.ellipse(cx + dx, cy + dy, r * k * 1.4, r * k, WHITE)

    def sea(self, y0, y1, top="#0A93C9", bottom="#4FE0D6"):
        self.vgrad(y0, y1, top, bottom)
        for _ in range(26):
            y = self.rnd.uniform(y0 + 6, y1 - 4)
            x = self.rnd.uniform(0, W)
            self.line([(x, y), (x + self.rnd.uniform(18, 46), y)], "#BFF6F2", 3)

    def sand(self, y_left, y_mid, y_right, color=SAND, foam=True):
        pts = [(0, y_left)]
        for i in range(1, 41):
            t = i / 40
            x = t * W
            y = (1 - t) ** 2 * y_left + 2 * (1 - t) * t * y_mid + t ** 2 * y_right
            pts.append((x, y))
        if foam:
            self.line(pts, WHITE, 9)
        self.poly(pts + [(W, H), (0, H)], color)

    def palm(self, bx, by, height, lean=0.15, flip=1):
        top = (bx + height * lean * flip, by - height)
        n = 18
        for i in range(n + 1):
            t = i / n
            x = bx + (top[0] - bx) * t + math.sin(t * math.pi) * height * 0.06 * flip
            y = by + (top[1] - by) * t
            r = height * (0.045 - 0.018 * t)
            self.ellipse(x, y, r, r * 0.8, TRUNK if i % 3 else "#80542C")
        for ang in [-170, -140, -105, -70, -35, -5, 20]:
            a = math.radians(ang)
            L = height * self.rnd.uniform(0.42, 0.52)
            pts_top, pts_bot = [], []
            for k in range(9):
                t = k / 8
                droop = (t ** 1.6) * L * 0.45
                x = top[0] + math.cos(a) * L * t
                y = top[1] + math.sin(a) * L * t * 0.55 + droop
                w = math.sin(t * math.pi) * height * 0.06
                nx, ny = -math.sin(a), math.cos(a)
                pts_top.append((x + nx * w, y + ny * w))
                pts_bot.append((x - nx * w, y - ny * w))
            self.poly(pts_top + pts_bot[::-1], LEAF if ang % 2 else PALM)
        self.ellipse(top[0], top[1] + 6, 10, 10, "#7A4A20")

    def bush(self, cx, cy, s, color=LEAF):
        for dx, dy, k in [(0, 0, 1), (-s * 0.8, s * 0.2, 0.75), (s * 0.8, s * 0.25, 0.7)]:
            self.ellipse(cx + dx, cy + dy, s * k, s * k * 0.8, color)

    def umbrella(self, cx, ground, color):
        self.line([(cx, ground), (cx, ground - 120)], "#5B4636", 5)
        pts = [(cx - 70, ground - 110)]
        for i in range(1, 20):
            a = math.pi + math.pi * i / 20
            pts.append((cx + math.cos(a) * 70, ground - 110 + math.sin(a) * 42))
        pts.append((cx + 70, ground - 110))
        self.poly(pts, color)
        for k in (-35, 0, 35):
            self.line([(cx, ground - 152), (cx + k * 2, ground - 110)], WHITE, 3)

    def lounger(self, cx, ground, color):
        self.poly([(cx - 50, ground - 14), (cx + 30, ground - 14), (cx + 52, ground - 40), (cx + 44, ground - 44), (cx + 24, ground - 22), (cx - 50, ground - 22)], color)
        self.line([(cx - 44, ground - 14), (cx - 44, ground)], "#5B4636", 4)
        self.line([(cx + 26, ground - 14), (cx + 26, ground)], "#5B4636", 4)

    def boat(self, cx, cy, color, s=1.0):
        self.poly([(cx - 60 * s, cy), (cx + 60 * s, cy), (cx + 44 * s, cy + 22 * s), (cx - 44 * s, cy + 22 * s)], color)
        self.rect(cx - 20 * s, cy - 18 * s, cx + 18 * s, cy, WHITE, r=4)

    def street(self, y):
        self.rect(0, y, W, y + 30, PAVE)
        self.rect(0, y + 30, W, H, ROAD)
        for x in range(30, W, 120):
            self.rect(x, y + 72, x + 60, y + 78, "#FFFFFF")

    # --- buildings ----------------------------------------------------------
    def windows(self, x0, x1, y, h, n, shutter, frame=WHITE, w=46):
        gap = (x1 - x0 - n * w) / (n + 1)
        for i in range(n):
            x = x0 + gap + i * (w + gap)
            self.rect(x - 8, y, x, y + h, shutter)
            self.rect(x + w, y, x + w + 8, y + h, shutter)
            self.rect(x, y, x + w, y + h, "#9ED7EC", outline=frame, width=4)
            self.line([(x + w / 2, y), (x + w / 2, y + h)], frame, 3)

    def house(self, x0, x1, base, floors, wall, roof, shutter, veranda=False, door=DEEP, sign=None,
              sign_fill=DEEP, sign_text=WHITE, hip=True):
        fh = 120
        top = base - floors * fh
        self.rect(x0, top, x1, base, wall)
        if hip:
            self.poly([(x0 - 22, top), (x0 + 40, top - 70), (x1 - 40, top - 70), (x1 + 22, top)], roof)
        else:
            self.rect(x0 - 14, top - 26, x1 + 14, top, roof)
        for f in range(floors):
            y = top + f * fh + 26
            n = max(2, int((x1 - x0) / 110))
            if f == floors - 1:
                self.windows(x0, x1, y, 70, n, shutter)
            else:
                self.windows(x0, x1, y, 66, n, shutter)
        if veranda and floors > 1:
            vy = base - fh
            self.rect(x0 - 10, vy - 8, x1 + 10, vy + 4, WHITE)
            for x in range(int(x0), int(x1) + 1, 30):
                self.line([(x, vy - 40), (x, vy)], WHITE, 4)
            self.line([(x0 - 10, vy - 40), (x1 + 10, vy - 40)], WHITE, 6)
            for x in range(int(x0), int(x1) + 1, int((x1 - x0) / 4)):
                self.rect(x - 5, vy, x + 5, base, WHITE)
        cx = (x0 + x1) / 2
        self.rect(cx - 30, base - 92, cx + 30, base, door, r=6)
        self.ellipse(cx + 16, base - 46, 4, 4, SUN)
        if sign:
            tw = max(150, len(sign) * 21 + 40)
            sy = base - floors * fh + (12 if floors == 1 else fh * (floors - 1) - 4)
            if floors == 1:
                sy = top - 34  # on the roof, clear of any awning
            self.rect(cx - tw / 2, sy - 22, cx + tw / 2, sy + 22, sign_fill, r=10)
            self.text(cx, sy + 1, sign, 26, sign_text)

    def awning(self, x0, x1, y, a, b):
        n = int((x1 - x0) / 40)
        for i in range(n):
            xa, xb = x0 + i * (x1 - x0) / n, x0 + (i + 1) * (x1 - x0) / n
            self.poly([(xa, y), (xb, y), (xb + 6, y + 44), (xa + 6, y + 44)], a if i % 2 == 0 else b)
            self.ellipse((xa + xb) / 2 + 6, y + 44, (xb - xa) / 2, 9, a if i % 2 == 0 else b)


# --- scenes ------------------------------------------------------------------

def beach(c: Canvas, variant: int):
    c.sky(300)
    c.sea(300, 470)
    c.boat(720, 340, "#FF5A6E", 0.7)
    c.sand(470, 430, 520)
    if variant == 1:
        c.palm(90, 600, 420, 0.18)
        c.palm(210, 610, 330, 0.08)
        c.umbrella(470, 580, SUNSET)
        c.lounger(560, 600, "#00A3B4")
        c.umbrella(740, 590, "#E8344F")
        c.lounger(830, 610, SUN)
    else:
        c.sand(500, 470, 540, SAND_LIGHT, foam=False)
        c.palm(860, 610, 400, 0.2, flip=-1)
        c.bush(80, 560, 50)
        c.umbrella(380, 590, "#00A3B4")
        c.lounger(470, 610, SUNSET)


def salina(c: Canvas, water_top, water_bottom, birds=False, town=False):
    c.sky(250)
    if town:
        x = 120
        while x < 860:
            w = c.rnd.uniform(70, 110)
            h = c.rnd.uniform(50, 80)
            c.rect(x, 250 - h, x + w, 252, c.rnd.choice(WALLS))
            c.poly([(x - 6, 250 - h), (x + w / 2, 250 - h - 28), (x + w + 6, 250 - h)], c.rnd.choice(ROOFS))
            x += w + 14
    c.rect(0, 246, W, 280, "#6FB46A")
    c.vgrad(276, 560, water_top, water_bottom)
    for _ in range(14):
        y = c.rnd.uniform(300, 540)
        x = c.rnd.uniform(0, W)
        c.line([(x, y), (x + c.rnd.uniform(30, 70), y)], WHITE, 3)
    pts = [(0, 520)] + [(i * W / 20, 520 + math.sin(i * 1.3) * 12) for i in range(21)] + [(W, H), (0, H)]
    c.poly(pts, "#F3EEE4")
    for i in range(5):
        x = 120 + i * 170 + c.rnd.uniform(-20, 20)
        c.poly([(x - 46, 600), (x, 556), (x + 46, 600)], WHITE)
    c.rect(560, 470, 900, 482, "#B88A5A")
    for x in range(570, 900, 40):
        c.rect(x, 482, x + 6, 520, "#8F6640")
    c.bush(60, 520, 40, PALM)
    c.bush(920, 512, 36, LEAF)
    if birds:
        for (bx, by) in [(300, 150), (360, 120), (420, 160)]:
            c.line([(bx - 20, by), (bx, by + 10), (bx + 20, by)], DEEP, 4)


def cay(c: Canvas):
    c.sky(250)
    c.sea(250, H, "#0A93C9", "#57E3D9")
    c.ellipse(430, 360, 280, 60, SAND_LIGHT)
    c.ellipse(430, 352, 250, 46, SAND)
    c.bush(320, 330, 46, PALM)
    c.bush(520, 334, 40, LEAF)
    c.palm(430, 350, 240, 0.12)
    c.boat(780, 420, SUN, 0.9)
    for (sx, sy) in [(250, 520), (640, 560)]:
        c.poly([(sx - 60, sy), (sx, sy - 26), (sx + 60, sy), (sx, sy + 22)], "#2C8FA3")
        c.line([(sx + 30, sy + 8), (sx + 100, sy + 30)], "#2C8FA3", 4)


def park(c: Canvas):
    c.sky(330)
    c.rect(0, 330, W, H, "#7ED38A")
    c.ellipse(480, 640, 520, 150, "#6CC77A")
    c.rect(430, 140, 530, 470, WHITE)
    c.poly([(420, 140), (480, 80), (540, 140)], "#E8344F")
    c.ellipse(480, 210, 36, 36, SUN, outline=DEEP, width=4)
    c.line([(480, 210), (480, 186)], DEEP, 4)
    c.line([(480, 210), (498, 216)], DEEP, 4)
    c.rect(462, 400, 498, 470, DEEP, r=4)
    c.line([(380, 640), (450, 470), (510, 470), (580, 640)], "#F2E6C9", 1)
    c.poly([(380, 640), (452, 470), (508, 470), (580, 640)], "#F2E6C9")
    c.palm(140, 560, 360, 0.15)
    c.palm(820, 560, 330, 0.12, flip=-1)
    for bx in (260, 680):
        c.rect(bx - 50, 520, bx + 50, 532, "#00727E", r=4)
        c.rect(bx - 50, 500, bx + 50, 510, "#00727E", r=4)
        c.rect(bx - 44, 532, bx - 38, 556, DEEP)
        c.rect(bx + 38, 532, bx + 44, 556, DEEP)
    c.bush(330, 440, 34, PALM)
    c.bush(640, 444, 30, PALM)


def town_building(c: Canvas, sign, floors=2, veranda=True, wall=None, roof=None, sign_fill=DEEP, sign_text=WHITE,
                  awning=None, extra=None, hip=True):
    c.sky(380)
    c.street(500)
    wall = wall or c.rnd.choice(WALLS)
    roof = roof or c.rnd.choice(ROOFS)
    shutter = c.rnd.choice(["#00A3B4", "#13855A", "#1E6FE0", "#E8344F", "#EF6C00"])
    for nx0, nx1 in [(-60, 150), (810, 1020)]:
        c.house(nx0, nx1, 500, 1, c.rnd.choice(WALLS), c.rnd.choice(ROOFS), shutter, hip=True)
    c.house(200, 760, 500, floors, wall, roof, shutter, veranda=veranda, sign=sign, sign_fill=sign_fill,
            sign_text=sign_text, hip=hip)
    if awning:
        c.awning(200, 760, 500 - 120 * floors + 6 if floors == 1 else 500 - 120 + 4, *awning)
    if extra:
        extra(c)
    c.palm(860, 520, 300, 0.12, flip=-1)
    c.bush(180, 506, 26, LEAF)


def flag(c: Canvas, x, base, colors):
    c.rect(x - 3, base - 260, x + 3, base, "#8A9AA6")
    for i, col in enumerate(colors):
        c.rect(x + 3, base - 256 + i * 18, x + 90, base - 238 + i * 18, col)


def bar_shack(c: Canvas, sign):
    c.sky(300)
    c.sea(300, 430)
    c.sand(430, 410, 470)
    c.rect(250, 300, 710, 520, "#C98B52")
    for x in range(250, 711, 26):
        c.line([(x, 300), (x, 520)], "#B07740", 3)
    c.poly([(210, 310), (480, 200), (750, 310)], "#E3B66B")
    for x in range(220, 740, 18):
        c.line([(x, 312), (x + 8, 334)], "#D3A055", 3)
    c.rect(240, 440, 720, 470, "#7A4A20")
    c.rect(290, 340, 670, 430, "#4A2E14")
    c.rect(330, 236, 630, 292, DEEP, r=12)
    c.text(480, 265, sign, 30, SUN)
    pts = [(240, 330)] + [(240 + i * 24, 330 + math.sin(i / 20 * math.pi) * 26) for i in range(21)]
    c.line(pts, "#5B4636", 2)
    for i in range(1, 20, 2):
        x, y = pts[i]
        c.ellipse(x, y + 8, 7, 7, [SUN, "#FF5A6E", LAGOON][i % 3])
    for sx in (330, 480, 630):
        c.rect(sx - 4, 470, sx + 4, 540, "#5B4636")
        c.ellipse(sx, 466, 26, 8, "#00A3B4")
    c.palm(110, 610, 400, 0.18)
    c.umbrella(820, 600, SUNSET)


def surf_extra(c: Canvas):
    for i, col in enumerate([SUNSET, LAGOON, "#E8344F", SUN]):
        x = 230 + i * 30
        c.ellipse(x, 430, 13, 66, col)
    for i, col in enumerate(["#7B3FD0", "#13855A", SUNSET]):
        x = 650 + i * 30
        c.ellipse(x, 430, 13, 66, col)


def cart_extra(c: Canvas):
    x, y = 640, 470
    c.line([(x - 40, y - 50), (x - 24, y - 50), (x - 6, y - 10), (x + 40, y - 10), (x + 50, y - 40), (x - 18, y - 40)], DEEP, 5)
    c.ellipse(x, y, 7, 7, DEEP)
    c.ellipse(x + 32, y, 7, 7, DEEP)


def pharmacy_extra(c: Canvas):
    cx, cy = 690, 300
    c.rect(cx - 40, cy - 40, cx + 40, cy + 40, WHITE, r=10)
    c.rect(cx - 12, cy - 30, cx + 12, cy + 30, "#13855A")
    c.rect(cx - 30, cy - 12, cx + 30, cy + 12, "#13855A")


def hospital_extra(c: Canvas):
    cx, cy = 690, 300
    c.ellipse(cx, cy, 42, 42, "#1E6FE0")
    c.text(cx, cy + 2, "H", 46, WHITE)


def prison(c: Canvas):
    c.sky(300)
    c.street(500)
    c.rect(80, 230, 880, 500, "#D9CDB8")
    for y in range(240, 500, 32):
        off = 0 if (y // 32) % 2 else 40
        for x in range(80 + off, 880, 80):
            c.rect(x, y, x + 76, y + 28, "#E6DCC8", r=3)
    c.rect(70, 214, 890, 236, "#BBA98C")
    c.rect(400, 330, 560, 500, "#BBA98C")
    c.ellipse(480, 330, 80, 70, "#BBA98C")
    c.rect(418, 340, 542, 500, "#5B4636")
    c.ellipse(480, 340, 62, 54, "#5B4636")
    for x in range(430, 540, 20):
        c.line([(x, 300), (x, 500)], "#2D2318", 5)
    for wx in (180, 300, 660, 780):
        c.rect(wx - 26, 300, wx + 26, 360, "#3C3C3C", r=6)
        for x in range(wx - 18, wx + 20, 12):
            c.line([(x, 300), (x, 360)], "#C9C2B4", 3)
    c.rect(330, 250, 630, 296, DEEP, r=10)
    c.text(480, 274, "MUSEUM", 28, SUN)
    c.palm(60, 520, 300, 0.1)


def residence(c: Canvas):
    c.sky(330)
    c.rect(0, 470, W, H, "#7ED38A")
    c.poly([(400, 640), (450, 470), (510, 470), (560, 640)], "#F2E6C9")
    c.house(170, 790, 470, 2, WHITE, "#00727E", "#13855A", veranda=True, hip=True)
    flag(c, 860, 470, ["#1E6FE0", WHITE, "#1E6FE0"])
    c.palm(90, 560, 380, 0.15)
    c.bush(300, 520, 40, PALM)
    c.bush(660, 520, 40, PALM)


SCENES = {
    "pillory-beach": lambda c: beach(c, 1),
    "white-sands-beach": lambda c: beach(c, 2),
    "town-salina": lambda c: salina(c, "#9FDCD8", "#D7F2EC", town=True),
    "red-salina": lambda c: salina(c, "#F6A9C4", "#FBD9E5"),
    "hawks-nest-salina": lambda c: salina(c, "#A8DCC8", "#DDF3EA", birds=True),
    "gibbs-cay": cay,
    "clock-tower-park": park,
    "hm-prison": prison,
    "waterloo": residence,
    "odd-fellows-lodge": lambda c: town_building(c, "LODGE", wall="#BDE7F2", roof="#E8344F"),
    "freemason-lodge": lambda c: town_building(c, "LODGE", wall="#FFF1A8", roof="#1E6FE0"),
    "victoria-library": lambda c: town_building(c, "LIBRARY", wall="#FFE0CC", roof="#00727E"),
    "sand-bar": lambda c: bar_shack(c, "RESTAURANT"),
    "barbies": lambda c: bar_shack(c, "BAR & GRILL"),
    "salt-raker-inn": lambda c: town_building(c, "INN", wall="#F8BBD0", roof="#13855A"),
    "shoprite-grocery": lambda c: town_building(c, "GROCERY", floors=1, veranda=False, wall="#C8F0D8",
                                                roof="#E8344F", awning=("#E8344F", WHITE), extra=cart_extra),
    "graceway-supermarket": lambda c: town_building(c, "SUPERMARKET", floors=1, veranda=False, wall="#FFF1A8",
                                                    roof="#1E6FE0", awning=("#1E6FE0", WHITE), extra=cart_extra),
    "ron-jon-surf-shop": lambda c: town_building(c, "SURF SHOP", floors=1, veranda=False, wall="#BDE7F2",
                                                 roof=SUNSET, awning=(SUNSET, WHITE), extra=surf_extra),
    "harbor-house": lambda c: town_building(c, "GIFTS", floors=1, veranda=False, wall="#E3D4FA",
                                            roof="#7B3FD0", awning=("#7B3FD0", WHITE)),
    "island-creations": lambda c: town_building(c, "CRAFTS", floors=1, veranda=False, wall="#FFD6A5",
                                                roof="#00727E", awning=("#00A3B4", WHITE)),
    "grace-bay-pharmacy": lambda c: town_building(c, "PHARMACY", floors=1, veranda=False, wall=WHITE,
                                                  roof="#13855A", awning=("#13855A", WHITE), extra=pharmacy_extra),
    "medical-centre": lambda c: town_building(c, "HOSPITAL", floors=2, veranda=False, wall=WHITE,
                                              roof="#1E6FE0", sign_fill="#1E6FE0", extra=hospital_extra),
    "police-station": lambda c: town_building(c, "POLICE", wall=WHITE, roof="#1E6FE0", sign_fill="#1E6FE0",
                                              extra=lambda c: flag(c, 100, 500, ["#1E6FE0", WHITE, "#E8344F"])),
    "post-office": lambda c: town_building(c, "POST OFFICE", wall="#FFE0CC", roof="#E8344F", sign_fill="#E8344F"),
    "scotiabank": lambda c: town_building(c, "BANK", wall="#FFFFFF", roof="#E8344F", veranda=False),
    "cibc-bank": lambda c: town_building(c, "BANK", wall="#FFF1A8", roof="#7B3FD0", veranda=False),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/photos")
    ap.add_argument("--credits", default="assets/photos/credits.json")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    credits_path = Path(a.credits)
    credits = json.loads(credits_path.read_text(encoding="utf-8"))
    pois = {p["id"]: p for p in json.loads(Path("assets/pois/pois.json").read_text(encoding="utf-8"))["pois"]}
    made = 0
    for pid, draw in SCENES.items():
        if pid not in pois:
            raise SystemExit(f"unknown destination id: {pid}")
        existing = credits.get(pid)
        if existing and existing.get("kind") != "illustration":
            continue  # a real licensed photo exists: never overwrite it
        c = Canvas(seed=sum(map(ord, pid)))
        draw(c)
        fname = f"illustration-{pid}.jpg"
        c.save(out / fname)
        credits[pid] = {
            "file": fname,
            "title": f"Illustration of {pois[pid]['name']} (not a photo)",
            "author": "TCI Beach Buddies",
            "license": "Original illustration",
            "url": "",
            "kind": "illustration",
        }
        made += 1
    credits_path.write_text(json.dumps(credits, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"drew {made} illustrations into {out}")


if __name__ == "__main__":
    main()
