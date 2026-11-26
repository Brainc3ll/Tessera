# Redraws Tessera's logo at 256 px (Media/Icon.png) from the original 128 px drawing
# (tools/logo-source-128.png): python3 tools/gen_logo.py tools/logo-source-128.png Media/Icon.png
from PIL import Image, ImageDraw, ImageChops
import statistics, sys
SRC, OUT, K = sys.argv[1], sys.argv[2], 4
im = Image.open(SRC).convert("RGBA"); px = im.load(); W, H = im.size
bg = (36, 168, 153)
def dist(c): return sum((c[i] - bg[i]) ** 2 for i in range(3)) ** 0.5
mask = {(x, y) for y in range(10, 118) for x in range(10, 118) if px[x, y][3] > 200 and dist(px[x, y]) > 30}
comps, seen = [], set()
for p in sorted(mask):
    if p in seen: continue
    st, pts = [p], set(); seen.add(p)
    while st:
        a, b = st.pop(); pts.add((a, b))
        for n in ((a+1, b), (a-1, b), (a, b+1), (a, b-1)):
            if n in mask and n not in seen: seen.add(n); st.append(n)
    comps.append(pts)
S = W * K
out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(out)
R = 26 * K; RIM = 2 * K
d.rounded_rectangle([0, 0, S - 1, S - 1], R, fill=(24, 118, 106, 255))
d.rounded_rectangle([0, 0, S - 1 - RIM, S - 1 - RIM], R, fill=(100, 214, 202, 255))
d.rounded_rectangle([RIM, RIM, S - 1 - RIM, S - 1 - RIM], R - RIM, fill=bg + (255,))
def big(pts):
    m = Image.new("L", (S, S), 0); md = ImageDraw.Draw(m)
    for x, y in pts: md.rectangle([x * K, y * K, x * K + K - 1, y * K + K - 1], fill=255)
    return m
def shift(m, dx, dy): return ImageChops.offset(m, dx, dy)
def mix(c, t, k): return tuple(round(c[i] + (t[i] - c[i]) * k) for i in range(3))
biggest = max(comps, key=len)
for pts in sorted(comps, key=len, reverse=True):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    if len(pts) / ((x1 - x0 + 1) * (y1 - y0 + 1)) >= 0.85:   # a square tile: its box, less the 1 px shadow
        tile = {(x, y) for x in range(x0, x1) for y in range(y0, y1)}
    else:                                                     # the T and the corners: close small gaps
        filled = set(pts)
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                if (x, y) in pts: continue
                h = any((x - i, y) in pts for i in (1, 2)) and any((x + i, y) in pts for i in (1, 2))
                v = any((x, y - i) in pts for i in (1, 2)) and any((x, y + i) in pts for i in (1, 2))
                if h and v: filled.add((x, y))
        tile = {p for p in filled if (p[0] + 1, p[1] + 1) in filled}   # the shadow is 1 px down-right
    core = {p for p in tile if all((p[0]+i, p[1]+j) in tile for i in (-2, 0, 2) for j in (-2, 0, 2))}
    face = tuple(round(statistics.median(px[x, y][i] for x, y in (core or tile))) for i in range(3))
    A = big(tile)
    shadow = ImageChops.subtract(shift(A, K, K), A)
    out.paste(mix(bg, (0, 0, 0), 0.62) + (255,), (0, 0), shadow)
    out.paste(face + (255,), (0, 0), A)
    inner_tl = ImageChops.multiply(A, ImageChops.multiply(shift(A, RIM, 0), shift(A, 0, RIM)))
    inner_br = ImageChops.multiply(A, ImageChops.multiply(shift(A, -K, 0), shift(A, 0, -K)))
    if pts is biggest:   # the T: a dark edge all round
        edge = ImageChops.subtract(A, ImageChops.multiply(inner_tl, inner_br))
        out.paste(mix(face, (0, 0, 0), 0.55) + (255,), (0, 0), edge)
    else:
        out.paste(mix(face, (255, 255, 255), 0.22) + (255,), (0, 0), ImageChops.subtract(A, inner_tl))
        out.paste(mix(face, (0, 0, 0), 0.5) + (255,), (0, 0), ImageChops.subtract(A, inner_br))
out.resize((256, 256), Image.LANCZOS).save(OUT)  # drawn at 512, saved at 256: sharp up to 96 px x 2.5
