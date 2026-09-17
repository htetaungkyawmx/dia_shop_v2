#!/usr/bin/env python3
"""
Rebuild the home slides as wide banners composed from each product's artwork.

    python3 scripts/make-hero-banners.py <api> <email> <password>

A product image is square, so a slide that contained it was mostly empty space.
Each slide is redrawn at 1280x512: a blurred, darkened copy of the artwork fills
the canvas, the artwork sits on it at its own ratio, and the name goes beside it.
"""
import json, os, sys, tempfile, uuid
from urllib import error, request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artwork_gen as art


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

    products = {p["slug"]: p for p in call(base, "GET", "/admin/products?size=200", tok)["items"]}
    # The admin product list carries a category id, not its slug.
    cat_id = {c["slug"]: c["id"] for c in call(base, "GET", "/admin/categories", tok)}
    banners = call(base, "GET", "/admin/banners", tok)
    tmp = tempfile.mkdtemp()
    done = 0

    for order, b in enumerate(banners, start=1):
        title = b.get("title") or ""
        source = None
        if b.get("linkType") == "PRODUCT":
            p = products.get(b.get("linkValue"))
            source = p.get("imageUrl") if p else None
        elif b.get("linkType") == "CATEGORY":
            # A category slide borrows the artwork of a product inside it,
            # rather than rendering as an empty panel.
            wanted = cat_id.get(b.get("linkValue"))
            source = next((p["imageUrl"] for p in products.values()
                           if p.get("categoryId") == wanted and p.get("imageUrl")),
                          None)
        if not source:
            print(f"  skip {title}: no artwork to compose from")
            continue
        raw = os.path.join(tmp, "src.img")
        with request.urlopen(source, timeout=60) as r, open(raw, "wb") as f:
            f.write(r.read())
        out = os.path.join(tmp, f"hero-{order}.png")
        art.make_hero(title, raw, out)
        url = upload(base, tok, out)
        call(base, "PUT", f"/admin/banners/{b['id']}", tok, {
            "title": title, "imageUrl": url,
            "linkType": b.get("linkType") or "NONE",
            "linkValue": b.get("linkValue"),
            "sortOrder": order, "active": True,
        })
        print(f"  ✓ {title}")
        done += 1
    print(f"done - {done} slide(s) rebuilt")


if __name__ == "__main__":
    main()
