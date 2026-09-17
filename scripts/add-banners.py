#!/usr/bin/env python3
"""
Fill the home slideshow with more slides, using original generated artwork.

    python3 scripts/add-banners.py https://api.hk-game-shop.store admin@mail.com 'password'

Idempotent: a banner whose title already exists is skipped. Artwork is drawn by
artwork_gen (gradient + gem/coin/gift/play icon), so no third-party art is used.
"""
import json, os, sys, tempfile, uuid
from urllib import error, request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artwork_gen as art

# (title, category-for-theme, slug-for-icon, linkType, linkValue, sortOrder)
SLIDES = [
    ("PUBG Mobile",   "mobile-games", "pubg-mobile",      "PRODUCT",  "pubg-mobile",    3),
    ("Free Fire",     "mobile-games", "free-fire",        "PRODUCT",  "free-fire",      4),
    ("Genshin Impact","mobile-games", "genshin-impact",   "PRODUCT",  "genshin-impact", 5),
    ("Gift Cards",    "gift-cards",   "gift-cards",       "CATEGORY", "gift-cards",     6),
    ("Premium Apps",  "premium-apps", "premium-apps",     "CATEGORY", "premium-apps",   7),
]


def call(base, method, path, tok=None, body=None):
    data = None if body is None else json.dumps(body).encode()
    r = request.Request(base + path, data=data, method=method)
    r.add_header("Accept", "application/json")
    if data is not None:
        r.add_header("Content-Type", "application/json")
    if tok:
        r.add_header("Authorization", "Bearer " + tok)
    try:
        with request.urlopen(r, timeout=60) as x:
            raw = x.read()
            return json.loads(raw) if raw else None
    except error.HTTPError as e:
        raise SystemExit(f"{method} {path} failed: {e.code} {e.read().decode()[:300]}")


def upload(base, tok, path):
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
            f"filename=\"{os.path.basename(path)}\"\r\nContent-Type: image/png\r\n\r\n"
            ).encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    r = request.Request(f"{base}/admin/uploads/image?folder=banners", data=body, method="POST")
    r.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    r.add_header("Authorization", "Bearer " + tok)
    with request.urlopen(r, timeout=120) as x:
        return json.loads(x.read())["url"]


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    base = sys.argv[1].rstrip("/") + "/api/v1"
    tok = call(base, "POST", "/auth/login",
               body={"email": sys.argv[2], "password": sys.argv[3]})["accessToken"]
    print("signed in")

    have = {b.get("title") for b in call(base, "GET", "/admin/banners", tok)}
    tmp = tempfile.mkdtemp()
    added = 0
    for title, cat, slug, link_type, link_value, order in SLIDES:
        if title in have:
            print(f"  {title}: already a slide")
            continue
        path = os.path.join(tmp, f"{slug}-banner.png")
        art.make_banner(title, cat, slug, path)
        url = upload(base, tok, path)
        call(base, "POST", "/admin/banners", tok, {
            "title": title, "imageUrl": url, "linkType": link_type,
            "linkValue": link_value, "sortOrder": order, "active": True,
        })
        print(f"  + slide: {title}  ->  {link_type}:{link_value}")
        added += 1
    print(f"done - {added} slide(s) added")


if __name__ == "__main__":
    main()
