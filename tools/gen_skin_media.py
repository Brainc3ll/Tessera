# White drawings of the options window skin (tinted in game): python3 tools/gen_skin_media.py Media/Skin
from PIL import Image, ImageDraw, ImageFilter
import sys
OUT = sys.argv[1]
S = 8  # supersampling

def save(name, size, draw_fn, sup=None):
    w, h = size
    sup = sup or S  # canvas pixels per output pixel
    m = Image.new("L", (w * sup, h * sup), 0)
    draw_fn(ImageDraw.Draw(m))
    m = m.resize((w, h), Image.LANCZOS)
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    img.putalpha(m)
    img.save(f"{OUT}/{name}.tga")

def u(*v):
    return [x * S for x in v]

for r in (8, 14):
    save(f"fill{r}", (64, 64), lambda d, r=r: d.rounded_rectangle(u(0, 0, 64) + [64 * S - 1], r * S, fill=255))
    for t, suffix in ((1.25, ""), (2.5, "b")):
        save(f"frame{r}{suffix}", (64, 64), lambda d, r=r, t=t: d.rounded_rectangle(
            [0, 0, 64 * S - 1, 64 * S - 1], r * S, outline=255, width=int(t * S)))

# the switch's rail (128 x 64, shown at 48 x 24): a pill and its outline
save("pill", (128, 64), sup=4, draw_fn=lambda d: d.rounded_rectangle([0, 0, 64 * S - 1, 32 * S - 1], 16 * S, fill=255))
save("pillEdge", (128, 64), sup=4, draw_fn=lambda d: d.rounded_rectangle([0, 0, 64 * S - 1, 32 * S - 1], 16 * S, outline=255, width=int(2.5 * S)))

# soft shadow
m = Image.new("L", (64, 64), 0)
ImageDraw.Draw(m).rounded_rectangle([14, 14, 50, 50], 10, fill=255)
m = m.filter(ImageFilter.GaussianBlur(7))
img = Image.new("RGBA", (64, 64), (255, 255, 255, 0))
img.putalpha(m)
img.save(f"{OUT}/shadow.tga")

# icons and small shapes: drawn on a 32-unit grid, saved at 128 px (HD, 2.0) so they stay sharp
# on big screens and with Shift + mouse wheel
S = 32
W = 3 * S
def line(d, *pts):
    p = [(pts[i] * S, pts[i + 1] * S) for i in range(0, len(pts), 2)]
    d.line(p, fill=255, width=W, joint="curve")
    for x, y in (p[0], p[-1]):
        d.ellipse([x - W / 2, y - W / 2, x + W / 2, y + W / 2], fill=255)
def ring(d, cx, cy, r):
    d.ellipse(u(cx - r, cy - r, cx + r, cy + r), outline=255, width=W)
def box(d, x0, y0, x1, y1, r=2):
    d.rounded_rectangle(u(x0, y0, x1, y1), r * S, outline=255, width=W)

icons = {
    "circle": lambda d: d.ellipse(u(1, 1, 31, 31), fill=255),
    "ring": lambda d: ring(d, 16, 16, 15),
    "diamond": lambda d: d.polygon([(16 * S, 1 * S), (31 * S, 16 * S), (16 * S, 31 * S), (1 * S, 16 * S)], fill=255),
    "check": lambda d: line(d, 6, 17, 13, 24, 26, 8),
    "cross": lambda d: (line(d, 8, 8, 24, 24), line(d, 24, 8, 8, 24)),
    "right": lambda d: line(d, 12, 6, 22, 16, 12, 26),
    "left": lambda d: line(d, 20, 6, 10, 16, 20, 26),
    "down": lambda d: line(d, 6, 12, 16, 22, 26, 12),
    "i_blocks": lambda d: (box(d, 3, 3, 14, 14), box(d, 18, 3, 29, 14), box(d, 3, 18, 14, 29), box(d, 18, 18, 29, 29)),
    "i_style": lambda d: (ring(d, 16, 16, 13), d.pieslice(u(3, 3, 29, 29), 90, 270, fill=255)),
    "i_place": lambda d: (ring(d, 16, 16, 9), line(d, 16, 2, 16, 30), line(d, 2, 16, 30, 16)),
    "i_access": lambda d: (ring(d, 16, 6, 3), line(d, 5, 12, 27, 12), line(d, 16, 12, 16, 20), line(d, 10, 29, 16, 20, 22, 29)),
    "i_launch": lambda d: (line(d, 6, 26, 26, 6), line(d, 12, 6, 26, 6, 26, 20)),
    "i_broker": lambda d: (box(d, 3, 6, 29, 13), box(d, 3, 19, 29, 26)),
    "i_profiles": lambda d: (ring(d, 16, 9, 6), d.arc(u(5, 18, 27, 40), 180, 360, fill=255, width=W)),
    "i_help": lambda d: (d.arc(u(9, 4, 23, 17), 180, 90, fill=255, width=W), line(d, 16, 16, 16, 20),
                         d.ellipse(u(13.5, 24.5, 18.5, 29.5), fill=255)),
    "i_about": lambda d: (ring(d, 16, 16, 13), line(d, 16, 15, 16, 23), d.ellipse(u(13.5, 7, 18.5, 12), fill=255)),
}
for name, fn in icons.items():
    save(name, (128, 128), fn, sup=8)
