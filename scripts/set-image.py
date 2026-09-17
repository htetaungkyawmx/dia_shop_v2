#!/usr/bin/env python3
"""
Set a product's card image (and optionally its wide banner) from image files on
your computer. Use this to put your own artwork - supplier art, a Canva design,
or brand images you are allowed to use - onto a product.

    python3 scripts/set-image.py <api> <email> <password> <product-slug> <card.png> [banner.png]

Example:
    python3 scripts/set-image.py https://api.hk-game-shop.store you@mail.com 'pass' \
        pubg-mobile ~/Desktop/pubg.png ~/Desktop/pubg-wide.png

The image can be PNG / JPG / WEBP. Square (~800x800) works best for the card;
wide (~1280x512) for the banner. You are responsible for having the right to
use any image you upload.
"""
import json, os, sys, uuid
from urllib import error, request


def call(base, method, path, tok=None, body=None):
    data = None if body is None else json.dumps(body).encode()
    r = request.Request(base + path, data=data, method=method)
    r.add_header("Accept", "application/json")
    if data is not None: r.add_header("Content-Type", "application/json")
    if tok: r.add_header("Authorization", "Bearer " + tok)
    try:
        with request.urlopen(r, timeout=60) as x:
            raw = x.read(); return json.loads(raw) if raw else None
    except error.HTTPError as e:
        raise SystemExit(f"{method} {path} failed: {e.code} {e.read().decode()[:200]}")


def upload(base, tok, path, folder):
    ext = os.path.splitext(path)[1].lower().lstrip(".")
    mime = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
            "webp": "image/webp"}.get(ext, "application/octet-stream")
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
            f"filename=\"{os.path.basename(path)}\"\r\nContent-Type: {mime}\r\n\r\n"
            ).encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    r = request.Request(f"{base}/admin/uploads/image?folder={folder}", data=body, method="POST")
    r.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    r.add_header("Authorization", "Bearer " + tok)
    with request.urlopen(r, timeout=120) as x:
        return json.loads(x.read())["url"]


def main():
    if len(sys.argv) < 6:
        raise SystemExit(__doc__)
    api, email, password, slug, card = sys.argv[1:6]
    banner = sys.argv[6] if len(sys.argv) > 6 else None
    for f in [card] + ([banner] if banner else []):
        if not os.path.exists(f):
            raise SystemExit(f"File not found: {f}")
    base = api.rstrip("/") + "/api/v1"
    tok = call(base, "POST", "/auth/login", body={"email": email, "password": password})["accessToken"]

    products = {p["slug"]: p for p in call(base, "GET", "/admin/products?size=200", tok)["items"]}
    p = products.get(slug)
    if not p:
        raise SystemExit(f"Product '{slug}' not found.")
    d = call(base, "GET", f"/admin/products/{p['id']}", tok)
    image_url = upload(base, tok, card, "catalog")
    banner_url = upload(base, tok, banner, "banners") if banner else d.get("bannerUrl")
    body = {
        "categoryId": d["categoryId"], "slug": d["slug"], "name": d["name"], "nameMy": d.get("nameMy"),
        "description": d.get("description"), "descriptionMy": d.get("descriptionMy"),
        "imageUrl": image_url, "bannerUrl": banner_url, "instructions": d.get("instructions"),
        "instructionsMy": d.get("instructionsMy"), "fulfillmentType": d["fulfillmentType"],
        "featured": d["featured"], "sortOrder": d["sortOrder"], "active": d["active"],
        "supplierGame": d.get("supplierGame"),
        "fields": [{**{k: f.get(k) for k in ("id","key","label","labelMy","placeholder",
                    "helpText","inputType","validationRegex","required")},
                    "options": f.get("options") or [], "sortOrder": i}
                   for i, f in enumerate(d.get("fields", []))],
    }
    call(base, "PUT", f"/admin/products/{p['id']}", tok, body)
    print(f"✓ {slug}: image updated" + (" (+ banner)" if banner else ""))


if __name__ == "__main__":
    main()
