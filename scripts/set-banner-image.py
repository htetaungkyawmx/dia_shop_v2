#!/usr/bin/env python3
"""
Put your own artwork on the home slideshow.

Reuse the artwork already on each product (no files needed):
    python3 scripts/set-banner-image.py <api> <email> <password> --from-products

Or set one slide from an image on your computer:
    python3 scripts/set-banner-image.py <api> <email> <password> "PUBG Mobile" ~/Desktop/pubg.png

List the slides:
    python3 scripts/set-banner-image.py <api> <email> <password> --list

Note: the banner API does not return a slide's active flag or sort order, so
every update re-sends active=true and keeps the slides in their current order.
"""
import json, os, sys, uuid
from urllib import error, request


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
    ext = os.path.splitext(path)[1].lower().lstrip(".")
    mime = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
            "webp": "image/webp"}.get(ext, "application/octet-stream")
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
            f"filename=\"{os.path.basename(path)}\"\r\nContent-Type: {mime}\r\n\r\n"
            ).encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    r = request.Request(f"{base}/admin/uploads/image?folder=banners", data=body, method="POST")
    r.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    r.add_header("Authorization", "Bearer " + tok)
    with request.urlopen(r, timeout=120) as x:
        return json.loads(x.read())["url"]


def save(base, tok, banner, image_url, order):
    call(base, "PUT", f"/admin/banners/{banner['id']}", tok, {
        "title": banner.get("title"), "imageUrl": image_url,
        "linkType": banner.get("linkType") or "NONE",
        "linkValue": banner.get("linkValue"),
        "sortOrder": order, "active": True,
    })


def main():
    if len(sys.argv) < 5:
        raise SystemExit(__doc__)
    base = sys.argv[1].rstrip("/") + "/api/v1"
    tok = call(base, "POST", "/auth/login",
               body={"email": sys.argv[2], "password": sys.argv[3]})["accessToken"]
    banners = call(base, "GET", "/admin/banners", tok)

    if sys.argv[4] == "--list":
        for i, b in enumerate(banners, start=1):
            print(f"  {i}. {b.get('title'):26} {b.get('linkType')}:{b.get('linkValue')}")
        return

    if sys.argv[4] == "--from-products":
        products = {p["slug"]: p for p in call(base, "GET", "/admin/products?size=200", tok)["items"]}
        done = 0
        for order, b in enumerate(banners, start=1):
            if b.get("linkType") != "PRODUCT":
                print(f"  skip {b.get('title')}: not linked to a product")
                continue
            p = products.get(b.get("linkValue"))
            if not p or not p.get("imageUrl"):
                print(f"  skip {b.get('title')}: that product has no image")
                continue
            save(base, tok, b, p["imageUrl"], order)
            print(f"  ✓ {b.get('title')}: now uses the {p['slug']} artwork")
            done += 1
        print(f"done - {done} slide(s) updated")
        return

    if len(sys.argv) < 6:
        raise SystemExit(__doc__)
    title, path = sys.argv[4], sys.argv[5]
    if not os.path.exists(path):
        raise SystemExit(f"File not found: {path}")
    match = next((b for b in banners if (b.get("title") or "").lower() == title.lower()), None)
    if not match:
        raise SystemExit(f"No slide titled {title!r}. Run with --list to see them.")
    order = banners.index(match) + 1
    save(base, tok, match, upload(base, tok, path), order)
    print(f"✓ {title}: image updated")


if __name__ == "__main__":
    main()
