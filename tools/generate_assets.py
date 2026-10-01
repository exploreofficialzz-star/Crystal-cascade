"""Generates every UI icon, gradient button and 3D texture used by Crystal Cascade.
Run:  python3 tools/generate_assets.py   (needs Pillow + numpy)
Outputs are committed under assets/ui, assets/icons, assets/textures."""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
S = 4            # supersampling
N = 96           # icon size
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def canvas(): 
    im = Image.new("L", (N*S, N*S), 0); return im, ImageDraw.Draw(im)
def P(v): return v*S
def save_icon(name, im):
    im = im.resize((N, N), Image.LANCZOS)
    out = Image.new("RGBA", (N, N), (255, 255, 255, 0)); out.putalpha(im)
    out.save(os.path.join(ROOT, "icons", name + ".png"))
def rr(d, box, r, fill=255): d.rounded_rectangle([P(x) for x in box], radius=P(r), fill=fill)
def circ(d, cx, cy, r, fill=255): d.ellipse([P(cx-r), P(cy-r), P(cx+r), P(cy+r)], fill=fill)
def poly(d, pts, fill=255): d.polygon([(P(x), P(y)) for x, y in pts], fill=fill)
def line(d, pts, w, fill=255):
    d.line([(P(x), P(y)) for x, y in pts], fill=fill, width=P(w), joint="curve")
    for x, y in (pts[0], pts[-1]): circ(d, x, y, w/2, fill)
def arc(d, cx, cy, r, a0, a1, w, fill=255):
    d.arc([P(cx-r), P(cy-r), P(cx+r), P(cy+r)], a0, a1, fill=fill, width=P(w))

def star_pts(cx, cy, ro, ri, n=5, rot=-90):
    pts = []
    for i in range(n*2):
        a = math.radians(rot + i*180/n); r = ro if i % 2 == 0 else ri
        pts.append((cx + r*math.cos(a), cy + r*math.sin(a)))
    return pts

icons = {}
def icon(f): icons[f.__name__] = f; return f

@icon
def play(d): poly(d, [(30, 20), (76, 48), (30, 76)]); d.line([(P(30),P(20)),(P(76),P(48)),(P(30),P(76)),(P(30),P(20))], fill=255, width=P(8), joint="curve")
@icon
def pause(d): rr(d, (26, 18, 42, 78), 5); rr(d, (54, 18, 70, 78), 5)
@icon
def grid(d):
    for x in (20, 52):
        for y in (20, 52): rr(d, (x, y, x+24, y+24), 6)
@icon
def bag(d):
    rr(d, (20, 32, 76, 82), 9); arc(d, 48, 34, 14, 180, 360, 6)
@icon
def gear(d):
    for i in range(8):
        a = math.radians(i*45); cx, cy = 48+30*math.cos(a), 48+30*math.sin(a)
        ux, uy = math.cos(a), math.sin(a); vx, vy = -uy, ux
        w, l = 8, 9
        poly(d, [(cx-vx*w+ux*l, cy-vy*w+uy*l), (cx+vx*w+ux*l, cy+vy*w+uy*l), (cx+vx*w-ux*l, cy+vy*w-uy*l), (cx-vx*w-ux*l, cy-vy*w-uy*l)])
    circ(d, 48, 48, 26); circ(d, 48, 48, 11, 0)
@icon
def share(d):
    line(d, [(70, 24), (26, 48), (70, 72)], 5)
    for x, y in ((70, 24), (26, 48), (70, 72)): circ(d, x, y, 12)
@icon
def lock(d):
    arc(d, 48, 38, 15, 180, 360, 8); line(d, [(33, 38), (33, 46)], 8); line(d, [(63, 38), (63, 46)], 8)
    rr(d, (22, 44, 74, 80), 9); circ(d, 48, 60, 6, 0); rr(d, (45, 60, 51, 70), 2, 0)
@icon
def star(d): poly(d, star_pts(48, 52, 40, 17)); d.line([(P(x), P(y)) for x, y in star_pts(48, 52, 40, 17)+[star_pts(48, 52, 40, 17)[0]]], fill=255, width=P(6), joint="curve")
@icon
def star_outline(d):
    pts = star_pts(48, 52, 40, 17); poly(d, pts); d.line([(P(x), P(y)) for x, y in pts+[pts[0]]], fill=255, width=P(6), joint="curve")
    poly(d, star_pts(48, 52, 26, 11), 0)
@icon
def heart(d):
    pts = []
    for i in range(120):
        t = i*2*math.pi/120
        pts.append((48+2.3*16*math.sin(t)**3, 46-2.3*(13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t))*0.98))
    poly(d, pts)
