# White drawings of the 2.0 block styles (Media/Looks), tinted in game.
# Usage: python3 tools/gen_looks_media.py Media/Looks
# Everything is drawn 8 times bigger, then reduced: smooth edges at any size.
# Frame drawings are 64 x 64 and cut in 9 pieces in game (Core/Core.lua, "hd" skin): the
# corners are the outer 16 px (CORNER), the edges between them are stretched, so the
# lines must stay the same along each side.
from PIL import Image, ImageDraw, ImageFilter
import sys

OUT = sys.argv[1]
S = 8  # supersampling
CORNER = 16  # corner piece, in texture pixels (texture coordinate 0.25 in game)
R = 12  # corner radius, in texture pixels
LINE = 1.6  # outer line: one screen pixel at the default corner size of 10


def mask(w, h):
    return Image.new("L", (w * S, h * S), 0)


def save(name, m, w, h, blur=0):
    m = m.resize((w, h), Image.LANCZOS)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    img.putalpha(m)
    img.save(f"{OUT}/{name}.tga")


def box(d, inset, r, **kw):
    n = 64 * S - 1
    d.rounded_rectangle([inset * S, inset * S, n - inset * S, n - inset * S], r * S, **kw)


# rounded fill (tinted with the block's background color)
m = mask(64, 64)
box(ImageDraw.Draw(m), 0, R, fill=255)
save("hd_fill", m, 64, 64)

# thin single edge (silver)
m = mask(64, 64)
box(ImageDraw.Draw(m), 0, R, outline=255, width=round(LINE * S))
save("hd_line", m, 64, 64)

# double edge (gold, bronze): outer line, a thinner and fainter line 4.5 px inside
m = mask(64, 64)
d = ImageDraw.Draw(m)
box(d, 0, R, outline=255, width=round(LINE * S))
box(d, 4.5, R - 4, outline=170, width=round(1.0 * S))
save("hd_double", m, 64, 64)

# runic edge (blue rune): thin line, a small diamond in each corner
m = mask(64, 64)
d = ImageDraw.Draw(m)
box(d, 0, R, outline=255, width=round(LINE * S))
for cx, cy in ((6, 6), (58, 6), (6, 58), (58, 58)):
    k = 3
    d.polygon([(cx * S, (cy - k) * S), ((cx + k) * S, cy * S), (cx * S, (cy + k) * S), ((cx - k) * S, cy * S)],
              fill=255)
save("hd_rune", m, 64, 64)


# ornate separators, 16 x 64: a line fading at both ends, with an ornament in the middle
def separator(name, ornament):
    w, h = 16, 64
    m = mask(w, h)
    d = ImageDraw.Draw(m)
    for y in range(h * S):
        t = abs(y / (h * S) - 0.5) * 2  # 0 in the middle, 1 at the ends
        v = int(255 * max(0.0, 1 - t ** 3))
        d.line([(7.5 * S, y), (8.5 * S, y)], fill=v)
    ornament(d)
    save(name, m, w, h)


def diamond(d):
    c, k = 32, 4.5
    d.polygon([(8 * S, (c - k) * S), ((8 + k * 0.8) * S, c * S), (8 * S, (c + k) * S), ((8 - k * 0.8) * S, c * S)],
              fill=255)


def runes(d):
    for c in (22, 32, 42):
        r = 1.7 if c == 32 else 1.2
        d.ellipse([(8 - r) * S, (c - r) * S, (8 + r) * S, (c + r) * S], fill=255)


separator("hd_sep_diamond", diamond)
separator("hd_sep_rune", runes)

# HD icons (Core/Looks.lua): a ring with a fine inner line, and a dark disc behind the icon,
# 128 px (the drawings of the preview chosen in game on 26/11)
m = mask(128, 128)
d = ImageDraw.Draw(m)
n = 128 * S - 1
d.ellipse([0, 0, n, n], outline=255, width=int(7 * S))
d.ellipse([10 * S, 10 * S, n - 10 * S, n - 10 * S], outline=150, width=int(1.5 * S))
save("hd_ring", m, 128, 128)

m = mask(128, 128)
ImageDraw.Draw(m).ellipse([3 * S, 3 * S, n - 3 * S, n - 3 * S], fill=255)
save("hd_disc", m, 128, 128)

# HD icons with a square icon frame: the same frame as the ring, square (27/11: the icon
# frame setting, square or round, also shapes the HD icons)
m = mask(128, 128)
d = ImageDraw.Draw(m)
d.rectangle([0, 0, n, n], outline=255, width=int(7 * S))
d.rectangle([10 * S, 10 * S, n - 10 * S, n - 10 * S], outline=150, width=int(1.5 * S))
save("hd_box", m, 128, 128)

# hover glow (Core/Looks.lua): a soft line just inside the edge, blurred; cut in 9 pieces
# like the frame (the preview's glow, chosen in game on 26/11)
m = mask(64, 64)
box(ImageDraw.Draw(m), 2, R - 1, outline=255, width=int(3 * S))
save("hd_glow", m, 64, 64, blur=2.2)
