"""Branded, copyright-safe product cards for the shop. Original artwork only:
a gradient, a soft glow, a drawn gem/coin/gift/play icon, and the name."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

S = 3  # supersample
W = H = 800

FONTS = ["/System/Library/Fonts/Avenir Next.ttc",
         "/System/Library/Fonts/HelveticaNeue.ttc",
         "/Library/Fonts/Arial Unicode.ttf"]

def font(size, bold=True):
    for f in FONTS:
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, size, index=(2 if bold and f.endswith('.ttc') else 0))
            except Exception:
                try: return ImageFont.truetype(f, size)
                except Exception: pass
    return ImageFont.load_default()

# category -> (top color, bottom color, accent, label)
THEMES = {
    "mobile-games": ((58, 28, 113), (20, 30, 90), (86, 204, 242), "GAME TOP-UP"),
    "gift-cards":   ((13, 94, 82),  (6, 50, 45),  (250, 204, 21), "GIFT CARD"),
    "premium-apps": ((124, 29, 49), (60, 12, 40), (244, 114, 182),"PREMIUM"),
    "vouchers":     ((124, 60, 18), (70, 34, 8),  (251, 191, 36), "VOUCHER"),
}


# Per-slug look overrides (original art, no third-party logos/characters).
SLUG_THEMES = {
    "pubg-mobile":      ((28,26,20), (8,8,8),   (245,197,60), "PUBG UC"),
    "free-fire":        ((40,16,8),  (90,30,10),(255,138,40), "FREE FIRE"),
    "netflix":          ((30,6,8),   (10,4,6),  (229,9,20),   "NETFLIX"),
    "spotify":          ((10,40,22), (5,20,12), (30,215,96),  "SPOTIFY"),
    "google-play-gift": ((28,30,40), (12,14,22),(66,133,244), "GOOGLE PLAY"),
}

def theme_for(slug, cat):
    if slug in SLUG_THEMES:
        return SLUG_THEMES[slug]
    return THEMES.get(cat, THEMES["mobile-games"])


def lerp(a, b, t): return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def gradient(top, bottom):
    img = Image.new("RGB", (W*S, H*S))
    d = ImageDraw.Draw(img)
    for y in range(H*S):
        d.line([(0, y), (W*S, y)], fill=lerp(top, bottom, y/(H*S)))
    return img

def glow(accent):
    g = Image.new("L", (W*S, H*S), 0)
    d = ImageDraw.Draw(g)
    cx, cy, r = W*S//2, int(H*S*0.42), int(W*S*0.34)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=110)
    g = g.filter(ImageFilter.GaussianBlur(W*S*0.06))
    layer = Image.new("RGB", (W*S, H*S), accent)
    return layer, g

def diamond(d, cx, cy, r, accent):
    light = lerp(accent, (255,255,255), 0.45)
    dark = lerp(accent, (0,0,0), 0.35)
    top = cy - r*0.62; tw = r*0.62; bot = cy + r*0.95
    L=(cx-r, cy-r*0.28); R=(cx+r, cy-r*0.28)
    TL=(cx-tw, top); TR=(cx+tw, top)
    d.polygon([TL, TR, R, L], fill=accent)                 # crown band
    d.polygon([TL, TR, (cx, cy-r*0.28)], fill=light)       # table
    d.polygon([L, R, (cx, bot)], fill=dark)                # pavilion
    d.polygon([L, (cx, cy-r*0.28), (cx, bot)], fill=lerp(accent,(0,0,0),0.15))
    d.polygon([R, (cx, cy-r*0.28), (cx, bot)], fill=accent)
    d.line([TL, (cx, bot)], fill=light, width=S*2)
    d.line([TR, (cx, bot)], fill=light, width=S*2)
    d.polygon([TL, (cx-tw*0.3, top), (cx-r*0.2, cy-r*0.28)], fill=light)

def coin(d, cx, cy, r, accent, text="UC"):
    gold=(250,204,21); dark=(180,120,10)
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=dark)
    d.ellipse([cx-r, cy-r*1.08, cx+r, cy+r*0.92], fill=gold)
    d.ellipse([cx-r*0.74, cy-r*0.82, cx+r*0.74, cy+r*0.66], outline=dark, width=S*4)
    f = font(int(r*0.9))
    tb = d.textbbox((0,0), text, font=f)
    d.text((cx-(tb[2]-tb[0])/2, cy-(tb[3]-tb[1])/2 - tb[1] - r*0.08), text, font=f, fill=dark)

def giftbox(d, cx, cy, r, accent):
    gold=(250,204,21)
    box=[cx-r, cy-r*0.35, cx+r, cy+r]
    d.rounded_rectangle(box, radius=int(r*0.12), fill=lerp(accent,(255,255,255),0.15))
    d.rectangle([cx-r*1.08, cy-r*0.55, cx+r*1.08, cy-r*0.15], fill=gold)  # lid
    d.rectangle([cx-r*0.16, cy-r*0.55, cx+r*0.16, cy+r], fill=gold)       # ribbon v
    # bow
    d.ellipse([cx-r*0.5, cy-r*0.85, cx-r*0.02, cy-r*0.4], fill=gold)
    d.ellipse([cx+r*0.02, cy-r*0.85, cx+r*0.5, cy-r*0.4], fill=gold)

def play(d, cx, cy, r, accent):
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=lerp(accent,(255,255,255),0.12))
    d.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(255,255,255), width=S*5)
    t=r*0.5
    d.polygon([(cx-t*0.7, cy-t), (cx-t*0.7, cy+t), (cx+t, cy)], fill=(255,255,255))

def ticket(d, cx, cy, r, accent):
    gold=(250,204,21)
    d.rounded_rectangle([cx-r, cy-r*0.6, cx+r, cy+r*0.6], radius=int(r*0.14), fill=lerp(accent,(255,255,255),0.15))
    for yy in range(int(cy-r*0.6), int(cy+r*0.6), int(r*0.22)):
        d.ellipse([cx-r*0.06, yy, cx+r*0.06, yy+r*0.12], fill=gold)  # perforation


def crate(d, cx, cy, r, accent, text="UC"):
    gold=(245,197,60); dark=(120,85,15); light=(255,230,140)
    # open lid
    d.polygon([(cx-r, cy-r*0.15),(cx+r, cy-r*0.15),(cx+r*0.8, cy-r*0.75),(cx-r*0.8, cy-r*0.75)], fill=dark)
    # box body
    d.rounded_rectangle([cx-r, cy-r*0.15, cx+r, cy+r*0.85], radius=int(r*0.08), fill=gold)
    d.rectangle([cx-r, cy+r*0.28, cx+r, cy+r*0.5], fill=dark)          # metal band
    d.rectangle([cx-r*0.18, cy+r*0.28, cx+r*0.18, cy+r*0.5], fill=light)
    # UC card popping out
    card=[cx-r*0.5, cy-r*1.15, cx+r*0.5, cy-r*0.25]
    d.rounded_rectangle(card, radius=int(r*0.1), fill=(30,30,30))
    d.rounded_rectangle(card, radius=int(r*0.1), outline=gold, width=S*3)
    f=font(int(r*0.5))
    tb=d.textbbox((0,0),text,font=f)
    d.text((cx-(tb[2]-tb[0])/2, cy-r*0.85-tb[1]-(tb[3]-tb[1])/2), text, font=f, fill=gold)

def flame(d, cx, cy, r, accent):
    red=(220,50,20); orange=(255,140,40); yellow=(255,215,80)
    d.polygon([(cx,cy-r),(cx+r*0.7,cy+r*0.2),(cx+r*0.5,cy+r*0.8),(cx-r*0.5,cy+r*0.8),(cx-r*0.7,cy+r*0.2)], fill=red)
    d.polygon([(cx,cy-r*0.55),(cx+r*0.45,cy+r*0.25),(cx+r*0.3,cy+r*0.7),(cx-r*0.3,cy+r*0.7),(cx-r*0.45,cy+r*0.25)], fill=orange)
    d.polygon([(cx,cy-r*0.1),(cx+r*0.22,cy+r*0.35),(cx,cy+r*0.65),(cx-r*0.22,cy+r*0.35)], fill=yellow)
    # small diamond spark
    diamond(d, cx+r*0.55, cy-r*0.5, r*0.26, (120,220,255))

def pick_icon(slug, cat):
    s = slug.lower()
    if "pubg" in s: return ("crate", "UC")
    if "free-fire" in s or "freefire" in s: return ("flame", None)
    if cat == "gift-cards": return ("gift", None)
    if cat == "premium-apps": return ("play", None)
    if cat == "vouchers": return ("ticket", None)
    return ("diamond", None)

def make_card(name, cat, slug, out):
    top, bottom, accent, label = theme_for(slug, cat)
    img = gradient(top, bottom).convert("RGB")
    layer, mask = glow(accent)
    img = Image.composite(layer, img, mask)
    d = ImageDraw.Draw(img)
    cx, cy, r = W*S//2, int(H*S*0.40), int(W*S*0.20)
    kind, txt = pick_icon(slug, cat)
    {"diamond":diamond,"coin":lambda *a: coin(*a, text=txt or "UC"),
     "crate":lambda *a: crate(*a, text=txt or "UC"),"flame":flame,
     "gift":giftbox,"play":play,"ticket":ticket}[kind](d, cx, cy, r, accent)

    # category chip
    cf = font(int(30*S))
    tb = d.textbbox((0,0), label, font=cf); tw=tb[2]-tb[0]
    chip=[W*S//2-tw//2-24*S, 60*S, W*S//2+tw//2+24*S, 60*S+58*S]
    d.rounded_rectangle(chip, radius=29*S, fill=(255,255,255,40), outline=accent, width=S*2)
    d.text((W*S//2-tw//2, 60*S+12*S), label, font=cf, fill=accent)

    # name (wrap to 2 lines)
    words=name.split(); lines=[]; cur=""
    nf=font(int(62*S))
    for w in words:
        t=(cur+" "+w).strip()
        if d.textbbox((0,0),t,font=nf)[2] > W*S*0.86 and cur:
            lines.append(cur); cur=w
        else: cur=t
    if cur: lines.append(cur)
    lines=lines[:2]
    y=int(H*S*0.68)
    for ln in lines:
        tb=d.textbbox((0,0),ln,font=nf); tw=tb[2]-tb[0]
        d.text((W*S//2-tw//2+2*S, y+2*S), ln, font=nf, fill=(0,0,0))
        d.text((W*S//2-tw//2, y), ln, font=nf, fill=(255,255,255))
        y += int(74*S)

    # brand
    bf=font(int(28*S))
    d.text((W*S//2 - d.textbbox((0,0),"GAME STORE",font=bf)[2]//2, H*S-70*S),
           "GAME STORE", font=bf, fill=lerp(accent,(255,255,255),0.3))

    img = img.resize((W, H), Image.LANCZOS)
    img.save(out, "PNG")

if __name__ == "__main__":
    samples = [
        ("Mobile Legends: Bang Bang", "mobile-games", "mlbb"),
        ("PUBG Mobile", "mobile-games", "pubg-mobile"),
        ("Google Play Gift Card", "gift-cards", "google-play-gift"),
        ("Netflix Premium", "premium-apps", "netflix"),
    ]
    for n,c,s in samples:
        make_card(n,c,s, f"/tmp/artwork/{s}.png")
        print("made", s)


def make_banner(name, cat, slug, out):
    """Wide 1280x512 hero for the product page: icon left, name right."""
    BW, BH = 1280, 512
    top, bottom, accent, label = theme_for(slug, cat)
    big = Image.new("RGB", (BW*2, BH*2))
    dd = ImageDraw.Draw(big)
    for y in range(BH*2):
        dd.line([(0, y), (BW*2, y)], fill=lerp(top, bottom, y/(BH*2)))
    # glow behind icon (left third)
    g = Image.new("L", (BW*2, BH*2), 0)
    gd = ImageDraw.Draw(g)
    cx, cy, r = int(BW*2*0.24), BH, int(BH*2*0.30)
    gd.ellipse([cx-r, cy-r, cx+r, cy+r], fill=120)
    g = g.filter(ImageFilter.GaussianBlur(BW*2*0.05))
    big = Image.composite(Image.new("RGB", (BW*2, BH*2), accent), big, g)
    d = ImageDraw.Draw(big)
    kind, txt = pick_icon(slug, cat)
    {"diamond": diamond, "coin": lambda *a: coin(*a, text=txt or "UC"),
     "crate": lambda *a: crate(*a, text=txt or "UC"), "flame": flame,
     "gift": giftbox, "play": play, "ticket": ticket}[kind](d, cx, cy, r, accent)
    # name on the right
    words = name.split(); lines=[]; cur=""
    nf = font(int(74*2))
    rx = int(BW*2*0.46)
    for w in words:
        t=(cur+" "+w).strip()
        if d.textbbox((0,0),t,font=nf)[2] > BW*2 - rx - 60 and cur:
            lines.append(cur); cur=w
        else: cur=t
    if cur: lines.append(cur)
    lines=lines[:3]
    ch=font(int(30*2))
    d.text((rx, BH*2*0.30 - 70), label, font=ch, fill=accent)
    y=int(BH*2*0.30)
    for ln in lines:
        d.text((rx+3, y+3), ln, font=nf, fill=(0,0,0))
        d.text((rx, y), ln, font=nf, fill=(255,255,255))
        y+=int(88*2)
    big.resize((BW, BH), Image.LANCZOS).save(out, "PNG")


def make_hero(name, artwork_path, out, accent=(77, 141, 255)):
    """Compose a wide slide from a product's own artwork.

    The artwork is usually square, so a slide that simply contained it was
    mostly empty. Here a blurred, darkened copy fills the canvas and the
    artwork sits on top at its own aspect ratio, with the name beside it.
    """
    W, H = 1280, 512
    art = Image.open(artwork_path).convert("RGB")

    # Backdrop: the artwork blown up to cover, blurred and darkened.
    scale = max(W / art.width, H / art.height)
    back = art.resize((int(art.width * scale), int(art.height * scale)), Image.LANCZOS)
    left = (back.width - W) // 2
    top = (back.height - H) // 2
    back = back.crop((left, top, left + W, top + H))
    back = back.filter(ImageFilter.GaussianBlur(28))
    back = Image.blend(back, Image.new("RGB", (W, H), (7, 11, 26)), 0.55)

    # Artwork at its own ratio, on the left.
    box = int(H * 0.72)
    fit = min(box / art.width, box / art.height)
    art = art.resize((int(art.width * fit), int(art.height * fit)), Image.LANCZOS)
    ax = int(W * 0.16) - art.width // 2
    ay = (H - art.height) // 2
    back.paste(art, (max(ax, 24), ay))

    d = ImageDraw.Draw(back)
    words = name.split()
    lines, cur = [], ""
    nf = font(58)
    tx = int(W * 0.34)
    for w in words:
        t = (cur + " " + w).strip()
        if d.textbbox((0, 0), t, font=nf)[2] > W - tx - 60 and cur:
            lines.append(cur); cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    lines = lines[:3]
    y = (H - len(lines) * 70) // 2
    for ln in lines:
        d.text((tx + 2, y + 2), ln, font=nf, fill=(0, 0, 0))
        d.text((tx, y), ln, font=nf, fill=(255, 255, 255))
        y += 70
    back.save(out, "PNG")