@icon
def coin(d):
    circ(d, 48, 48, 40); circ(d, 48, 48, 33, 0); circ(d, 48, 48, 30)
    f = ImageFont.truetype(FONT, P(46)); d.text((P(48), P(50)), "$", font=f, fill=0, anchor="mm")
@icon
def bulb(d):
    circ(d, 48, 38, 22); poly(d, [(38, 52), (58, 52), (55, 66), (41, 66)]); rr(d, (39, 68, 57, 74), 3); rr(d, (42, 76, 54, 82), 3)
    circ(d, 48, 38, 13, 0); circ(d, 48, 38, 9)
@icon
def gift(d):
    rr(d, (18, 38, 78, 80), 6); rr(d, (14, 28, 82, 44), 5); rr(d, (43, 28, 53, 80), 0, 0)
    line(d, [(48, 28), (34, 16)], 6); line(d, [(48, 28), (62, 16)], 6); circ(d, 34, 18, 7); circ(d, 62, 18, 7); circ(d, 48, 28, 6)
@icon
def calendar(d):
    rr(d, (16, 24, 80, 80), 9); rr(d, (22, 42, 74, 74), 3, 0); rr(d, (28, 12, 36, 32), 3); rr(d, (60, 12, 68, 32), 3)
    for x in (30, 44, 58):
        for y in (48, 60): rr(d, (x, y, x+8, y+8), 2)
@icon
def moon(d):
    circ(d, 46, 48, 32); circ(d, 62, 40, 27, 0)
@icon
def sun(d):
    circ(d, 48, 48, 17)
    for i in range(8):
        a = math.radians(i*45); line(d, [(48+27*math.cos(a), 48+27*math.sin(a)), (48+38*math.cos(a), 48+38*math.sin(a))], 6)
@icon
def diamond(d):
    poly(d, [(26, 18), (70, 18), (86, 38), (48, 84), (10, 38)])
    for pts in ([(10, 38), (86, 38)], [(38, 38), (48, 84)], [(58, 38), (48, 84)], [(38, 38), (30, 18)], [(58, 38), (66, 18)]): line(d, pts, 3, 0)
@icon
def trophy(d):
    poly(d, [(26, 16), (70, 16), (66, 46), (48, 58), (30, 46)]); rr(d, (42, 56, 54, 70), 2); rr(d, (30, 70, 66, 82), 4)
    arc(d, 24, 32, 12, 90, 270, 5); arc(d, 72, 32, 12, 270, 90, 5)
@icon
def home(d):
    poly(d, [(48, 14), (86, 48), (74, 48), (74, 82), (22, 82), (22, 48), (10, 48)]); rr(d, (40, 56, 56, 82), 3, 0)
@icon
def arrow_right(d): line(d, [(18, 48), (76, 48)], 8); line(d, [(54, 26), (76, 48), (54, 70)], 8)
@icon
def back(d): line(d, [(78, 48), (20, 48)], 8); line(d, [(42, 26), (20, 48), (42, 70)], 8)
@icon
def chevron_right(d): line(d, [(34, 22), (62, 48), (34, 74)], 9)
@icon
def video(d): circ(d, 48, 48, 40); poly(d, [(38, 30), (66, 48), (38, 66)], 0)
@icon
def restore(d):
    arc(d, 50, 50, 30, 40, 340, 8); poly(d, [(14, 26), (36, 30), (22, 50)]); line(d, [(50, 32), (50, 50), (64, 58)], 6)
@icon
def trash(d):
    rr(d, (24, 30, 72, 82), 7); rr(d, (16, 20, 80, 30), 4); rr(d, (38, 12, 58, 22), 4)
    for x in (38, 48, 58): line(d, [(x, 40), (x, 72)], 4, 0)
@icon
def wallet(d):
    rr(d, (14, 26, 82, 78), 10); rr(d, (50, 42, 82, 62), 8, 0); circ(d, 62, 52, 5); rr(d, (18, 18, 60, 30), 5)
@icon
def sound(d):
    poly(d, [(16, 38), (32, 38), (52, 22), (52, 74), (32, 58), (16, 58)]); arc(d, 52, 48, 16, -50, 50, 6); arc(d, 52, 48, 28, -50, 50, 6)
@icon
def music(d):
    line(d, [(38, 66), (38, 22), (70, 14), (70, 58)], 8); circ(d, 30, 68, 12); circ(d, 62, 60, 12)
@icon
def vibrate(d):
    rr(d, (32, 14, 64, 82), 8); rr(d, (37, 22, 59, 66), 2, 0); circ(d, 48, 74, 3, 0)
    line(d, [(20, 34), (20, 62)], 5); line(d, [(10, 42), (10, 54)], 5); line(d, [(76, 34), (76, 62)], 5); line(d, [(86, 42), (86, 54)], 5)
@icon
def plus(d): line(d, [(48, 20), (48, 76)], 9); line(d, [(20, 48), (76, 48)], 9)
@icon
def close(d): line(d, [(24, 24), (72, 72)], 9); line(d, [(72, 24), (24, 72)], 9)
@icon
def check(d): line(d, [(20, 50), (40, 70), (76, 28)], 10)
@icon
def camera(d):
    rr(d, (12, 28, 84, 78), 10); rr(d, (30, 18, 50, 30), 4); circ(d, 48, 53, 17, 0); circ(d, 48, 53, 11); circ(d, 72, 38, 4, 0)
@icon
def tube(d):
    rr(d, (30, 12, 66, 86), 18); rr(d, (38, 20, 58, 78), 10, 0); rr(d, (38, 46, 58, 78), 10); rr(d, (25, 8, 71, 20), 6)
@icon
def ad_free(d):
    circ(d, 48, 48, 38); circ(d, 48, 48, 30, 0); line(d, [(24, 72), (72, 24)], 8)
@icon
def moves(d):
    line(d, [(20, 60), (48, 32), (76, 60)], 9); line(d, [(20, 78), (48, 50), (76, 78)], 9)

for name, fn in icons.items():
    im, d = canvas(); fn(d); save_icon(name, im)

# ── Gradient pill buttons (9-slice, r=64) ────────────────────────────────────
def pill(name, c0, c1, w=256, h=128, alpha=240):
    r = h//2; k = 3
    W, H = w*k, h*k
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx = np.clip(xx, r*k, W-r*k); cy = H/2
    dist = np.sqrt((xx-cx)**2 + (yy-cy)**2)
    inside = np.clip((r*k - dist)/1.5 + 0.5, 0, 1)
    t = xx/W
    c0 = np.array(c0, np.float32); c1 = np.array(c1, np.float32)
    rgb = c0[None, None, :]*(1-t[..., None]) + c1[None, None, :]*t[..., None]
    v = yy/H
    gloss = np.clip(1 - v*2.1, 0, 1)[..., None]*0.18
    shade = np.clip((v-0.62)/0.38, 0, 1)[..., None]*0.16
    rgb = rgb + (255-rgb)*gloss - rgb*shade
    edge = np.clip((dist-(r*k-3*k))/ (1.5*k), 0, 1)*inside
    rgb = rgb*(1-edge[..., None]*0.35) + 255*edge[..., None]*0.35
    a = inside*alpha
    img = np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8)
    Image.fromarray(img, "RGBA").resize((w, h), Image.LANCZOS).save(os.path.join(ROOT, "ui", name + ".png"))

pill("btn_pink",   (196, 59, 224), (172, 70, 208))
pill("btn_blue",   (63, 128, 232), (55, 110, 200))
pill("btn_gold",   (232, 194, 67), (199, 167, 66))
pill("btn_green",  (46, 190, 120), (34, 150, 110))
pill("btn_purple", (120, 70, 230), (92, 60, 200))
pill("btn_red",    (226, 70, 90),  (190, 50, 80))

# ── 3D textures ───────────────────────────────────────────────────────────────
rng = np.random.default_rng(7)
def noise(w, h, scale_x, scale_y):
    small = rng.random((max(2, h//scale_y), max(2, w//scale_x))).astype(np.float32)
    im = Image.fromarray((small*255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im, np.float32)/255.0

def wood(name, size=512):
    h = w = size
    y = np.arange(h)[:, None]
    plank = 128
    idx = y // plank
    seed = (idx*37 % 7)/7.0
    grain = 0.55*noise(w, h, 128, 3) + 0.30*noise(w, h, 40, 2) + 0.15*noise(w, h, 12, 1)
    rings = 0.5 + 0.5*np.sin((y % plank)*0.18 + noise(w, h, 90, 8)*6 + seed*10)
    base = np.array([112, 70, 38], np.float32)
    tone = 0.62 + 0.45*grain*0.8 + 0.18*rings*0.5 + (seed-0.5)*0.22
    img = base[None, None, :]*tone[..., None]
    seam = (np.abs((y % plank) - 0) < 3) | (np.abs((y % plank) - (plank-1)) < 2)
    img = np.where(seam[..., None], img*0.35, img)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(os.path.join(ROOT, "textures", name + ".png"))

def velvet(name, size=256):
    n = 0.6*noise(size, size, 3, 3) + 0.4*noise(size, size, 1, 1)
    yy, xx = np.mgrid[0:size, 0:size]
    dia = 0.5 + 0.5*np.sin((xx+yy)*0.35)*np.sin((xx-yy)*0.35)
    base = np.array([26, 30, 92], np.float32)
    img = base[None, None, :]*(0.85 + 0.30*n[..., None] + 0.10*dia[..., None])
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(os.path.join(ROOT, "textures", name + ".png"))

def rune_rug(name, size=1024):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = size/2; dx, dy = xx-c, yy-c
    r = np.sqrt(dx*dx+dy*dy)/c; ang = np.arctan2(dy, dx)
    img = np.zeros((size, size, 4), np.float32)
    base = np.array([16, 18, 52], np.float32)
    inside = np.clip((0.98-r)/0.02, 0, 1)
    img[..., :3] = base*(0.8+0.4*noise(size, size, 6, 6)[..., None])
    def ring(r0, w, col, a=1.0):
        m = np.clip(1-np.abs(r-r0)/w, 0, 1)
        for i in range(3): img[..., i] = img[..., i]*(1-m*a) + col[i]*m*a
    gold = (232, 194, 67); teal = (70, 210, 230)
    ring(0.95, 0.012, gold); ring(0.88, 0.006, gold, 0.8); ring(0.58, 0.006, teal, 0.8); ring(0.30, 0.005, teal, 0.6)
    ticks = (np.abs(np.sin(ang*24)) > 0.985) & (r > 0.62) & (r < 0.86)
    img[..., 0] = np.where(ticks, gold[0], img[..., 0]); img[..., 1] = np.where(ticks, gold[1], img[..., 1]); img[..., 2] = np.where(ticks, gold[2], img[..., 2])
    star = (np.abs(np.cos(ang*5.0)) < 0.04+0.02) & (r > 0.1) & (r < 0.56)
    img[..., 0] = np.where(star, teal[0]*0.8, img[..., 0]); img[..., 1] = np.where(star, teal[1]*0.8, img[..., 1]); img[..., 2] = np.where(star, teal[2]*0.8, img[..., 2])
    img[..., 3] = inside*255*0.92
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(ROOT, "textures", name + ".png"))

def backdrop(name, w=2048, h=512):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = yy/h
    top = np.array([12, 14, 44], np.float32); bot = np.array([46, 28, 86], np.float32)
    img = top[None, None, :]*(1-v[..., None]) + bot[None, None, :]*v[..., None]
    img = img*(0.9+0.2*noise(w, h, 24, 24)[..., None])
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB"); d = ImageDraw.Draw(im, "RGBA")
    # stone columns
    for i in range(0, 8):
        x = int(i*w/8 + 20)
        d.rectangle([x-26, 0, x+26, h], fill=(20, 18, 46, 255)); d.rectangle([x-26, 0, x-18, h], fill=(70, 60, 120, 120))
    # arched windows with moonlight
    for i in range(8):
        cx = int(i*w/8 + w/16 + 20); top_y = 70
        d.rounded_rectangle([cx-62, top_y, cx+62, 330], radius=62, fill=(70, 120, 220, 255))
        d.rounded_rectangle([cx-52, top_y+10, cx+52, 320], radius=52, fill=(120, 180, 255, 255))
        d.line([cx, top_y+10, cx, 320], fill=(30, 40, 90, 255), width=5); d.line([cx-52, 180, cx+52, 180], fill=(30, 40, 90, 255), width=5)
        for k in range(6):
            sx = cx + int(rng.integers(-40, 40)); sy = int(rng.integers(90, 300)); d.ellipse([sx-2, sy-2, sx+2, sy+2], fill=(255, 255, 255, 220))
    # shelves with bottles
    for i in range(8):
        cx = int(i*w/8 + w/16 + 20)
        d.rectangle([cx-90, 400, cx+90, 410], fill=(60, 36, 24, 255))
        for k in range(-3, 4):
            bx = cx + k*24; col = [(200, 70, 230, 255), (60, 200, 130, 255), (70, 140, 240, 255), (240, 190, 60, 255)][(k+i) % 4]
            d.rounded_rectangle([bx-8, 372, bx+8, 400], radius=6, fill=col); d.rectangle([bx-3, 360, bx+3, 374], fill=col)
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    a = np.asarray(im, np.float32)
    vign = np.clip(1 - 0.35*((xx/w-0.5)*2)**2, 0.5, 1)[..., None]
    Image.fromarray(np.clip(a*vign*0.75, 0, 255).astype(np.uint8), "RGB").save(os.path.join(ROOT, "textures", name + ".png"))

wood("wood_planks"); velvet("velvet"); rune_rug("rune_rug"); backdrop("lab_backdrop")
print("assets generated:", len(icons), "icons")
